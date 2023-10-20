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


var linkerSettings: [LinkerSetting]? = nil
#if os(macOS)
// Fixes ld: warning: ignoring duplicate libraries: '-lz'
linkerSettings = [.unsafeFlags(["-Xlinker", "-no_warn_duplicate_libraries"])]
// Linux build fails with
// /usr/bin/ld.gold: fatal error: -pie and -static are incompatible
// if we include this settings
#endif

let package = Package(
    name: "DocUploader",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "doc-uploader", targets: ["Executable"]),
        .library(name: "DocUploadBundle", targets: ["DocUploadBundle"])
    ],
    dependencies: [
        // NB: We include swift-crypto even though it's not a direct dependency to ensure we can build with
        // --disable-automatic-resolution on all platforms.
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", from: "0.1.0"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "1.0.0-alpha.1"),
        .package(url: "https://github.com/soto-project/soto-s3-file-transfer.git", from: "1.2.0"),
        .package(url: "https://github.com/marmelroy/Zip.git", from: "2.1.2"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(name: "Executable", dependencies: ["DocUploader"]),
        .target(
            name: "DocUploader",
            dependencies: [
                "DocUploadBundle",
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "SotoS3FileTransfer", package: "soto-s3-file-transfer"),
            ],
            linkerSettings: linkerSettings
        ),
        .target(name: "DocUploadBundle", dependencies: [
            .product(name: "Zip", package: "Zip"),
            .product(name: "Dependencies", package: "swift-dependencies")
        ]),
        .testTarget(name: "DocUploadBundleTests", dependencies: ["DocUploadBundle"]),
        .testTarget(name: "DocUploaderTests", dependencies: ["DocUploader"]),
    ]
)
