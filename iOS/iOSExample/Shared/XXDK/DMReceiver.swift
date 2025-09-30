//
//  DMReceiver.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import Bindings
import SwiftData

// DMReceiver's are callbacks for message processing. These include
// message reception and retrieval of specific data to process a message.
// DmCallbacks are events that signify the UI should be updated
// for full details see the docstrings or the "bindings" folder
// inside the core codebase.
// We implement them both inside the same object for convenience of passing updates to the UI.
// Your implementation may vary based on your needs.


struct ReceivedMessage: Identifiable {
    var Msg: String
    var id = UUID()
}


class DMReceiver: NSObject, ObservableObject, Bindings.BindingsDMReceiverProtocol, Bindings.BindingsDmCallbacksProtocol {
    // Optional SwiftData context injected from SwiftUI
    public var modelContext: ModelContext?

    override init() {
        super.init()
    }

    init(modelContext: ModelContext?) {
        self.modelContext = modelContext
    }

    @Published var msgBuf: [ReceivedMessage] = []
    private var msgCnt: Int64 = 0
    
    func eventUpdate(_ eventType: Int64, jsonData: Data?) {
        msgBuf.append(ReceivedMessage(Msg: "Received Event id \(eventType)"))
    }
        
    func deleteMessage(_ messageID: Data?, senderPubKey: Data?) -> Bool {
        msgBuf.append(ReceivedMessage(Msg: "Delete message: " +
                      "\(messageID?.base64EncodedString() ?? "empty id"), " +
                      "\(senderPubKey?.base64EncodedString() ?? "empty pubkey")"))
        return true
    }
    
    func getConversation(_ senderPubKey: Data?) -> Data? {
        msgBuf.append(ReceivedMessage(Msg: "getConversation: \(senderPubKey?.base64EncodedString() ?? "empty pubkey")"))
        return "".data
    }
    
    func getConversations() -> Data? {
        msgBuf.append(ReceivedMessage(Msg: "getConversations"))
        return "[]".data
    }
    
    func receive(_ messageID: Data?, nickname: String?, text: Data?, partnerKey: Data?, senderKey: Data?, dmToken: Int32, codeset: Int, timestamp: Int64, roundId: Int64, mType: Int64, status: Int64) -> Int64 {
        let textB64 = String(data: text ?? Data(), encoding: .utf8) ?? ""
        print("[DMReceiver.receive] Raw text from Data: \(textB64.prefix(50))...")
        let decodedText = decodeMessage(textB64) ?? "empty text"
        print("[DMReceiver.receive] Decoded: \(decodedText)")
        msgBuf.append(ReceivedMessage(Msg: "\(senderKey?.base64EncodedString() ?? "empty pubkey"): \(decodedText)"))
        persistIncoming(message: decodedText, codename: nickname, partnerKey: partnerKey, dmToken: dmToken)
        // Note: this should be a UUID in your database so
        // you can uniquely identify the message.
        msgCnt += 1;
        return msgCnt;
    }
    
    func receiveReaction(_ messageID: Data?, reactionTo: Data?, nickname: String?, reaction: String?, partnerKey: Data?, senderKey: Data?, dmToken: Int32, codeset: Int, timestamp: Int64, roundId: Int64, status: Int64) -> Int64 {
        msgBuf.append(ReceivedMessage(Msg:  "\(senderKey?.base64EncodedString() ?? "empty pubkey"): \(reaction ?? "empty text")"))
        // Note: this should be a UUID in your database so
        // you can uniquely identify the message.
        msgCnt += 1;
        return msgCnt;
    }
    
    func receiveReply(_ messageID: Data?, reactionTo: Data?, nickname: String?, text: String?, partnerKey: Data?, senderKey: Data?, dmToken: Int32, codeset: Int, timestamp: Int64, roundId: Int64, status: Int64) -> Int64 {
        print("[DMReceiver.receiveReply] Raw: \(text?.prefix(50) ?? "")...")
        let decodedText = decodeMessage(text ?? "") ?? "empty text"
        print("[DMReceiver.receiveReply] Decoded: \(decodedText)")
        msgBuf.append(ReceivedMessage(Msg: "\(senderKey?.base64EncodedString() ?? "empty pubkey"): \(decodedText)"))
        persistIncoming(message: decodedText, codename: nickname, partnerKey: partnerKey, dmToken: dmToken)
        msgCnt += 1;
        return msgCnt;
    }
    
