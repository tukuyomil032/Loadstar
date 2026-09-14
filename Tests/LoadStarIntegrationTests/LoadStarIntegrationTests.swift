import XCTest

@testable import LoadStarServices

final class LoadStarIntegrationTests: XCTestCase {
    func testIntegrationTargetLoads() {
        XCTAssertEqual(LoadStarServices.productName, "LoadStar")
    }
}
