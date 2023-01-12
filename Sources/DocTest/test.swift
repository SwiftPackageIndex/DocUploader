import Foundation

import DocUploader


@main
struct DocTest {
    static func main() async throws {
        let args = ProcessInfo.processInfo.arguments
        guard args.count > 2 else {
            fatalError("Usage: doc-test <sync path> <s3 key>")
        }
        try await UploaderTest.test(syncPath: args[1], s3Key: args[2])
    }
}
