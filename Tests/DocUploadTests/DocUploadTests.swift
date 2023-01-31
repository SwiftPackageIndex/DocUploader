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
@testable import DocUploader

import Dependencies


final class DocUploadTests: XCTestCase {

    func test_init() throws {
        let bundle = withDependencies {
            $0.uuid = .constant(UUID(uuidString: "cafecafe-cafe-cafe-cafe-cafecafecafe")!)
        } operation: {
            DocUploadBundle(sourcePath: "/foo/bar/owner/name/branch",
                            bucket: "spi-prod-docs",
                            repository: .init(owner: "Owner", name: "Name"),
                            reference: "Branch")
        }
        XCTAssertEqual(bundle.archiveName, "prod-owner-name-branch-cafecafe.zip")
        XCTAssertEqual(bundle.metadata,
                       .init(sourcePath: "branch", targetFolder: bundle.s3Folder))
        XCTAssertEqual(bundle.s3Folder,
                       .init(bucket: "spi-prod-docs", path: "owner/name/branch"))
    }

    func test_logUrl() throws {
        let logURL = DocUploader
            .logURL(region: "us-east-2",
                    logGroup: "/aws/lambda/DocUploaderLambda-Test-UploadFunction-3D3w0QTh1l6H",
                    logStream: "2023/01/30/[$LATEST]3ecb4050574245699b3db785b07142f2")

        XCTAssertEqual(logURL,
                       "https://us-east-2.console.aws.amazon.com/cloudwatch/home?region=us-east-2#logsV2:log-groups/log-group/$252Faws$252Flambda$252FDocUploaderLambda-Test-UploadFunction-3D3w0QTh1l6H/log-events/2023$252F01$252F30$252F$255B$2524LATEST$255D3ecb4050574245699b3db785b07142f2")
    }

}
