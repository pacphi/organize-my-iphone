import Foundation
import Testing

@testable import OrganizeCore

@Suite("Taxonomy")
struct TaxonomyTests {
    @Test func matchesNamesLoosely() {
        let taxonomy = Taxonomy.standard
        #expect(taxonomy.canonicalName(for: "music and audio") == "Music & Audio")
        #expect(taxonomy.canonicalName(for: "  FINANCE ") == "Finance")
        #expect(taxonomy.canonicalName(for: "other") == "Other")
        #expect(taxonomy.canonicalName(for: "Nonsense") == nil)
        #expect(taxonomy.canonicalName(for: "") == nil)
    }

    @Test func ranksKnownCategoriesBeforeUnknownOnesAndTheFallbackLast() {
        let taxonomy = Taxonomy.standard
        #expect(taxonomy.rank(of: "Communication") == 0)
        #expect(taxonomy.rank(of: "Mystery") < taxonomy.rank(of: "Other"))
        #expect(taxonomy.rank(of: "Utilities") < taxonomy.rank(of: "Mystery"))
    }

    @Test func aHandWrittenTaxonomyMayOmitTheFallback() throws {
        let json = #"{"categories":[{"name":"Play","hint":"games and fun"}]}"#
        let taxonomy = try JSONDecoder().decode(Taxonomy.self, from: Data(json.utf8))
        #expect(taxonomy.fallback == "Other")
        #expect(taxonomy.names == ["Play", "Other"])
    }
}

@Suite("Heuristic classifier")
struct HeuristicClassifierTests {
    let classifier = HeuristicClassifier()
    let taxonomy = Taxonomy.standard

    @Test func knowsApplesOwnApps() {
        let result = classifier.classifyOne(AppRecord(bundleID: "com.apple.Maps", name: "Maps"), taxonomy: taxonomy)
        #expect(result.category == "Travel")
        #expect(result.source == "heuristic:system-app")
    }

    @Test func knowsBrowsersByBundleIdentifier() {
        let chrome = AppRecord(bundleID: "com.google.chrome.ios", name: "Chrome", storeGenre: "Utilities")
        let result = classifier.classifyOne(chrome, taxonomy: taxonomy)
        #expect(result.category == "Browsers")
        #expect(result.source == "heuristic:known-browser")
        #expect(result.confidence >= TieredClassification.defaultThreshold)

        let safari = AppRecord(bundleID: "com.apple.mobilesafari", name: "Safari")
        #expect(classifier.classifyOne(safari, taxonomy: taxonomy).category == "Browsers")

        // The phone reports mixed-case identifiers; the table is matched without regard to case.
        let firefox = AppRecord(bundleID: "org.mozilla.ios.Firefox", name: "Firefox", storeGenre: "Utilities")
        #expect(classifier.classifyOne(firefox, taxonomy: taxonomy).source == "heuristic:known-browser")
    }

    @Test func recognisesOtherBrowsersByName() {
        let onion = AppRecord(bundleID: "com.example.onion", name: "Onion Browser", storeGenre: "Utilities")
        let result = classifier.classifyOne(onion, taxonomy: taxonomy)
        #expect(result.category == "Browsers")
        #expect(result.source == "heuristic:keyword")

        let vivaldi = AppRecord(bundleID: "com.example.v", name: "Vivaldi", storeGenre: "Utilities")
        #expect(classifier.classifyOne(vivaldi, taxonomy: taxonomy).category == "Browsers")

        // A browser from an AI company is still a browser.
        let comet = AppRecord(bundleID: "ai.perplexity.comet", name: "Comet Browser", storeGenre: "Productivity")
        #expect(classifier.classifyOne(comet, taxonomy: taxonomy).category == "Browsers")

        // Sharing a word with a browser's name is not enough.
        let remote = AppRecord(
            bundleID: "com.google.chromeremotedesktop", name: "Chrome Remote Desktop", storeGenre: "Utilities")
        #expect(classifier.classifyOne(remote, taxonomy: taxonomy).category == "Utilities")
    }

    @Test func browsersGoToUtilitiesWhenATaxonomyHasNoBrowserCategory() {
        let custom = Taxonomy(categories: [AppCategory(name: "Utilities", hint: "tools")])
        let safari = AppRecord(bundleID: "com.apple.mobilesafari", name: "Safari")
        #expect(classifier.classifyOne(safari, taxonomy: custom).category == "Utilities")
    }

