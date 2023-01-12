import Foundation

import AsyncHTTPClient
import Logging
import SotoS3
import SotoS3FileTransfer


public enum UploaderTest {
    enum Error: Swift.Error {
        case noCredentials
    }

    public static func test(syncPath: String, s3Key: String) async throws {
        let logger = Logger(label: "upload-test")

        guard let accessKeyId = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"],
              let secretAccessKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] else {
            throw Error.noCredentials
        }

        let awsClient = AWSClient(
            credentialProvider: .static(accessKeyId: accessKeyId, secretAccessKey: secretAccessKey),
            httpClientProvider: .createNew
        )
        defer { try? awsClient.syncShutdown() }

        let targetKey = S3Key(bucketName: "spi-scratch", objectKey: s3Key)

        logger.info("Syncing \(syncPath) to \(targetKey) ...")
        try await LiveS3Client().sync(client: awsClient,
                                      logger: logger,
                                      from: syncPath,
                                      to: targetKey)
        logger.info("✅ Completed syncing \(syncPath)")
    }
}
