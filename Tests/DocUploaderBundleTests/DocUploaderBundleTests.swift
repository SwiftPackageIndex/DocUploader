import XCTest

@testable import DocUploaderBundle


final class DocUploaderBundleTests: XCTestCase {

    func test_init() throws {
        let bundle = DocUploadBundle(sourcePath: "/foo/bar/owner/name/develop",
                                     bucket: "some-bucket",
                                     repository: .init(owner: "Owner", name: "Name"),
                                     reference: "Develop")
        XCTAssertEqual(bundle.archiveName, "owner-name-develop.zip")
        XCTAssertEqual(bundle.metadata,
                       .init(sourcePath: "develop", targetFolder: bundle.s3Folder))
        XCTAssertEqual(bundle.s3Folder,
                       .init(bucket: "some-bucket", path: "owner/name/develop"))
    }

}
