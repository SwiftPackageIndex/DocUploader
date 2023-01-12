import Foundation

import DocUploader


@main
struct DocTest {
    static func main() async throws {
        let args = ProcessInfo.processInfo.arguments
        guard args.count > 1 else {
            fatalError("Usage: doc-test <sync path>")
        }
        try await UploaderTest.sync(path: args[1])
    }
}
