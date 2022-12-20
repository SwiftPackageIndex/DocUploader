import AWSLambdaEvents
import AWSLambdaRuntime
import Zip


struct Error: Swift.Error {
    var message: String
}


public enum DocUploader {
    public static func run() {
        Lambda.run { (context, event: S3.Event, callback) in
            guard let record = event.records.first else {
                callback(.failure(Error(message: "no records")))
                return
            }

            // FIXME: handle multiple zips
            // FIXME: add a report back stage

            let object = record.s3.object
            context.logger.log(level: .info, "file: \(record.s3.bucket.name)/\(object.key)")

            callback(.success(Void()))
        }
    }
}
