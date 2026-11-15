import Foundation
import Testing

@testable import OrganizeCore

/// A large phone: two dock apps, 400 loose apps across many categories, a two-page folder, a web
/// clip and an item the tool does not understand. Big enough that loose-page layouts must fold
/// apps into folders to stay within 15 pages.
enum BigPhone {
    static let categories = Taxonomy.standard.names

    static var apps: [String] { Fixtures.apps(400, prefix: "com.big.app") }

    static var layout: IconLayout {
        let loose = apps.map { IconItem.app($0) }
        var pages = loose.chunked(into: 24)
        pages[0][0] = .folder(
            IconFolder(
                name: "Old",
                pages: [[.app("com.big.folded1"), .app("com.big.folded2")], [.app("com.big.folded3")]]
            )
        )
        pages[0].append(.app(apps[0]))
        pages[1][0] = .webClip("https://example.com/big")
        pages[1].append(.app(apps[24]))
        pages[2].append(.unknown(.object(["iconType": .string("widget")])))
        // Keep every page within 24 items.
        let flat = pages.flatMap { $0 }
        return IconLayout(
            dock: [.app("com.apple.mobilephone"), .app("com.apple.mobilesafari")],
            pages: flat.chunked(into: 24)
        )
    }

    static var classifications: [String: String] {
        var result: [String: String] = [:]
        for (index, bundleID) in (apps + ["com.big.folded1", "com.big.folded2", "com.big.folded3"]).enumerated() {
            result[bundleID] = categories[index % categories.count]
        }
        return result
    }

    static var names: [String: String] {
        var result: [String: String] = [:]
        let words = ["Alpha", "bravo", "Charlie", "Éclair", "9Lives", "Zulu", "mike", "Quebec"]
        for (index, bundleID) in apps.enumerated() {
            result[bundleID] = "\(words[index % words.count]) \(index)"
        }
        return result
    }

    static var nonDockKeys: Set<String> {
        Set(layout.pages.flatMap { IconLayout.flatten($0) }.map { $0.identityKey })
    }
}

@Suite("More layouts")
struct MoreLayoutsTests {
    private func keys(of layout: IconLayout) -> [String] {
        layout.pages.flatMap { IconLayout.flatten($0) }.map { $0.identityKey }
    }

