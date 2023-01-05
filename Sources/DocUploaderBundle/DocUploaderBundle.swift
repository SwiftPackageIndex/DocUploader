import Foundation

import Zip


public struct DocUploadBundle {

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
        /// Basename of the doc set source directory after unzipping. The value will be the source code revision, e.g. "1.2.3" or "main".
        public var sourcePath: String
        /// Target folder where the doc set will be synced to in S3.
        public var targetFolder: S3Folder
    }

    var sourcePath: String
    var bucket: String
    var repository: Repository
    var reference: String

    public var s3Folder: S3Folder {
        .init(bucket: bucket,
              path: "\(repository.owner)/\(repository.name)/\(reference)".lowercased())
    }

    var metadata: Metadata {
        .init(sourcePath: URL(fileURLWithPath: sourcePath).lastPathComponent.lowercased(),
              targetFolder: s3Folder)
    }

    var archiveName: String {
        "\(repository.owner)-\(repository.name)-\(reference).zip".lowercased()
    }

    public init(sourcePath: String, bucket: String, repository: Repository, reference: String) {
        self.sourcePath = sourcePath
        self.bucket = bucket
        self.repository = repository
        self.reference = reference
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
