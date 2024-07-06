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


public enum Zipper {
    public static func zip(paths inputPaths: [URL], to outputPath: URL, method: Method = .library) throws {
        switch method {
            case .library:
                do {
                    try Zip.zipFiles(paths: inputPaths, zipFilePath: outputPath, password: nil, progress: nil)
                } catch let error as ZipError {
                    switch error {
                        case .fileNotFound: throw Error.fileNotFound
                        case .unzipFail: throw Error.unzipFail
                        case .zipFail: throw Error.zipFail
                    }
                }
                catch {
                    throw Error.generic(reason: "\(error)")
                }

            case .zipTool:
                do {
                    try withTempDir { tempDir in
                        let tempURL = URL(fileURLWithPath: tempDir)
                        // Copy inputs to tempDir
                        for source in inputPaths {
                            let target = tempURL.appendingPathComponent(source.lastPathComponent)
                            try FileManager.default.copyItem(at: source, to: target)
                        }

                        // Run zip
                        let process = Process()
                        process.executableURL = zip
                        process.arguments = ["-q", "-r", outputPath.path] + inputPaths.map(\.lastPathComponent)
                        process.currentDirectoryURL = tempURL
                        try process.run()
                        process.waitUntilExit()
                    }
                } catch {
                    throw Error.generic(reason: "\(error)")
                }
        }
    }

    public static func unzip(from inputPath: URL, to outputPath: URL, fileOutputHandler: ((_ unzippedFile: URL) -> Void)? = nil) throws {
        do {
            try Zip.unzipFile(inputPath, destination: outputPath, overwrite: true, password: nil, fileOutputHandler: fileOutputHandler)
        } catch let error as ZipError {
            switch error {
                case .fileNotFound: throw Error.fileNotFound
                case .unzipFail: throw Error.unzipFail
                case .zipFail: throw Error.zipFail
            }
        }
        catch {
            throw Error.generic(reason: "\(error)")
        }
    }

    static let zip = URL(fileURLWithPath: "/usr/bin/zip")

    public enum Method {
        case library
        case zipTool
    }

    public enum Error: Swift.Error {
        case generic(reason: String)
        case fileNotFound
        case unzipFail
        case zipFail
    }
}


extension Zipper {
    static func unzip(from inputPath: String, to outputPath: String, fileOutputHandler: ((_ unzippedFile: URL) -> Void)? = nil) throws {
        try unzip(from: URL(fileURLWithPath: inputPath), to: URL(fileURLWithPath: outputPath), fileOutputHandler: fileOutputHandler)
    }
}
