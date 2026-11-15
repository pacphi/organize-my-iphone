import Foundation
import OrganizeAdapters
import OrganizeCore

/// The steps of a run. Each command calls the steps it needs; `run` calls them all in order.
/// The steps only wire library pieces together and report progress, so the logic worth
/// testing lives in OrganizeCore and OrganizeAdapters.
enum Pipeline {
    // MARK: Scan

    static func scan(device: any DeviceClient, ecid: String?, workspace: Workspace, now: Date = Date()) async throws
        -> ScanSnapshot
    {
        let snapshot: ScanSnapshot = try await Console.step("Read apps and Home Screen layout from the iPhone") {
            let devices = try await device.listDevices()
            let target = try DeviceSelector.select(from: devices, ecid: ecid)
            Console.detail(target.name)

            let layout = try await device.iconLayout(ecid: target.ecid)
            let apps = try await device.installedApps(ecid: target.ecid)
            return ScanSnapshot(device: target, scannedAt: now, installedApps: apps, layout: layout)
        }

        try workspace.write(snapshot, to: workspace.scanURL)
        let backup = try workspace.saveBackup(snapshot.layout, reason: .scan, at: now)
        Console.say(
            "  Found \(snapshot.layout.appBundleIDs.count) app icons on \(snapshot.layout.pages.count) page(s) "
                + "with \(snapshot.layout.folders.count) folder(s)."
        )
        Console.say("  Layout backed up to \(backup.path)")
        return snapshot
    }

    static func loadScan(_ workspace: Workspace) throws -> ScanSnapshot {
        guard workspace.exists(workspace.scanURL) else {
            throw UserError("No scan found in \(workspace.root.path). Run `organize-my-iphone scan` first.")
        }
        return try workspace.read(ScanSnapshot.self, from: workspace.scanURL)
    }

    // MARK: Enrich

    static func loadMetadata(_ workspace: Workspace) -> MetadataCache {
        (try? workspace.read(MetadataCache.self, from: workspace.metadataURL)) ?? MetadataCache()
    }

    /// Looks up App Store details for apps not already cached.
    static func enrich(workspace: Workspace, snapshot: ScanSnapshot, country: String, refresh: Bool) async throws {
        var cache = refresh ? MetadataCache() : loadMetadata(workspace)
        let known = Set(cache.entries.keys).union(cache.notFound)
        var seen: Set<String> = []
        var wanted: [String] = []
        for bundleID in snapshot.layout.appBundleIDs where !known.contains(bundleID) {
            if seen.insert(bundleID).inserted {
                wanted.append(bundleID)
            }
        }
        guard !wanted.isEmpty else {
            Console.say("✓ App Store details are already cached")
            return
        }

        let lookups = wanted
        let found = try await Console.step("Look up \(lookups.count) app(s) in the App Store") {
            try await AppStoreLookupClient(country: country).lookup(bundleIDs: lookups)
        }
        for (bundleID, metadata) in found {
            cache.entries[bundleID] = metadata
        }
        cache.notFound.append(contentsOf: wanted.filter { found[$0] == nil })
        try workspace.write(cache, to: workspace.metadataURL)
        Console.say("  Found \(found.count) of \(wanted.count).")
    }

    /// One record per app icon, merged from the scan, the cache and the built-in tables.
    static func catalog(workspace: Workspace, snapshot: ScanSnapshot) -> [AppRecord] {
        AppCatalog.records(
            for: snapshot.layout.appBundleIDs,
            installed: snapshot.installedApps,
            store: loadMetadata(workspace).entries
        )
    }

    // MARK: Icon colors

    static func loadStoreColors(_ workspace: Workspace) -> StoreIconColors {
        (try? workspace.read(StoreIconColors.self, from: workspace.storeIconColorsURL)) ?? StoreIconColors()
    }

