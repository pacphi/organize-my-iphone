import Foundation
import OrganizeCore

/// The wrapper `cfgutil --format JSON` puts around every result.
///
/// Shapes handled (seen with cfgutil 2.20):
///
///     {"Command":"list","Type":"CommandOutput","Devices":["0x1"],
///      "Output":{"0x1":{"ECID":"0x1","UDID":"…","name":"…","deviceType":"iPhone16,1"}}}
///
///     {"Command":"get","Type":"CommandOutput","Devices":["0x1"],
///      "Output":{"0x1":{"installedApps":[…]},"Errors":{"0x1":{}}}}
///
///     {"Command":"get","Type":"Error","Message":"No devices found","Code":1}
public struct CfgutilEnvelope: Hashable, Sendable {
    public var command: String?
    public var devices: [String]
    /// Results keyed by ECID.
    public var output: [String: JSONValue]
    /// Per-device error messages keyed by ECID. Empty when everything worked.
    public var errors: [String: String]

    public init(command: String?, devices: [String], output: [String: JSONValue], errors: [String: String]) {
        self.command = command
        self.devices = devices
        self.output = output
        self.errors = errors
    }
}

public enum CfgutilParser {
    public static func parseEnvelope(_ text: String) throws -> CfgutilEnvelope {
        guard let root = lastJSONObject(in: text) else {
            throw DeviceError.malformedOutput(String(text.prefix(200)))
        }
        if root["Type"]?.stringValue == "Error" {
            throw DeviceError.commandFailed(message: root["Message"]?.stringValue ?? "unknown error")
        }

        var output = root["Output"]?.objectValue ?? [:]
        // cfgutil nests "Errors" inside "Output"; an empty object per device means no error.
        let rawErrors = output.removeValue(forKey: "Errors")?.objectValue ?? root["Errors"]?.objectValue ?? [:]
        var errors: [String: String] = [:]
        for (ecid, detail) in rawErrors {
            guard let fields = detail.objectValue, !fields.isEmpty else {
                continue
            }
            errors[ecid] = fields["Message"]?.stringValue ?? "unknown error"
        }

        var devices: [String] = []
        for entry in root["Devices"]?.arrayValue ?? [] {
            if let ecid = entry.stringValue {
                devices.append(ecid)
            }
        }
        return CfgutilEnvelope(
            command: root["Command"]?.stringValue,
            devices: devices,
            output: output,
            errors: errors
        )
    }

    public static func parseDevices(_ envelope: CfgutilEnvelope) -> [ConnectedDevice] {
        let ecids = envelope.devices.isEmpty ? envelope.output.keys.sorted() : envelope.devices
        var devices: [ConnectedDevice] = []
        for ecid in ecids {
            let fields = envelope.output[ecid]
            devices.append(
                ConnectedDevice(
                    ecid: fields?["ECID"]?.stringValue ?? ecid,
                    udid: fields?["UDID"]?.stringValue,
                    name: fields?["name"]?.stringValue ?? "iPhone",
                    deviceType: fields?["deviceType"]?.stringValue
                )
            )
        }
        return devices
    }

    /// Reads `installedApps` for one device. With no ECID, the first device in the reply is used.
    public static func parseInstalledApps(_ envelope: CfgutilEnvelope, ecid: String?) throws -> [AppRecord] {
        let wanted = ecid ?? envelope.devices.first ?? envelope.output.keys.sorted().first
        if let wanted, let message = envelope.errors[wanted] {
            throw DeviceError.commandFailed(message: message)
        }
        guard let device = wanted, let fields = envelope.output[device] else {
            if let message = envelope.errors.values.sorted().first {
                throw DeviceError.commandFailed(message: message)
            }
            throw DeviceError.malformedOutput("no result for the device")
        }
        // Older cfgutil builds call the property "apps".
        let entries = fields["installedApps"]?.arrayValue ?? fields["apps"]?.arrayValue ?? []

        var apps: [AppRecord] = []
        for entry in entries {
            guard let bundleID = entry["bundleIdentifier"]?.stringValue, !bundleID.isEmpty else {
                continue
            }
            let name =
                nonEmpty(entry["displayName"]?.stringValue)
                ?? nonEmpty(entry["itunesName"]?.stringValue)
                ?? KnownApps.fallbackName(for: bundleID)
            apps.append(AppRecord(bundleID: bundleID, name: name, version: entry["bundleVersion"]?.stringValue))
        }
        return apps
    }

    /// cfgutil can print progress lines before its result, so the last JSON object wins.
    static func lastJSONObject(in text: String) -> JSONValue? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let whole = try? JSONValue.parse(trimmed), whole.objectValue != nil {
            return whole
        }
        for line in trimmed.split(separator: "\n").reversed() {
            let candidate = line.trimmingCharacters(in: .whitespaces)
            if candidate.hasPrefix("{"), let value = try? JSONValue.parse(candidate), value.objectValue != nil {
                return value
            }
        }
        return nil
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.isEmpty else {
            return nil
        }
        return text
    }
}
