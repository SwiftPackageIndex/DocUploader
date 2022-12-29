import Foundation

import AsyncHTTPClient
import AWSLambdaEvents
import AWSLambdaRuntime
import SotoS3
import Zip


public struct DocUploader: LambdaHandler {
    let httpClient: HTTPClient
    let awsClient: AWSClient

    public init(context: LambdaInitializationContext) async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .shared(context.eventLoop))
        context.terminator.register(name: "awsclient") { eventLoop in
            let promise = eventLoop.makePromise(of: Void.self)
            httpClient.shutdown() { error in
                switch error {
                case .none:
                    promise.succeed(())
                case .some(let error):
                    promise.fail(error)
                }
            }
            return promise.futureResult
        }
        self.httpClient = httpClient

        let awsClient = AWSClient(httpClientProvider: .shared(httpClient))
        context.terminator.register(name: "awsclient") { eventLoop in
            let promise = eventLoop.makePromise(of: Void.self)
            awsClient.shutdown() { error in
                switch error {
                case .none:
                    promise.succeed(())
                case .some(let error):
                    promise.fail(error)
                }
            }
            return promise.futureResult
        }
        self.awsClient = awsClient
    }

    public func handle(_ event: S3Event, context: LambdaContext) async throws {
        let logger = context.logger
        logger.info("Lambda version: \(LambdaVersion)")

        guard !event.records.isEmpty else {
            throw Error(message: "no records")
        }

        if event.records.count > 1 {
            logger.warning("Number of records: \(event.records)")
        } else {
            logger.info("Number of records: \(event.records)")
        }

        var errors = [Swift.Error]()

        for record in event.records {
            let bucketName = record.s3.bucket.name
            let objectKey = record.s3.object.key
            let s3Key = S3Key(bucketName: bucketName, objectKey: objectKey)
            logger.info("file: \(s3Key.url)")
            logger.info("record: \(record)")

            do {
                try await run {
                    // FIXME: add a report back stage

                    let outputPath = "/tmp"
                    try await Current.s3Client.loadFile(client: awsClient,
                                                        logger: logger,
                                                        from: s3Key,
                                                        to: outputPath)

                    let zipFileName = "\(outputPath)/\(objectKey)"
                    let syncPath = try Self.unzipFile(logger: logger,
                                                      filename: zipFileName,
                                                      outputPath: outputPath)

                    let basename = objectKey.droppingSuffix(".zip")
                    // FIXME: pass in actual bucket
                    let targetKey = S3Key(bucketName: "spi-scratch", objectKey: basename)
                    try await Current.s3Client.sync(client: awsClient,
                                                    logger: logger,
                                                    from: syncPath,
                                                    to: targetKey)
                } defer: {
                    // try? await Current.s3Client.deleteFile(client: awsClient, logger: logger, key: s3Key)
                }
            } catch {
                // Track any errors but continue on to attempt to process all events.
                logger.error("\(error)")
                errors.append(error)
            }
        }

        // Raise any errors we encountered.
        guard errors.isEmpty else {
            if errors.count == 1 {
                throw errors.first!
            } else {
                throw Error(message: "Encountered \(errors.count) errors (see logs for details)")
            }
        }
    }
}


extension DocUploader {
    static func unzipFile(logger: Logger, filename: String, outputPath: String) throws -> String {
        logger.info("Unzipping \(filename)")

        var fileCount = 0
        var topLevelDir = ""
        try Zip.unzipFile(URL(fileURLWithPath: filename),
                          destination: URL(fileURLWithPath: outputPath),
                          overwrite: true,
                          password: nil,
                          fileOutputHandler: { unzippedFile in
            defer { fileCount += 1 }
            if fileCount == 0 {
                topLevelDir = unzippedFile.absoluteString
            }
            if fileCount % 100 == 0 {
                logger.info("- \(unzippedFile)")
            }
        })

        logger.info("✅ Completed unzipping \(filename)")

        return topLevelDir
    }
}


private extension String {
    func droppingSuffix(_ suffix: String) -> String {
        if lowercased().hasSuffix(suffix.lowercased()) {
            return String(dropLast(suffix.count))
        } else {
            return self
        }
    }
}


func run(_ operation: () async throws -> Void,
         defer deferredOperation: () async -> Void) async throws {
    do {
        try await operation()
        await deferredOperation()
    } catch {
        await deferredOperation()
        throw error
    }
}
