//
//  ChatMessage.swift
//  iOSExample
//
//  Created by Om More on 17/10/25.
//
import SwiftData
import Foundation
@Model
class ChatMessage: Identifiable {
    @Attribute(.unique) var id: String
    var message: String
    var timestamp: Date
    var isIncoming: Bool
    var sender: Sender?
    var chat: Chat
    var replyTo: String?
    init(message: String, isIncoming: Bool, chat: Chat, sender: Sender? = nil, id: String, replyTo: String? = nil, timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1e+6 * 1e+3)) {


        self.id = id
        self.message = message
        self.timestamp = Date(timeIntervalSince1970: Double(timestamp) * 1e-6 * 1e-3)
        self.isIncoming = isIncoming
        if (sender != nil)
        {
            self.sender = sender
        }
        self.chat = chat
        self.replyTo = replyTo
    }
}
