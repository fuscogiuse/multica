import Foundation
import XCTest
@testable import CalmCore

enum Fixture {
    static func data(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws -> Data {
        let bundle = Bundle(for: BundleToken.self)
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: "json")
        guard let url else {
            XCTFail("Missing fixture \(name)", file: file, line: line)
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        try APIClient.decoder.decode(T.self, from: try data(name))
    }
}

private final class BundleToken {}
