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


final class ZipTests: XCTestCase {

    func test_zip() async throws {
        // Test basic zip behaviour we expect from the library we use
        try await withTempDir { tempDir in
            let tempURL = URL(filePath: tempDir)
            let fileA = tempURL.appending(path: "a.txt")
            let fileB = tempURL.appending(path: "b.txt")
            try "a".write(to: fileA, atomically: true, encoding: .utf8)
            try "b".write(to: fileB, atomically: true, encoding: .utf8)
            let zipFile = tempURL.appending(path: "out.zip")
            try Zipping.zip(paths: [fileA, fileB], to: zipFile)
            XCTAssert(FileManager.default.fileExists(atPath: zipFile.path()))
        }
    }

    func test_unzip() async throws {
        // Test basic unzip behaviour we expect from the library we use
        try await withTempDir { tempDir in
            let tempURL = URL(filePath: tempDir)
            let zipFile = fixtureUrl(for: "out.zip")
            let outDir = tempURL.appending(path: "out")
            try Zipping.unzip(from: zipFile, to: outDir)
            XCTAssert(FileManager.default.fileExists(atPath: outDir.path()))
            let fileA = outDir.appending(path: "a.txt")
            let fileB = outDir.appending(path: "b.txt")
            XCTAssert(FileManager.default.fileExists(atPath: fileA.path()))
            XCTAssert(FileManager.default.fileExists(atPath: fileB.path()))
            XCTAssertEqual(try String(contentsOf: fileA), "a")
            XCTAssertEqual(try String(contentsOf: fileB), "b")
        }
    }

}
