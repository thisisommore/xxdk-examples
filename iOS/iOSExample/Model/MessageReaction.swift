import Foundation
import SwiftData

@Model
class MessageReaction {
    var id: UUID = UUID()
    var messageId: String
    var emoji: String
    var timestamp: Date
    var isMe: Bool

    init(messageId: String, emoji: String, isMe: Bool = false) {
        self.messageId = messageId
        self.emoji = emoji
        self.timestamp = Date()
        self.isMe = isMe
    }
}
