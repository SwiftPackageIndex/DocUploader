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
        context.logger.info("Lambda version: \(LambdaVersion)")

        guard let record = event.records.first else {
            throw Error(message: "no records")
        }

        // FIXME: handle multiple zips
        // FIXME: add a report back stage

        let bucketName = record.s3.bucket.name
        let objectKey = record.s3.object.key
        let s3Key = S3Key(bucketName: bucketName, objectKey: objectKey)
        context.logger.info("file: \(s3Key.url)")

        let outputPath = "/tmp"
        try await Current.s3Client.loadFile(client: awsClient,
                                            logger: context.logger,
                                            from: s3Key,
                                            to: outputPath)

        let zipFileName = "\(outputPath)/\(objectKey)"
        try Self.unzipFile(logger: context.logger, filename: zipFileName, outputPath: outputPath)

        // TODO: sync data to S3

        try await Current.s3Client.deleteFile(client: awsClient, logger: context.logger, key: s3Key)
    }
}


extension DocUploader {
    static func unzipFile(logger: Logger, filename: String, outputPath: String) throws {
        logger.info("Unzipping \(filename)")
        var fileCount = 0
        try Zip.unzipFile(URL(fileURLWithPath: filename),
                          destination: URL(fileURLWithPath: outputPath),
                          overwrite: true,
                          password: nil,
                          fileOutputHandler: { unzippedFile in
            defer { fileCount += 1 }
            if fileCount % 100 == 0 {
                logger.info("- \(unzippedFile)")
            }
        })
        logger.info("✅ Completed unzipping \(filename)")
    }
}
