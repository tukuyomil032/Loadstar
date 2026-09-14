import XCTest

@testable import LoadStarPersistence

final class LoadStarPersistenceTests: XCTestCase {
    func testManagedRootFolderNameIsStable() {
        XCTAssertEqual(LoadStarPersistence.managedRootFolderName, "LoadStar")
    }
}
