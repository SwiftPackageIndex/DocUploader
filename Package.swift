// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "spi-doc-uploader",
    products: [
        .executable(name: "doc-uploader", targets: ["Executable"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", .upToNextMajor(from: "0.5.0")),
    ],
    targets: [
        .executableTarget(name: "Executable", dependencies: ["DocUploader"]),
        .target(name: "DocUploader", dependencies: [
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime")
        ]),
        .testTarget(name: "DocUploaderTests", dependencies: ["DocUploader"]),
    ]
)