    /// Downloads the App Store icon of every app that has no color yet and finds its main color.
    /// Opt-in: contacts Apple's image server. Results are cached in the workspace.
    static func sampleStoreIconColors(
        workspace: Workspace,
        snapshot: ScanSnapshot,
        country: String,
        refresh: Bool
    ) async throws {
        var store = refresh ? StoreIconColors() : loadStoreColors(workspace)
        var cache = loadMetadata(workspace)
        let done = Set(store.colors.keys).union(store.failed)
        var seen: Set<String> = []
        let wanted = snapshot.layout.appBundleIDs.filter { !done.contains($0) && seen.insert($0).inserted }
        guard !wanted.isEmpty else {
            Console.say("✓ Icon colors from the App Store are already cached")
            return
        }

        // Caches made before icon links were kept need one more lookup for those apps.
        let needLinks = wanted.filter { cache.entries[$0] != nil && cache.entries[$0]?.artworkURL == nil }
        if !needLinks.isEmpty {
            let found = try await Console.step("Look up icon links for \(needLinks.count) app(s)") {
                try await AppStoreLookupClient(country: country).lookup(bundleIDs: needLinks)
            }
            for (bundleID, metadata) in found {
                cache.entries[bundleID] = metadata
            }
            try workspace.write(cache, to: workspace.metadataURL)
        }

        var artwork: [String: String] = [:]
        for bundleID in wanted {
            if let link = cache.entries[bundleID]?.artworkURL {
                artwork[bundleID] = link
            }
        }
        guard !artwork.isEmpty else {
            Console.say("- No App Store icon links for these apps. Run `enrich` first.")
            return
        }

        let jobs = artwork
        let colors = try await Console.step("Find the main color of \(jobs.count) App Store icon(s)") {
            await IconColorSampler().sample(artwork: jobs) { finished, total in
                Console.detail("\(finished)/\(total) icons")
            }
        }
        for (bundleID, color) in colors {
            store.colors[bundleID] = color.hex
        }
        store.failed.append(contentsOf: jobs.keys.filter { colors[$0] == nil }.sorted())
        try workspace.write(store, to: workspace.storeIconColorsURL)
        Console.say("  Found colors for \(colors.count) of \(jobs.count). Check them on colors.html after `preview`.")
    }

    // MARK: Classify

    /// What will sort the apps into categories, decided up front so a model can load in the
    /// background while the phone is being read.
    enum Engine: Sendable {
        /// Built-in rules only.
        case rules
        /// Apple's on-device model.
        case apple(any TextCompletionModel)
        /// A model served by Ollama. `warmup` finishes when the model is in memory.
        case ollama(OllamaModel, warmup: Task<Void, any Error>)
    }

    /// Chooses the engine and says which one, and why. For Ollama this also starts loading the
    /// model straight away, without waiting for it: loading takes seconds to a minute, and that
    /// time is better spent overlapping the scan and the App Store lookup than added to them.
    static func chooseEngine(_ options: ClassifyOptions) async throws -> Engine {
        switch options.engine {
        case .heuristic:
            Console.say("✓ Engine: built-in rules")
            return .rules
        case .ollama:
            return try await ollamaEngine(options)
        case .apple:
            guard let model = AppleIntelligence.makeOnDeviceModel() else {
                throw UserError(
                    "Apple's on-device model is not available on this Mac. It needs macOS 26 or later with "
                        + "Apple Intelligence turned on and its model downloaded."
                )
            }
            Console.say("✓ Engine: Apple's on-device model")
            return .apple(model)
        case .auto:
            do {
                return try await ollamaEngine(options)
            } catch {
                Console.say("- Ollama not used: \(error.localizedDescription)")
            }
            return fallbackEngine()
        }
    }

    /// The best engine that needs no Ollama: Apple's model if this Mac has it, else rules.
    static func fallbackEngine() -> Engine {
        if let model = AppleIntelligence.makeOnDeviceModel() {
            Console.say("✓ Engine: Apple's on-device model")
            return .apple(model)
        }
        Console.say("✓ Engine: built-in rules (no local model available)")
        return .rules
    }

    /// Finds the Ollama server, picks a model that can chat, and starts loading it.
    static func ollamaEngine(_ options: ClassifyOptions) async throws -> Engine {
        guard let baseURL = URL(string: options.ollamaURL) else {
            throw UserError("--ollama-url is not a valid URL: \(options.ollamaURL)")
        }

        let installed: [String]
        do {
            installed = try await OllamaModel.installedModels(baseURL: baseURL)
        } catch {
            throw UserError(
                "Ollama is not answering at \(options.ollamaURL). Open the Ollama app or run `ollama serve`."
            )
        }
        let running = (try? await OllamaModel.runningModels(baseURL: baseURL)) ?? []

        let requested = options.model ?? ProcessInfo.processInfo.environment["OMI_OLLAMA_MODEL"]
        let modelName: String
        if let requested, !requested.isEmpty {
            modelName = requested
        } else if let found = await OllamaModel.chooseChatModel(installed: installed, running: running, baseURL: baseURL) {
            modelName = found
        } else {
            throw UserError("Ollama has no model that can chat. Pull one with `ollama pull <model>`, or pass --model.")
        }

        let model = OllamaModel(name: modelName, baseURL: baseURL)
        let inMemory = running.contains { OllamaModel.canonicalName($0) == OllamaModel.canonicalName(modelName) }
        if inMemory {
            Console.say("✓ Engine: Ollama model \(modelName) (already in memory)")
        } else {
            Console.say("✓ Engine: Ollama model \(modelName) (loading in the background)")
        }
        // Loading a model that is already in memory returns at once and renews its keep-alive.
        let warmup = Task {
            try await model.load()
        }
        return .ollama(model, warmup: warmup)
    }

