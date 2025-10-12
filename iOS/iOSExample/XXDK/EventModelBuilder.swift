import Bindings
import Foundation
import SwiftData

final class EventModelBuilder: NSObject, BindingsEventModelBuilderProtocol {
    private var r: EventModel

    // Optional SwiftData container for the built EventModel
    public var modelContainer: ModelContainer?

    // Allow late injection from the app so the EventModel can persist messages
    public func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        // Propagate immediately to the underlying model if already created
        r.configure(modelContainer: modelContainer)
    }

    init(model: EventModel) {
        self.r = model
        super.init()
    }

    func build(_ path: String?) -> (any BindingsEventModelProtocol)? {
        // If a modelContainer has been configured on the builder, ensure the model gets it
        if let container = modelContainer, r.modelContainer == nil {
            r.configure(modelContainer: container)
        }
        return r
    }
}

final class EventModel: NSObject, BindingsEventModelProtocol {
    // Optional SwiftData container for persisting chats/messages
    public var modelContainer: ModelContainer?

    // Allow late injection of the model container without changing initializer signature
    public func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func update(
        fromMessageID messageID: Data?,
        messageUpdateInfoJSON: Data?,
        ret0_: UnsafeMutablePointer<Int64>?
    ) throws {
        log(
            "updateFromMessageID - messageID \(short(messageID)) | messageUpdateInfoJSON \(messageUpdateInfoJSON)"
        )
    }

    func update(fromUUID uuid: Int64, messageUpdateInfoJSON: Data?) throws {
        log(
            "updateFromUUID - uuid \(uuid) | messageUpdateInfoJSON \(messageUpdateInfoJSON)"
        )
    }

    // MARK: - Helpers
    private func log(_ message: String) {
        print("[EventModel] \(message)")
    }

    private func short(_ data: Data?) -> String {
        guard let d = data else { return "nil" }
        let b64 = d.base64EncodedString()
        return b64.count > 16 ? String(b64.prefix(16)) + "…" : b64
    }

    // Fetch existing Chat by channelId or create a new one
    private func fetchOrCreateChannelChat(
        channelId: String,
        channelName: String,
        mCoin: ModelContainer
    ) throws -> Chat {
        let descriptor = FetchDescriptor<Chat>(
            predicate: #Predicate { $0.id == channelId }
        )
        let ctx = ModelContext(mCoin)
        if let existing = try ctx.fetch(descriptor).first {
            return existing
        }
        log("Chat(channelId: \(channelId), name: \(channelName))")
        let newChat = Chat(channelId: channelId, name: channelName)
        ctx.insert(newChat)
        try ctx.save()
        return newChat
    }

    // Persist a message into SwiftData if modelContainer is set
    private func persistIncomingMessageIfPossible(
        channelId: String,
        channelName: String,
        text: String,
        senderCodename: String?,
        senderPubKey: Data?,
        messageIdB64: String? = nil,
        replyTo: String? = nil,
        timestamp: Int64,
        dmToken: Int32? = nil
    ) -> Int64 {
        guard let container = modelContainer else {
            fatalError("no modelContainer")
        }

        do {
            let context = ModelContext(container)
            let chat = try fetchOrCreateChannelChat(
                channelId: channelId,
                channelName: channelName,
                mCoin: container
            )

            // Create or update Sender object if we have codename and pubkey
            var sender: Sender? = nil
            if let codename = senderCodename, let pubKey = senderPubKey {
                let senderId = pubKey.base64EncodedString()

                // Check if sender already exists and update dmToken
                let senderDescriptor = FetchDescriptor<Sender>(
                    predicate: #Predicate { $0.id == senderId }
                )
                if let existingSender = try? context.fetch(
                    senderDescriptor
                ).first {
                    // Update existing sender's dmToken
                    existingSender.dmToken = dmToken ?? 0
                    sender = existingSender
                    try context.save()
                    log(
                        "Updated Sender dmToken for \(codename): \(dmToken ?? 0)"
                    )
                } else {
                    // Create new sender
                    sender = Sender(
                        id: senderId,
                        pubkey: pubKey,
                        codename: codename,
                        dmToken: dmToken ?? 0
                    )
                    log(
                        "Created new Sender for \(codename) with dmToken: \(dmToken ?? 0)"
                    )
                }
            }
            try context.insert(sender!)
            try context.save()
            let msg: ChatMessage
            if let mid = messageIdB64, !mid.isEmpty {
                // Check if sender's pubkey matches the pubkey of chat with id "<self>"
                let isIncoming = !isSenderSelf(chat: chat, senderPubKey: senderPubKey, ctx: context)
                log(
                    "ChatMessage(message: \(text), isIncoming: \(isIncoming), chat: \(chat.name), sender: \(sender!.codename), id: \(mid))"
                )
                log(
                    "Sender(codename: \(sender!.codename), dmToken: \(sender!.dmToken))"
                )
                msg = ChatMessage(
                    message: text,
                    isIncoming: isIncoming,
                    chat: chat,
                    sender: sender,
                    id: mid,
                    replyTo: replyTo,
                    timestamp: timestamp
                )
                context.insert(msg)
            } else {
                fatalError("no message id")
            }
            
            try context.save()
            chat.messages.append(msg)
            try context.save()
            return Int64(msg.persistentModelID.hashValue)
        } catch {
            print(error)
            fatalError(
                error.localizedDescription
            )
        }

    }

