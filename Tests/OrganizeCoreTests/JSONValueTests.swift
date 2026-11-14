import Foundation
import Testing

@testable import OrganizeCore

@Suite("JSON value")
struct JSONValueTests {
    @Test func parsesEveryKindOfValue() throws {
        let value = try JSONValue.parse(#"{"a":[1,true,null,"x",{"b":2.5}]}"#)
        let expected = JSONValue.object([
            "a": .array([.number(1), .bool(true), .null, .string("x"), .object(["b": .number(2.5)])])
        ])
        #expect(value == expected)
    }

    @Test func wholeNumbersSerializeWithoutAFraction() throws {
        let text = String(decoding: try JSONValue.number(17_825_792).serialized(), as: UTF8.self)
        #expect(text == "17825792")
    }

    @Test func serializationRoundTrips() throws {
        let original = JSONValue.object(["name": .string("a/b"), "list": .array([.bool(false), .number(3)])])
        let copy = try JSONValue.parse(try original.serialized(pretty: true))
        #expect(copy == original)
    }

    @Test func accessorsReturnNilForTheWrongKind() {
        let value = JSONValue.string("hello")
        #expect(value.stringValue == "hello")
        #expect(value.arrayValue == nil)
        #expect(value.objectValue == nil)
        #expect(value["key"] == nil)
    }
}

@Suite("JSON text extraction")
struct JSONTextTests {
    @Test func extractsJSONFromACodeFence() {
        let reply = "Here you go:\n```json\n{\"a\":1}\n```\nAnything else?"
        #expect(JSONText.extract(from: reply) == .object(["a": .number(1)]))
    }

    @Test func extractsAnArrayAfterLeadingNoise() {
        let output = "warning: something minor\n[[\"a\"]]"
        #expect(JSONText.extract(from: output) == .array([.array([.string("a")])]))
    }

    @Test func returnsNilWhenThereIsNoJSON() {
        #expect(JSONText.extract(from: "I cannot help with that.") == nil)
        #expect(JSONText.extract(from: "   ") == nil)
    }
}
