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
                do { try Zip.zipFiles(paths: inputPaths, zipFilePath: outputPath, password: nil, progress: nil) } 
                catch ZipError.fileNotFound { throw Error.fileNotFound }
                catch ZipError.unzipFail { throw Error.unzipFail }
                catch ZipError.zipFail { throw Error.zipFail }
                catch { throw Error.generic(reason: "\(error)") }

            case let .zipTool(cwd):
                do {
                    let process = Process()
                    process.executableURL = zip
                    process.arguments = ["-q", "-r", outputPath.path] + inputPaths.map(\.lastPathComponent)
                    process.currentDirectoryURL = cwd.map(URL.init(fileURLWithPath:))
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    throw Error.generic(reason: "\(error)")
                }
        }
    }

    public static func unzip(from inputPath: URL, to outputPath: URL, fileOutputHandler: ((_ unzippedFile: URL) -> Void)? = nil) throws {
        do { try Zip.unzipFile(inputPath, destination: outputPath, overwrite: true, password: nil, fileOutputHandler: fileOutputHandler) }
        catch ZipError.fileNotFound { throw Error.fileNotFound }
        catch ZipError.unzipFail { throw Error.unzipFail }
        catch ZipError.zipFail { throw Error.zipFail }
        catch { throw Error.generic(reason: "\(error)") }
    }

    static let zip = URL(fileURLWithPath: "/usr/bin/zip")

    public enum Method {
        case library
        case zipTool(workingDirectory: String? = nil)
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
