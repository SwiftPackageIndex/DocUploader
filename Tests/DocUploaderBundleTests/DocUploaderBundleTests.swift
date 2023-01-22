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