    private let storageTag: String

    init(storageTag: String) { self.storageTag = storageTag }

    func joinChannel(_ channel: String?) {
    }

    func leaveChannel(_ channelID: Data?) {
    }

    func receiveMessage(
        _ channelID: Data?,
        messageID: Data?,
        nickname: String?,
        text: String?,
        pubKey: Data?,
        dmToken: Int32,
        codeset: Int,
        timestamp: Int64,
        lease: Int64,
        roundID: Int64,
        messageType: Int64,
        status: Int64,
        hidden: Bool
    ) -> Int64 {
        let messageIdB64 = messageID?.base64EncodedString()
        let messageTextB64 = text ?? ""
        if let decodedText = decodeMessage(messageTextB64) {
            log(
                "[EventReceived] new | \(messageIdB64 ?? "nil") | | \(decodedText)"
            )
        }

        var err: NSError?
        let identityData = Bindings.BindingsConstructIdentity(
            pubKey,
            codeset,
            &err
        )
        do {
            let identity = try Parser.decodeIdentity(from: identityData!)
            let channelIdB64 = channelID?.base64EncodedString() ?? "unknown"
            let nick = identity.codename
            if let decodedText = decodeMessage(messageTextB64) {
                // Persist into SwiftData chat if available
                return persistIncomingMessageIfPossible(
                    channelId: channelIdB64,
                    channelName: "Channel \(String(channelIdB64.prefix(8)))",
                    text: decodedText,
                    senderCodename: nick,
                    senderPubKey: pubKey,
                    messageIdB64: messageIdB64,
                    timestamp: timestamp,
                    dmToken: dmToken
                )
            }
            return 0
        } catch {
            fatalError("something went wrong \(error)")
        }

    }

    func receiveReaction(
        _ channelID: Data?,
        messageID: Data?,
        reactionTo: Data?,
        nickname: String?,
        reaction: String?,
        pubKey: Data?,
        dmToken: Int32,
        codeset: Int,
        timestamp: Int64,
        lease: Int64,
        roundID: Int64,
        messageType: Int64,
        status: Int64,
        hidden: Bool
    ) -> Int64 {
        log(
            "[EventReceived] new | \(messageID?.base64EncodedString() ?? "nil") | \(reactionTo?.base64EncodedString() ?? "nil") | \(reaction ?? "")"
        )

        let nick = nickname ?? ""
        let reactionText = reaction ?? ""
        let targetMessageIdB64 = reactionTo?.base64EncodedString()

        // Validate inputs
        guard let container = modelContainer else {
            fatalError("no model container")
        }
        guard let targetId = targetMessageIdB64, !targetId.isEmpty else {
            fatalError("no target id")
        }
        guard !reactionText.isEmpty else {
            fatalError("no reaction")
        }

        do {
            let context = ModelContext(container)

            // Create or update Sender object if we have codename and pubkey
            var sender: Sender? = nil
            if let pubKey = pubKey {
                let senderId = pubKey.base64EncodedString()

                // Check if sender already exists and update dmToken
                let senderDescriptor = FetchDescriptor<Sender>(
                    predicate: #Predicate { $0.id == senderId }
                )
                if let existingSender = try? context.fetch(senderDescriptor).first {
                    // Update existing sender's dmToken (nil for reactions since dmToken not provided)
                    existingSender.dmToken = 0
                    sender = existingSender
                    log("Updated Sender dmToken for \(nick): nil (reaction)")
                } else {
                    // Create new sender
                    sender = Sender(
                        id: senderId,
                        pubkey: pubKey,
                        codename: nick,
                        dmToken: 0
                    )
                    log(
                        "Created new Sender for \(nick) with dmToken: nil (reaction)"
                    )
                }
            }

            let record = MessageReaction(
                id: messageID!.base64EncodedString(),
                targetMessageId: targetId,
                emoji: reactionText,
                sender: sender
            )
            context.insert(record)
            try context.save()
            log(
                "MessageReaction(id: \(messageID!.base64EncodedString()), targetMessageId: \(targetId), emoji: \(reactionText), sender: \(sender))"
            )
            return Int64(record.persistentModelID.hashValue)
        } catch {
            fatalError(
                "failed to store message reaction \(error.localizedDescription)"
            )
        }

    }

