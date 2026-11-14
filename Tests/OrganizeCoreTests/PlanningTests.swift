import Foundation
import Testing

@testable import OrganizeCore

@Suite("Grouping")
struct GroupingTests {
    @Test func groupsFollowTaxonomyOrderAndSkipTheDock() {
        let groups = Grouping.groups(
            for: Fixtures.layout,
            classifications: Fixtures.classifications,
            names: Fixtures.names,
            taxonomy: .standard
        )
        #expect(groups.map { $0.category } == ["Social", "AI", "Finance", "Travel", "Music & Audio", "Games"])
        #expect(!groups.flatMap { $0.bundleIDs }.contains("com.apple.mobilephone"))
    }

    @Test func appsAreSortedByNameIgnoringCase() {
        let groups = Grouping.groups(
            for: Fixtures.layout,
            classifications: Fixtures.classifications,
            names: Fixtures.names,
            taxonomy: .standard
        )
        let games = groups.first { $0.category == "Games" }
        // Names are "alpha", "Mid", "Zeta".
        #expect(games?.bundleIDs == ["com.a.two", "com.a.three", "com.a.one"])
        let finance = groups.first { $0.category == "Finance" }
        #expect(finance?.bundleIDs == ["com.chase.sig.ios", "com.paypal.PPClient"])
    }

    @Test func unclassifiedAppsLandInTheFallbackLast() {
        var classifications = Fixtures.classifications
        classifications["com.burbn.instagram"] = nil
        let groups = Grouping.groups(
            for: Fixtures.layout,
            classifications: classifications,
            names: Fixtures.names,
            taxonomy: .standard
        )
        #expect(groups.last == AppGroup(category: "Other", bundleIDs: ["com.burbn.instagram"]))
    }
}

@Suite("Planners")
struct PlannerTests {
    let groups = Grouping.groups(
        for: Fixtures.layout,
        classifications: Fixtures.classifications,
        names: Fixtures.names,
        taxonomy: .standard
    )

    private func keys(of layout: IconLayout) -> Set<String> {
        Set(layout.pages.flatMap { IconLayout.flatten($0) }.map { $0.identityKey })
    }

    // MARK: Category pages

