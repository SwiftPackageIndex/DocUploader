public struct DocArchive: Codable, Equatable {
    public var name: String
    public var title: String

    public init(name: String, title: String) {
        self.name = name
        self.title = title
    }
}
