import Foundation
import Bindings
import SwiftData

final class EventModelBuilder: NSObject, BindingsEventModelBuilderProtocol {
    private var r: EventModel

    // Optional SwiftData context for the built EventModel
    public var modelContext: ModelContext?

    // Allow late injection from the app so the EventModel can persist messages
    public func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        // Propagate immediately to the underlying model if already created
        r.configure(modelContext: modelContext)
    }

    init(model: EventModel) {
        self.r = model
        super.init()
    }

    func build(_ path: String?) -> (any BindingsEventModelProtocol)? {
        // If a modelContext has been configured on the builder, ensure the model gets it
        if let ctx = modelContext, r.modelContext == nil {
            r.configure(modelContext: ctx)
        }
        return r
    }
}

final class EventModel: NSObject, BindingsEventModelProtocol {
    // Optional SwiftData context for persisting chats/messages
    public var modelContext: ModelContext?

    // Allow late injection of the model context without changing initializer signature
    public func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func deleteMessage(_ messageID: Data?) throws {
    }
    
    func update(fromMessageID messageID: Data?, messageUpdateInfoJSON: Data?, ret0_: UnsafeMutablePointer<Int64>?) throws {
    }
    
    func update(fromUUID uuid: Int64, messageUpdateInfoJSON: Data?) throws {
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
    private func fetchOrCreateChannelChat(channelId: String, channelName: String, ctx: ModelContext) throws -> Chat {
        let descriptor = FetchDescriptor<Chat>(predicate: #Predicate { $0.id == channelId })
        if let existing = try ctx.fetch(descriptor).first {
            return existing
        }
        log("Chat(channelId: \(channelId), name: \(channelName))")
        let newChat = Chat(channelId: channelId, name: channelName)
        ctx.insert(newChat)
        try ctx.save()
        return newChat
    }

    // Persist a message into SwiftData if modelContext is set
    private func persistIncomingMessageIfPossible(channelId: String, channelName: String, text: String, sender: String?, messageIdB64: String? = nil, replyTo: String? = nil, timestamp: Int64) {
        guard let mainContext = modelContext else {
            return
        }
        
        // Create a background context for this operation
        let backgroundContext = ModelContext(mainContext.container)
        
        Task { @MainActor in
            do {
                let chat = try fetchOrCreateChannelChat(channelId: channelId, channelName: channelName, ctx: backgroundContext)
                let msg: ChatMessage
                if let mid = messageIdB64, !mid.isEmpty {
                    log("ChatMessage(message: \(text), isIncoming: \(true), chat: \(chat), sender: \(sender), id: \(mid))")
                    msg = ChatMessage(message: text, isIncoming: true, chat: chat, sender: sender, id: mid, replyTo: replyTo, timestamp: timestamp)
                } else {
                    fatalError("no message id")
                }
                chat.messages.append(msg)
                try backgroundContext.save()
            } catch {
                print("EventModel: Failed to save message: \(error)")
            }
        }
    }

    private let storageTag: String

    init(storageTag: String) { self.storageTag = storageTag }

    func joinChannel(_ channel: String?) {
    }

    func leaveChannel(_ channelID: Data?) {
    }

    func receiveMessage(_ channelID: Data?, messageID: Data?, nickname: String?, text: String?, pubKey: Data?, dmToken: Int32, codeset: Int, timestamp: Int64, lease: Int64, roundID: Int64, messageType: Int64, status: Int64, hidden: Bool) -> Int64 {
        var err: NSError?
        let identityData = Bindings.BindingsConstructIdentity(pubKey, codeset, &err)
        do {
            let identity = try Parser.decodeIdentity(from: identityData!)
            let channelIdB64 = channelID?.base64EncodedString() ?? "unknown"
            let messageIdB64 = messageID?.base64EncodedString()
            let nick = identity.codename
            let messageTextB64 = text ?? ""
            if let decodedText = decodeMessage(messageTextB64) {
                log("\(decodedText) | \(messageIdB64 ?? "nil") | message")
                // Persist into SwiftData chat if available
                persistIncomingMessageIfPossible(channelId: channelIdB64, channelName: "Channel \(String(channelIdB64.prefix(8)))", text: decodedText, sender: nick, messageIdB64: messageIdB64, timestamp: timestamp)
            }
            return 0
        } catch {
            fatalError("something went wrong \(error)")
        }
      
    }

    func receiveReaction(_ channelID: Data?, messageID: Data?, reactionTo: Data?, nickname: String?, reaction: String?, pubKey: Data?, dmToken: Int32, codeset: Int, timestamp: Int64, lease: Int64, roundID: Int64, messageType: Int64, status: Int64, hidden: Bool) -> Int64 {
        let nick = nickname ?? ""
        let reactionText = reaction ?? ""
        let targetMessageIdB64 = reactionTo?.base64EncodedString()
        
        log("\(reactionText) | \(targetMessageIdB64 ?? "nil") | reaction")
        
        // Validate inputs
        guard let ctx = modelContext else {
            return 0
        }
        guard let targetId = targetMessageIdB64, !targetId.isEmpty else {
            return 0
        }
        guard !reactionText.isEmpty else {
            return 0
        }
        
        Task { @MainActor in
            do {
                log("MessageReaction(messageId: \(targetId), emoji: \(reactionText), sender: \(nick))")
            
                let record = MessageReaction(messageId: targetId, emoji: reactionText)
                ctx.insert(record)
                try ctx.save()
            } catch {
                fatalError("failed to store message reaction \(error)")
            }
        }
        return 0
    }

    func deleteReaction(messageId: String, emoji: String) {
        guard let ctx = modelContext else {
            log("deleteReaction: no modelContext available")
            return
        }
        
        Task { @MainActor in
            do {
                let descriptor = FetchDescriptor<MessageReaction>(
                    predicate: #Predicate { $0.messageId == messageId && $0.emoji == emoji }
                )
                let reactions = try ctx.fetch(descriptor)
                
                for reaction in reactions {
                    ctx.delete(reaction)
                    log("Deleted reaction: \(emoji) from message \(messageId)")
                }
                
                try ctx.save()
            } catch {
                print("EventModel: Failed to delete reaction: \(error)")
            }
        }
    }

    func receiveReply(_ channelID: Data?, messageID: Data?, reactionTo: Data?, nickname: String?, text: String?, pubKey: Data?, dmToken: Int32, codeset: Int, timestamp: Int64, lease: Int64, roundID: Int64, messageType: Int64, status: Int64, hidden: Bool) -> Int64 {
        var err: NSError?
        let identityData = Bindings.BindingsConstructIdentity(pubKey, codeset, &err)
        let nick: String
        do {
            let identity = try Parser.decodeIdentity(from: identityData!)
            nick = identity.codename
        } catch {
            // Fallback to provided nickname if identity decoding fails
            nick = nickname ?? ""
        }
        let channelIdB64 = channelID?.base64EncodedString() ?? "unknown"
        let messageIdB64 = messageID?.base64EncodedString()
        let replyTextB64 = text ?? ""
        guard let reactionTo else {
            fatalError("reactionTo is missing")
        }
        if let decodedReply = decodeMessage(replyTextB64) {
            log("\(decodedReply) | \(messageIdB64 ?? "nil") | reply")
            persistIncomingMessageIfPossible(channelId: channelIdB64, channelName: "Channel \(String(channelIdB64.prefix(8)))", text: decodedReply, sender: nick, messageIdB64: messageIdB64, replyTo: reactionTo.base64EncodedString(), timestamp: timestamp)
        }
        return 0
    }

    func updateFromMessageID(_ messageID: Data?, messageUpdateInfoJSON: Data?, ret0_: UnsafeMutablePointer<Int64>?) throws -> Bool {
        return true
    }

    func updateFromUUID(_ uuid: Int64, messageUpdateInfoJSON: Data?) throws -> Bool {
        return true
    }

    func getMessage(_ messageID: Data?) throws -> Data {
        return Data()
    }

    func deleteMessage(_ messageID: Data?) throws -> Bool {
        guard let messageID = messageID else {
            log("deleteMessage: messageID is nil")
            return false
        }
        
        let messageIdB64 = messageID.base64EncodedString()
        log("deleteMessage: messageId=\(messageIdB64)")
        
        guard let ctx = modelContext else {
            log("deleteMessage: no modelContext available")
            return false
        }
        
        Task { @MainActor in
            do {
                // First, try to find and delete a ChatMessage
                let messageDescriptor = FetchDescriptor<ChatMessage>(
                    predicate: #Predicate { $0.id == messageIdB64 }
                )
                let messages = try ctx.fetch(messageDescriptor)
                
                if !messages.isEmpty {
                    for message in messages {
                        log("deleteMessage: Deleting ChatMessage with id=\(messageIdB64)")
                        ctx.delete(message)
                    }
                    try ctx.save()
                    log("deleteMessage: ChatMessage deleted successfully")
                    return
                }
                
                // If no message found, check for reactions
                log("deleteMessage: No ChatMessage found, checking for MessageReaction")
                let reactionDescriptor = FetchDescriptor<MessageReaction>(
                    predicate: #Predicate { $0.messageId == messageIdB64 }
                )
                let reactions = try ctx.fetch(reactionDescriptor)
                
                if !reactions.isEmpty {
                    for reaction in reactions {
                        log("deleteMessage: Deleting MessageReaction with messageId=\(messageIdB64), emoji=\(reaction.emoji)")
                        ctx.delete(reaction)
                    }
                    try ctx.save()
                    log("deleteMessage: MessageReaction(s) deleted successfully")
                    return
                }
                
                // Neither message nor reaction found
                log("deleteMessage: Warning - No ChatMessage or MessageReaction found for id=\(messageIdB64)")
                
            } catch {
                print("EventModel: Failed to delete message/reaction: \(error)")
            }
        }
        
        return true
    }

    func muteUser(_ channelID: Data?, pubkey: Data?, unmute: Bool) {
        // no-op
    }
}
