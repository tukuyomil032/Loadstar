import XCTest

@testable import LoadStarDomain

final class LoadStarDomainTests: XCTestCase {
    func testProductNameIsStable() {
        XCTAssertEqual(LoadStarDomain.productName, "LoadStar")
    }
}
