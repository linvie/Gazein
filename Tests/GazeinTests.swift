import XCTest
@testable import Gazein

final class GazeinTests: XCTestCase {
    func testConfigLoading() throws {
        // Test JSON config parsing
        let json = """
        {
            "profile_name": "Test Profile",
            "trigger": {
                "type": "key_simulation",
                "key": "arrow_down",
                "interval_ms": 1000
            },
            "capture": {
                "region": { "x": 0, "y": 0, "width": 100, "height": 100 }
            },
            "extractor": {
                "type": "vision_ocr"
            },
            "writer": {
                "type": "sqlite"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let profile = try decoder.decode(Profile.self, from: data)

        XCTAssertEqual(profile.profileName, "Test Profile")
        XCTAssertEqual(profile.trigger.type, "key_simulation")
        XCTAssertEqual(profile.trigger.key, "arrow_down")
        XCTAssertEqual(profile.capture.region.width, 100)
    }

    func testSessionManager() {
        let manager = SessionManager()

        manager.startNewSession()
        XCTAssertFalse(manager.currentSessionId.isEmpty)

        let seq1 = manager.nextSeq()
        let seq2 = manager.nextSeq()

        XCTAssertEqual(seq1, 1)
        XCTAssertEqual(seq2, 2)
    }
}
