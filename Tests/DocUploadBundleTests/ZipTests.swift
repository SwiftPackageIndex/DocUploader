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
    
    func test_unzip() async throws {
        // Test basic unzip behaviour we expect from the library we use
        try await withTempDir { tempDir in
            let tempURL = URL(fileURLWithPath: tempDir)
            let zipFile = fixtureUrl(for: "out.zip")
            let outDir = tempURL.appendingPathComponent("out")
            try Zipper.unzip(from: zipFile, to: outDir)
            XCTAssert(FileManager.default.fileExists(atPath: outDir.path))

            // out/a.txt
            // out/subdir/b.txt
            let fileA = outDir.appendingPathComponent("a.txt")
            let fileB = outDir.appendingPathComponent("subdir").appendingPathComponent("b.txt")
            XCTAssert(FileManager.default.fileExists(atPath: fileA.path))
            XCTAssert(FileManager.default.fileExists(atPath: fileB.path))
            XCTAssertEqual(try String(contentsOf: fileA), "a")
            XCTAssertEqual(try String(contentsOf: fileB), "b")
        }
    }

    func test_zip_roundtrip() async throws {
        // Test basic zip roundtrip
        try await withTempDir { tempDir in
            //  temp
            let tempURL = URL(fileURLWithPath: tempDir)

            // temp/a.txt
            let fileA = tempURL.appendingPathComponent("a.txt")
            try "a".write(to: fileA, atomically: true, encoding: .utf8)

            // temp/subdir/
            let subdir = tempURL.appendingPathComponent("subdir")
            try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: false)

            // temp/subdir/b.txt
            let fileB = subdir.appendingPathComponent("b.txt")
            try "b".write(to: fileB, atomically: true, encoding: .utf8)

            let zipFile = tempURL.appendingPathComponent("out.zip")
            try Zipper.zip(paths: [fileA, subdir], to: zipFile)
            XCTAssert(FileManager.default.fileExists(atPath: zipFile.path))

            do { // unzip what we zipped and check results
                let roundtrip = tempURL.appendingPathComponent("roundtrip")
                try Zipper.unzip(from: zipFile, to: roundtrip)
                XCTAssert(FileManager.default.fileExists(atPath: roundtrip.path))
                // roundtrip/a.txt
                // roundtrip/subdir/b.txt
                let fileA = roundtrip.appendingPathComponent("a.txt")
                let fileB = roundtrip.appendingPathComponent("subdir").appendingPathComponent("b.txt")
                XCTAssert(FileManager.default.fileExists(atPath: fileA.path))
                XCTAssert(FileManager.default.fileExists(atPath: fileB.path))
                XCTAssertEqual(try String(contentsOf: fileA), "a")
                XCTAssertEqual(try String(contentsOf: fileB), "b")
            }
        }
    }

}
