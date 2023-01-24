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

import SotoS3


struct Environment {
    var fileManager: FileManager
    var s3Client: S3Client
}


extension Environment {
    static let live: Self = .init(
        fileManager: LiveFileManager(),
        s3Client: LiveS3Client()
    )
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
    func deleteFile(client: AWSClient, logger: Logger, key: S3StoreKey) async throws
    func loadFile(client: AWSClient, logger: Logger, from key: S3StoreKey, to path: String) async throws
    func sync(client: AWSClient, logger: Logger, from folder: String, to key: S3StoreKey) async throws
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
