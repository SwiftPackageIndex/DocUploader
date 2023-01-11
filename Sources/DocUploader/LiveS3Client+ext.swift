import Foundation

import SotoS3
import SotoS3FileTransfer


extension LiveS3Client {
    struct FileDescriptor: Equatable {
        let name: String
        let modificationDate: Date
        let size: Int
    }

    struct S3FileDescriptor: Equatable {
        let file: _S3File
        let modificationDate: Date
        let size: Int
    }

    struct _S3File: S3Path {
        /// s3 bucket name
        public let bucket: String
        /// path inside s3 bucket
        public let key: String

        internal init(bucket: String, key: String) {
            self.bucket = bucket
            self.key = key.removingPrefix("/")
        }

        /// initialiizer
        /// - Parameter url: Construct file descriptor from url of form `s3://<bucketname>/<key>`
        public init?(url: String) {
            guard url.hasPrefix("s3://") || url.hasPrefix("S3://") else { return nil }
            guard !url.hasSuffix("/") else { return nil }
            let path = url.dropFirst(5)
            guard let slash = path.firstIndex(of: "/") else { return nil }
            self.init(bucket: String(path[path.startIndex..<slash]), key: String(path[slash..<path.endIndex]))
        }

        /// file name without path
        public var name: String {
            guard let slash = key.lastIndex(of: "/") else { return self.key }
            return String(self.key[self.key.index(after: slash)..<self.key.endIndex])
        }

        /// file name without path or extension
        public var nameWithoutExtension: String {
            let name = self.name
            guard let dot = name.lastIndex(of: ".") else { return name }
            return String(name[name.startIndex..<dot])
        }

        /// file extension of file
        public var `extension`: String? {
            let name = self.name
            guard let dot = name.lastIndex(of: ".") else { return nil }
            return String(name[name.index(after: dot)..<name.endIndex])
        }
    }

    static func listFiles(in folder: String) throws -> [FileDescriptor] {
        var files: [FileDescriptor] = []
        let path = URL(fileURLWithPath: folder)
        guard let fileEnumerator = Foundation.FileManager.default.enumerator(
            at: path,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            throw S3FileTransferManager.Error.failedToEnumerateFolder(folder)
        }
        while let file = fileEnumerator.nextObject() as? URL {
            let fileResolved = file.resolvingSymlinksInPath()
            var isDirectory: ObjCBool = false
            // ignore if it is a directory
            _ = Foundation.FileManager.default.fileExists(atPath: fileResolved.path, isDirectory: &isDirectory)
            guard !isDirectory.boolValue else { continue }
            // get modification data and append along with file name
            let attributes = try Foundation.FileManager.default.attributesOfItem(atPath: fileResolved.path)
            guard let modificationDate = attributes[.modificationDate] as? Date else { continue }
            guard let size = attributes[.size] as? NSNumber else { continue }
            let fileDescriptor = FileDescriptor(name: fileResolved.path, modificationDate: modificationDate, size: size.intValue)
            files.append(fileDescriptor)
        }
        return files
    }

    static func listFiles(_ s3: S3, logger: Logger, in folder: S3Folder) async throws -> [S3FileDescriptor] {
        let request = S3.ListObjectsV2Request(bucket: folder.bucket, prefix: folder.key)
        return try await s3.listObjectsV2Paginator(request, [S3FileDescriptor](), logger: logger) { accumulator, response, eventLoop in
            let files: [S3FileDescriptor] = response.contents?.compactMap {
                guard let key = $0.key,
                      let lastModified = $0.lastModified,
                      let fileSize = $0.size else { return nil }
                return S3FileDescriptor(
                    file: _S3File(bucket: folder.bucket, key: key),
                    modificationDate: lastModified,
                    size: Int(fileSize)
                )
            } ?? []
            return eventLoop.makeSucceededFuture((true, accumulator + files))
        }.get()
    }

}


internal extension String {
    func removingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }

    func appendingPrefixIfNeeded(_ prefix: String) -> String {
        guard !hasPrefix(prefix) else { return self }
        return prefix + self
    }

    func removingSuffix(_ suffix: String) -> String {
        guard hasSuffix(suffix) else { return self }
        return String(dropLast(suffix.count))
    }

    func appendingSuffixIfNeeded(_ suffix: String) -> String {
        guard !hasSuffix(suffix) else { return self }
        return self + suffix
    }
}
