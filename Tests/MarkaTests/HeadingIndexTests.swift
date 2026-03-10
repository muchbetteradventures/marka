import XCTest
@testable import Marka

final class HeadingIndexTests: XCTestCase {

    // MARK: - parseHeadings

    func testParsesATXHeadings() {
        let md = """
        # Heading 1
        ## Heading 2
        ### Heading 3
        #### Heading 4
        ##### Heading 5
        ###### Heading 6
        """
        let headings = HeadingIndex.parseHeadings(from: md)
        XCTAssertEqual(headings.count, 6)
        XCTAssertEqual(headings[0].level, 1)
        XCTAssertEqual(headings[0].text, "Heading 1")
        XCTAssertEqual(headings[5].level, 6)
        XCTAssertEqual(headings[5].text, "Heading 6")
    }

    func testIgnoresNonHeadingLines() {
        let md = """
        Regular text
        Not a heading
        #no space after hash
        ##also no space
        """
        let headings = HeadingIndex.parseHeadings(from: md)
        XCTAssertEqual(headings.count, 0)
    }

    func testIgnoresEmptyHeadings() {
        let md = "# \n## \n###"
        let headings = HeadingIndex.parseHeadings(from: md)
        XCTAssertEqual(headings.count, 0)
    }

    func testIgnoresHeadingsAboveLevel6() {
        let md = "####### Not a heading"
        let headings = HeadingIndex.parseHeadings(from: md)
        XCTAssertEqual(headings.count, 0)
    }

    func testHandlesCodeBlockHeadings() {
        // Headings inside code blocks are still parsed by this function.
        // The build() method handles filtering via attributed string lookup.
        // parseHeadings is a simple line-by-line parser.
        let md = """
        # Real Heading
        ```
        # Not a heading
        ```
        ## Another Real
        """
        let headings = HeadingIndex.parseHeadings(from: md)
        // parseHeadings doesn't know about code blocks, it sees 3 headings
        XCTAssertEqual(headings.count, 3)
    }

    func testParsesFixtureFile() throws {
        let fixtureURL = Bundle(for: type(of: self)).bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tests/Fixtures/headings.md")

        // Fallback to source tree path
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/headings.md")

        let url = FileManager.default.fileExists(atPath: fixtureURL.path) ? fixtureURL : sourceURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Fixture headings.md not found")
        }

        let md = try String(contentsOf: url, encoding: .utf8)
        let headings = HeadingIndex.parseHeadings(from: md)
        XCTAssertEqual(headings.count, 7)
        XCTAssertEqual(headings[0].level, 1)
        XCTAssertEqual(headings[0].text, "Top Level Heading")
        XCTAssertEqual(headings[1].level, 2)
        XCTAssertEqual(headings[6].level, 2)
        XCTAssertEqual(headings[6].text, "Another Second Level")
    }

    // MARK: - nextHeading / previousHeading

    func testNextHeadingFindsFirstAfterPosition() {
        let index = HeadingIndex(entries: [
            .init(level: 1, text: "A", yPosition: 0),
            .init(level: 2, text: "B", yPosition: 100),
            .init(level: 3, text: "C", yPosition: 200),
        ])

        let result = index.nextHeading(after: 50)
        XCTAssertEqual(result?.text, "B")
    }

    func testNextHeadingReturnsNilAtEnd() {
        let index = HeadingIndex(entries: [
            .init(level: 1, text: "A", yPosition: 0),
        ])

        XCTAssertNil(index.nextHeading(after: 100))
    }

    func testNextHeadingMajorOnlySkipsMinorHeadings() {
        let index = HeadingIndex(entries: [
            .init(level: 1, text: "A", yPosition: 0),
            .init(level: 3, text: "B", yPosition: 100),
            .init(level: 2, text: "C", yPosition: 200),
        ])

        let result = index.nextHeading(after: 50, majorOnly: true)
        XCTAssertEqual(result?.text, "C")
    }

    func testPreviousHeadingFindsLastBeforePosition() {
        let index = HeadingIndex(entries: [
            .init(level: 1, text: "A", yPosition: 0),
            .init(level: 2, text: "B", yPosition: 100),
            .init(level: 3, text: "C", yPosition: 200),
        ])

        let result = index.previousHeading(before: 150)
        XCTAssertEqual(result?.text, "B")
    }

    func testPreviousHeadingReturnsNilAtStart() {
        let index = HeadingIndex(entries: [
            .init(level: 1, text: "A", yPosition: 100),
        ])

        XCTAssertNil(index.previousHeading(before: 50))
    }

    func testPreviousHeadingMajorOnly() {
        let index = HeadingIndex(entries: [
            .init(level: 2, text: "A", yPosition: 0),
            .init(level: 3, text: "B", yPosition: 100),
            .init(level: 4, text: "C", yPosition: 200),
        ])

        let result = index.previousHeading(before: 250, majorOnly: true)
        XCTAssertEqual(result?.text, "A")
    }

    func testNavigationToleranceSkipsCurrentPosition() {
        // The ±1 tolerance means a heading at exactly scrollY shouldn't match
        let index = HeadingIndex(entries: [
            .init(level: 1, text: "A", yPosition: 100),
        ])

        XCTAssertNil(index.nextHeading(after: 100))
        XCTAssertNil(index.previousHeading(before: 100))
    }

    func testEmptyIndexReturnsNil() {
        let index = HeadingIndex(entries: [])
        XCTAssertNil(index.nextHeading(after: 0))
        XCTAssertNil(index.previousHeading(before: 100))
    }
}
