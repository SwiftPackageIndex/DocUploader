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

import AWSLambdaEvents
import AWSLambdaRuntime
import AsyncHTTPClient
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
                concurrentHTTP1ConnectionsPerHostSoftLimit: 64)
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

        if event.records.count > 1 {
            logger.warning("Number of records: \(event.records)")
        } else {
            logger.info("Number of records: \(event.records)")
        }

        guard let record = event.records.first else {
            throw Error(message: "no records")
        }

        let s3Key = S3Key(bucketName: record.s3.bucket.name, objectKey: record.s3.object.key)
        logger.info("file: \(s3Key.url)")
        logger.info("record: \(record)")

        try await run {
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
                let zipFileName = "\(outputPath)/\(s3Key.objectKey)"
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

            try await Retry.repeatedly("Syncing ...", logger: logger) {
                do {
                    let syncPath = "\(outputPath)/\(metadata.sourcePath)"
                    logger.info("Syncing \(syncPath) to \(metadata.targetFolder.s3Key)...")
                    try await Current.s3Client.sync(client: awsClient,
                                                    logger: logger,
                                                    from: syncPath,
                                                    to: metadata.targetFolder.s3Key)
                    logger.info("✅ Completed syncing \(syncPath)")
                    return .success
                } catch {
                    logger.error("\(error)")
                    return .failure
                }
            }

            try await Retry.repeatedly("Sending doc result ...", logger: logger) {
                do {
                    let status = try await DocReport.reportResult(
                        client: httpClient,
                        apiBaseURL: metadata.apiBaseURL,
                        apiToken: metadata.apiToken,
                        buildId: metadata.buildId,
                        // FIXME: fill in values
                        dto: .init(error: nil,
                                   fileCount: metadata.fileCount,
                                   logUrl: nil,
                                   mbSize: metadata.mbSize,
                                   status: .ok)
                    )
                    switch status.code {
                        case 200..<299:
                            return .success
                        default:
                            return .failure
                    }
                } catch {
                    logger.error("\(error)")
                    return .failure
                }
            }
        } defer: {
            // try? await Current.s3Client.deleteFile(client: awsClient, logger: logger, key: s3Key)
        }
    }

    public static func logURL(region: String?, logGroup: String?, logStream: String?) -> String? {
        guard let region = region,
              let group = logGroup,
              let stream = logStream else { return nil }
        return "https://\(region).console.aws.amazon.com/cloudwatch/home?" +
        "region=\(region)" +
        "#logsV2:log-groups/log-group/" +
        group.awsEncoded +
        "/log-events/" +
        stream.awsEncoded
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

private extension String {
    static let replacements = [
        // keep "$" first, so it doesn't replace the "$" in the following substitutions
        ("$", "$2524"),
        ("/", "$252F"),
        ("[", "$255B"),
        ("]", "$255D")
    ]

    var awsEncoded: String {
        var result = self
        for (key, value) in Self.replacements {
            result = result.replacingOccurrences(of: key, with: value)
        }
        return result
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