    private func plan(
        _ scheme: OrganizationScheme,
        context: PlanContext = PlanContext(),
        options: PlanOptions = PlanOptions()
    ) -> OrganizationPlan {
        PlanBuilder.makePlan(
            scheme: scheme,
            current: BigPhone.layout,
            classifications: BigPhone.classifications,
            names: BigPhone.names,
            options: options,
            context: context,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    private var richContext: PlanContext {
        let apps = BigPhone.apps
        var colors: [String: RGBColor] = [:]
        for (index, bundleID) in apps.enumerated() where index % 3 != 0 {
            colors[bundleID] = RGBColor(red: Double(index % 7) / 6, green: Double(index % 5) / 4, blue: 0.5)
        }
        return PlanContext(
            usage: Array(apps.reversed().prefix(200)) + ["not.on.phone"],
            recent: Array(apps.prefix(40)),
            iconColors: colors
        )
    }

    // MARK: Guarantees, on a big phone, with and without the optional files

    @Test(arguments: OrganizationScheme.allCases)
    func everySchemeIsValidOnABigPhoneWithNoExtraData(scheme: OrganizationScheme) {
        let plan = plan(scheme)
        #expect(plan.layout.dock == BigPhone.layout.dock)
        let placed = keys(of: plan.layout)
        #expect(placed.count == Set(placed).count, "an icon is placed twice")
        #expect(Set(placed) == BigPhone.nonDockKeys)
        let issues = LayoutValidator.validate(plan.layout, against: BigPhone.layout)
        #expect(!LayoutValidator.hasErrors(issues), "\(issues)")
        #expect(plan.pageLabels.count == plan.layout.pages.count)
    }

    @Test(arguments: OrganizationScheme.allCases)
    func everySchemeIsValidOnABigPhoneWithEveryFile(scheme: OrganizationScheme) {
        let options = PlanOptions(letterFolders: scheme == .alphabetical, essentialsCount: 20, newCount: 30)
        let plan = plan(scheme, context: richContext, options: options)
        #expect(plan.layout.dock == BigPhone.layout.dock)
        #expect(Set(keys(of: plan.layout)) == BigPhone.nonDockKeys)
        #expect(!LayoutValidator.hasErrors(LayoutValidator.validate(plan.layout, against: BigPhone.layout)))
    }

    @Test(arguments: [BucketTable.timeOfDay, .verbs, .places, .lifeAreas])
    func everyStandardCategoryHasABucketOnPurpose(table: BucketTable) {
        let named = Set(table.buckets.flatMap { $0.categories })
        for category in Taxonomy.standard.names {
            #expect(named.contains(category), "\(category) is not in a bucket")
        }
        #expect(table.bucket(for: "Something custom") == table.fallback)
        #expect(table.bucket(for: "music and audio") == table.bucket(for: "Music & Audio"))
    }

    @Test func schemeIdentifiersAreUnique() {
        let raw = OrganizationScheme.allCases.map { $0.rawValue }
        #expect(raw.count == 12)
        #expect(Set(raw).count == raw.count)
        #expect(Set(OrganizationScheme.allCases.map { $0.title }).count == raw.count)
    }

    // MARK: Alphabetical

    @Test func alphabeticalSortsByNameWithSymbolsLast() {
        let planned = AlphabeticalPlanner().plan(
            current: Fixtures.layout,
            groups: [],
            context: PlanContext(names: Fixtures.names.merging(["com.a.one": "1Password"]) { _, new in new }),
            options: PlanOptions()
        )
        let apps = IconLayout.appIDs(in: planned.layout.pages.flatMap { $0 })
        #expect(apps.first == "com.a.two")  // alpha
        #expect(apps.last == "com.a.one")  // 1Password, under "#"
        #expect(planned.pageLabels == ["A–S · # · Web clips & other"])
    }

    @Test func lettersIgnoreCaseAndAccents() {
        #expect(AlphabeticalPlanner.letter(of: "éclair") == "E")
        #expect(AlphabeticalPlanner.letter(of: "zulu") == "Z")
        #expect(AlphabeticalPlanner.letter(of: "9Lives") == "#")
        #expect(AlphabeticalPlanner.letter(of: "") == "#")
        #expect(AlphabeticalPlanner.rangeLabel(["A", "B", "C"]) == "A–C")
        #expect(AlphabeticalPlanner.rangeLabel(["Q"]) == "Q")
    }

    @Test func letterFoldersMakeOneFolderPerLetter() {
        let plan = plan(.alphabetical, options: PlanOptions(letterFolders: true))
        let folderNames = plan.layout.folders.map { $0.name }
        #expect(folderNames.contains("A"))
        #expect(folderNames.last == "#")
        #expect(plan.layout.pages.count == 1)
    }

    // MARK: Most used and thumb reach

    @Test func mostUsedFollowsTheUsageFileThenCurrentOrder() {
        let context = PlanContext(usage: ["com.openai.chat", "com.spotify.client", "not.installed"])
        let planned = MostUsedPlanner().plan(
            current: Fixtures.layout,
            groups: [],
            context: context,
            options: PlanOptions()
        )
        let apps = IconLayout.appIDs(in: planned.layout.pages.flatMap { $0 })
        #expect(Array(apps.prefix(3)) == ["com.openai.chat", "com.spotify.client", "com.apple.Maps"])
        #expect(planned.notes.isEmpty)
    }

    @Test func mostUsedSaysWhenItUsesTheCurrentOrder() {
        let planned = MostUsedPlanner().plan(current: Fixtures.layout, groups: [], options: PlanOptions())
        #expect(IconLayout.appIDs(in: planned.layout.pages.flatMap { $0 }).first == "com.apple.Maps")
        #expect(planned.notes == [Signals.usageStandIn])
    }

    @Test func mostUsedFoldsTheLeastUsedWhenPagesRunOut() {
        let plan = plan(.mostUsed)
        #expect(plan.layout.pages.count <= 15)
        #expect(!plan.layout.folders.isEmpty)
        // The leading pages are loose and in rank order.
        #expect(plan.layout.pages[0].allSatisfy { if case .app = $0 { return true } else { return false } })
    }

    @Test func thumbReachPutsTheTopRanksInTheBottomRow() {
        let grid = GridSpec(columns: 2, rows: 2)
        let page: [IconItem] = [.app("1"), .app("2"), .app("3"), .app("4")]
        #expect(ThumbReachPlanner.reach(page, grid: grid) == [.app("3"), .app("4"), .app("1"), .app("2")])
        // A page that is not full is left alone: iOS would move the icons up anyway.
        #expect(ThumbReachPlanner.reach(Array(page.prefix(3)), grid: grid) == Array(page.prefix(3)))
    }

    // MARK: Buckets

    @Test func timeOfDayStartsEachPartOfTheDayOnItsOwnPage() {
        let planned = BucketPagesPlanner(scheme: .timeOfDay, table: .timeOfDay).plan(
            current: Fixtures.layout,
            groups: Grouping.groups(
                for: Fixtures.layout,
                classifications: Fixtures.classifications,
                names: Fixtures.names,
                taxonomy: .standard
            ),
            options: PlanOptions()
        )
        // Fixtures: Social, Music & Audio, Games → Evening; AI, Finance → Work day; Travel → Anytime.
        #expect(planned.pageLabels == ["Work day", "Evening", "Anytime · Web clips & other"])
    }

    @Test func repeatedPageLabelsAreNumbered() {
        #expect(
            BucketPagesPlanner.numberRepeats(["Home", "Home", "Gym", "Home"]) == ["Home", "Home (2)", "Gym", "Home"]
        )
    }

    @Test func verbFoldersAreNamedForVerbs() {
        let plan = PlanBuilder.makePlan(
            scheme: .verbFolders,
            current: Fixtures.layout,
            classifications: Fixtures.classifications,
            names: Fixtures.names
        )
        // Finance → Track (2 apps), Games → Play (3 apps); the rest are single apps and stay loose.
        #expect(plan.layout.folders.map { $0.name } == ["Track", "Play"])
    }

    @Test func foldingToFitIsExplainedInTheNotes() {
        let plan = plan(.categoryPages)
        #expect(plan.layout.pages.count <= 15)
        #expect(plan.notes?.first?.hasPrefix("To stay within 15 pages") == true)
        // A small phone needs no folding, so there is no note.
        let small = PlanBuilder.makePlan(
            scheme: .categoryPages,
            current: Fixtures.layout,
            classifications: Fixtures.classifications,
            names: Fixtures.names
        )
        #expect(small.notes == nil)
    }

    @Test func bucketPagesFitWithinFifteenPages() {
        for scheme in [OrganizationScheme.timeOfDay, .places, .lifeAreas] {
            #expect(plan(scheme).layout.pages.count <= 15)
        }
    }

    // MARK: Rainbow

    @Test func colorBandsCoverTheWheelAndTheNeutrals() {
        #expect(ColorBand.of(RGBColor(hex: "#FF3B30")!) == .red)
        #expect(ColorBand.of(RGBColor(hex: "#FF9500")!) == .orange)
        #expect(ColorBand.of(RGBColor(hex: "#FFD60A")!) == .yellow)
        #expect(ColorBand.of(RGBColor(hex: "#34C759")!) == .green)
        #expect(ColorBand.of(RGBColor(hex: "#30D5C8")!) == .teal)
        #expect(ColorBand.of(RGBColor(hex: "#1E88E5")!) == .blue)
        #expect(ColorBand.of(RGBColor(hex: "#6E3BD9")!) == .purple)
        #expect(ColorBand.of(RGBColor(hex: "#E5407A")!) == .pink)
        #expect(ColorBand.of(RGBColor(hex: "#FFFFFF")!) == .white)
        #expect(ColorBand.of(RGBColor(hex: "#8E8E93")!) == .gray)
        #expect(ColorBand.of(RGBColor(hex: "#1C1C1E")!) == .black)
        #expect(RGBColor(hex: "nope") == nil)
        #expect(RGBColor(hex: "1db954")?.hex == "#1DB954")
    }

    @Test func rainbowOrdersBandsAndPutsUnknownColorsLast() {
        let context = PlanContext(
            iconColors: [
                "com.spotify.client": RGBColor(hex: "#1DB954")!,
                "com.chase.sig.ios": RGBColor(hex: "#117ACA")!,
                "com.paypal.PPClient": RGBColor(hex: "#FF3B30")!,
            ]
        )
        let planned = RainbowPlanner().plan(
            current: Fixtures.layout,
            groups: [],
            context: context,
            options: PlanOptions()
        )
        let apps = IconLayout.appIDs(in: planned.layout.pages.flatMap { $0 })
        #expect(Array(apps.prefix(3)) == ["com.paypal.PPClient", "com.spotify.client", "com.chase.sig.ios"])
        #expect(planned.groups?.last?.category == "No color data")
        #expect(planned.notes.first?.hasPrefix("6 app(s) have no known icon color") == true)
    }

    // MARK: New and review, essentials

    @Test func newAndReviewPutsTheNewestFirstAndUnusedAppsInReview() {
        let context = PlanContext(
            usage: [
                "com.openai.chat", "com.apple.Maps", "com.spotify.client", "com.chase.sig.ios", "com.paypal.PPClient",
            ],
            recent: ["com.burbn.instagram"]
        )
        let planned = NewAndReviewPlanner().plan(
            current: Fixtures.layout,
            groups: [],
            context: context,
            options: PlanOptions(newCount: 1)
        )
        #expect(planned.layout.pages.first == [.app("com.burbn.instagram")])
        #expect(planned.pageLabels.first == "New")
        #expect(planned.pageLabels.last == "Review")
        // The three game apps are not in the usage file.
        #expect(
            Set(IconLayout.appIDs(in: planned.layout.pages.last ?? [])) == ["com.a.one", "com.a.two", "com.a.three"]
        )
    }

