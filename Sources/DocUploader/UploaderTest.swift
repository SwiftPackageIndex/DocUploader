

public enum UploaderTest {
    public static func sync(path: String) async throws {
        let targetKey = S3Key(bucketName: "spi-dev-docs", objectKey: "swiftpackageindex/semanticversion/0.3.5")
        print("Syncing \(path) to \(targetKey) ...")

//        logger.info("Syncing \(syncPath) to \(targetKey) ...")
//        try await Current.s3Client.sync(client: awsClient,
//                                        logger: logger,
//                                        from: syncPath,
//                                        to: metadata.targetFolder.s3Key)
//        logger.info("✅ Completed syncing \(syncPath)")
    }
}
