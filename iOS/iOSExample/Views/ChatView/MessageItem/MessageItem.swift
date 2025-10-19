import SwiftUI

struct MessageItem: View {
    let text: String
    let isIncoming: Bool
    let repliedTo: String?
    let sender: Sender?
    let timeStamp: Date = Date()

    var onReply: (() -> Void)?
    var onDM: ((String, Int32, Data) -> Void)?

    @State private var isEmojiSheetPresented = false
    @State private var shouldTriggerReply = false
    @State private var selectedEmoji: MessageEmoji = .none

    var body: some View {

        HStack(spacing: 2) {
            ConditionalSpacer(!isIncoming)
            VStack {
                if let repliedTo {
                    HStack {
                        ConditionalSpacer(!isIncoming)
                        MessageReplyPreview(
                            text: repliedTo,
                            isIncoming: isIncoming
                        )
                        ConditionalSpacer(isIncoming)
                    }
                }

                HStack {
                    ConditionalSpacer(!isIncoming)
                    MessageBubble(
                        text: text,
                        isIncoming: isIncoming,
                        sender: sender,
                        selectedEmoji: $selectedEmoji,
                        shouldTriggerReply: $shouldTriggerReply,
                        onDM: onDM
                    )
                    ConditionalSpacer(isIncoming)
                }
              
            }
            ConditionalSpacer(isIncoming)

        }

        .sheet(isPresented: $isEmojiSheetPresented) {
            EmojiKeyboard { emoji in
                // Handle emoji selection
                isEmojiSheetPresented = false
            }
        }
        .onChange(of: selectedEmoji) { _, newValue in
            if newValue == .custom {
                DispatchQueue.main.async {
                    isEmojiSheetPresented = true
                }
                selectedEmoji = .none
            }
        }
        .onChange(of: shouldTriggerReply) { _, newValue in
            if newValue {
                onReply?()
                shouldTriggerReply = false
            }
        }
    }
}
#Preview {
    ScrollView {
        VStack(spacing: 2) {
            // Incoming message with reply
            MessageItem(
                text: "<p>Yup here you go</p>",
                isIncoming: true,
                repliedTo:
                    "Wow lets go Wow lets go Wow lets go Wow lets go Wow lets go",
                sender: Sender(
                    id: "1",
                    pubkey: Data(),
                    codename: "Mayur",
                    dmToken: 123,
                    color: 0x4CAF50
                ),
                onReply: {
                    print("Reply tapped")
                },
                onDM: { name, token, pubkey in
                    print("DM to \(name)")
                }
            )

            // Incoming message with link
            MessageItem(
                text: """
                    <a href="https://www.example.com" rel="noopener noreferrer" target="_blank">
                    Check out this link!
                    </a>
                    """,
                isIncoming: true,
                repliedTo: nil,
                sender: Sender(
                    id: "2",
                    pubkey: Data(),
                    codename: "Alex",
                    dmToken: 456,
                    color: 0x2196F3
                )
            )

            // Outgoing message with reply
            MessageItem(
                text: "Thanks for sharing!",
                isIncoming: false,
                repliedTo: """
                    <a href="https://www.example.com" rel="noopener noreferrer" target="_blank">
                    Check out this link!
                    </a>
                    """,
                sender: nil,
                onReply: {
                    print("Reply tapped")
                }
            )

            // Simple incoming message
            MessageItem(
                text: "Hello there 👋",
                isIncoming: true,
                repliedTo: nil,
                sender: Sender(
                    id: "3",
                    pubkey: Data(),
                    codename: "Sarah",
                    dmToken: 0,
                    color: 0xFF9800
                )
            )

            // Simple outgoing message
            MessageItem(
                text: "Hi! How are you doing?",
                isIncoming: false,
                repliedTo: nil,
                sender: nil
            )

            // Long incoming message
            MessageItem(
                text:
                    "This is a much longer message to test how the bubble handles multiple lines of text. It should wrap nicely and maintain proper styling throughout.",
                isIncoming: true,
                repliedTo: nil,
                sender: Sender(
                    id: "1",
                    pubkey: Data(),
                    codename: "Mayur",
                    dmToken: 123,
                    color: 0xcef8c5
                )
            )
        }
        .padding()
    }
}