    @Test func usesWholeWordKeywords() {
        let chatGPT = AppRecord(bundleID: "com.openai.chat", name: "ChatGPT")
        #expect(classifier.classifyOne(chatGPT, taxonomy: taxonomy).category == "AI")

        // "Mail Pilot" contains the letters "ai" but not the word; it must not become an AI app.
        let mail = AppRecord(bundleID: "com.mindsense.mailpilot", name: "Mail Pilot")
        #expect(classifier.classifyOne(mail, taxonomy: taxonomy).category == "Other")
    }

    @Test func keywordsBeatTheStoreGenre() {
        let slack = AppRecord(bundleID: "com.tinyspeck.chatlyio", name: "Slack", storeGenre: "Business")
        #expect(classifier.classifyOne(slack, taxonomy: taxonomy).category == "Communication")
    }

    @Test func fallsBackToTheStoreGenre() {
        let app = AppRecord(bundleID: "com.example.budget", name: "Budgeteer", storeGenre: "Finance")
        let result = classifier.classifyOne(app, taxonomy: taxonomy)
        #expect(result.category == "Finance")
        #expect(result.source == "heuristic:store-genre")
    }

    @Test func unknownAppsGoToTheFallbackWithLowConfidence() {
        let app = AppRecord(bundleID: "com.example.zzz", name: "Zzz")
        let result = classifier.classifyOne(app, taxonomy: taxonomy)
        #expect(result.category == "Other")
        #expect(result.confidence < 0.5)
    }

    @Test func aCustomTaxonomyCanUseStoreGenreNamesDirectly() {
        let custom = Taxonomy(categories: [
            AppCategory(name: "Finance", hint: "money"),
            AppCategory(name: "Navigation", hint: "maps"),
        ])
        let waze = AppRecord(bundleID: "com.example.roads", name: "Roads", storeGenre: "Navigation")
        #expect(classifier.classifyOne(waze, taxonomy: custom).category == "Navigation")

        // "Travel" is not in this taxonomy, so Apple Maps has nowhere better to go.
        let maps = AppRecord(bundleID: "com.apple.Maps", name: "Maps")
        #expect(classifier.classifyOne(maps, taxonomy: custom).category == "Other")
    }
}

@Suite("Tiered classification")
struct TieredClassificationTests {
    let taxonomy = Taxonomy.standard
    let apps = [
        AppRecord(bundleID: "com.apple.Maps", name: "Maps"),
        AppRecord(bundleID: "com.example.ledger", name: "Ledgerly", storeGenre: "Finance"),
        AppRecord(bundleID: "com.example.notes", name: "Notely", storeGenre: "Productivity"),
        AppRecord(bundleID: "com.example.zzz", name: "Zzz"),
        AppRecord(bundleID: "com.openai.chat", name: "ChatGPT", storeGenre: "Productivity"),
    ]

    @Test func rulesAreConfidentAboutAppleAppsAndDecisiveGenresOnly() {
        let rules = HeuristicClassifier()
        let confidences = apps.map { rules.classifyOne($0, taxonomy: taxonomy).confidence }
        let threshold = TieredClassification.defaultThreshold
        // Apple app, decisive genre: sure. Catch-all genre, unknown app, keyword match: not sure.
        #expect(confidences.map { $0 >= threshold } == [true, true, false, false, false])
    }

    @Test func onlyUncertainAppsAreLeftForTheModel() {
        let split = TieredClassification.split(apps, taxonomy: taxonomy)
        #expect(split.settled.map { $0.bundleID } == ["com.apple.Maps", "com.example.ledger"])
        #expect(split.settled.map { $0.category } == ["Travel", "Finance"])
        #expect(split.undecided.map { $0.bundleID } == ["com.example.notes", "com.example.zzz", "com.openai.chat"])
    }

    @Test func aThresholdOfZeroSettlesEverythingByRules() {
        let split = TieredClassification.split(apps, taxonomy: taxonomy, threshold: 0)
        #expect(split.settled.count == 5)
        #expect(split.undecided.isEmpty)
    }

    @Test func mergingKeepsTheOriginalOrderAndFillsGapsWithRules() {
        let split = TieredClassification.split(apps, taxonomy: taxonomy)
        let judged = [
            Classification(bundleID: "com.openai.chat", category: "AI", confidence: 0.85, source: "llm:fake"),
            Classification(bundleID: "com.example.notes", category: "Work", confidence: 0.85, source: "llm:fake"),
        ]
        let merged = TieredClassification.merge(order: apps, settled: split.settled, judged: judged, taxonomy: taxonomy)

        #expect(merged.map { $0.bundleID } == apps.map { $0.bundleID })
        #expect(merged.map { $0.category } == ["Travel", "Finance", "Work", "Other", "AI"])
        // The model never answered for Zzz, so the rules placed it.
        #expect(merged[3].source == "heuristic:fallback")
    }

