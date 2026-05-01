import XCTest
@testable import VoiceTag

final class TagParserTests: XCTestCase {

    let parser = TagParser()
    var config: AppConfig = .default

    override func setUp() {
        super.setUp()
        config = .default
        config.baseDirectory = "/tmp/VoiceTagTests"
        config.tagMappings = [
            "kuari pass": "Kuari_Pass",
            "not kuari": "Not_Kuari"
        ]
    }

    func testSkipCommand() {
        let action = parser.parse(text: "skip", currentFolder: nil, config: config)
        if case .skip = action { } else { XCTFail("Expected .skip") }
    }

    func testSkipCommandVariants() {
        for cmd in ["next", "pass"] {
            let action = parser.parse(text: cmd, currentFolder: nil, config: config)
            if case .skip = action { } else { XCTFail("Expected .skip for '\(cmd)'") }
        }
    }

    func testDeleteCommand() {
        let action = parser.parse(text: "delete", currentFolder: nil, config: config)
        if case .delete = action { } else { XCTFail("Expected .delete") }
    }

    func testDeleteVariants() {
        for cmd in ["trash", "remove", "discard"] {
            let action = parser.parse(text: cmd, currentFolder: nil, config: config)
            if case .delete = action { } else { XCTFail("Expected .delete for '\(cmd)'") }
        }
    }

    func testUndoCommand() {
        let action = parser.parse(text: "undo", currentFolder: nil, config: config)
        if case .undo = action { } else { XCTFail("Expected .undo") }
    }

    func testCustomTagMapping() {
        let action = parser.parse(text: "kuari pass", currentFolder: nil, config: config)
        if case .tag(let url) = action {
            XCTAssertTrue(url.path.contains("Kuari_Pass"), "Expected Kuari_Pass in path: \(url.path)")
        } else {
            XCTFail("Expected .tag for 'kuari pass'")
        }
    }

    func testNotKuariMapping() {
        let action = parser.parse(text: "not kuari", currentFolder: nil, config: config)
        if case .tag(let url) = action {
            XCTAssertTrue(url.path.contains("Not_Kuari"))
        } else {
            XCTFail("Expected .tag")
        }
    }

    func testDayParsing() {
        let action = parser.parse(text: "kuari pass day 2", currentFolder: nil, config: config)
        if case .tag(let url) = action {
            // Should have multiple path components
            XCTAssertTrue(url.path.contains("day_2") || url.path.contains("Day_2"),
                          "Day should be in path: \(url.path)")
        } else {
            XCTFail("Expected .tag")
        }
    }

    func testFillerWordRemoval() {
        let action1 = parser.parse(text: "the beach", currentFolder: nil, config: config)
        let action2 = parser.parse(text: "beach", currentFolder: nil, config: config)
        if case .tag(let url1) = action1, case .tag(let url2) = action2 {
            XCTAssertEqual(url1.lastPathComponent, url2.lastPathComponent)
        }
    }

    func testCaseInsensitive() {
        let action = parser.parse(text: "SKIP", currentFolder: nil, config: config)
        if case .skip = action { } else { XCTFail("Expected .skip for 'SKIP'") }
    }

    func testSpaceNormalization() {
        let action = parser.parse(text: "family photos", currentFolder: nil, config: config)
        if case .tag(let url) = action {
            XCTAssertFalse(url.path.contains(" "), "Path should not contain spaces: \(url.path)")
        }
    }
}
