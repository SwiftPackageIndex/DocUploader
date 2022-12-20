import Foundation


struct Environment {
    var environment: (String) -> String?
    var fileManager: FileManager
    var s3Client: S3Client
}


extension Environment {
    static let live: Self = .init(
        environment: environment(variable:),
        fileManager: LiveFileManager(),
        s3Client: LiveS3Client()
    )

    static func environment(variable: String) -> String? {
        guard let value = ProcessInfo.processInfo.environment[variable] else {
//            Logger.log("WARNING: environment variable \(variable) is not set")
            return nil
        }
        return value
    }
}


// MARK: - FileManager

protocol FileManager {

}

struct LiveFileManager: FileManager {

}


// MARK: - S3 types

protocol S3StoreKey {
    var filename: String { get }
    var url: String { get }
}


// MARK: - S3 Client

protocol S3Client {
    func loadFile(from key: S3StoreKey, to path: String) async throws
}


struct S3Key: S3StoreKey {
    let bucketName: String
    let objectKey: String

    var filename: String { objectKey }
    var url: String { "s3://\(bucketName)/\(objectKey)" }
}


// MARK: - Current

#if DEBUG
var Current: Environment = .live
#else
let Current: Environment = .live
#endif
