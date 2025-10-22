//
//  MessageBubble.swift
//  iOSExample
//
//  Created by Om More on 19/10/25.
//

import SwiftUI
import UniformTypeIdentifiers

/// The main message bubble containing text and context menu
struct MessageBubble: View {
    let text: String
    let isIncoming: Bool
    let sender: Sender?
    let timestamp: String
    @Binding var selectedEmoji: MessageEmoji
    @Binding var shouldTriggerReply: Bool

    var onDM: ((String, Int32, Data, Int) -> Void)?

    var body: some View {
        VStack(alignment: isIncoming ? .leading : .trailing, spacing: 4) {
            if isIncoming {
                MessageSender(
                    isIncoming: isIncoming,
                    sender: sender
                )
            }

            HStack {

                HTMLText(
                    text,
                    textColor: isIncoming ? Color.messageText : Color.white,
                    linkColor: isIncoming ? Color.messageText : Color.white
                )

            }
            VStack(alignment: .trailing) {
                Text(timestamp).font(.system(size: 10)).foregroundStyle(
                    isIncoming ? Color.messageText : Color.white
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(isIncoming ? Color.messageBubble : Color.haven)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 10,
                bottomLeadingRadius: isIncoming ? 0 : 10,
                bottomTrailingRadius: isIncoming ? 10 : 0,
                topTrailingRadius: 10
            )
        ).contextMenu {
            MessageContextMenu(
                text: text,
                isIncoming: isIncoming,
                sender: sender,
                selectedEmoji: $selectedEmoji,
                shouldTriggerReply: $shouldTriggerReply,
                onDM: onDM
            )
        }
        .id(sender)
        .padding(.top, 6)
    }
}
#Preview {
    ScrollView {
        VStack(spacing: 16) {
            // Incoming bubble with sender
            MessageBubble(
                text: "Hey! How's it going? 👋",
                isIncoming: true,
                sender: Sender(
                    id: "1",
                    pubkey: Data(),
                    codename: "Mayur",
                    dmToken: 123,
                    color: 0xcef8c5
                ),
                timestamp: "6:04pm",
                selectedEmoji: .constant(.none),
                shouldTriggerReply: .constant(false),
                onDM: { name, token, pubkey, color in
                    print("DM to \(name)")
                },

            )

            // Outgoing bubble
            MessageBubble(
                text: "I'm doing great, thanks for asking!",
                isIncoming: false,
                sender: nil,
                timestamp: "6:04pm",
                selectedEmoji: .constant(.none),
                shouldTriggerReply: .constant(false)
            )

            // Incoming with link
            MessageBubble(
                text: """
                    <p>Hey <a href="https://www.example.com" rel="noopener noreferrer" target="_blank">Check this out!</a></p>
                    """,
                isIncoming: true,
                sender: Sender(
                    id: "2",
                    pubkey: Data(),
                    codename: "Alex",
                    dmToken: 456,
                    color: 0x2196F3
                ),
                timestamp: "6:04pm",
                selectedEmoji: .constant(.none),
                shouldTriggerReply: .constant(false)
            )

            // Long message incoming
            MessageBubble(
                text:
                    "This is a longer message to demonstrate how the bubble handles multiple lines of text. It should wrap properly and maintain the correct styling throughout the entire message.",
                isIncoming: true,
                sender: Sender(
                    id: "3",
                    pubkey: Data(),
                    codename: "Sarah",
                    dmToken: 0,
                    color: 0xFF9800
                ),
                timestamp: "6:04pm",
                selectedEmoji: .constant(.none),
                shouldTriggerReply: .constant(false)
            )

            // Long message outgoing
            MessageBubble(
                text:
                    "Absolutely! I completely agree with what you're saying. The implementation looks solid and should work well for our use case.",
                isIncoming: false,
                sender: nil,
                timestamp: "6:04pm",
                selectedEmoji: .constant(.none),
                shouldTriggerReply: .constant(false)
            )

            // Short incoming without DM token
            MessageBubble(
                text: "👍",
                isIncoming: true,
                sender: Sender(
                    id: "4",
                    pubkey: Data(),
                    codename: "Guest",
                    dmToken: 0,
                    color: 0x9E9E9E
                ),
                timestamp: "6:04pm",
                selectedEmoji: .constant(.none),
                shouldTriggerReply: .constant(false)
            )
        }
        .padding()
    }
}
