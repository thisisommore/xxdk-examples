//
//  MessageForm.swift
//  iOSExample
//
//  Created by Om More on 28/09/25.
//
import SwiftData
import SwiftUI

extension View {
    @ViewBuilder
    func glassEffectIfAvailable() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: .rect(cornerRadius: 0))
        } else {
            self
        }
    }
}

struct MessageForm<T: XXDKP>: View {
    @State private var abc: String = ""
    var chat: Chat?
    var replyTo: ChatMessage?
    var onCancelReply: (() -> Void)?
    @EnvironmentObject private var xxdk: T
    @State private var showSendButton: Bool = false
    @Namespace private var namespace

    var body: some View {
        VStack(spacing: 0) {
            // Reply preview
            if let replyTo = replyTo {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Replying to \(replyTo.sender?.codename ?? "You")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HTMLText(
                            replyTo.message,
                            textColor: .black,
                            linkColor: .blue
                        )
                        .lineLimit(2)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        onCancelReply?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
            }
            
            // Message input with liquid glass effect
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 0) {
                    HStack(spacing: 0) {
                        TextField(
                            "",
                            text: $abc,
                            prompt: Text("Message").foregroundStyle(Color.placeHolder)
                        )
                        .onSubmit {
                            sendMessage()
                        }
                        .onChange(of: abc, {
                            withAnimation {
                                showSendButton = !abc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            }
                        })
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(.LG)
                        .clipShape(RoundedRectangle(cornerRadius: 40))
                        .glassEffect(in: RoundedRectangle(cornerRadius: 40))
                        .glassEffectID("messageinput", in: namespace)
                        
                        if showSendButton {
                            Button(action: sendMessage) {
                                Image(systemName: "chevron.right")
                                    .frame(width: 20, height: 20)
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.circle)
                            .glassEffect(in: .circle)
                            .glassEffectID("send", in: namespace)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom,4)
                    .animation(.spring(duration: 0.1), value: abc.isEmpty)
                }
                .padding(.top, 10)
                .background(.regularMaterial)
            } else {
                // Fallback for iOS < 26
                HStack(spacing: 0) {
                    TextField(
                        "",
                        text: $abc,
                        prompt: Text("Message").foregroundStyle(Color.placeHolder)
                    )
                    .onSubmit {
                        sendMessage()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(.LG)
                    .clipShape(RoundedRectangle(cornerRadius: 40))
                    
                    if !abc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(action: sendMessage) {
                            Image(systemName: "chevron.right")
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal, 6)
                        .buttonBorderShape(.circle)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 40)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: abc.isEmpty)
            }
                
        }
    }
    
    private func sendMessage() {
        let trimmed = abc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if let chat = chat {
            if let token = chat.dmToken {
                // DM chat: send direct message or reply
                if let pubKey = Data(base64Encoded: chat.id) {
                    if let replyTo = replyTo {
                        xxdk.sendReply(
                            msg: trimmed,
                            toPubKey: pubKey,
                            partnerToken: token,
                            replyToMessageIdB64: replyTo.id
                        )
                    } else {
                        xxdk.sendDM(
                            msg: trimmed,
                            toPubKey: pubKey,
                            partnerToken: token
                        )
                    }
                }
            } else {
                // Channel chat: send via Channels Manager using channelId (stored in id)
                if let replyTo = replyTo {
                    xxdk.sendReply(
                        msg: trimmed,
                        channelId: chat.id,
                        replyToMessageIdB64: replyTo.id
                    )
                } else {
                    xxdk.sendDM(
                        msg: trimmed,
                        channelId: chat.id
                    )
                }
            }
        }
        
        abc = ""
        onCancelReply?()
    }
}

#Preview {
    // In-memory SwiftData container for previewing MessageForm
    let container = try! ModelContainer(
        for: Chat.self,
        ChatMessage.self,
        MessageReaction.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    // Create a simple preview chat
    let previewChat = Chat(channelId: "previewChannelId", name: "Preview Chat")
    container.mainContext.insert(previewChat)

    return VStack {
        Spacer()
        MessageForm<XXDKMock>(
            chat: previewChat,
            replyTo: nil,
            onCancelReply: {}
        )
        .modelContainer(container)
        .environmentObject(XXDKMock())
    }
}

#Preview("Reply Mode") {
    // In-memory SwiftData container for previewing MessageForm with reply
    let container = try! ModelContainer(
        for: Chat.self,
        ChatMessage.self,
        MessageReaction.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    // Create a simple preview chat
    let previewChat = Chat(channelId: "previewChannelId", name: "Preview Chat")
    container.mainContext.insert(previewChat)
    
    // Create a message to reply to
    let messageToReplyTo = ChatMessage(
        message: "<p>Hey! Can you check out this <a href=\"https://example.com\">link</a>? It has some really interesting information about the project we discussed yesterday.</p>",
        isIncoming: true,
        chat: previewChat,
        sender: Sender(id: "alice-id", pubkey: Data(), codename: "Alice", dmToken: 0, color: greenColorInt),
        id: "msg-123"
    )
    container.mainContext.insert(messageToReplyTo)

    return VStack {
        Spacer()
        MessageForm<XXDKMock>(
            chat: previewChat,
            replyTo: messageToReplyTo,
            onCancelReply: {
                print("Cancel reply tapped")
            }
        )
        .modelContainer(container)
        .environmentObject(XXDKMock())
    }
}
