import Foundation
import Testing

@testable import OrganizeCore

@Suite("Rendering")
struct RenderingTests {
    private var plan: OrganizationPlan {
        PlanBuilder.makePlan(
            scheme: .folderBoard,
            current: Fixtures.layout,
            classifications: Fixtures.classifications,
            names: Fixtures.names,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    @Test func thePreviewShowsTheCurrentLayoutAndEachProposal() {
        let document = PreviewDocument(
            deviceName: "Chris's <iPhone>",
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            names: Fixtures.names,
            categories: Fixtures.classifications,
            current: Fixtures.layout,
            plans: [plan]
        )
        let html = HTMLPreviewRenderer.render(document)

        #expect(html.hasPrefix("<!DOCTYPE html>"))
        #expect(html.contains("Chris&#39;s &lt;iPhone&gt;"))
        #expect(!html.contains("<iPhone>"))
        #expect(html.contains("Current layout"))
        #expect(html.contains("Proposal: Folder board"))
        #expect(html.contains("Folder contents"))
        #expect(html.contains("Instagram"))
        // The page must stay self-contained: no scripts, nothing fetched.
        #expect(!html.contains("<script"))
        #expect(!html.contains("http://"))
    }

    @Test func escapesHTML() {
        #expect(HTMLPreviewRenderer.escape(#"<a href="x">Tom & Jerry's</a>"#) == "&lt;a href=&quot;x&quot;&gt;Tom &amp; Jerry&#39;s&lt;/a&gt;")
    }

    @Test func coloursAreStableAndInRange() {
        let first = HTMLPreviewRenderer.hue(for: "Finance")
        #expect(first == HTMLPreviewRenderer.hue(for: "Finance"))
        #expect((0..<360).contains(first))
        #expect(HTMLPreviewRenderer.hue(for: "Finance") != HTMLPreviewRenderer.hue(for: "Games"))
    }

    @Test func initialsUseTwoWordsWhenThereAreTwo() {
        #expect(HTMLPreviewRenderer.initials(of: "App Store") == "AS")
        #expect(HTMLPreviewRenderer.initials(of: "Maps") == "MA")
        #expect(HTMLPreviewRenderer.initials(of: "X") == "X")
    }

    @Test func theTerminalSummaryListsGroupsAndTheSizeOfTheChange() {
        let summary = PlanReport.summary(of: plan, current: Fixtures.layout, names: Fixtures.names)
        #expect(summary.contains("Folder board (folder-board)"))
        #expect(summary.contains("1 page(s), 2 folder(s)"))
        #expect(summary.contains("Finance"))
        #expect(summary.contains("Chase, PayPal"))
    }
}

@Suite("Elapsed time and status lines")
struct StatusLineTests {
    @Test func aTickingCounterShowsWholeSeconds() {
        #expect(ElapsedTime.ticking(0) == "0s")
        #expect(ElapsedTime.ticking(7.9) == "7s")
        #expect(ElapsedTime.ticking(59.99) == "59s")
        #expect(ElapsedTime.ticking(65) == "1m 05s")
        #expect(ElapsedTime.ticking(600) == "10m 00s")
        #expect(ElapsedTime.ticking(-3) == "0s")
    }

    @Test func aFinishedTotalShowsTenthsBelowAMinute() {
        #expect(ElapsedTime.total(0) == "0.0s")
        #expect(ElapsedTime.total(0.44) == "0.4s")
        #expect(ElapsedTime.total(42.3) == "42.3s")
        #expect(ElapsedTime.total(59.96) == "1m 00s")
        #expect(ElapsedTime.total(125.2) == "2m 05s")
    }

    @Test func durationsConvertToSeconds() {
        #expect(ElapsedTime.seconds(.milliseconds(1500)) == 1.5)
        #expect(ElapsedTime.seconds(.seconds(90)) == 90)
    }

    @Test func aRunningStepShowsSpinnerTitleDetailAndSeconds() {
        let line = StatusLine.running(frame: 0, title: "Classify 3 apps", detail: "2/3 apps", seconds: 12.9, width: 80)
        #expect(line == "⠋ Classify 3 apps · 2/3 apps · 12s")

        let next = StatusLine.running(frame: 1, title: "Classify 3 apps", detail: nil, seconds: 13.1, width: 80)
        #expect(next == "⠙ Classify 3 apps · 13s")
    }

    @Test func aRunningStepIsCutToFitTheTerminalSoItNeverWraps() {
        let title = String(repeating: "a", count: 60)
        let line = StatusLine.running(frame: 0, title: title, detail: nil, seconds: 5, width: 30)
        #expect(line.count <= 29)
        #expect(line.hasPrefix("⠋ aaa"))
        #expect(line.hasSuffix("… · 5s"))
    }

    @Test func batchProgressShowsBatchCountAndTimeLeft() {
        // Nothing finished yet: no estimate.
        #expect(
            StatusLine.batchProgress(completed: 0, total: 242, batchSize: 25, elapsedSeconds: 4) == "batch 1/10 · 0/242 apps"
        )
        // 50 apps took 10s, so the remaining 192 should take about 39s.
        #expect(
            StatusLine.batchProgress(completed: 50, total: 242, batchSize: 25, elapsedSeconds: 10)
                == "batch 3/10 · 50/242 apps · about 39s left"
        )
        #expect(StatusLine.batchProgress(completed: 242, total: 242, batchSize: 25, elapsedSeconds: 50) == "242/242 apps")
    }

    @Test func aFinishedStepShowsItsOutcomeAndTotal() {
        let done = StatusLine.finished(title: "Classify 3 apps", detail: "3/3 apps", seconds: 42.3, succeeded: true)
        #expect(done == "✓ Classify 3 apps · 3/3 apps · 42.3s")

        let failed = StatusLine.finished(title: "Read the iPhone", detail: nil, seconds: 3.1, succeeded: false)
        #expect(failed == "✗ Read the iPhone · failed after 3.1s")
    }
}
