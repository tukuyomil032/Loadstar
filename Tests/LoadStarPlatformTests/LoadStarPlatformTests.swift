import XCTest

@testable import LoadStarPlatform

final class LoadStarPlatformTests: XCTestCase {
    func testMinimumMacOSMajorVersion() {
        XCTAssertEqual(LoadStarPlatform.minimumMacOSMajorVersion, 26)
    }
}
