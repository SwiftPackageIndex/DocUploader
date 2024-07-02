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

import Foundation

import SwiftZip


extension URL {
    var isDirectory: Bool {
       (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}


enum Zipper {
    static func zip(paths inputPaths: [URL], to outputPath: URL) throws {
        let archive = try ZipMutableArchive(url: outputPath, flags: [.create])
        for url in inputPaths {
            if url.isDirectory {
                try archive.addDirectory(name: url.lastPathComponent)
            } else {
                try archive.addFile(name: url.lastPathComponent, source: .init(url: url))
            }
        }
    }

    static func unzip(from inputPath: URL, to outputPath: URL, fileOutputHandler: ((_ unzippedFile: URL) -> Void)? = nil) throws {
        try FileManager.default.createDirectory(at: outputPath, withIntermediateDirectories: true)
        let archive = try ZipArchive(url: inputPath)
        for entry in archive.entries() {
            let name = try entry.getName()
            let output = outputPath.appendingPathComponent(name)
            let parentDir = output.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: parentDir.path) {
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }
            try entry.data().write(to: output)
        }
    }
}


extension Zipper {
    static func unzip(from inputPath: String, to outputPath: String, fileOutputHandler: ((_ unzippedFile: URL) -> Void)? = nil) throws {
        try unzip(from: URL(fileURLWithPath: inputPath), to: URL(fileURLWithPath: outputPath), fileOutputHandler: fileOutputHandler)
    }
}
