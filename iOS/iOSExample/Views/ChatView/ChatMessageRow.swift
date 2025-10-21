//
//  ChatMessageRow.swift
//  iOSExample
//
//  Created by Om More on 28/09/25.
//
import SwiftData
import SwiftUI
struct ChatMessageRow: View {
    let result: ChatMessage
    var onReply: ((ChatMessage) -> Void)?
    var onDM: ((String, Int32, Data, Int) -> Void)?
    @Query private var chatReactions: [MessageReaction]
    @Query private var repliedTo: [ChatMessage]
    @Query private var messageSender: [Sender]
    init(result: ChatMessage, onReply: ((ChatMessage) -> Void)? = nil, onDM: ((String, Int32, Data, Int) -> Void)?) {
        self.result = result
        self.onReply = onReply
        let messageId = result.id
        let replyTo = result.replyTo
        let senderId = result.sender?.id
        _chatReactions = Query(filter: #Predicate<MessageReaction> { r in
            r.targetMessageId == messageId
        })
        self.onDM = onDM
        _repliedTo = Query(filter: #Predicate<ChatMessage> { r in
            if (replyTo != nil) { r.id == replyTo! } else { false }
        })
        _messageSender = Query(filter: #Predicate<Sender> { s in
            if (senderId != nil) { s.id == senderId! } else { false }
        })
    }
    var body: some View {
        HStack(spacing: 0) {
            VStack(
                alignment: result.isIncoming ? .leading : .trailing,
                spacing: 0
            ) {
                MessageItem(
                    text: result.message,
                    isIncoming: result.isIncoming,
                    repliedTo: repliedTo.first?.message,
                    sender: messageSender.first,
                    onReply: {
                        onReply?(result)
                    },
                    onDM: onDM,
                    timestamp: result.timestamp
                )
                Reactions(reactions: chatReactions)
            }
            if result.isIncoming {  // incoming aligns left
                Spacer()
            }
        }
        .id(result.id)
    }
}

