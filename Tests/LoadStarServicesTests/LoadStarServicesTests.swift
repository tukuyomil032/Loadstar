import XCTest

@testable import LoadStarServices

final class LoadStarServicesTests: XCTestCase {
    func testProductNameIsExposedByServices() {
        XCTAssertEqual(LoadStarServices.productName, "LoadStar")
    }
}
