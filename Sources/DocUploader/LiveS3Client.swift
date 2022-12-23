import SotoS3
import SotoS3FileTransfer


struct LiveS3Client: S3Client {
    func loadFile(client: AWSClient, logger: Logger, from key: S3StoreKey, to path: String) async throws {
        logger.info("Copying \(key) to \(path) ...")

        let s3 = S3(client: client, region: .useast2)
        let s3FileTransfer = S3FileTransferManager(s3: s3, threadPoolProvider: .createNew)

        guard let file = S3File(key: key) else {
            throw Error(message: "Invalid key: \(key)")
        }
        try await s3FileTransfer.copy(from: file, to: path)
        logger.info("✅ Completed copying \(key) to \(path)")
    }
}


extension S3File {
    init?(key: S3StoreKey) {
        self.init(url: key.url)
    }
}
