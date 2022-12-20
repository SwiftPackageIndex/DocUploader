import AWSLambdaEvents
import AWSLambdaRuntime


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
            let object = record.s3.object
            context.logger.log(level: .info, "bucket: \(record.s3.bucket.name)")
            context.logger.log(level: .info, "file: \(object.key)")
            callback(.success(Void()))
        }
    }
}