    @Test func aModelAnswerWinsOverARule() {
        let split = TieredClassification.split(apps, taxonomy: taxonomy)
        let judged = [Classification(bundleID: "com.apple.Maps", category: "Lifestyle", confidence: 0.85, source: "llm:fake")]
        let merged = TieredClassification.merge(order: apps, settled: split.settled, judged: judged, taxonomy: taxonomy)
        #expect(merged[0].category == "Lifestyle")
    }
}

@Suite("Classification prompt and reply")
struct ClassificationPromptTests {
    let taxonomy = Taxonomy.standard
    let batch = [
        AppRecord(bundleID: "com.a", name: "Alpha"),
        AppRecord(bundleID: "com.b", name: "Beta"),
        AppRecord(bundleID: "com.c", name: "Gamma"),
    ]

    @Test func thePromptListsEveryCategoryAndNumbersEveryApp() {
        let apps = [
            AppRecord(bundleID: "com.example.budget", name: "Budgeteer", storeGenre: "Finance", summary: "Track spending"),
            AppRecord(bundleID: "com.example.zzz", name: "Zzz"),
        ]
        let prompt = ClassificationPrompt.build(apps: apps, taxonomy: taxonomy)
        for name in taxonomy.names {
            #expect(prompt.contains("- \(name):"))
        }
        #expect(prompt.contains("1. Budgeteer (com.example.budget) | App Store genre: Finance | Track spending"))
        #expect(prompt.contains("2. Zzz (com.example.zzz)"))
        #expect(prompt.contains("Answer for every number from 1 to 2."))
    }

    @Test func longDescriptionsAreShortenedToKeepThePromptSmall() {
        let long = String(repeating: "x", count: 300)
        let prompt = ClassificationPrompt.build(
            apps: [AppRecord(bundleID: "com.a", name: "Alpha", summary: long)],
            taxonomy: taxonomy
        )
        #expect(!prompt.contains(long))
        #expect(prompt.contains(String(repeating: "x", count: 119) + "…"))
    }

    @Test func theSchemaRequiresOneValidCategoryPerApp() {
        let schema = ClassificationPrompt.schema(taxonomy: taxonomy, count: 3)
        #expect(schema["properties"]?.objectValue?.keys.sorted() == ["1", "2", "3"])
        #expect(schema["required"] == .array([.string("1"), .string("2"), .string("3")]))
        #expect(schema["additionalProperties"] == .bool(false))

        let allowed = schema["properties"]?["2"]?["enum"]?.arrayValue
        #expect(allowed?.count == taxonomy.names.count)
        #expect(allowed?.contains(.string("Other")) == true)
    }

    @Test func readsTheNumberedReplyAndDropsUnknownCategories() {
        let reply = #"{"1":"finance","2":"Made Up","3":"AI"}"#
        let result = ClassificationResponseParser.parse(reply, apps: batch, taxonomy: taxonomy)
        #expect(result == ["com.a": "Finance", "com.c": "AI"])
    }

    @Test func ignoresNumbersOutsideTheBatch() {
        let reply = #"{"0":"Games","4":"Games","2":"Games"}"#
        #expect(ClassificationResponseParser.parse(reply, apps: batch, taxonomy: taxonomy) == ["com.b": "Games"])
    }

    @Test func readsAnAssignmentsArrayByBundleIdentifierOrNumber() {
        let reply = """
            {"assignments":[
              {"bundleID":"com.a","category":"finance"},
              {"number":2,"category":"Games"},
              {"bundleId":"com.c","category":"AI"},
              {"bundleID":"not.in.this.batch","category":"AI"}
            ]}
            """
        let result = ClassificationResponseParser.parse(reply, apps: batch, taxonomy: taxonomy)
        #expect(result == ["com.a": "Finance", "com.b": "Games", "com.c": "AI"])
    }

    @Test func readsAFencedBareArray() {
        let reply = "```json\n[{\"id\":\"com.a\",\"category\":\"Games\"}]\n```"
        #expect(ClassificationResponseParser.parse(reply, apps: batch, taxonomy: taxonomy) == ["com.a": "Games"])
    }

    @Test func readsAnObjectKeyedByBundleIdentifier() {
        let reply = #"{"com.a":"Travel","com.b":"???"}"#
        #expect(ClassificationResponseParser.parse(reply, apps: batch, taxonomy: taxonomy) == ["com.a": "Travel"])
    }

