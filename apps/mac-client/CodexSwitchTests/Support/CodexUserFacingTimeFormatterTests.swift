import XCTest
@testable import CodexSwitchKit

final class CodexUserFacingTimeFormatterTests: XCTestCase {
    func testFormatterRendersDisplayLogAndFilenameTimestampsInRequestedTimeZone() {
        let formatter = CodexUserFacingTimeFormatter(timeZone: TimeZone(secondsFromGMT: 8 * 3600)!)
        let date = Date(timeIntervalSince1970: 1_743_157_872)

        XCTAssertEqual(formatter.displayTimestamp(from: date), "2025-03-28 18:31:12 +08:00")
        XCTAssertEqual(formatter.logTimestamp(from: date), "2025-03-28T18:31:12+08:00")
        XCTAssertEqual(formatter.filenameTimestamp(from: date), "20250328T183112")
    }
}
