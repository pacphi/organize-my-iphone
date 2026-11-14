import ArgumentParser
import Foundation
import OrganizeAdapters
import OrganizeCore

struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check that everything a run needs is in place: cfgutil, a connected iPhone, and a local model."
    )

    @OptionGroup var global: GlobalOptions

    @Option(name: .customLong("ollama-url"), help: "Base URL of the Ollama server.")
    var ollamaURL: String = "http://127.0.0.1:11434"

    func run() async throws {
        Console.say("Workspace: \(global.makeWorkspace().root.path)")

        // cfgutil and the phone.
        do {
            let device = try global.makeDeviceClient()
            Console.say("[ok]   cfgutil: \(device.executable)")
            do {
                let devices = try await device.listDevices()
                if devices.isEmpty {
                    Console.say("[miss] iPhone: none found. Connect it with a cable, unlock it, and tap Trust.")
                }
                for found in devices {
                    Console.say("[ok]   iPhone: \(found.name) (\(found.deviceType ?? "unknown model"), ECID \(found.ecid))")
                }
            } catch {
                Console.say("[miss] iPhone: \(error.localizedDescription)")
            }
        } catch {
            Console.say("[miss] cfgutil: \(error.localizedDescription)")
        }

        // Local models. Either one is enough; with neither, built-in rules are used.
        if let baseURL = URL(string: ollamaURL), let models = try? await OllamaModel.installedModels(baseURL: baseURL) {
            if models.isEmpty {
                Console.say("[miss] Ollama: running, but no models are installed.")
            } else {
                Console.say("[ok]   Ollama: \(models.joined(separator: ", "))")
            }
        } else {
            Console.say("[miss] Ollama: not reachable at \(ollamaURL)")
        }

        if AppleIntelligence.makeOnDeviceModel() != nil {
            Console.say("[ok]   Apple on-device model: available")
        } else {
            Console.say("[miss] Apple on-device model: not available on this Mac")
        }

        Console.say("")
        Console.say("Close the Apple Configurator window before scanning: it locks the phone while open.")
    }
}
