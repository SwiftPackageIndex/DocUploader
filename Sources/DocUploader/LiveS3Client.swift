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
        logger.info("targetFiles: \(targetFiles.count)")

        let s3KeyMap = Dictionary(uniqueKeysWithValues: s3Files.map { ($0.file.key, $0) })
        let targetKeyMap = Dictionary(uniqueKeysWithValues: targetFiles.map { ($0.to.key, $0) })

        let transfers = timed(logger, "transfers compactMap") {
            targetFiles.compactMap { transfer -> (from: FileDescriptor, to: S3File)? in
                // does file exist on S3
                guard let s3File = s3KeyMap[transfer.to.key] else { return transfer }
                // does file on S3 have a later date
                guard s3File.modificationDate > transfer.from.modificationDate else { return transfer }
                return nil
            }
        }
        logger.info("transfers: \(transfers.count)")

        let deletions = timed(logger, "deletions compactMap") {
            s3Files.compactMap { s3File -> S3File? in
                if targetKeyMap[s3File.file.key] == nil {
                    return s3File.file
                } else {
                    return nil
                }
            }
        }
        logger.info("deletions: \(deletions.count)")

        let clientConcurrency = 4
        let taskConcurrency = Concurrency(maximum: 8)

        guard let accessKeyId = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"],
              let secretAccessKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] else {
            throw Error(message: "no credentials")
        }
        let awsClients = (0..<clientConcurrency).map { _ in
            AWSClient(
                credentialProvider: .static(accessKeyId: accessKeyId, secretAccessKey: secretAccessKey),
                httpClientProvider: .createNew
            )
        }
        defer { awsClients.forEach { try? $0.syncShutdown() } }
        let transferManagers = (0..<clientConcurrency).map { index in
            let s3 = S3(client: awsClients[index],
                        region: .useast2,
                        timeout: .seconds(60),
                        options: .s3DisableChunkedUploads)
            return S3FileTransferManager(s3: s3, threadPoolProvider: .createNew)
        }
        defer { transferManagers.forEach { try? $0.syncShutdown() } }


        if !transfers.isEmpty {
            await timed(logger, "copying (concurrency client/task: \(clientConcurrency)/\(taskConcurrency.maximum)") {
                logger.info("Copying ...")
                let done = await withTaskGroup(of: LiveS3Client.FileDescriptor?.self) { group in
                    for (index, transfer) in transfers.enumerated() {
                        try? await taskConcurrency.waitForAvailability()
                        let manager = transferManagers[index % clientConcurrency]
                        let s3File = SotoS3FileTransfer.S3File(url: transfer.to.url)!
                        group.addTask {
                            do {
                                await taskConcurrency.increment()
                                try await manager.copy(from: transfer.from.name, to: s3File)
                                if index % 500 == 0 {
                                    logger.info("... [\(index)] copied")
                                }
                                await taskConcurrency.decrement()
                                return transfer.from
                            } catch {
                                logger.error("addTask handler: \(error)")
                                await taskConcurrency.decrement()
                                return nil
                            }
                        }
                    }

                    let done = await group
                        .compactMap { $0 }
                        .reduce(into: [], { result, next in result.append(next) })
                    return done
                }
                logger.info("Copied: \(done.count)")
            }
        }

        if !deletions.isEmpty {
            try await timed(logger, "deleting") {
                logger.info("Deleting ...")
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for (index, deletion) in deletions.enumerated() {
                        let manager = transferManagers[index % clientConcurrency]
                        let s3File = SotoS3FileTransfer.S3File(url: deletion.url)!
                        group.addTask {
                            try await manager.delete(s3File)
                            if index % 500 == 0 {
                                logger.info("... [\(index)] deleted")
                            }
                        }
                    }
                    return try await group.waitForAll()
                }
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
    logger.info("\(label) elapsed: \(Date().timeIntervalSince(start))s (\(Date().timeIntervalSince(start)/60)m)")
    return result
}

actor Concurrency {
    var current = 0
    var maximum: Int
    var granularity: Double

    init(maximum: Int, granularity: Double = 0.1) {
        self.maximum = maximum
        self.granularity = granularity
    }

    var unavailable: Bool { current > maximum }

    func increment() { current += 1 }
    func decrement() { current -= 1 }

    func waitForAvailability() async throws {
        while unavailable { try await Task.sleep(seconds: granularity) }
    }
}


extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000.0))
    }
}
