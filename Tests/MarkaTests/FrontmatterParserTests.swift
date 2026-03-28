import XCTest
@testable import Marka

final class FrontmatterParserTests: XCTestCase {

    func testParseReturnsEmptyFieldsForPlainMarkdown() {
        let result = FrontmatterParser.parse("# Hello\n\nBody text.")
        XCTAssertEqual(result.fields.count, 0)
        XCTAssertEqual(result.body, "# Hello\n\nBody text.")
    }

    func testParseExtractsFields() {
        let md = "---\ntitle: My Note\ndate: 2024-01-15\n---\nBody here."
        let result = FrontmatterParser.parse(md)
        XCTAssertEqual(result.fields.count, 2)
        XCTAssertEqual(result.fields[0].key, "title")
        XCTAssertEqual(result.fields[0].value, "My Note")
        XCTAssertEqual(result.fields[1].key, "date")
        XCTAssertEqual(result.fields[1].value, "2024-01-15")
    }

    func testParsePreservesFieldOrder() {
        let md = "---\nz: last\na: first\nm: middle\n---\n"
        let result = FrontmatterParser.parse(md)
        XCTAssertEqual(result.fields.map(\.key), ["z", "a", "m"])
    }

    func testParseHandlesValueWithColon() {
        let md = "---\ndate: 2013-04-04T15:22:06+00:00\nurl: https://example.com/path\n---\n"
        let result = FrontmatterParser.parse(md)
        XCTAssertEqual(result.fields.count, 2)
        XCTAssertEqual(result.fields[0].value, "2013-04-04T15:22:06+00:00")
        XCTAssertEqual(result.fields[1].value, "https://example.com/path")
    }

    func testParseReturnsBothBodyAndFields() {
        let md = "---\ntitle: Hello\n---\n# Heading\n\nParagraph."
        let result = FrontmatterParser.parse(md)
        XCTAssertEqual(result.fields.count, 1)
        XCTAssertTrue(result.body.contains("# Heading"))
    }

    func testParseReturnsNoFieldsWhenFrontmatterUnclosed() {
        let md = "---\ntitle: Hello\nNo closing delimiter"
        let result = FrontmatterParser.parse(md)
        XCTAssertEqual(result.fields.count, 0)
        XCTAssertEqual(result.body, md)
    }

    func testParseAcceptsTripleDotClose() {
        let md = "---\ntitle: Test\n...\nBody."
        let result = FrontmatterParser.parse(md)
        XCTAssertEqual(result.fields.count, 1)
        XCTAssertEqual(result.fields[0].value, "Test")
        XCTAssertTrue(result.body.contains("Body."))
    }

    func testBodyFromDelegatesCorrectly() {
        let md = "---\ntitle: Test\n---\nBody."
        XCTAssertEqual(FrontmatterParser.body(from: md), "Body.")
    }
}
