import Foundation
import Testing

@testable import OrganizeCore

@Suite("Layout validator")
struct LayoutValidatorTests {
    private func apps(_ count: Int) -> [IconItem] {
        Fixtures.apps(count).map { IconItem.app($0) }
    }

    @Test func aLayoutIsValidAgainstItself() {
        #expect(LayoutValidator.validate(Fixtures.layout, against: Fixtures.layout).isEmpty)
    }

    @Test func flagsAnOverfullDock() {
        let issues = LayoutValidator.validate(IconLayout(dock: apps(5), pages: []))
        #expect(LayoutValidator.hasErrors(issues))
        #expect(issues.contains { $0.message.contains("dock") })
    }

    @Test func flagsAnOverfullPage() {
        let issues = LayoutValidator.validate(IconLayout(dock: [], pages: [apps(25)]))
        #expect(issues.contains { $0.severity == .error && $0.message.contains("Page 1") })
    }

    @Test func flagsTooManyPages() {
        let pages = Fixtures.apps(16).map { [IconItem.app($0)] }
        let issues = LayoutValidator.validate(IconLayout(dock: [], pages: pages))
        #expect(issues.contains { $0.severity == .error && $0.message.contains("16 pages") })
    }

    @Test func flagsDuplicateIcons() {
        let issues = LayoutValidator.validate(IconLayout(dock: [.app("a")], pages: [[.app("a")]]))
        #expect(issues.contains { $0.severity == .error && $0.message.contains("more than once") })
    }

    @Test func flagsEmptyAndOverfullFolders() {
        let empty = IconItem.folder(IconFolder(name: "Empty", pages: []))
        let stuffed = IconItem.folder(IconFolder(name: "Stuffed", pages: [apps(10)]))
        let issues = LayoutValidator.validate(IconLayout(dock: [], pages: [[empty, stuffed]]))
        #expect(issues.contains { $0.message.contains("\"Empty\" is empty") })
        #expect(issues.contains { $0.message.contains("\"Stuffed\" page 1") })
    }

    @Test func flagsIconsMissingFromOrAddedToThePlan() {
        let current = IconLayout(dock: [], pages: [[.app("a"), .app("b")]])
        let missing = LayoutValidator.validate(IconLayout(dock: [], pages: [[.app("a")]]), against: current)
        #expect(missing.contains { $0.severity == .error && $0.message.contains("missing from the plan") })

        let extra = LayoutValidator.validate(
            IconLayout(dock: [], pages: [[.app("a"), .app("b"), .app("c")]]),
            against: current
        )
        #expect(extra.contains { $0.severity == .error && $0.message.contains("not on the phone") })
    }

    @Test func anEmptyPageIsOnlyAWarning() {
        let issues = LayoutValidator.validate(IconLayout(dock: [], pages: [[.app("a")], []]))
        #expect(issues.count == 1)
        #expect(!LayoutValidator.hasErrors(issues))
    }
}

@Suite("Layout diff")
struct LayoutDiffTests {
    @Test func findsWhereEachIconLives() {
        let locations = LayoutDiff.locations(in: Fixtures.layout)
        #expect(locations["app:com.apple.mobilephone"] == IconLocation(page: nil))
        #expect(locations["app:com.chase.sig.ios"] == IconLocation(page: 1, folder: "Money"))
        #expect(locations["app:com.a.three"] == IconLocation(page: 2, folder: "Big"))
        #expect(locations["web:https://example.com/dashboard"] == IconLocation(page: 1))
    }

    @Test func anUnchangedLayoutMovesNothing() {
        let summary = LayoutDiff.summarize(from: Fixtures.layout, to: Fixtures.layout)
        #expect(summary == LayoutChangeSummary(totalIcons: 14, moved: 0, unchanged: 14))
    }

    @Test func countsIconsThatChangePageOrFolder() {
        var proposed = Fixtures.layout
        proposed.pages[1].removeLast()
        proposed.pages[0].append(.app("com.burbn.instagram"))
        let summary = LayoutDiff.summarize(from: Fixtures.layout, to: proposed)
        #expect(summary.moved == 1)
        #expect(summary.unchanged == 13)
    }

    @Test func describesLocationsInWords() {
        #expect(IconLocation(page: nil).description == "dock")
        #expect(IconLocation(page: 2, folder: "Big").description == "page 2, folder \"Big\"")
    }
}
