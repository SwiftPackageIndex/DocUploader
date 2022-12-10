import AWSLambdaRuntime

public enum DocUploader {
    public static func run() {
        Lambda.run { (context, name: String, callback: @escaping (Result<String, Error>) -> Void) in
            callback(.success("Hello \(name)"))
        }
    }
}
