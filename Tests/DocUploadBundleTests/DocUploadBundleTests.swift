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
                           mbSize: 456,
                           sourcePath: "branch",
                           targetFolder: bundle.s3Folder)
                       )
        XCTAssertEqual(bundle.s3Folder,
                       .init(bucket: "spi-prod-docs", path: "owner/name/branch"))
    }

}
