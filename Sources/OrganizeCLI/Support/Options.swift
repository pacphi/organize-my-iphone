import ArgumentParser
import Foundation
import OrganizeAdapters
import OrganizeCore

/// Options every command accepts.
struct GlobalOptions: ParsableArguments {
    @Option(
        name: .long,
        help: "Folder for scans, plans, previews and backups. Defaults to $OMI_WORKSPACE or ~/.organize-my-iphone."
    )
    var workspace: String?

    @Option(name: .long, help: "ECID of the iPhone to use when more than one is attached.")
    var ecid: String?

    @Option(name: .long, help: "Path to cfgutil. Defaults to $CFGUTIL_PATH or the copy inside Apple Configurator.")
    var cfgutil: String?

    @Option(name: .long, help: "Path to a JSON taxonomy file that replaces the built-in categories.")
    var taxonomy: String?

    func makeWorkspace() -> Workspace {
        if let workspace, !workspace.isEmpty {
            return Workspace(root: URL(fileURLWithPath: GlobalOptions.expand(workspace)))
        }
        return Workspace(root: Workspace.defaultRoot())
    }

    func makeDeviceClient() throws -> CfgutilDeviceClient {
        let explicit = cfgutil.map { URL(fileURLWithPath: GlobalOptions.expand($0)).path }
        return CfgutilDeviceClient(executable: try CfgutilLocator.locate(explicitPath: explicit))
    }

    func loadTaxonomy() throws -> Taxonomy {
        guard let taxonomy, !taxonomy.isEmpty else {
            return .standard
        }
        let url = URL(fileURLWithPath: GlobalOptions.expand(taxonomy))
        do {
            return try JSONDecoder().decode(Taxonomy.self, from: Data(contentsOf: url))
        } catch {
            throw UserError("Could not read the taxonomy at \(url.path): \(error.localizedDescription)")
        }
    }

    static func expand(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }
}

/// Which engine sorts apps into categories.
enum EngineOption: String, ExpressibleByArgument, CaseIterable {
    /// Ollama if it is running, else Apple's on-device model, else built-in rules.
    case auto
    case heuristic
    case ollama
    case apple
}

/// Layout schemes are named on the command line by their identifiers, such as `folder-board`.
extension OrganizationScheme: ExpressibleByArgument {}

struct ClassifyOptions: ParsableArguments {
    @Option(name: .long, help: "How to classify apps: auto, heuristic, ollama or apple.")
    var engine: EngineOption = .auto

    @Option(name: .long, help: "Ollama model to use. Defaults to $OMI_OLLAMA_MODEL or the first installed model.")
    var model: String?

    @Option(name: .customLong("ollama-url"), help: "Base URL of the Ollama server.")
    var ollamaURL: String = "http://127.0.0.1:11434"

    @Option(name: .long, help: "Apps per model request. Defaults to 25 for Ollama and 8 for Apple's on-device model.")
    var batchSize: Int?

    @Flag(
        name: .long,
        help: "Ask the model about every app, not only the ones built-in rules are unsure about. Slower."
    )
    var thorough = false
}

struct LayoutOptions: ParsableArguments {
    @Flag(name: .long, help: "Category pages: start every category on a new page instead of filling pages.")
    var onePagePerCategory = false

    @Option(name: .long, help: "Folder layouts: groups smaller than this stay loose instead of getting a folder.")
    var minFolderSize: Int = 2

    @Flag(name: .long, help: "Alphabetical: one folder per letter instead of loose pages.")
    var letterFolders = false

    @Option(name: .long, help: "Essentials: how many apps go on the essentials page (1 to 24).")
    var essentials: Int = 12

    @Option(name: .long, help: "New and review: how many of the newest apps go on the first page. Default: one page.")
    var newCount: Int?

