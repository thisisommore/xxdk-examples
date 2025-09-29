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
        log("deleteMessage(messageID=\(short(messageID)))")
    }
    
    func update(fromMessageID messageID: Data?, messageUpdateInfoJSON: Data?, ret0_: UnsafeMutablePointer<Int64>?) throws {
        log("update(fromMessageID=\(short(messageID))) json=\(short(messageUpdateInfoJSON))")
        // If the protocol expects ret0_ to be set, leave as-is (no-op) to preserve behavior
    }
    
    func update(fromUUID uuid: Int64, messageUpdateInfoJSON: Data?) throws {
        log("update(fromUUID=\(uuid)) json=\(short(messageUpdateInfoJSON))")
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
        let newChat = Chat(channelId: channelId, name: channelName)
        ctx.insert(newChat)
        try ctx.save()
        return newChat
    }

    // Persist a message into SwiftData if modelContext is set
    private func persistIncomingMessageIfPossible(channelId: String, channelName: String, text: String, sender: String?, messageIdB64: String? = nil) {
        guard let ctx = modelContext else {
            log("modelContext not set; skipping persistence for incoming message in channel \(channelName)")
            return
        }
        Task { @MainActor in
            do {
                let chat = try fetchOrCreateChannelChat(channelId: channelId, channelName: channelName, ctx: ctx)
                let msg: ChatMessage
                if let mid = messageIdB64, !mid.isEmpty {
                    msg = ChatMessage(message: text, isIncoming: true, chat: chat, sender: sender, id: mid)
                } else {
                    msg = ChatMessage(message: text, isIncoming: true, chat: chat, sender: sender)
                }
                chat.messages.append(msg)
                try ctx.save()
                log("Saved incoming message to chat='\(chat.name)' (messages: \(chat.messages.count))")
            } catch {
                log("Failed to persist incoming message: \(error)")
            }
        }
    }

    private let storageTag: String

    init(storageTag: String) { self.storageTag = storageTag }

    func joinChannel(_ channel: String?) {
        log("Joined channel: \(channel ?? "")")
    }

    func leaveChannel(_ channelID: Data?) {
        log("Left channel: \(channelID?.base64EncodedString() ?? "")")
    }

    func receiveMessage(_ channelID: Data?, messageID: Data?, nickname: String?, text: String?, pubKey: Data?, dmToken: Int32, codeset: Int, timestamp: Int64, lease: Int64, roundID: Int64, messageType: Int64, status: Int64, hidden: Bool) -> Int64 {
        var err: NSError?
        let identityData = Bindings.BindingsConstructIdentity(pubKey, codeset, &err)
        let identity = try! Parser.decodeIdentity(from: identityData!)
        let channelIdB64 = channelID?.base64EncodedString() ?? "unknown"
        let messageIdB64 = messageID?.base64EncodedString()
        let nick = identity.codename
        let messageTextB64 = text ?? ""
        if let decodedText = decodeMessage(messageTextB64) {
            log("Msg on \(channelIdB64) from \(nick): \(decodedText) \(String(describing: messageID))")
            // Persist into SwiftData chat if available
            persistIncomingMessageIfPossible(channelId: channelIdB64, channelName: "Channel \(String(channelIdB64.prefix(8)))", text: decodedText, sender: nick, messageIdB64: messageIdB64)
        } else {
            log("Warning: Failed to decode incoming message (b64/zlib) \(messageTextB64) on channel \(channelIdB64) from \(nick); skipping persistence")
        }
        return 0
    }

    func receiveReaction(_ channelID: Data?, messageID: Data?, reactionTo: Data?, nickname: String?, reaction: String?, pubKey: Data?, dmToken: Int32, codeset: Int, timestamp: Int64, lease: Int64, roundID: Int64, messageType: Int64, status: Int64, hidden: Bool) -> Int64 {
        let channelIdB64 = channelID?.base64EncodedString() ?? "unknown"
        let nick = nickname ?? ""
        let reactionText = reaction ?? ""
        let targetMessageIdB64 = reactionTo?.base64EncodedString()

        // Validate inputs
        guard let ctx = modelContext else {
            log("modelContext not set; skipping reaction persist for channel \(channelIdB64)")
            return 0
        }
        guard let targetId = targetMessageIdB64, !targetId.isEmpty else {
            log("Warning: Missing target message id for reaction '" + reactionText + "' by \(nick) on channel \(channelIdB64)")
            return 0
        }
        guard !reactionText.isEmpty else {
            log("Warning: Empty reaction received for target \(targetId) on channel \(channelIdB64)")
            return 0
        }

        Task { @MainActor in
            do {
                // Find the message within this channel by external messageId
                let descriptor = FetchDescriptor<ChatMessage>(predicate: #Predicate { msg in
                    msg.messageId == targetId
                })
                if let targetMsg = try ctx.fetch(descriptor).first {
                    targetMsg.addReaction(reactionText)
                    try ctx.save()
                    log("Added reaction '" + reactionText + "' by \(nick) to messageId=\(targetId) in channel=\(channelIdB64)")
                } else {
                    log("Warning: Could not find target messageId=\(targetId) in channel=\(channelIdB64) to apply reaction \(reactionText)'")
                }
            } catch {
                log("Failed to persist reaction: \(error)")
            }
        }
        return 0
    }

    func receiveReply(_ channelID: Data?, messageID: Data?, reactionTo: Data?, nickname: String?, text: String?, pubKey: Data?, dmToken: Int32, codeset: Int, timestamp: Int64, lease: Int64, roundID: Int64, messageType: Int64, status: Int64, hidden: Bool) -> Int64 {
        let channelIdB64 = channelID?.base64EncodedString() ?? "unknown"
        let nick = nickname ?? ""
        let replyTextB64 = text ?? ""
        if let decodedReply = decodeMessage(replyTextB64) {
            log("Reply from \(nick): \(decodedReply)")
            // Persist reply as an incoming message
            let rendered = "\(nick) replied: \(decodedReply)"
            persistIncomingMessageIfPossible(channelId: channelIdB64, channelName: "Channel \(String(channelIdB64.prefix(8)))", text: rendered, sender: nickname)
        } else {
            log("Warning: Failed to decode reply (b64/zlib) on channel \(channelIdB64) from \(nick); skipping persistence")
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
        return true
    }

    func muteUser(_ channelID: Data?, pubkey: Data?, unmute: Bool) {
        // no-op
    }
}
