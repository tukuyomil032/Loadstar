import XCTest

@testable import LoadStarUI

@MainActor
final class LoadStarUITests: XCTestCase {
    func testDashboardViewCanBeConstructed() {
        _ = DashboardView()
        XCTAssertTrue(true)
    }
}