    @Option(
        name: .long,
        help: ArgumentHelp(
            "A text file of apps, most-used first, one per line (bundle ID or name).",
            discussion: "Used by most-used, thumb-reach, essentials and new-and-review. Without it, your "
                + "current icon order stands in for usage. Screen Time on the phone shows the order to copy.",
            valueName: "file"
        )
    )
    var usage: String?

    @Option(
        name: .long,
        help: ArgumentHelp(
            "A text file of apps, newest install first, one per line (bundle ID or name).",
            discussion: "Used by new-and-review. Without it, the apps at the end of your current layout are "
                + "treated as the newest.",
            valueName: "file"
        )
    )
    var recent: String?

    @Option(
        name: .long,
        help: ArgumentHelp(
            "A JSON file of icon colors, such as {\"com.spotify.client\": \"#1DB954\"}.",
            discussion: "Used by rainbow, on top of built-in colors for Apple's apps.",
            valueName: "file"
        )
    )
    var iconColors: String?

    var planOptions: PlanOptions {
        PlanOptions(
            onePagePerCategory: onePagePerCategory,
            minimumFolderSize: max(1, minFolderSize),
            letterFolders: letterFolders,
            essentialsCount: min(max(1, essentials), GridSpec.iPhone.pageCapacity),
            newCount: newCount.map { max(0, $0) }
        )
    }

    /// Reads the optional usage, install-order and color files. Lines or entries that match no
    /// app are reported, not fatal. `storeColors` are colors found earlier from App Store icons.
    func loadContext(
        records: [AppRecord],
        apps: [String],
        storeColors: [String: RGBColor] = [:]
    ) throws -> (context: PlanContext, colors: IconColorSet) {
        let names = AppCatalog.names(of: records)
        var context = PlanContext(names: names)

        func readText(_ path: String, flag: String) throws -> (url: URL, text: String) {
            let url = URL(fileURLWithPath: GlobalOptions.expand(path))
            do {
                return (url, try String(contentsOf: url, encoding: .utf8))
            } catch {
                throw UserError("Could not read the \(flag) file at \(url.path): \(error.localizedDescription)")
            }
        }
        func report(_ unmatched: [String], flag: String) {
            guard !unmatched.isEmpty else {
                return
            }
            let shown = unmatched.prefix(5).joined(separator: ", ")
            let more = unmatched.count > 5 ? ", and \(unmatched.count - 5) more" : ""
            Console.warn("\(unmatched.count) entry(ies) in the \(flag) file match no app on the phone: \(shown)\(more)")
        }

        if let usage, !usage.isEmpty {
            let file = try readText(usage, flag: "--usage")
            let ranking = SignalFiles.parseRanking(file.text, apps: apps, names: names)
            report(ranking.unmatched, flag: "--usage")
            Console.say("✓ Usage order: \(ranking.order.count) app(s) from \(file.url.lastPathComponent)")
            context.usage = ranking.order
        }
        if let recent, !recent.isEmpty {
            let file = try readText(recent, flag: "--recent")
            let ranking = SignalFiles.parseRanking(file.text, apps: apps, names: names)
            report(ranking.unmatched, flag: "--recent")
            Console.say("✓ Install order: \(ranking.order.count) app(s) from \(file.url.lastPathComponent)")
            context.recent = ranking.order
        }
        var colors: [String: RGBColor] = [:]
        if let iconColors, !iconColors.isEmpty {
            let file = try readText(iconColors, flag: "--icon-colors")
            do {
                let parsed = try SignalFiles.parseColors(Data(file.text.utf8), apps: apps, names: names)
                report(parsed.unmatched, flag: "--icon-colors")
                Console.say("✓ Icon colors: \(parsed.colors.count) app(s) from \(file.url.lastPathComponent)")
                colors = parsed.colors
            } catch {
                throw UserError("Could not read the --icon-colors file at \(file.url.path): \(error)")
            }
        }
        let colorSet = IconColorSet(store: storeColors, file: colors)
        context.iconColors = colorSet.merged
        return (context, colorSet)
    }
}
