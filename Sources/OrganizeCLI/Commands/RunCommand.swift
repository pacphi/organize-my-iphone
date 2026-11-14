import ArgumentParser
import Foundation
import OrganizeAdapters
import OrganizeCore

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Scan the phone, classify its apps, build both proposals and write a preview. Changes nothing on the phone."
    )

    @OptionGroup var global: GlobalOptions
    @OptionGroup var classifyOptions: ClassifyOptions
    @OptionGroup var layoutOptions: LayoutOptions

    @Flag(name: .long, help: "Skip the App Store lookup. No bundle identifiers leave this Mac.")
    var offline = false

    @Option(name: .long, help: "App Store storefront to look apps up in.")
    var country: String = "us"

    @Flag(name: .customLong("open"), help: "Open the preview in your browser when it is ready.")
    var openPreview = false

    func run() async throws {
        let stopwatch = Console.stopwatch()
        let workspace = global.makeWorkspace()
        let taxonomy = try global.loadTaxonomy()
        let device = try global.makeDeviceClient()

        // Decide how apps will be classified first. If that is an Ollama model, it starts
        // loading now, in the background, while the phone is read and apps are looked up.
        let engine = try await Pipeline.chooseEngine(classifyOptions)

        let snapshot = try await Pipeline.scan(device: device, ecid: global.ecid, workspace: workspace)

        if offline {
            Console.say("- App Store lookup skipped (--offline)")
        } else {
            do {
                try await Pipeline.enrich(workspace: workspace, snapshot: snapshot, country: country, refresh: false)
            } catch {
                Console.warn("App Store lookup failed (\(error.localizedDescription)); continuing without it.")
            }
        }

        let records = Pipeline.catalog(workspace: workspace, snapshot: snapshot)
        let classification = try await Pipeline.classify(
            workspace: workspace,
            records: records,
            options: classifyOptions,
            taxonomy: taxonomy,
            engine: engine
        )
        let plans = try await Pipeline.plan(
            workspace: workspace,
            snapshot: snapshot,
            records: records,
            classification: classification,
            schemes: OrganizationScheme.allCases,
            options: layoutOptions.planOptions,
            taxonomy: taxonomy
        )
        let preview = try await Pipeline.preview(
            workspace: workspace,
            snapshot: snapshot,
            records: records,
            classification: classification,
            plans: plans
        )
        if openPreview {
            await Pipeline.open(preview)
        }

        Console.say("")
        Console.say("Finished in \(stopwatch.elapsed()). Nothing on the phone has changed.")
        Console.say("When you have picked a proposal:")
        Console.say("  organize-my-iphone apply category-pages")
        Console.say("  organize-my-iphone apply folder-board")
    }
}
