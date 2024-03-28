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

import Dependencies
import Zip


public struct DocUploadBundle {

#if DEBUG
    @Dependency(\.uuid) var uuid
#else
    let uuid = { UUID() }
#endif

    public struct S3Folder: Codable, Equatable {
        public var bucket: String
        public var path: String

        public init(bucket: String, path: String) {
            self.bucket = bucket
            self.path = path
        }
    }

    public struct Repository {
        var owner: String
        var name: String

        public init(owner: String, name: String) {
            self.owner = owner
            self.name = name
        }
    }

    public struct Metadata: Codable, Equatable {
        public var apiBaseURL: String
        public var apiToken: String
        public var buildId: UUID
        public var docArchives: [DocArchive]
        public var fileCount: Int?
        public var linkablePathsCount: Int?
        public var mbSize: Int?

        /// Basename of the doc set source directory after unzipping. The value will be the source code revision, e.g. "1.2.3" or "main".
        public var sourcePath: String
        /// Target folder where the doc set will be synced to in S3.
        public var targetFolder: S3Folder
    }

    let sourcePath: String
    let bucket: String
    let repository: Repository
    let reference: String
    let env: String

    public let metadata: Metadata
    public let s3Folder: S3Folder

    var archiveName: String {
        "\(env)-\(repository.owner)-\(repository.name)-\(reference.pathEncoded)-\(self.uuid().firstSegment).zip"
            .lowercased()
    }

    public init(
        sourcePath: String,
        bucket: String,
        repository: Repository,
        reference: String,
        apiBaseURL: String,
        apiToken: String,
        buildId: UUID,
        docArchives: [DocArchive],
        fileCount: Int? = nil,
        linkablePathsCount: Int? = nil,
        mbSize: Int? = nil
    ) {
        self.sourcePath = sourcePath
        self.bucket = bucket
        self.repository = repository
        self.reference = reference
        self.env = bucket.droppingSPIPrefix().droppingDocsSuffix()
        self.s3Folder = .init(
            bucket: bucket,
            path: "\(repository.owner)/\(repository.name)/\(reference.pathEncoded)".lowercased()
        )
        self.metadata = .init(
            apiBaseURL: apiBaseURL,
            apiToken: apiToken,
            buildId: buildId,
            docArchives: docArchives,
            fileCount: fileCount,
            linkablePathsCount: linkablePathsCount,
            mbSize: mbSize,
            sourcePath: URL(fileURLWithPath: sourcePath).lastPathComponent.lowercased(),
            targetFolder: s3Folder
        )
    }

    public func zip(to workDir: String) throws -> String {
            let archiveURL = URL(fileURLWithPath: "\(workDir)/\(archiveName)")
            let metadataURL = URL(fileURLWithPath: "\(workDir)/metadata.json")
            try JSONEncoder().encode(metadata).write(to: metadataURL)

            try Zip.zipFiles(
                paths: [metadataURL, URL(fileURLWithPath: sourcePath)],
                zipFilePath: archiveURL,
                password: nil,
                progress: nil
            )

            return archiveURL.path
    }

    public static func unzip(bundle: String, outputPath: String, fileOutputHandler: ((_ unzippedFile: URL) -> Void)? = nil) throws -> Metadata {
        try Zip.unzipFile(URL(fileURLWithPath: bundle),
                          destination: URL(fileURLWithPath: outputPath),
                          overwrite: true,
                          password: nil,
                          fileOutputHandler: fileOutputHandler)
        let metadataURL = URL(fileURLWithPath: "\(outputPath)/metadata.json")
        let data = try Data(contentsOf: metadataURL)
        return try JSONDecoder().decode(Metadata.self, from: data)
    }

}


private extension UUID {
    var firstSegment: String {
        uuidString.components(separatedBy: "-").first!.lowercased()
    }
}


private extension String {
    func droppingSPIPrefix() -> String {
        let prefix = "spi-"
        if lowercased().hasPrefix(prefix) {
            return String(dropFirst(prefix.count))
        }
        return self
    }
    func droppingDocsSuffix() -> String {
        let suffix = "-docs"
        if lowercased().hasSuffix(suffix) {
            return String(dropLast(suffix.count))
        }
        return self
    }
}
