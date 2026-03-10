import XCTest
@testable import Marka

final class RecentFilesTests: XCTestCase {
    private nonisolated(unsafe) var suiteName: String!
    private nonisolated(unsafe) var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "com.marka.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        UserDefaults.standard.removeSuite(named: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makePayload(
        path: String = "/test/file.md",
        title: String = "Test",
        baseURL: String? = nil,
        isTextBundle: Bool = false,
        bundlePath: String? = nil
    ) -> IPCPayload {
        IPCPayload(
            path: path,
            isTemp: false,
            title: title,
            baseURL: baseURL,
            isTextBundle: isTextBundle,
            bundlePath: bundlePath,
            extractedPath: nil
        )
    }

    // MARK: - Tests

    @MainActor func testStartsEmpty() {
        let rf = RecentFiles(defaults: defaults)
        XCTAssertEqual(rf.entries.count, 0)
    }

    @MainActor func testAddSingleEntry() {
        let rf = RecentFiles(defaults: defaults)
        rf.add(makePayload(path: "/a.md", title: "A"))
        let entries = rf.entries
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].path, "/a.md")
        XCTAssertEqual(entries[0].title, "A")
    }

    @MainActor func testAddPrependsToFront() {
        let rf = RecentFiles(defaults: defaults)
        rf.add(makePayload(path: "/a.md", title: "A"))
        rf.add(makePayload(path: "/b.md", title: "B"))
        let entries = rf.entries
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].path, "/b.md")
        XCTAssertEqual(entries[1].path, "/a.md")
    }

    @MainActor func testDeduplicatesByPath() {
        let rf = RecentFiles(defaults: defaults)
        rf.add(makePayload(path: "/a.md", title: "A"))
        rf.add(makePayload(path: "/b.md", title: "B"))
        rf.add(makePayload(path: "/a.md", title: "A Updated"))
        let entries = rf.entries
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].path, "/a.md")
        XCTAssertEqual(entries[0].title, "A Updated")
        XCTAssertEqual(entries[1].path, "/b.md")
    }

    @MainActor func testDeduplicatesByBundlePath() {
        let rf = RecentFiles(defaults: defaults)
        rf.add(makePayload(
            path: "/bundle/text.md",
            title: "Bundle",
            isTextBundle: true,
            bundlePath: "/bundle.textbundle"
        ))
        rf.add(makePayload(path: "/other.md", title: "Other"))
        rf.add(makePayload(
            path: "/bundle/text.md",
            title: "Bundle Again",
            isTextBundle: true,
            bundlePath: "/bundle.textbundle"
        ))
        let entries = rf.entries
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].title, "Bundle Again")
    }

    @MainActor func testTrimsToMaxCount() {
        let rf = RecentFiles(defaults: defaults)
        for i in 0..<15 {
            rf.add(makePayload(path: "/file\(i).md", title: "File \(i)"))
        }
        let entries = rf.entries
        XCTAssertEqual(entries.count, rf.maxCount)
        XCTAssertEqual(entries[0].path, "/file14.md")
    }

    @MainActor func testClearRemovesAllEntries() {
        let rf = RecentFiles(defaults: defaults)
        rf.add(makePayload(path: "/a.md", title: "A"))
        rf.add(makePayload(path: "/b.md", title: "B"))
        rf.clear()
        XCTAssertEqual(rf.entries.count, 0)
    }

    @MainActor func testEntriesRoundtripThroughJSON() {
        let rf = RecentFiles(defaults: defaults)
        rf.add(makePayload(
            path: "/test.md",
            title: "Test",
            baseURL: "/base",
            isTextBundle: true,
            bundlePath: "/test.textbundle"
        ))
        let fresh = RecentFiles(defaults: defaults)
        let entries = fresh.entries
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].path, "/test.textbundle")
        XCTAssertEqual(entries[0].baseURL, "/base")
        XCTAssertEqual(entries[0].isTextBundle, true)
        XCTAssertEqual(entries[0].bundlePath, "/test.textbundle")
    }
}
