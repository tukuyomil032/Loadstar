import Foundation

enum FixtureLoader {
    static func data(at relativePath: String) throws -> Data {
        guard let fixturesURL = Bundle.module.url(forResource: "Fixtures", withExtension: nil) else {
            throw FixtureLoaderError.bundleMissing
        }
        return try Data(contentsOf: fixturesURL.appendingPathComponent(relativePath))
    }
}

private enum FixtureLoaderError: Error {
    case bundleMissing
}
