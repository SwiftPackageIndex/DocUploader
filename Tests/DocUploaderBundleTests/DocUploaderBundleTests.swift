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

@testable import DocUploaderBundle

import Dependencies


final class DocUploaderBundleTests: XCTestCase {

    func test_init() throws {
        let bundle = withDependencies {
            $0.uuid = .constant(UUID(uuidString: "cafecafe-cafe-cafe-cafe-cafecafecafe")!)
        } operation: {
            DocUploadBundle(sourcePath: "/foo/bar/owner/name/develop",
                            bucket: "some-bucket",
                            repository: .init(owner: "Owner", name: "Name"),
                            reference: "Develop")
        }
        XCTAssertEqual(bundle.archiveName, "owner-name-develop-cafecafe.zip")
        XCTAssertEqual(bundle.metadata,
                       .init(sourcePath: "develop", targetFolder: bundle.s3Folder))
        XCTAssertEqual(bundle.s3Folder,
                       .init(bucket: "some-bucket", path: "owner/name/develop"))
    }

}
