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

import XCTest

@testable import DocUploadBundle

import Dependencies


final class DocUploadBundleTests: XCTestCase {

    func test_init() throws {
        let cafe = UUID(uuidString: "cafecafe-cafe-cafe-cafe-cafecafecafe")!
        let bundle = withDependencies {
            $0.uuid = .constant(cafe)
        } operation: {
            DocUploadBundle(sourcePath: "/foo/bar/owner/name/branch",
                            bucket: "spi-prod-docs",
                            repository: .init(owner: "Owner", name: "Name"),
                            reference: "Branch",
                            apiBaseURL: "baseURL",
                            apiToken: "token",
                            buildId: cafe,
                            docArchives: [.init(name: "foo", title: "Foo")],
                            fileCount: 123,
                            linkablePathsCount: 234,
                            mbSize: 456)
        }
        XCTAssertEqual(bundle.archiveName, "prod-owner-name-branch-cafecafe.zip")
        XCTAssertEqual(bundle.metadata,
                       .init(
                           apiBaseURL: "baseURL",
                           apiToken: "token",
                           buildId: cafe,
                           docArchives: [.init(name: "foo", title: "Foo")],
                           fileCount: 123,
                           linkablePathsCount: 234,
                           mbSize: 456,
                           sourcePath: "branch",
                           targetFolder: bundle.s3Folder)
                       )
        XCTAssertEqual(bundle.s3Folder,
                       .init(bucket: "spi-prod-docs", path: "owner/name/branch"))
    }

    func test_String_pathEncoded() throws {
        XCTAssertEqual("main".pathEncoded, "main")
        XCTAssertEqual("1.2.3".pathEncoded, "1.2.3")
        XCTAssertEqual("0.50900.0-swift-DEVELOPMENT-SNAPSHOT-2023-02-27-a".pathEncoded,
                       "0.50900.0-swift-DEVELOPMENT-SNAPSHOT-2023-02-27-a")
        XCTAssertEqual("foo/bar".pathEncoded, "foo-bar")
        XCTAssertEqual("v1.2.3-beta1+build5".pathEncoded, "v1.2.3-beta1+build5")
    }

    func test_issue_10() throws {
        // https://github.com/SwiftPackageIndex/DocUploader/issues/10
        // Reference with / produces bad archive name
        let cafe = UUID(uuidString: "cafecafe-cafe-cafe-cafe-cafecafecafe")!
        let bundle = withDependencies {
            $0.uuid = .constant(cafe)
        } operation: {
            DocUploadBundle(sourcePath: "/owner/name/feature-2.0.0",
                            bucket: "spi-prod-docs",
                            repository: .init(owner: "Owner", name: "Name"),
                            reference: "feature/2.0.0",
                            apiBaseURL: "baseURL",
                            apiToken: "token",
                            buildId: cafe,
                            docArchives: [.init(name: "foo", title: "Foo")],
                            fileCount: 123,
                            linkablePathsCount: 234,
                            mbSize: 456)
        }
        XCTAssertEqual(bundle.archiveName, "prod-owner-name-feature-2.0.0-cafecafe.zip")
        XCTAssertEqual(bundle.metadata,
                       .init(
                           apiBaseURL: "baseURL",
                           apiToken: "token",
                           buildId: cafe,
                           docArchives: [.init(name: "foo", title: "Foo")],
                           fileCount: 123,
                           linkablePathsCount: 234,
                           mbSize: 456,
                           sourcePath: "feature-2.0.0",
                           targetFolder: bundle.s3Folder)
                       )
        XCTAssertEqual(bundle.s3Folder,
                       .init(bucket: "spi-prod-docs", path: "owner/name/feature-2.0.0"))
    }

    func test_issue_3069() async throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/3069
        // This test fails but there is a chance that the problematic zip file would not be produced anymore with recent versions. Therefore we skip this test for now.
        // See https://github.com/vapor-community/Zip/issues/4#issuecomment-2308356328 for more details.
        try XCTSkipIf(true)
        try await withTempDir { tempDir in
            let url = fixtureUrl(for: "prod-apple-swift-metrics-main-e6a00d36.zip")
            XCTAssertNoThrow(
                try DocUploadBundle.unzip(bundle: url.path, outputPath: tempDir)
            )
            for pathComponent in ["metadata.json",
                                  "main/index.html",
                                  "main/index/index.json"] {
                let path = tempDir + "/" + pathComponent
                XCTAssertTrue(FileManager.default.fileExists(atPath: path), "does not exist: \(path)")
            }
            // test roundtrip, to ensure the zip library can zip/unzip its own product
            // zip
            let urls = [tempDir + "/metadata.json",
                        tempDir + "/main"].map(URL.init(fileURLWithPath:))
            let zipped = URL(fileURLWithPath: tempDir + "/out.zip")
            try Zipper.zip(paths: urls, to: zipped)
            XCTAssertTrue(FileManager.default.fileExists(atPath: zipped.path))
            // unzip
            let out = URL(fileURLWithPath: tempDir + "/out")
            try Zipper.unzip(from: zipped, to: out)
            XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: out.appendingPathComponent("metadata.json").path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: out.appendingPathComponent("main/index.html").path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: out.appendingPathComponent("main/index/index.json").path))
        }
    }

}
