import Foundation
import OrganizeCore
import Testing

@testable import OrganizeAdapters

@Suite("Workspace")
struct WorkspaceTests {
    // 2027-01-15 08:00:00 UTC. Whole seconds, because dates are stored as ISO 8601.
    let moment = Date(timeIntervalSince1970: 1_800_000_000)
    let utc = TimeZone(identifier: "UTC")!

    private func makeWorkspace() throws -> Workspace {
        Workspace(root: try TestSupport.temporaryDirectory().appendingPathComponent("workspace"))
    }

    @Test func defaultsToAFolderInTheHomeDirectory() {
        let home = URL(fileURLWithPath: "/Users/someone")
        #expect(Workspace.defaultRoot(environment: [:], home: home).path == "/Users/someone/.organize-my-iphone")
        #expect(Workspace.defaultRoot(environment: ["OMI_WORKSPACE": "/tmp/omi"], home: home).path == "/tmp/omi")
    }

    @Test func namesFilesByWhatTheyHold() throws {
        let workspace = try makeWorkspace()
        #expect(workspace.scanURL.lastPathComponent == "scan.json")
        #expect(workspace.planURL(for: .categoryPages).lastPathComponent == "plan-category-pages.json")
        #expect(workspace.planURL(for: .folderBoard).lastPathComponent == "plan-folder-board.json")
    }

    @Test func documentsRoundTripThroughDisk() throws {
        let workspace = try makeWorkspace()
        let snapshot = ScanSnapshot(
            device: ConnectedDevice(ecid: "0x1", udid: "udid", name: "Test iPhone", deviceType: "iPhone17,1"),
            scannedAt: moment,
            installedApps: [AppRecord(bundleID: "com.a", name: "Alpha", version: "1.0")],
            layout: TestSupport.layout
        )

        #expect(!workspace.exists(workspace.scanURL))
        try workspace.write(snapshot, to: workspace.scanURL)

        #expect(workspace.exists(workspace.scanURL))
        #expect(try workspace.read(ScanSnapshot.self, from: workspace.scanURL) == snapshot)
    }

    @Test func theMetadataCacheRoundTrips() throws {
        let workspace = try makeWorkspace()
        let cache = MetadataCache(
            entries: ["com.a": AppStoreMetadata(bundleID: "com.a", name: "Alpha", primaryGenre: "Games")],
            notFound: ["com.b"]
        )
        try workspace.write(cache, to: workspace.metadataURL)
        #expect(try workspace.read(MetadataCache.self, from: workspace.metadataURL) == cache)
    }

    @Test func backupsAreNamedByTimeAndReasonAndHoldCfgutilJSON() throws {
        let workspace = try makeWorkspace()
        let url = try workspace.saveBackup(TestSupport.layout, reason: .scan, at: moment, timeZone: utc)

        #expect(url.lastPathComponent == "icon-layout-20270115-080000-000-scan.json")
        #expect(try workspace.loadLayout(from: url) == TestSupport.layout)
        #expect(try JSONValue.parse(Data(contentsOf: url)) == IconLayoutCodec.encode(TestSupport.layout))
    }

    @Test func restoreCanFindTheLayoutSavedBeforeTheLastApply() throws {
        let workspace = try makeWorkspace()
        #expect(try workspace.latestBackup() == nil)

        let beforeApply = try workspace.saveBackup(TestSupport.layout, reason: .beforeApply, at: moment, timeZone: utc)
        let laterScan = try workspace.saveBackup(
            TestSupport.layout,
            reason: .scan,
            at: moment.addingTimeInterval(100),
            timeZone: utc
        )

        #expect(try workspace.backups().map { $0.lastPathComponent } == [
            beforeApply.lastPathComponent, laterScan.lastPathComponent,
        ])
        #expect(try workspace.latestBackup()?.lastPathComponent == laterScan.lastPathComponent)
        #expect(try workspace.latestBackup(reason: .beforeApply)?.lastPathComponent == beforeApply.lastPathComponent)
    }

    @Test func writesThePreviewAsText() throws {
        let workspace = try makeWorkspace()
        try workspace.writeText("<!DOCTYPE html>", to: workspace.previewURL)
        #expect(try String(contentsOf: workspace.previewURL, encoding: .utf8) == "<!DOCTYPE html>")
    }
}
