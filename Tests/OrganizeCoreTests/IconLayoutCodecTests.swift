import Foundation
import Testing

@testable import OrganizeCore

@Suite("Icon layout codec")
struct IconLayoutCodecTests {
    @Test func decodesDockPagesFoldersAndWebClips() throws {
        let layout = try IconLayoutCodec.decode(text: Fixtures.layoutJSON)
        #expect(layout == Fixtures.layout)
    }

    @Test func encodingThenDecodingGivesTheSameLayout() throws {
        let encoded = IconLayoutCodec.encode(Fixtures.layout)
        #expect(try IconLayoutCodec.decode(encoded) == Fixtures.layout)
    }

    @Test func singlePageFoldersAreFlatAndMultiPageFoldersAreNested() {
        let single = IconFolder(name: "Money", pages: [[.app("a"), .app("b")]])
        let multi = IconFolder(name: "Big", pages: [[.app("a")], [.app("b")]])
        #expect(IconLayoutCodec.encodeItem(.folder(single)) == .array([.string("Money"), .string("a"), .string("b")]))
        #expect(
            IconLayoutCodec.encodeItem(.folder(multi))
                == .array([.string("Big"), .array([.string("a")]), .array([.string("b")])])
        )
    }

    @Test func acceptsTheCfgutilJSONEnvelope() throws {
        let envelope = """
            {"Command":"get-icon-layout","Type":"CommandOutput","Devices":["0x1"],
             "Output":{"0x1":[["dock.app"],["page.app"]],"Errors":{"0x1":{}}}}
            """
        let layout = try IconLayoutCodec.decode(text: envelope)
        #expect(layout.dock == [.app("dock.app")])
        #expect(layout.pages == [[.app("page.app")]])
    }

    @Test func keepsItemsItDoesNotUnderstand() throws {
        let source = try JSONValue.parse(#"[[],[{"widget":"clock"},42,"com.example.app"]]"#)
        let layout = try IconLayoutCodec.decode(source)
        #expect(
            layout.pages == [
                [.unknown(.object(["widget": .string("clock")])), .unknown(.number(42)), .app("com.example.app")]
            ]
        )
        #expect(IconLayoutCodec.encode(layout) == source)
    }

    @Test(arguments: ["{}", "[]", "[1]", "hello"])
    func rejectsThingsThatAreNotLayouts(text: String) {
        #expect(throws: IconLayoutError.self) {
            try IconLayoutCodec.decode(text: text)
        }
    }

    @Test func layoutsAreStoredOnDiskInCfgutilFormat() throws {
        let data = try JSONEncoder().encode(Fixtures.layout)
        #expect(try JSONValue.parse(data) == IconLayoutCodec.encode(Fixtures.layout))
        #expect(try JSONDecoder().decode(IconLayout.self, from: data) == Fixtures.layout)
    }

    @Test func flattenedViewsCountEveryApp() {
        let layout = Fixtures.layout
        #expect(layout.appBundleIDs.count == 13)
        #expect(layout.dockAppBundleIDs.count == 4)
        #expect(layout.folders.map { $0.name } == ["Money", "Big"])
        #expect(layout.flattenedItems.count == 14)
    }
}
