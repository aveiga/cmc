import Foundation
import Testing

/// Loads a checked-in copy of a real page from `CMCTests/Fixtures/`.
///
/// Every parser test runs against these, so the suite is offline, deterministic
/// and fast. When `Scripts/refresh-fixtures.sh` re-downloads them and tests
/// start failing, the site changed — that diff *is* the alert, and the failing
/// test names the selector that died (PLAN §3.4).
enum Fixture {
    static func html(_ name: String) throws -> String {
        try load(name, extension: "html")
    }

    static func data(_ name: String, extension ext: String) throws -> Data {
        guard let url = Bundle(for: BundleToken.self)
            .url(forResource: name, withExtension: ext) else {
            throw FixtureError.missing("\(name).\(ext)")
        }
        return try Data(contentsOf: url)
    }

    private static func load(_ name: String, extension ext: String) throws -> String {
        let data = try data(name, extension: ext)
        guard let text = String(data: data, encoding: .utf8) else {
            throw FixtureError.undecodable("\(name).\(ext)")
        }
        return text
    }

    enum FixtureError: Error, CustomStringConvertible {
        case missing(String)
        case undecodable(String)

        var description: String {
            switch self {
            case .missing(let name):
                return "Fixture \(name) not found. Run Scripts/refresh-fixtures.sh."
            case .undecodable(let name):
                return "Fixture \(name) is not valid UTF-8."
            }
        }
    }

    private final class BundleToken {}
}
