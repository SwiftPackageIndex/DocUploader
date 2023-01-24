// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

import AsyncHTTPClient
import AWSLambdaEvents
import AWSLambdaRuntime
import DocUploadBundle
import SotoS3


public struct DocUploader: LambdaHandler {
    let httpClient: HTTPClient
    let awsClient: AWSClient

    public init(context: LambdaInitializationContext) async throws {
        let httpClient = HTTPClient(
            eventLoopGroupProvider: .shared(context.eventLoop),
            configuration: .init(connectionPool: .init(
                idleTimeout: .seconds(60),
                concurrentHTTP1ConnectionsPerHostSoftLimit: 32)
            )
        )
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
                    do {
                        logger.info("Copying \(s3Key.url) to \(outputPath)...")
                        try await Current.s3Client.loadFile(client: awsClient,
                                                            logger: logger,
                                                            from: s3Key,
                                                            to: outputPath)
                        logger.info("✅ Completed copying \(s3Key.url)")
                    }

                    let metadata: DocUploadBundle.Metadata
                    do {
                        let zipFileName = "\(outputPath)/\(objectKey)"
                        logger.info("Unzipping \(zipFileName)")
                        var fileIndex = 0
                        metadata = try DocUploadBundle.unzip(bundle: zipFileName,
                                                             outputPath: outputPath) { path in
                            defer { fileIndex += 1 }
                            if fileIndex % 5000 == 0 {
                                logger.info("... [\(fileIndex)] - \(path.lastPathComponent)")
                            }
                        }
                        logger.info("✅ Completed unzipping \(zipFileName)")
                    }

                    do {
                        let syncPath = "\(outputPath)/\(metadata.sourcePath)"
                        logger.info("Syncing \(syncPath) to \(metadata.targetFolder.s3Key)...")
                        try await Current.s3Client.sync(client: awsClient,
                                                        logger: logger,
                                                        from: syncPath,
                                                        to: metadata.targetFolder.s3Key)
                        logger.info("✅ Completed syncing \(syncPath)")
                    }
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


private extension DocUploadBundle.S3Folder {
    var s3Key: S3Key { .init(bucketName: bucket, objectKey: path) }
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
