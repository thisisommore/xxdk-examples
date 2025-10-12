//
//  Chat.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import SwiftData
import Foundation

@Model
class User {
    // For users, codename uniquely identifies the user. We store it as the id.
    var id: String
    // Display name; for now, same as codename unless changed later.
    var name: String
    @Relationship(deleteRule: .cascade)
    var chat = [Chat]()

    init(codename: String) {
        self.id = codename
        self.name = codename
    }
}

@Model
class Chat {
    // For channels, this is the channel ID. For DMs, this is the pub key.
    @Attribute(.unique) var id: String
    // Human-readable name (channel name or partner codename)
    var name: String
    // Channel description
    var channelDescription: String?

    // needed for direct dm
    var dmToken: Int32?
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.chat)
    var messages = [ChatMessage]()

    // General initializer (use for channels where you have a channel id and name)
    init(channelId: String, name: String, description: String? = nil) {
        self.id = channelId
        self.name = name
        self.channelDescription = description
    }

    // initializer for DM chats where pubkey and dmToken is required
    init(pubKey: Data, name: String, dmToken: Int32) {
        self.id = pubKey.base64EncodedString()
        self.name = name
        self.dmToken = dmToken
    }

    func add(m: ChatMessage){
        messages.append(m)
    }
}

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
        self.sender = sender
        self.chat = chat
        self.replyTo = replyTo
    }
}

