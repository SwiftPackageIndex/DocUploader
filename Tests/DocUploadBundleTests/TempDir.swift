import Foundation


enum TempDirError: LocalizedError {
    case invalidPath(String)
}


class TempDir {
    let path: String

    init() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        path = tempDir.path
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        precondition(FileManager.default.fileExists(atPath: path), "failed to create temp dir")
    }

    deinit {
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch {
            print("⚠️ failed to delete temp directory: \(error.localizedDescription)")
        }
    }

}


func withTempDir<T>(body: (String) async throws -> T) async throws -> T {
    let tmp = try TempDir()
    return try await body(tmp.path)
}
