import Foundation
import SotoS3
import SotoS3FileTransfer


struct LiveS3Client: S3Client {
    func deleteFile(client: AWSClient, logger: Logger, key: S3StoreKey) async throws {
        let s3 = S3(client: client, region: .useast2)
        let s3FileTransfer = S3FileTransferManager(s3: s3, threadPoolProvider: .createNew)

        // FIXME: drop SotoS3FileTransfer.
        guard let file = SotoS3FileTransfer.S3File(key: key) else {
            throw Error(message: "Invalid key: \(key)")
        }
        try await s3FileTransfer.delete(file)
    }

    func loadFile(client: AWSClient, logger: Logger, from key: S3StoreKey, to path: String) async throws {
        let s3 = S3(client: client, region: .useast2)
        let s3FileTransfer = S3FileTransferManager(s3: s3, threadPoolProvider: .createNew)

        // FIXME: drop SotoS3FileTransfer.
        guard let file = SotoS3FileTransfer.S3File(key: key) else {
            throw Error(message: "Invalid key: \(key)")
        }
        try await s3FileTransfer.copy(from: file, to: path)
    }

    func sync(client: AWSClient, logger: Logger, from folder: String, to key: S3StoreKey) async throws {
        guard let s3Folder = S3Folder(url: key.url) else {
            throw Error(message: "Invalid key: \(key)")
        }

        let s3 = S3(client: client,
                    region: .useast2,
                    timeout: .seconds(60),
                    options: .s3DisableChunkedUploads)

        try timed(logger, "listFiles (local)") {
            let localFiles = try Self.listFiles(in: folder)
            logger.info("local files: \(localFiles.count)")
        }

        try await timed(logger, "listFiles (remote)") {
            let s3Files = try await Self.listFiles(s3, logger: logger, in: s3Folder)
            logger.info("remote files: \(s3Files.count)")
        }

        let s3FileTransfer = S3FileTransferManager(s3: s3, threadPoolProvider: .createNew)
        defer { try? s3FileTransfer.syncShutdown() }

        var nextProgressTick = 0.1
        try await s3FileTransfer.sync(from: folder, to: s3Folder, delete: true) { progress in
            if progress >= nextProgressTick {
                logger.info("Syncing... [\(percent: progress)]")
                nextProgressTick += 0.1
            }
        }
    }

    func syncConcurrent(client: AWSClient, logger: Logger, from folder: String, to key: S3StoreKey) async throws {
        guard let s3Folder = S3Folder(url: key.url) else {
            throw Error(message: "Invalid key: \(key)")
        }

        let localFiles = try timed(logger, "listFiles (local)") {
            try Self.listFiles(in: folder)
        }
        logger.info("local files: \(localFiles.count)")

        let s3 = S3(client: client,
                    region: .useast2,
                    timeout: .seconds(60),
                    options: .s3DisableChunkedUploads)

        let s3Files = try await timed(logger, "listFiles (remote)") {
            try await Self.listFiles(s3, logger: logger, in: s3Folder)
        }
        logger.info("remote files: \(s3Files.count)")

        let folderResolved = URL(fileURLWithPath: folder).standardizedFileURL.resolvingSymlinksInPath()
        let targetFiles = Self.targetFiles(files: localFiles, from: folderResolved.path, to: s3Folder)
        let transfers = targetFiles.compactMap { transfer -> (from: FileDescriptor, to: S3File)? in
            // does file exist on S3
            guard let s3File = s3Files.first(where: { $0.file.key == transfer.to.key }) else { return transfer }
            // does file on S3 have a later date
            guard s3File.modificationDate > transfer.from.modificationDate else { return transfer }
            return nil
        }
        let deletions = s3Files.compactMap { s3File -> S3File? in
            if targetFiles.first(where: { $0.to.key == s3File.file.key }) == nil {
                return s3File.file
            } else {
                return nil
            }
        }

        logger.info("transfers: \(transfers.count)")
        logger.info("deletions: \(deletions.count)")

        let concurrency = 4
        guard let accessKeyId = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"],
              let secretAccessKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] else {
            throw Error(message: "no credentials")
        }
        let awsClients = (0..<concurrency).map { _ in
            AWSClient(
                credentialProvider: .static(accessKeyId: accessKeyId, secretAccessKey: secretAccessKey),
                httpClientProvider: .createNew
            )
        }
        defer { awsClients.forEach { try? $0.syncShutdown() } }
        let transferManagers = (0..<concurrency).map { index in
            let s3 = S3(client: awsClients[index],
                        region: .useast2,
                        timeout: .seconds(60),
                        options: .s3DisableChunkedUploads)
            return S3FileTransferManager(s3: s3, threadPoolProvider: .createNew)
        }
        defer { transferManagers.forEach { try? $0.syncShutdown() } }

        if !transfers.isEmpty {
            logger.info("Copying ...")
            try await withThrowingTaskGroup(of: Void.self) { group in
                for (index, transfer) in transfers.enumerated() {
                    let manager = transferManagers[index % concurrency]
                    let s3File = SotoS3FileTransfer.S3File(url: transfer.to.url)!
                    if index % 100 == 0 {
                        logger.info("... [\(index)]")
                    }
                    group.addTask {
                        try await manager.copy(from: transfer.from.name, to: s3File)
                    }
                }
                return try await group.waitForAll()
            }
        }

        if !deletions.isEmpty {
            logger.info("Deleting ...")
            try await withThrowingTaskGroup(of: Void.self) { group in
                for (index, deletion) in deletions.enumerated() {
                    let manager = transferManagers[index % concurrency]
                    let s3File = SotoS3FileTransfer.S3File(url: deletion.url)!
                    if index % 100 == 0 {
                        logger.info("... [\(index)]")
                    }
                    group.addTask {
                        try await manager.delete(s3File)
                    }
                }
                return try await group.waitForAll()
            }
        }

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


@discardableResult
func timed<T>(_ logger: Logger, _ label: String, block: () throws -> T) rethrows -> T {
    let start = Date()
    let result = try block()
    logger.info("\(label) elapsed: \(Date().timeIntervalSince(start))")
    return result
}

@discardableResult
func timed<T>(_ logger: Logger, _ label: String, block: () async throws -> T) async rethrows -> T {
    let start = Date()
    let result = try await block()
    logger.info("\(label) elapsed: \(Date().timeIntervalSince(start))")
    return result
}
