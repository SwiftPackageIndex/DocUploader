// swift-tools-version: 5.7

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

import PackageDescription

let package = Package(
    name: "DocUploader",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "doc-uploader", targets: ["Executable"]),
        .library(name: "DocUploadBundle", targets: ["DocUploadBundle"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", branch: "main"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main"),
        .package(url: "https://github.com/soto-project/soto-s3-file-transfer.git", from: "1.2.0"),
        .package(url: "https://github.com/marmelroy/Zip.git", from: "2.1.2"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "0.1.4")
    ],
    targets: [
        .executableTarget(name: "Executable", dependencies: ["DocUploader"]),
        .target(name: "DocUploader", dependencies: [
            "DocUploadBundle",
            .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
            .product(name: "SotoS3FileTransfer", package: "soto-s3-file-transfer"),
        ]),
        .target(name: "DocUploadBundle", dependencies: [
            .product(name: "Zip", package: "Zip"),
            .product(name: "Dependencies", package: "swift-dependencies")
        ]),
        .testTarget(name: "DocUploaderTests", dependencies: ["DocUploader", "DocUploadBundle"]),
    ]
)