    /// Sorts every app into a category, in tiers:
    ///
    /// 1. Built-in rules place the apps they are sure about (Apple's own apps, and apps whose
    ///    App Store genre settles it). This is instant.
    /// 2. The model is asked only about the rest, in batches, with progress and time left.
    /// 3. Anything the model does not answer for falls back to the rules.
    ///
    /// With `--thorough` the model is asked about every app.
    static func classify(
        workspace: Workspace,
        records: [AppRecord],
        options: ClassifyOptions,
        taxonomy: Taxonomy,
        engine chosen: Engine,
        now: Date = Date()
    ) async throws -> ClassificationSet {
        var engine = chosen

        // Tier 1: rules.
        let split: TieredClassification.Split
        if case .rules = engine {
            split = TieredClassification.split(records, taxonomy: taxonomy, threshold: 0)
        } else if options.thorough {
            split = TieredClassification.Split(settled: [], undecided: records)
        } else {
            split = TieredClassification.split(records, taxonomy: taxonomy)
        }
        if !split.settled.isEmpty {
            Console.say("✓ Placed \(split.settled.count) app(s) by App Store genre and built-in rules")
        }

        // Tier 2: the model, for whatever is left.
        var judged: [Classification] = []
        var engineName = "heuristic"
        if !split.undecided.isEmpty {
            // Make sure the Ollama model is in memory. This is its own timed step so a cold
            // start is never mistaken for slow classification.
            if case .ollama(let model, let warmup) = engine {
                do {
                    try await Console.step("Load Ollama model \(model.name) into memory") {
                        try await warmup.value
                    }
                } catch {
                    guard options.engine == .auto else {
                        throw error
                    }
                    Console.warn("\(model.name) could not be loaded (\(error.localizedDescription)).")
                    engine = fallbackEngine()
                }
            }

            if let classifier = modelClassifier(for: engine, options: options) {
                do {
                    judged = try await Console.step(
                        "Classify \(split.undecided.count) app(s) with \(classifier.engineName)"
                    ) {
                        try await classifier.classify(split.undecided, taxonomy: taxonomy)
                    }
                    engineName = split.settled.isEmpty ? classifier.engineName : "rules+\(classifier.engineName)"
                } catch {
                    guard options.engine == .auto else {
                        throw error
                    }
                    Console.warn("\(classifier.engineName) failed (\(error.localizedDescription)); using built-in rules.")
                }
            }
        }

        // Tier 3: rules fill any gap.
        let items = TieredClassification.merge(
            order: records,
            settled: split.settled,
            judged: judged,
            taxonomy: taxonomy
        )
        let result = ClassificationSet(engine: engineName, createdAt: now, items: items)
        try workspace.write(result, to: workspace.classificationURL)

        let fallbackCount = items.filter { $0.category == taxonomy.fallback }.count
        Console.say("  \(fallbackCount) of \(items.count) landed in \"\(taxonomy.fallback)\".")
        let unanswered = split.undecided.count - judged.filter { $0.source.hasPrefix("llm:") }.count
        if !judged.isEmpty, unanswered > 0 {
            Console.say("  \(unanswered) app(s) got no usable answer from the model and were placed by rules.")
        }
        return result
    }

    /// The model-backed classifier for an engine, or `nil` for rules.
    static func modelClassifier(for engine: Engine, options: ClassifyOptions) -> LLMClassifier? {
        switch engine {
        case .rules:
            return nil
        case .apple(let model):
            // A small model with a small context window: few apps per request.
            let batchSize = options.batchSize ?? 8
            return LLMClassifier(model: model, batchSize: batchSize, onProgress: progressReporter(batchSize: batchSize))
        case .ollama(let model, _):
            let batchSize = options.batchSize ?? 25
            return LLMClassifier(model: model, batchSize: batchSize, onProgress: progressReporter(batchSize: batchSize))
        }
    }

