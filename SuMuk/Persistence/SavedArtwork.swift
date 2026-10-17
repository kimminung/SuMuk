import Foundation
import SwiftData

/// Gallery entry. The script is the truth; the thumbnail is a cache that can always be re-rendered.
@Model
final class SavedArtwork {
    var title: String
    var script: String
    var createdAt: Date
    var elementCount: Int
    var sourceNote: String
    @Attribute(.externalStorage) var thumbnail: Data?

    init(title: String, script: String, elementCount: Int, sourceNote: String = "", thumbnail: Data? = nil) {
        self.title = title
        self.script = script
        self.createdAt = .now
        self.elementCount = elementCount
        self.sourceNote = sourceNote
        self.thumbnail = thumbnail
    }
}
