import ArgumentParser
import Foundation
import OrganizeAdapters
import OrganizeCore

// The individual steps of `run`, for when you want to redo just one of them.

struct ScanCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Read the installed apps and the Home Screen layout from the phone, and back the layout up."
    )

    @OptionGroup var global: GlobalOptions

    func run() async throws {
        let workspace = global.makeWorkspace()
        let device = try global.makeDeviceClient()
        _ = try await Pipeline.scan(device: device, ecid: global.ecid, workspace: workspace)
    }
}

struct EnrichCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "enrich",
        abstract: "Look up each app's App Store genre and description. Sends bundle identifiers to Apple."
    )

    @OptionGroup var global: GlobalOptions

    @Option(name: .long, help: "App Store storefront to look apps up in.")
    var country: String = "us"

    @Flag(name: .long, help: "Ignore the cache and look every app up again.")
    var refresh = false

    func run() async throws {
        let workspace = global.makeWorkspace()
        let snapshot = try Pipeline.loadScan(workspace)
        try await Pipeline.enrich(workspace: workspace, snapshot: snapshot, country: country, refresh: refresh)
    }
}

struct ClassifyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "classify",
        abstract: "Sort the scanned apps into categories with a local model or built-in rules."
    )

    @OptionGroup var global: GlobalOptions
    @OptionGroup var classifyOptions: ClassifyOptions

    func run() async throws {
        let workspace = global.makeWorkspace()
        let snapshot = try Pipeline.loadScan(workspace)
        let records = Pipeline.catalog(workspace: workspace, snapshot: snapshot)
        let engine = try await Pipeline.chooseEngine(classifyOptions)
        _ = try await Pipeline.classify(
            workspace: workspace,
            records: records,
            options: classifyOptions,
            taxonomy: try global.loadTaxonomy(),
            engine: engine
        )
    }
}

struct PlanCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "plan",
        abstract: "Turn the classification into layout proposals."
    )

    @OptionGroup var global: GlobalOptions
    @OptionGroup var layoutOptions: LayoutOptions

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Build only this scheme. Repeat to build several. Default: all of them.",
            discussion: "`organize-my-iphone schemes` describes each one.",
            valueName: "scheme"
        )
    )
    var scheme: [OrganizationScheme] = []

    func run() async throws {
        let workspace = global.makeWorkspace()
        let snapshot = try Pipeline.loadScan(workspace)
        let records = Pipeline.catalog(workspace: workspace, snapshot: snapshot)
        _ = try await Pipeline.plan(
            workspace: workspace,
            snapshot: snapshot,
            records: records,
            classification: try Pipeline.loadClassification(workspace),
            schemes: scheme.isEmpty ? OrganizationScheme.allCases : scheme,
            options: layoutOptions.planOptions,
            context: try layoutOptions.loadContext(records: records, apps: snapshot.layout.appBundleIDs),
            taxonomy: try global.loadTaxonomy()
        )
    }
}

struct PreviewCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "preview",
        abstract: "Write an HTML page comparing the current Home Screen with the saved proposals."
    )

    @OptionGroup var global: GlobalOptions

    @Flag(name: .customLong("open"), help: "Open the preview in your browser.")
    var openPreview = false

    @OptionGroup var layoutOptions: LayoutOptions

    func run() async throws {
        let workspace = global.makeWorkspace()
        let snapshot = try Pipeline.loadScan(workspace)
        let records = Pipeline.catalog(workspace: workspace, snapshot: snapshot)
        let context = try layoutOptions.loadContext(records: records, apps: snapshot.layout.appBundleIDs)
        let preview = try await Pipeline.preview(
            workspace: workspace,
            snapshot: snapshot,
            records: records,
            classification: try? Pipeline.loadClassification(workspace),
            plans: try Pipeline.loadPlans(workspace),
            iconColors: context.iconColors
        )
        if openPreview {
            await Pipeline.open(preview)
        }
    }
}

struct SchemesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "schemes",
        abstract: "List the layout schemes, what each looks like, and the data it uses."
    )

    func run() throws {
        Console.say("Layout schemes. Build them with `run` or `plan`, then `apply <scheme>`.")
        for scheme in OrganizationScheme.allCases {
            Console.say("")
            Console.say("\(scheme.rawValue)  (\(scheme.title))")
            Console.say("  \(scheme.summary)")
            if let note = scheme.dataNote {
                Console.say("  \(note)")
            }
        }
    }
}