    @Test func newAndReviewWithoutFilesSaysWhatItAssumed() {
        let planned = NewAndReviewPlanner().plan(
            current: Fixtures.layout,
            groups: [],
            options: PlanOptions(newCount: 1)
        )
        // The last app on the phone counts as the newest.
        #expect(planned.layout.pages.first == [.app("com.burbn.instagram")])
        #expect(planned.notes.contains(Signals.recentStandIn))
        #expect(!planned.pageLabels.contains("Review"))
    }

    @Test func essentialsKeepsOnePageAndFoldsTheRest() {
        let plan = plan(.essentials, options: PlanOptions(essentialsCount: 8))
        #expect(plan.layout.pages[0].count == 8)
        #expect(plan.pageLabels.first == "Essentials")
        #expect(
            plan.layout.pages.dropFirst().allSatisfy { page in
                page.allSatisfy { if case .app = $0 { return false } else { return true } }
            }
        )
        #expect(plan.notes?.contains { $0.contains("hide pages 2 and later") } == true)
    }

    // MARK: Signal files

    @Test func rankingFilesAcceptIDsNamesAndNumberedLines() {
        let text = """
            # My Screen Time order
            1. Spotify
            2) com.openai.chat
            chase

            Nothing Like This
            spotify
            """
        let ranking = SignalFiles.parseRanking(text, apps: Array(Fixtures.names.keys), names: Fixtures.names)
        #expect(ranking.order == ["com.spotify.client", "com.openai.chat", "com.chase.sig.ios"])
        #expect(ranking.unmatched == ["Nothing Like This"])
    }

    @Test func aBundleIDBeatsADisplayName() {
        // An app whose display name is another app's bundle identifier.
        let names = ["com.a.one": "com.a.two", "com.a.two": "Two"]
        let ranking = SignalFiles.parseRanking("com.a.two", apps: ["com.a.one", "com.a.two"], names: names)
        #expect(ranking.order == ["com.a.two"])
    }

    @Test func colorFilesMapAppsToColors() throws {
        let json = ##"{"Spotify": "#1DB954", "com.chase.sig.ios": "117ACA", "Unknown": "#000000", "PayPal": "blue"}"##
        let parsed = try SignalFiles.parseColors(
            Data(json.utf8),
            apps: Array(Fixtures.names.keys),
            names: Fixtures.names
        )
        #expect(parsed.colors["com.spotify.client"]?.hex == "#1DB954")
        #expect(parsed.colors["com.chase.sig.ios"]?.hex == "#117ACA")
        #expect(parsed.unmatched == ["PayPal", "Unknown"])
        #expect(throws: SignalFiles.FileError.notAJSONObject) {
            try SignalFiles.parseColors(Data("[1]".utf8), apps: [], names: [:])
        }
    }

    @Test func builtInColorsCoverApplesAppsAndCanBeOverridden() {
        let colors = SignalFiles.iconColors(merging: ["com.apple.Music": RGBColor(hex: "#000000")!])
        #expect(colors["com.apple.mobilenotes"].map(ColorBand.of) == .yellow)
        #expect(colors["com.apple.Music"]?.hex == "#000000")
        for hex in KnownApps.iconColors.values {
            #expect(RGBColor(hex: hex) != nil, "\(hex) is not a color")
        }
    }

    // MARK: Plans and preview

    @Test func plansKeepTheirNotesThroughJSON() throws {
        let plan = plan(.mostUsed)
        #expect(plan.notes == [Signals.usageStandIn])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        #expect(try decoder.decode(OrganizationPlan.self, from: encoder.encode(plan)) == plan)
    }

    @Test func thePreviewLinksToEveryProposalAndShowsItsNotes() {
        let plans = OrganizationScheme.allCases.map { plan($0) }
        let html = HTMLPreviewRenderer.render(
            PreviewDocument(
                deviceName: "Test",
                generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
                names: BigPhone.names,
                categories: BigPhone.classifications,
                current: BigPhone.layout,
                plans: plans,
                iconColors: ["com.big.app1": RGBColor(hex: "#1DB954")!]
            )
        )
        for scheme in OrganizationScheme.allCases {
            #expect(html.contains("href=\"#\(scheme.rawValue)\""))
            #expect(html.contains("id=\"\(scheme.rawValue)\""))
        }
        #expect(html.contains("organize-my-iphone apply rainbow"))
        #expect(html.contains("No --usage file was given"))
        #expect(html.contains("#1DB954"))
        #expect(!html.contains("<script"))
    }
}
