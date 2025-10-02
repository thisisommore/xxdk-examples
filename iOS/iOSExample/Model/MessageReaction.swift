import Foundation
import SwiftData

@Model
class MessageReaction {
    var id: String
    var targetMessageId: String
    var emoji: String
    var timestamp: Date
    var isMe: Bool
    var sender: Sender?

    init(id: String, targetMessageId: String, emoji: String, sender: Sender? = nil, isMe: Bool = false) {
        self.targetMessageId = targetMessageId
        self.emoji = emoji
        self.timestamp = Date()
        self.isMe = isMe
        self.sender = sender
        self.id = id
    }
}
