// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "spi-doc-uploader",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "doc-uploader", targets: ["Executable"]),
        .library(name: "DocUploaderBundle", targets: ["DocUploaderBundle"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", branch: "main"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main"),
        .package(url: "https://github.com/finestructure/soto-s3-file-transfer.git", revision: "690584351c0c1fd336c8208046f7445e0dd3e9de"),
        .package(url: "https://github.com/marmelroy/Zip.git", from: "2.1.2")
    ],
    targets: [
        .executableTarget(name: "Executable", dependencies: ["DocUploader"]),
        .target(name: "DocUploader", dependencies: [
            "DocUploaderBundle",
            .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
            .product(name: "SotoS3FileTransfer", package: "soto-s3-file-transfer"),
        ]),
        .target(name: "DocUploaderBundle", dependencies: [
            .product(name: "Zip", package: "Zip")
        ]),
        .testTarget(name: "DocUploaderBundleTests", dependencies: ["DocUploaderBundle"]),
    ]
)
