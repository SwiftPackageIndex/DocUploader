import SotoS3
import SotoS3FileTransfer


struct LiveS3Client: S3Client {
    func deleteFile(client: AWSClient, logger: Logger, key: S3StoreKey) async throws {
        let s3 = S3(client: client, region: .useast2)
        let s3FileTransfer = S3FileTransferManager(s3: s3, threadPoolProvider: .createNew)

        guard let file = S3File(key: key) else {
            throw Error(message: "Invalid key: \(key)")
        }
        try await s3FileTransfer.delete(file)
    }

    func loadFile(client: AWSClient, logger: Logger, from key: S3StoreKey, to path: String) async throws {
        logger.info("Copying \(key.url) to \(path) ...")

        let s3 = S3(client: client, region: .useast2)
        let s3FileTransfer = S3FileTransferManager(s3: s3, threadPoolProvider: .createNew)

        guard let file = S3File(key: key) else {
            throw Error(message: "Invalid key: \(key)")
        }
        try await s3FileTransfer.copy(from: file, to: path)
        logger.info("✅ Completed copying \(key.url) to \(path)")
    }

    func sync(client: AWSClient, logger: Logger, from folder: String, to key: S3StoreKey) async throws {
        logger.info("Syncing \(folder) to \(key) ...")

        let s3 = S3(client: client, region: .useast2)
        let s3FileTransfer = S3FileTransferManager(s3: s3, threadPoolProvider: .createNew)

        guard let s3Folder = S3Folder(url: key.url) else {
            throw Error(message: "Invalid key: \(key)")
        }

        var nextProgressTick = 0.1
        try await s3FileTransfer.sync(from: folder, to: s3Folder, delete: true) { progress in
            if progress >= nextProgressTick {
                logger.info("Syncing... [\(percent: progress)]")
                nextProgressTick += 0.1
            }
        }

        logger.info("✅ Completed syncing \(folder) to \(s3Folder)")
    }
}


extension S3File {
    init?(key: S3StoreKey) {
        self.init(url: key.url)
    }
}


private extension DefaultStringInterpolation {
    mutating func appendInterpolation(percent value: Double) {
        appendInterpolation(String(format: "%.0f%%", value * 100))
    }
}