    func deleteReaction(messageId: String, emoji: String) {
        log("[EventReceived] delete | \(messageId) | | \(emoji)")
        guard let container = modelContainer else {
            log("deleteReaction: no modelContainer available")
            return
        }

        do {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<MessageReaction>(
                predicate: #Predicate {
                    $0.id == messageId && $0.emoji == emoji
                }
            )
            let reactions = try context.fetch(descriptor)

            for reaction in reactions {
                context.delete(reaction)
                log("Deleted reaction: \(emoji) from message \(messageId)")
            }

            try context.save()
        } catch {
            print("EventModel: Failed to delete reaction: \(error)")
        }
    }

    func receiveReply(
        _ channelID: Data?,
        messageID: Data?,
        reactionTo: Data?,
        nickname: String?,
        text: String?,
        pubKey: Data?,
        dmToken: Int32,
        codeset: Int,
        timestamp: Int64,
        lease: Int64,
        roundID: Int64,
        messageType: Int64,
        status: Int64,
        hidden: Bool
    ) -> Int64 {
        let messageIdB64 = messageID?.base64EncodedString()
        let replyTextB64 = text ?? ""
        if let decodedReply = decodeMessage(replyTextB64) {
            log(
                "[EventReceived] reply | \(messageIdB64 ?? "nil") | \(reactionTo?.base64EncodedString() ?? "nil") | \(decodedReply)"
            )
        }

        var err: NSError?
        let identityData = Bindings.BindingsConstructIdentity(
            pubKey,
            codeset,
            &err
        )
        let nick: String
        do {
            let identity = try Parser.decodeIdentity(from: identityData!)
            nick = identity.codename
        } catch {
            // Fallback to provided nickname if identity decoding fails
            nick = nickname ?? ""
        }
        let channelIdB64 = channelID?.base64EncodedString() ?? "unknown"
        guard let reactionTo else {
            fatalError("reactionTo is missing")
        }
        if let decodedReply = decodeMessage(replyTextB64) {
            return persistIncomingMessageIfPossible(
                channelId: channelIdB64,
                channelName: "Channel \(String(channelIdB64.prefix(8)))",
                text: decodedReply,
                senderCodename: nick,
                senderPubKey: pubKey,
                messageIdB64: messageIdB64,
                replyTo: reactionTo.base64EncodedString(),
                timestamp: timestamp,
                dmToken: dmToken
            )
        }
        return 0
    }

    func updateFromMessageID(
        _ messageID: Data?,
        messageUpdateInfoJSON: Data?,
        ret0_: UnsafeMutablePointer<Int64>?
    ) throws -> Bool {
        log(
            "updateFromMessageID - messageID \(messageID?.utf8) | messageUpdateInfoJSON \(messageUpdateInfoJSON?.utf8)"
        )
        return true
    }

    func updateFromUUID(_ uuid: Int64, messageUpdateInfoJSON: Data?) throws
        -> Bool
    {
        log(
            "updateFromUUID - uuid \(uuid) | messageUpdateInfoJSON \(messageUpdateInfoJSON?.utf8)"
        )
        return true
    }

    func getMessage(_ messageID: Data?) throws -> Data {
        guard let messageID = messageID else {
            throw NSError(
                domain: "EventModel",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: BindingsGetNoMessageErr()]
            )
        }

        let messageIdB64 = messageID.base64EncodedString()
        log("[EventReceived] get | \(messageIdB64) | | ")

        guard let container = modelContainer else {
            throw NSError(domain: "EventModel", code: 500)
        }

        let context = ModelContext(container)

        // Check ChatMessage
        let msgDescriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.id == messageIdB64 }
        )
        if let msg = try? context.fetch(msgDescriptor).first {
            let pubKeyData = msg.sender?.pubkey ?? Data()
            let modelMsg = ModelMessageJSON(
                pubKey: pubKeyData,
                messageID: messageID
            )
            return try Parser.encodeModelMessage(modelMsg)
        }

        // Check MessageReaction - if message not found, check if it's a reaction
        let reactionDescriptor = FetchDescriptor<MessageReaction>(
            predicate: #Predicate { $0.id == messageIdB64 }
        )
        if let reaction = try? context.fetch(reactionDescriptor).first {
            let pubKeyData = reaction.sender?.pubkey ?? Data()
            let modelMsg = ModelMessageJSON(
                pubKey: pubKeyData,
                messageID: messageID
            )
            return try Parser.encodeModelMessage(modelMsg)
        }
        // Not found
        throw NSError(
            domain: "EventModel",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: BindingsGetNoMessageErr()]
        )
    }

    func deleteMessage(_ messageID: Data?) throws {
        guard let messageID = messageID else {
            fatalError("message id is nil")
        }

        let messageIdB64 = messageID.base64EncodedString()
        log("[EventReceived] delete | \(messageIdB64) | | ")

        guard let container = modelContainer else {
            fatalError("deleteMessage: no modelContainer available")
        }

        let context = ModelContext(container)

        do {
            // First, try to find and delete a ChatMessage
            let messageDescriptor = FetchDescriptor<ChatMessage>(
                predicate: #Predicate { $0.id == messageIdB64 }
            )
            let messages = try context.fetch(messageDescriptor)

            if !messages.isEmpty {
                for message in messages {
                    log(
                        "deleteMessage: Deleting ChatMessage with id=\(messageIdB64)"
                    )
                    context.delete(message)
                }
                try context.save()
                log("deleteMessage: ChatMessage deleted successfully")
                return
            }

            // If no message found, check for reactions
            log(
                "deleteMessage: No ChatMessage found, checking for MessageReaction"
            )
            let reactionDescriptor = FetchDescriptor<MessageReaction>(
                predicate: #Predicate { $0.id == messageIdB64 }
            )
            let reactions = try context.fetch(reactionDescriptor)

            if !reactions.isEmpty {
                for reaction in reactions {
                    log(
                        "deleteMessage: Deleting MessageReaction with messageId=\(messageIdB64), emoji=\(reaction.emoji)"
                    )
                    context.delete(reaction)
                }
                try context.save()
                log("deleteMessage: MessageReaction(s) deleted successfully")
                return
            }

            // Neither message nor reaction found
            log(
                "deleteMessage: Warning - No ChatMessage or MessageReaction found for id=\(messageIdB64)"
            )

        } catch {
            print("EventModel: Failed to delete message/reaction: \(error)")
        }

    }

    func muteUser(_ channelID: Data?, pubkey: Data?, unmute: Bool) {
        log(
            "muteUser - channelID \(short(channelID)) | pubkey \(short(pubkey)) | unmute \(unmute)"
        )
    }

    // MARK: - Helper Methods
    private func isSenderSelf(chat: Chat, senderPubKey: Data?, ctx: ModelContext) -> Bool {
        // Check if there's a chat with id "<self>" and compare its pubkey with sender's pubkey
        let selfChatDescriptor = FetchDescriptor<Chat>(predicate: #Predicate { $0.name == "<self>" })
        if let selfChat = try? ctx.fetch(selfChatDescriptor).first {
            guard let senderPubKey = senderPubKey else { return false }
            return Data(base64Encoded: selfChat.id) == senderPubKey
        }

        return false
    }
}
