import Foundation
import OrganizeCore
import Testing

@testable import OrganizeAdapters

// JSON shapes below match what cfgutil 2.20 prints.

@Suite("cfgutil output parser")
struct CfgutilParserTests {
    static let list = """
        {"Command":"list","Output":{"0x1A2B":{"locationID":17825792,"UDID":"00008130-001A2B","ECID":"0x1A2B","name":"Test iPhone","deviceType":"iPhone17,1"}},"Type":"CommandOutput","Devices":["0x1A2B"]}
        """

    static let apps = """
        {"Command":"get","Output":{"0x1A2B":{"installedApps":[
          {"bundleIdentifier":"com.spotify.client","displayName":"Spotify","itunesName":"Spotify: Music","bundleVersion":"9.0.1"},
          {"bundleIdentifier":"com.example.noname","itunesName":"Store Name"},
          {"displayName":"No bundle identifier"}
        ]},"Errors":{"0x1A2B":{}}},"Type":"CommandOutput","Devices":["0x1A2B"]}
        """

    @Test func readsTheDeviceList() throws {
        let envelope = try CfgutilParser.parseEnvelope(Self.list)
        #expect(envelope.command == "list")
        #expect(
            CfgutilParser.parseDevices(envelope) == [
                ConnectedDevice(ecid: "0x1A2B", udid: "00008130-001A2B", name: "Test iPhone", deviceType: "iPhone17,1")
            ]
        )
    }

    @Test func anEmptyListMeansNoDevices() throws {
        let envelope = try CfgutilParser.parseEnvelope(#"{"Command":"list","Output":{},"Type":"CommandOutput","Devices":[]}"#)
        #expect(CfgutilParser.parseDevices(envelope).isEmpty)
    }

    @Test func emptyNestedErrorsAreNotErrors() throws {
        let envelope = try CfgutilParser.parseEnvelope(Self.apps)
        #expect(envelope.errors.isEmpty)
        #expect(envelope.output["Errors"] == nil)
    }

    @Test func readsInstalledAppsAndSkipsEntriesWithoutABundleIdentifier() throws {
        let envelope = try CfgutilParser.parseEnvelope(Self.apps)
        let apps = try CfgutilParser.parseInstalledApps(envelope, ecid: "0x1A2B")
        #expect(
            apps == [
                AppRecord(bundleID: "com.spotify.client", name: "Spotify", version: "9.0.1"),
                AppRecord(bundleID: "com.example.noname", name: "Store Name"),
            ]
        )
    }

    @Test func aPerDeviceErrorIsReported() throws {
        let json = #"{"Command":"get","Output":{"Errors":{"0x1":{"Message":"Device is locked","Code":42}}},"Type":"CommandOutput","Devices":["0x1"]}"#
        let envelope = try CfgutilParser.parseEnvelope(json)
        #expect(envelope.errors == ["0x1": "Device is locked"])
        #expect(throws: DeviceError.commandFailed(message: "Device is locked")) {
            try CfgutilParser.parseInstalledApps(envelope, ecid: nil)
        }
    }

    @Test func aCommandLevelErrorIsThrown() {
        #expect(throws: DeviceError.commandFailed(message: "No devices found")) {
            try CfgutilParser.parseEnvelope(#"{"Command":"get","Type":"Error","Message":"No devices found","Code":1}"#)
        }
    }

    @Test func progressLinesBeforeTheResultAreIgnored() throws {
        let envelope = try CfgutilParser.parseEnvelope("Waiting for the device…\n" + Self.list)
        #expect(envelope.devices == ["0x1A2B"])
    }

    @Test func outputWithoutJSONIsMalformed() {
        #expect(throws: DeviceError.malformedOutput("cfgutil: something went wrong")) {
            try CfgutilParser.parseEnvelope("cfgutil: something went wrong")
        }
    }
}

@Suite("cfgutil device client")
struct CfgutilDeviceClientTests {
    private func ok(_ output: String) -> CommandResult {
        CommandResult(succeeded: true, standardOutput: output)
    }

    @Test func listsDevicesWithJSONOutput() async throws {
        let runner = FakeCommandRunner(results: [ok(CfgutilParserTests.list)])
        let client = CfgutilDeviceClient(executable: "/fake/cfgutil", runner: runner)

        let devices = try await client.listDevices()

        #expect(devices.map { $0.name } == ["Test iPhone"])
        #expect(await runner.calls == [.init(executable: "/fake/cfgutil", arguments: ["--format", "JSON", "list"])])
    }

    @Test func selectsTheDeviceBeforeTheCommand() async throws {
        let runner = FakeCommandRunner(results: [ok(CfgutilParserTests.apps)])
        let client = CfgutilDeviceClient(executable: "/fake/cfgutil", runner: runner)

        let apps = try await client.installedApps(ecid: "0x1A2B")

        #expect(apps.count == 2)
        #expect(await runner.calls.first?.arguments == ["--format", "JSON", "-e", "0x1A2B", "get", "installedApps"])
    }

    @Test func readsTheIconLayout() async throws {
        let runner = FakeCommandRunner(results: [ok(TestSupport.layoutJSON)])
        let client = CfgutilDeviceClient(executable: "/fake/cfgutil", runner: runner)

        let layout = try await client.iconLayout(ecid: nil)

        #expect(layout == TestSupport.layout)
        #expect(await runner.calls.first?.arguments == ["get-icon-layout"])
    }

