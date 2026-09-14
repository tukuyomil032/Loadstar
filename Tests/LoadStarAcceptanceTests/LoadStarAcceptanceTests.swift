import XCTest

@testable import LoadStarUI

@MainActor
final class LoadStarAcceptanceTests: XCTestCase {
    func testInitialDashboardSurfaceCanBeConstructed() {
        _ = DashboardView()
        XCTAssertTrue(true)
    }
}
