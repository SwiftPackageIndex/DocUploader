// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "spi-doc-uploader",
    products: [
        .executable(name: "doc-uploader", targets: ["Executable"])
    ],
    dependencies: [
    ],
    targets: [
        .executableTarget(name: "Executable", dependencies: ["DocUploader"]),
        .target(name: "DocUploader", dependencies: []),
        .testTarget(name: "DocUploaderTests", dependencies: ["DocUploader"]),
    ]
)
