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

import Zip
import ZIPFoundation


enum Zipper {
    static func zip(paths inputPaths: [URL], to outputPath: URL) throws {
        try Zip.zipFiles(paths: inputPaths, zipFilePath: outputPath, password: nil, progress: nil)
    }

    static func unzip(from inputPath: URL, to outputPath: URL, fileOutputHandler: ((_ unzippedFile: URL) -> Void)? = nil) throws {
        // Use ZipFoundation to unzip because of an archive that can't be round-tripped with marmelroy/Zip
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/3137
        try FileManager.default.createDirectory(at: outputPath, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: inputPath, to: outputPath)
    }
}


extension Zipper {
    static func unzip(from inputPath: String, to outputPath: String, fileOutputHandler: ((_ unzippedFile: URL) -> Void)? = nil) throws {
        try unzip(from: URL(fileURLWithPath: inputPath), to: URL(fileURLWithPath: outputPath), fileOutputHandler: fileOutputHandler)
    }
}
