import Foundation

import Zip


struct DocUploadBundle {
    struct S3Folder: Codable, Equatable {
        var bucket: String
        var path: String
//        var url: String { "s3://\(bucket)/\(path)".lowercased() }
    }

    struct Repository {
        var owner: String
        var name: String
    }

    struct Metadata: Codable, Equatable {
        /// Basename of the doc set source directory after unzipping. The value will be the source code revision, e.g. "1.2.3" or "main".
        var sourcePath: String
        /// Target folder where the doc set will be synced to in S3.
        var targetFolder: S3Folder
    }

    var sourcePath: String
    var bucket: String
    var repository: Repository
    var reference: String

    var s3Folder: S3Folder {
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

    init(sourcePath: String, bucket: String, repository: Repository, reference: String) {
        self.sourcePath = sourcePath
        self.bucket = bucket
        self.repository = repository
        self.reference = reference
    }

    func zip(to workDir: String) throws -> String {
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
}
