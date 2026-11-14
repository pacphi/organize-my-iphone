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

enum SchemeOption: String, ExpressibleByArgument, CaseIterable {
    case categoryPages = "category-pages"
    case folderBoard = "folder-board"

    var scheme: OrganizationScheme {
        switch self {
        case .categoryPages:
            return .categoryPages
        case .folderBoard:
            return .folderBoard
        }
    }
}

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

    @Option(name: .long, help: "Folder board: categories smaller than this stay loose instead of getting a folder.")
    var minFolderSize: Int = 2

    var planOptions: PlanOptions {
        PlanOptions(onePagePerCategory: onePagePerCategory, minimumFolderSize: max(1, minFolderSize))
    }
}