    /// Makes the callback that keeps the classify step's line current as batches come back:
    /// `batch 3/10 · 50/242 apps · about 40s left`.
    static func progressReporter(batchSize: Int) -> @Sendable (Int, Int) -> Void {
        let clock = ContinuousClock()
        let start = clock.now
        return { completed, total in
            let elapsed = ElapsedTime.seconds(clock.now - start)
            Console.detail(
                StatusLine.batchProgress(
                    completed: completed,
                    total: total,
                    batchSize: batchSize,
                    elapsedSeconds: elapsed
                )
            )
        }
    }

    static func loadClassification(_ workspace: Workspace) throws -> ClassificationSet {
        guard workspace.exists(workspace.classificationURL) else {
            throw UserError("No classification found. Run `organize-my-iphone classify` first.")
        }
        return try workspace.read(ClassificationSet.self, from: workspace.classificationURL)
    }

    // MARK: Plan

    static func plan(
        workspace: Workspace,
        snapshot: ScanSnapshot,
        records: [AppRecord],
        classification: ClassificationSet,
        schemes: [OrganizationScheme],
        options: PlanOptions,
        context: PlanContext,
        taxonomy: Taxonomy,
        now: Date = Date()
    ) async throws -> [OrganizationPlan] {
        let names = AppCatalog.names(of: records)
        let plans: [OrganizationPlan] = try await Console.step("Build \(schemes.count) layout proposal(s)") {
            var built: [OrganizationPlan] = []
            for scheme in schemes {
                let plan = PlanBuilder.makePlan(
                    scheme: scheme,
                    current: snapshot.layout,
                    classifications: classification.categoriesByBundleID,
                    names: names,
                    taxonomy: taxonomy,
                    options: options,
                    context: context,
                    now: now
                )
                try workspace.write(plan, to: workspace.planURL(for: scheme))
                built.append(plan)
            }
            return built
        }

        for plan in plans {
            Console.say("")
            Console.say(PlanReport.summary(of: plan, current: snapshot.layout, names: names))
            for issue in LayoutValidator.validate(plan.layout, against: snapshot.layout, grid: options.grid) {
                Console.say("  \(issue.description)")
            }
        }
        Console.say("")
        return plans
    }

    static func loadPlans(_ workspace: Workspace) throws -> [OrganizationPlan] {
        var plans: [OrganizationPlan] = []
        for scheme in OrganizationScheme.allCases where workspace.exists(workspace.planURL(for: scheme)) {
            plans.append(try workspace.read(OrganizationPlan.self, from: workspace.planURL(for: scheme)))
        }
        return plans
    }

    // MARK: Preview

    @discardableResult
    static func preview(
        workspace: Workspace,
        snapshot: ScanSnapshot,
        records: [AppRecord],
        classification: ClassificationSet?,
        plans: [OrganizationPlan],
        colors: IconColorSet = IconColorSet(),
        now: Date = Date()
    ) async throws -> URL {
        let document = PreviewDocument(
            deviceName: snapshot.device.name,
            generatedAt: now,
            names: AppCatalog.names(of: records),
            categories: classification?.categoriesByBundleID ?? [:],
            current: snapshot.layout,
            plans: plans,
            iconColors: colors.merged,
            colorPage: workspace.colorWheelURL.lastPathComponent
        )
        let wheel = ColorWheelRenderer.render(
            deviceName: snapshot.device.name,
            apps: ColorWheelRenderer.apps(
                bundleIDs: snapshot.layout.appBundleIDs,
                names: AppCatalog.names(of: records),
                colors: colors
            ),
            fileColors: colors.file
        )
        try await Console.step("Write the preview page and the icon-color wheel") {
            try workspace.writeText(HTMLPreviewRenderer.render(document), to: workspace.previewURL)
            try workspace.writeText(wheel, to: workspace.colorWheelURL)
        }
        Console.say("  \(workspace.previewURL.path)")
        Console.say("  \(workspace.colorWheelURL.path)")
        return workspace.previewURL
    }

    static func open(_ url: URL) async {
        _ = try? await SubprocessCommandRunner().execute("/usr/bin/open", arguments: [url.path])
    }
}
