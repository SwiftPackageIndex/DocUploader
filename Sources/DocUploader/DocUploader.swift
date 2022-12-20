import Foundation

import AWSLambdaEvents
import AWSLambdaRuntime
import Zip


public struct DocUploader: SimpleLambdaHandler {
    public func handle(_ event: S3Event, context: LambdaContext) async throws {
        guard let record = event.records.first else {
            throw Error(message: "no records")
        }

        // FIXME: handle multiple zips
        // FIXME: add a report back stage

        let bucketName = record.s3.bucket.name
        let objectKey = record.s3.object.key
        context.logger.log(level: .info, "file: \(bucketName)/\(objectKey)")

        let outputPath = "/tmp"
        try await Current.s3Client.loadFile(from: S3Key(bucketName: bucketName,
                                                        objectKey: objectKey),
                                            to: outputPath)
    }

    public init() { }
}