    @Test func returnsNothingForProse() {
        #expect(ClassificationResponseParser.parse("I cannot help with that.", apps: batch, taxonomy: taxonomy).isEmpty)
    }
}

@Suite("LLM classifier")
struct LLMClassifierTests {
    let taxonomy = Taxonomy.standard
    let apps = [
        AppRecord(bundleID: "com.a", name: "Alpha"),
        AppRecord(bundleID: "com.b", name: "Beta"),
        AppRecord(bundleID: "com.apple.Maps", name: "Maps"),
    ]

    @Test func batchesRequestsAndFillsGapsWithRules() async throws {
        let model = FakeModel(replies: [
            .success(#"{"assignments":[{"bundleID":"com.a","category":"Games"},{"bundleID":"com.b","category":"Finance"}]}"#),
            .success("sorry, no idea"),
        ])
        let classifier = LLMClassifier(model: model, batchSize: 2)
        let results = try await classifier.classify(apps, taxonomy: taxonomy)

        #expect(results.map { $0.bundleID } == ["com.a", "com.b", "com.apple.Maps"])
        #expect(results.map { $0.category } == ["Games", "Finance", "Travel"])
        #expect(results[0].source == "llm:fake")
        #expect(results[2].source == "heuristic:system-app")
        #expect(await model.prompts.count == 2)
    }

    @Test func asksForACompactNumberedReply() async throws {
        let model = FakeModel(replies: [.success(#"{"1":"Games","2":"Finance","3":"Travel"}"#)])
        let results = try await LLMClassifier(model: model, batchSize: 10).classify(apps, taxonomy: taxonomy)

        #expect(results.map { $0.category } == ["Games", "Finance", "Travel"])
        #expect(results.allSatisfy { $0.source == "llm:fake" })
        let prompt = try #require(await model.prompts.first)
        #expect(prompt.contains("3. Maps (com.apple.Maps)"))
    }

    @Test func aFailureOnTheFirstBatchIsReported() async {
        let model = FakeModel(replies: [.failure(FakeFailure())])
        let classifier = LLMClassifier(model: model, batchSize: 2)
        await #expect(throws: FakeFailure.self) {
            try await classifier.classify(apps, taxonomy: taxonomy)
        }
    }

    @Test func aLaterFailureFallsBackToRules() async throws {
        let model = FakeModel(replies: [
            .success(#"{"assignments":[{"bundleID":"com.a","category":"Games"},{"bundleID":"com.b","category":"Games"}]}"#),
            .failure(FakeFailure()),
        ])
        let classifier = LLMClassifier(model: model, batchSize: 2)
        let results = try await classifier.classify(apps, taxonomy: taxonomy)
        #expect(results.count == 3)
        #expect(results[2].category == "Travel")
    }

    @Test func reportsProgressBeforeTheFirstBatchAndAfterEachOne() async throws {
        let log = ProgressLog()
        let model = FakeModel(replies: [.success("{}"), .success("{}")])
        let classifier = LLMClassifier(model: model, batchSize: 2) { completed, total in
            log.record(completed, total)
        }

        _ = try await classifier.classify(apps, taxonomy: taxonomy)

        #expect(log.all == [[0, 3], [2, 3], [3, 3]])
    }

    @Test func namesItsEngineAfterTheModel() {
        #expect(LLMClassifier(model: FakeModel(replies: [])).engineName == "llm:fake")
    }
}

@Suite("App catalog")
struct AppCatalogTests {
    @Test func mergesThePhoneTheStoreAndBuiltInNames() {
        let records = AppCatalog.records(
            for: ["com.a", "com.apple.Maps", "com.b", "com.acme.SuperNotes", "com.a"],
            installed: [AppRecord(bundleID: "com.a", name: "Alpha", version: "1.0")],
            store: [
                "com.a": AppStoreMetadata(bundleID: "com.a", name: "Alpha: The App", primaryGenre: "Games"),
                "com.b": AppStoreMetadata(bundleID: "com.b", name: "Beta", primaryGenre: "Finance", summary: "Banking"),
            ]
        )
        #expect(records.map { $0.bundleID } == ["com.a", "com.apple.Maps", "com.b", "com.acme.SuperNotes"])
        #expect(records.map { $0.name } == ["Alpha", "Maps", "Beta", "SuperNotes"])
        #expect(records[0].storeGenre == "Games")
        #expect(records[0].version == "1.0")
        #expect(records[2].summary == "Banking")
        #expect(AppCatalog.names(of: records)["com.b"] == "Beta")
    }
}