    func receiveText(_ messageID: Data?, nickname: String?, text: String?, partnerKey: Data?, senderKey: Data?, dmToken: Int32, codeset: Int, timestamp: Int64, roundId: Int64, status: Int64) -> Int64 {
        print("[DMReceiver.receiveText] Raw: \(text?.prefix(50) ?? "")...")
        let decodedText = decodeMessage(text ?? "") ?? "empty text"
        print("[DMReceiver.receiveText] Decoded: \(decodedText)")
        msgBuf.append(ReceivedMessage(Msg: "\(senderKey?.base64EncodedString() ?? "empty pubkey"): \(decodedText)"))
        persistIncoming(message: decodedText, codename: nickname, partnerKey: partnerKey, dmToken: dmToken)
        msgCnt += 1;
        return msgCnt;
    }
    
    func updateSentStatus(_ uuid: Int64, messageID: Data?, timestamp: Int64, roundID: Int64, status: Int64) {
        msgBuf.append(ReceivedMessage(Msg: "Message sent status update: \(uuid) -> \(status), \(roundID)"))
    }
    
    // MARK: - Persistence Helpers
    private func persistIncomingIfPossible(message: String, codename: String?) {
        guard let ctx = modelContext else { return }
        let name = (codename?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Unknown"
        Task { @MainActor in
            do {
                let chat = try fetchOrCreateDMChat(codename: name, ctx: ctx, pubKey: nil, dmToken: nil)
                print("DMReceiver: ChatMessage(message: \"\(message)\", isIncoming: true, chat: \(chat.id))")
                let msg = ChatMessage(message: message, isIncoming: true, chat: chat)
                chat.messages.append(msg)
                try ctx.save()
            } catch {
                print("DMReceiver: Failed to save incoming message for \(name): \(error)")
            }
        }
    }

    private func persistIncoming(message: String, codename: String?, partnerKey: Data?, dmToken: Int32) {
        guard let ctx = modelContext else { return }
        let name = (codename?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Unknown"
        Task { @MainActor in
            do {
                if let partnerKey {
                    let chat = try fetchOrCreateDMChat(codename: name, ctx: ctx, pubKey: partnerKey, dmToken: dmToken)
                    print("DMReceiver: ChatMessage(message: \"\(message)\", isIncoming: true, chat: \(chat.id))")
                    let msg = ChatMessage(message: message, isIncoming: true, chat: chat)
                    chat.messages.append(msg)
                    try ctx.save()
                } else {
                    // Fallback if no partner key available
                    persistIncomingIfPossible(message: message, codename: name)
                }
            } catch {
                print("DMReceiver: Failed to save incoming message for \(name): \(error)")
            }
        }
    }

    private func fetchOrCreateDMChat(codename: String, ctx: ModelContext, pubKey: Data?, dmToken: Int32?) throws -> Chat {
        if let pubKey {
            let pubKeyB64 = pubKey.base64EncodedString()
            let byKey = FetchDescriptor<Chat>(predicate: #Predicate { $0.id == pubKeyB64 })
            if let existingByKey = try ctx.fetch(byKey).first {
                return existingByKey
            } else {
                guard let dmToken else { throw MyError.runtimeError("dmToken is required to create chat with pubKey") }
                let newChat = Chat(pubKey: pubKey, name: codename, dmToken: dmToken)
                ctx.insert(newChat)
                try ctx.save()
                return newChat
            }
        } else {
            // Fallback to codename-based lookup (may collide)
            let byName = FetchDescriptor<Chat>(predicate: #Predicate { $0.name == codename })
            if let existingByName = try ctx.fetch(byName).first {
                return existingByName
            } else {
                throw MyError.runtimeError("pubkey is required to create chat")
            }
        }
    }
    
}