    @Test func categoryPagesPackClustersOntoAsFewPagesAsPossible() {
        let planned = CategoryPagesPlanner().plan(current: Fixtures.layout, groups: groups, options: PlanOptions())
        #expect(planned.layout.pages.count == 1)
        #expect(
            planned.layout.pages[0] == [
                .app("com.burbn.instagram"),
                .app("com.openai.chat"),
                .app("com.chase.sig.ios"),
                .app("com.paypal.PPClient"),
                .app("com.apple.Maps"),
                .app("com.spotify.client"),
                .app("com.a.two"),
                .app("com.a.three"),
                .app("com.a.one"),
                .webClip("https://example.com/dashboard"),
            ]
        )
        #expect(planned.pageLabels == ["Social · AI · Finance · Travel · Music & Audio · Games · Web clips & other"])
    }

    @Test func categoryPagesNeverSplitAClusterThatFitsOnAPage() {
        let options = PlanOptions(grid: GridSpec(columns: 2, rows: 2))
        let planned = CategoryPagesPlanner().plan(current: Fixtures.layout, groups: groups, options: options)
        // Capacity 4: [Social 1, AI 1, Finance 2] [Travel 1, Music 1] [Games 3, web clip 1]
        #expect(planned.layout.pages.map { $0.count } == [4, 2, 4])
        #expect(planned.pageLabels == ["Social · AI · Finance", "Travel · Music & Audio", "Games · Web clips & other"])
    }

    @Test func onePagePerCategoryStartsEachClusterOnAFreshPage() {
        let options = PlanOptions(onePagePerCategory: true)
        let planned = CategoryPagesPlanner().plan(current: Fixtures.layout, groups: groups, options: options)
        #expect(planned.layout.pages.count == 7)
        #expect(planned.pageLabels.first == "Social")
        #expect(planned.pageLabels.last == "Web clips & other")
    }

    @Test func aClusterLargerThanAPageContinuesOnTheNext() {
        let ids = Fixtures.apps(30)
        let current = IconLayout(dock: [], pages: [ids.map { IconItem.app($0) }])
        let planned = CategoryPagesPlanner().plan(
            current: current,
            groups: [AppGroup(category: "Games", bundleIDs: ids)],
            options: PlanOptions()
        )
        #expect(planned.layout.pages.map { $0.count } == [24, 6])
    }

    // MARK: Folder board

    @Test func folderBoardMakesOneFolderPerCategoryAndLeavesSingletonsLoose() {
        let planned = FolderBoardPlanner().plan(current: Fixtures.layout, groups: groups, options: PlanOptions())
        #expect(planned.layout.pages.count == 1)
        #expect(planned.layout.folders.map { $0.name } == ["Finance", "Games"])
        #expect(
            Array(planned.layout.pages[0].suffix(5)) == [
                .app("com.burbn.instagram"),
                .app("com.openai.chat"),
                .app("com.apple.Maps"),
                .app("com.spotify.client"),
                .webClip("https://example.com/dashboard"),
            ]
        )
        #expect(planned.pageLabels == ["Folders"])
    }

    @Test func folderBoardCanPutEverythingInFolders() {
        let options = PlanOptions(minimumFolderSize: 1)
        let planned = FolderBoardPlanner().plan(current: Fixtures.layout, groups: groups, options: options)
        #expect(planned.layout.folders.count == 6)
    }

    @Test func bigFoldersSpillOntoMoreFolderPages() {
        let ids = Fixtures.apps(20)
        let current = IconLayout(dock: [], pages: [ids.map { IconItem.app($0) }])
        let planned = FolderBoardPlanner().plan(
            current: current,
            groups: [AppGroup(category: "Games", bundleIDs: ids)],
            options: PlanOptions()
        )
        #expect(planned.layout.folders.first?.pages.map { $0.count } == [9, 9, 2])
    }

    // MARK: Guarantees shared by every planner

    @Test(arguments: OrganizationScheme.allCases)
    func everyPlannerKeepsTheDockAndEveryIcon(scheme: OrganizationScheme) {
        let planned = PlanBuilder.planner(for: scheme).plan(
            current: Fixtures.layout,
            groups: groups,
            options: PlanOptions()
        )
        #expect(planned.layout.dock == Fixtures.layout.dock)
        #expect(keys(of: planned.layout) == Fixtures.nonDockKeys)
        #expect(!LayoutValidator.hasErrors(LayoutValidator.validate(planned.layout, against: Fixtures.layout)))
    }

    @Test(arguments: OrganizationScheme.allCases)
    func plannersRepairIncompleteOrWrongGroups(scheme: OrganizationScheme) {
        // One real app, one app that is not on the phone, and everything else forgotten.
        let sloppy = [AppGroup(category: "Music & Audio", bundleIDs: ["com.spotify.client", "not.installed"])]
        let planned = PlanBuilder.planner(for: scheme).plan(
            current: Fixtures.layout,
            groups: sloppy,
            options: PlanOptions()
        )
        #expect(keys(of: planned.layout) == Fixtures.nonDockKeys)
    }

    @Test func planBuilderProducesAValidSavedPlan() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = PlanBuilder.makePlan(
            scheme: .folderBoard,
            current: Fixtures.layout,
            classifications: Fixtures.classifications,
            names: Fixtures.names,
            now: now
        )
        #expect(plan.scheme == .folderBoard)
        #expect(plan.createdAt == now)
        #expect(plan.groups.count == 6)
        #expect(LayoutValidator.validate(plan.layout, against: Fixtures.layout).isEmpty)

        // Plans survive a trip through JSON.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        #expect(try decoder.decode(OrganizationPlan.self, from: encoder.encode(plan)) == plan)
    }
}
