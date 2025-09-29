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
    
    @Query private var chatReactions: [MessageReaction]
    @Query private var repliedTo: [ChatMessage]
    init(result: ChatMessage) {
        self.result = result
        let messageId = result.id
        let replyTo = result.replyTo
        print("mid \(messageId)")
        _chatReactions = Query(filter: #Predicate<MessageReaction> { r in
            r.messageId == messageId
        })
        
        _repliedTo = Query(filter: #Predicate<ChatMessage> { r in
            if (replyTo != nil) { r.id == replyTo! } else { false }
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
                    sender: result.sender
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

