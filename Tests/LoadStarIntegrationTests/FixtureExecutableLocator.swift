import Foundation

enum FixtureExecutableLocator {
    static func path() -> String? {
        guard let value = ProcessInfo.processInfo.environment["LOADSTAR_FIXTURE_SERVER_PATH"],
            !value.isEmpty,
            FileManager.default.isExecutableFile(atPath: value)
        else {
            return nil
        }
        return value
    }
}
