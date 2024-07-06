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
        try withTempDir { tempDir in
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
        try withTempDir { tempDir in
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

            // temp/subdir/subsubdir
            let subsubdir = subdir.appendingPathComponent("subsubdir")
            try FileManager.default.createDirectory(at: subsubdir, withIntermediateDirectories: false)

            // temp/subdir/subdir/c.txt
            let fileC = subsubdir.appendingPathComponent("c.txt")
            try "c".write(to: fileC, atomically: true, encoding: .utf8)

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
                let fileC = roundtrip.appendingPathComponent("subdir").appendingPathComponent("subsubdir").appendingPathComponent("c.txt")
                XCTAssert(FileManager.default.fileExists(atPath: fileA.path))
                XCTAssert(FileManager.default.fileExists(atPath: fileB.path))
                XCTAssert(FileManager.default.fileExists(atPath: fileC.path))
                XCTAssertEqual(try String(contentsOf: fileA), "a")
                XCTAssertEqual(try String(contentsOf: fileB), "b")
                XCTAssertEqual(try String(contentsOf: fileC), "c")
            }
        }
    }

    func test_zip_roundtrip_shellTool() async throws {
        try XCTSkipIf(!FileManager.default.fileExists(atPath: Zipper.zip.path))
        
        // Test basic zip roundtrip with the shellTool method
        try withTempDir { tempDir in
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

            // temp/subdir/subsubdir
            let subsubdir = subdir.appendingPathComponent("subsubdir")
            try FileManager.default.createDirectory(at: subsubdir, withIntermediateDirectories: false)

            // temp/subdir/subdir/c.txt
            let fileC = subsubdir.appendingPathComponent("c.txt")
            try "c".write(to: fileC, atomically: true, encoding: .utf8)

            let zipFile = tempURL.appendingPathComponent("out.zip")
            try Zipper.zip(paths: [fileA, subdir], to: zipFile, method: .zipTool)
            XCTAssert(FileManager.default.fileExists(atPath: zipFile.path))

            do { // unzip what we zipped and check results
                let roundtrip = tempURL.appendingPathComponent("roundtrip")
                try Zipper.unzip(from: zipFile, to: roundtrip)
                XCTAssert(FileManager.default.fileExists(atPath: roundtrip.path))
                // roundtrip/a.txt
                // roundtrip/subdir/b.txt
                let fileA = roundtrip.appendingPathComponent("a.txt")
                let fileB = roundtrip.appendingPathComponent("subdir").appendingPathComponent("b.txt")
                let fileC = roundtrip.appendingPathComponent("subdir").appendingPathComponent("subsubdir").appendingPathComponent("c.txt")
                XCTAssert(FileManager.default.fileExists(atPath: fileA.path))
                XCTAssert(FileManager.default.fileExists(atPath: fileB.path))
                XCTAssert(FileManager.default.fileExists(atPath: fileC.path))
                XCTAssertEqual(try String(contentsOf: fileA), "a")
                XCTAssertEqual(try String(contentsOf: fileB), "b")
                XCTAssertEqual(try String(contentsOf: fileC), "c")
            }
        }
    }

    func test_zip_roundtrip_shellTool_relative_paths() async throws {
        try XCTSkipIf(!FileManager.default.fileExists(atPath: Zipper.zip.path))

        // Test basic zip roundtrip with the shellTool method and relative paths
        try withTempDir { tempDir in
            // DocBundle components
            // metadataURL: tempDir/metadata.json
            // sourceURL:   tempDir/.docs/owner/repo/ref
            // should be zipped as
            //   - metadata.json
            //   - ref
            // at the top level as relative paths.
            let tempURL = URL(fileURLWithPath: tempDir)
            let metadataURL = tempURL.appendingPathComponent("metadata.json")
            try "metadata".write(to: metadataURL, atomically: true, encoding: .utf8)
            let sourceURL = tempURL.appendingPathComponent("docs/owner/repo/ref")
            try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
            let indexHTML = sourceURL.appendingPathComponent("index.html")
            try "index".write(to: indexHTML, atomically: true, encoding: .utf8)

            // MUT
            let zipFile = tempURL.appendingPathComponent("out.zip")
            try Zipper.zip(paths: [metadataURL, sourceURL], to: zipFile, method: .zipTool)

            do {  // validate
                let unzipDir = tempURL.appendingPathComponent("unzip")
                try Zipper.unzip(from: zipFile, to: unzipDir)
                let metadataURL = unzipDir.appendingPathComponent("metadata.json")
                let indexHTML = unzipDir.appendingPathComponent("ref/index.html")
                XCTAssert(FileManager.default.fileExists(atPath: metadataURL.path))
                XCTAssert(FileManager.default.fileExists(atPath: indexHTML.path))
                XCTAssertEqual(try String(contentsOf: metadataURL), "metadata")
                XCTAssertEqual(try String(contentsOf: indexHTML), "index")
            }
        }
    }

}