    @Test func explainsADeviceThatIsInUse() async {
        let busy = CommandResult(succeeded: false, standardOutput: "", standardError: "The device is already in use.")
        let client = CfgutilDeviceClient(executable: "/fake/cfgutil", runner: FakeCommandRunner(results: [busy]))

        await #expect(
            throws: DeviceError.commandFailed(
                message: "The device is already in use. (quit the Apple Configurator app and try again)"
            )
        ) {
            try await client.iconLayout(ecid: nil)
        }
    }

    @Test func unreadableLayoutOutputIsMalformed() async {
        let client = CfgutilDeviceClient(executable: "/fake/cfgutil", runner: FakeCommandRunner(results: [ok("nonsense")]))
        await #expect(throws: DeviceError.malformedOutput("nonsense")) {
            try await client.iconLayout(ecid: nil)
        }
    }

    @Test func appliesALayoutFromATemporaryFileAndCleansUp() async throws {
        let runner = FakeCommandRunner(results: [ok("")])
        let directory = try TestSupport.temporaryDirectory()
        let client = CfgutilDeviceClient(executable: "/fake/cfgutil", runner: runner, temporaryDirectory: directory)

        try await client.applyIconLayout(TestSupport.layout, ecid: "0x1A2B")

        let call = try #require(await runner.calls.first)
        #expect(Array(call.arguments.prefix(3)) == ["-e", "0x1A2B", "set-icon-layout"])
        let file = try #require(call.arguments.last)
        #expect(file.hasPrefix(directory.path))

        // The file held the layout in cfgutil's format while the command ran, and is gone now.
        let written = try #require(await runner.capturedFiles.first)
        #expect(try IconLayoutCodec.decode(text: written) == TestSupport.layout)
        #expect(!FileManager.default.fileExists(atPath: file))
    }

    @Test func aFailedApplyIsReported() async throws {
        let failed = CommandResult(succeeded: false, standardOutput: "", standardError: "boom")
        let client = CfgutilDeviceClient(
            executable: "/fake/cfgutil",
            runner: FakeCommandRunner(results: [failed]),
            temporaryDirectory: try TestSupport.temporaryDirectory()
        )
        await #expect(throws: DeviceError.commandFailed(message: "boom")) {
            try await client.applyIconLayout(TestSupport.layout, ecid: nil)
        }
    }

    /// The same client, driven through a real process: the fake cfgutil script in Tests/Fixtures.
    @Test func worksEndToEndThroughARealSubprocess() async throws {
        let script = TestSupport.fixture("fake-cfgutil").path
        let client = CfgutilDeviceClient(executable: "cfgutil", runner: ScriptRunner(script: script))

        let devices = try await client.listDevices()
        let device = try DeviceSelector.select(from: devices, ecid: nil)
        #expect(device.name == "Test iPhone")

        let layout = try await client.iconLayout(ecid: device.ecid)
        #expect(layout.dock.count == 4)
        #expect(layout.pages.count == 2)
        #expect(layout.appBundleIDs.count == 28)
        #expect(layout.folders.map { $0.name } == ["Stuff", "Games"])

        let apps = try await client.installedApps(ecid: device.ecid)
        #expect(apps.count == 19)
        #expect(apps.first?.name == "Spotify")

        try await client.applyIconLayout(layout, ecid: device.ecid)
    }
}

@Suite("Finding cfgutil and choosing a device")
struct LocatorAndSelectorTests {
    @Test func anExplicitPathWinsAndIsNotSecondGuessed() throws {
        let found = try CfgutilLocator.locate(explicitPath: "/x/cfgutil", environment: [:]) { $0 == "/x/cfgutil" }
        #expect(found == "/x/cfgutil")

        #expect(throws: DeviceError.cfgutilNotFound(searched: ["/x/cfgutil"])) {
            try CfgutilLocator.locate(explicitPath: "/x/cfgutil", environment: [:]) { _ in false }
        }
    }

    @Test func theEnvironmentVariableComesBeforeTheDefaults() throws {
        let found = try CfgutilLocator.locate(environment: ["CFGUTIL_PATH": "/env/cfgutil"]) { _ in true }
        #expect(found == "/env/cfgutil")
    }

    @Test func fallsBackToTheAppleConfiguratorBundle() throws {
        let second = CfgutilLocator.defaultCandidates[1]
        let found = try CfgutilLocator.locate(environment: [:]) { $0 == second }
        #expect(found == second)
    }

    @Test func reportsEverywhereItLooked() {
        #expect(throws: DeviceError.cfgutilNotFound(searched: CfgutilLocator.defaultCandidates)) {
            try CfgutilLocator.locate(environment: [:]) { _ in false }
        }
    }

    let phone = ConnectedDevice(ecid: "0xAB", name: "Phone")
    let tablet = ConnectedDevice(ecid: "0xCD", name: "Tablet")

    @Test func picksTheOnlyDevice() throws {
        #expect(try DeviceSelector.select(from: [phone], ecid: nil) == phone)
    }

    @Test func matchesAnECIDIgnoringCase() throws {
        #expect(try DeviceSelector.select(from: [phone, tablet], ecid: "0xcd") == tablet)
    }

    @Test func refusesToGuessBetweenSeveralDevices() {
        #expect(throws: DeviceError.multipleDevices(["Phone (0xAB)", "Tablet (0xCD)"])) {
            try DeviceSelector.select(from: [phone, tablet], ecid: nil)
        }
    }

    @Test func reportsNoDeviceAndUnknownECIDs() {
        #expect(throws: DeviceError.noDeviceConnected) {
            try DeviceSelector.select(from: [], ecid: nil)
        }
        #expect(throws: DeviceError.deviceNotFound(ecid: "0xEF")) {
            try DeviceSelector.select(from: [phone], ecid: "0xEF")
        }
    }
}
