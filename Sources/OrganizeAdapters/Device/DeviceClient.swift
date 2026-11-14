import Foundation
import OrganizeCore

public enum DeviceError: Error, Equatable, Sendable, LocalizedError {
    case cfgutilNotFound(searched: [String])
    case noDeviceConnected
    case deviceNotFound(ecid: String)
    case multipleDevices([String])
    case commandFailed(message: String)
    case malformedOutput(String)

    public var errorDescription: String? {
        switch self {
        case .cfgutilNotFound(let searched):
            return """
                cfgutil was not found. Install Apple Configurator from the Mac App Store, or pass \
                --cfgutil <path>. Looked in: \(searched.joined(separator: ", "))
                """
        case .noDeviceConnected:
            return "No iPhone found. Connect it with a cable, unlock it, and tap Trust if asked."
        case .deviceNotFound(let ecid):
            return "No attached device has ECID \(ecid)."
        case .multipleDevices(let devices):
            return "More than one device is attached: \(devices.joined(separator: ", ")). Pick one with --ecid."
        case .commandFailed(let message):
            return "cfgutil failed: \(message)"
        case .malformedOutput(let detail):
            return "cfgutil printed something unexpected: \(detail)"
        }
    }
}

/// Reads from and writes to a phone. `CfgutilDeviceClient` is the real one; a different
/// transport (for example pymobiledevice3) can be added by conforming to this.
public protocol DeviceClient: Sendable {
    func listDevices() async throws -> [ConnectedDevice]
    func installedApps(ecid: String?) async throws -> [AppRecord]
    func iconLayout(ecid: String?) async throws -> IconLayout
    func applyIconLayout(_ layout: IconLayout, ecid: String?) async throws
}

/// Chooses which attached device to work on.
public enum DeviceSelector {
    /// With an ECID, returns that device. Without one, returns the only device attached and
    /// refuses to guess when there are several.
    public static func select(from devices: [ConnectedDevice], ecid: String?) throws -> ConnectedDevice {
        guard let first = devices.first else {
            throw DeviceError.noDeviceConnected
        }
        if let ecid, !ecid.isEmpty {
            guard let match = devices.first(where: { $0.ecid.caseInsensitiveCompare(ecid) == .orderedSame }) else {
                throw DeviceError.deviceNotFound(ecid: ecid)
            }
            return match
        }
        if devices.count > 1 {
            throw DeviceError.multipleDevices(devices.map { "\($0.name) (\($0.ecid))" })
        }
        return first
    }
}

/// Finds the `cfgutil` binary that ships inside Apple Configurator.
public enum CfgutilLocator {
    public static let defaultCandidates = [
        "/Applications/Apple Configurator.app/Contents/MacOS/cfgutil",
        "/Applications/Apple Configurator 2.app/Contents/MacOS/cfgutil",
        "/usr/local/bin/cfgutil",
        "/opt/homebrew/bin/cfgutil",
    ]

    /// - Parameters:
    ///   - explicitPath: A path the user asked for. Wins over everything else.
    ///   - environment: Checked for `CFGUTIL_PATH`.
    ///   - isExecutable: Injected so tests do not depend on what is installed.
    public static func locate(
        explicitPath: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) throws -> String {
        var candidates: [String] = []
        if let explicitPath, !explicitPath.isEmpty {
            candidates.append(explicitPath)
        } else {
            if let fromEnvironment = environment["CFGUTIL_PATH"], !fromEnvironment.isEmpty {
                candidates.append(fromEnvironment)
            }
            candidates.append(contentsOf: defaultCandidates)
        }
        for candidate in candidates where isExecutable(candidate) {
            return candidate
        }
        throw DeviceError.cfgutilNotFound(searched: candidates)
    }
}
