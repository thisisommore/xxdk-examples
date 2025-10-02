//
//  ChatView.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ChatView : View {
    let width: CGFloat;
    let chatId: String
    let chatTitle: String
    
    @Environment(\.modelContext) private var modelContext
    @Query private var chatResults: [Chat]
    
    private var chat: Chat? { chatResults.first }
    private var messages: [ChatMessage] {
        guard let chat else { return [] }
        // Sort by timestamp ascending
        return chat.messages.sorted { $0.timestamp > $1.timestamp }
    }
    
    // Strips a single surrounding <p>...</p> pair if present (after trimming whitespace)
    private func stripParagraphTags(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<p>") && trimmed.hasSuffix("</p>") {
            let inner = trimmed.dropFirst(3).dropLast(4)
            return String(inner)
        }
        return s
    }
    
    @EnvironmentObject var xxdkServ: XXDKService
    @Environment(\.dismiss) private var dismiss
    @State var abc: String = ""
    
    init(width: CGFloat, chatId: String, chatTitle: String) {
        self.width = width
        self.chatId = chatId
        self.chatTitle = chatTitle
        _chatResults = Query(filter: #Predicate<Chat> { chat in
            chat.id == chatId
        })
    }
    
    var body : some View {
        NavigationStack{
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(messages, id: \.id) { result in
                            HStack {
                                if !result.isIncoming { // outgoing from current user
                                    Spacer()
                                }
                                VStack(alignment: result.isIncoming ? .leading : .trailing, spacing: 2) {
                                    if let senderName = result.sender, !senderName.isEmpty, result.isIncoming {
                                        Text(senderName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    if !result.isIncoming {
                                        Text("You")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(stripParagraphTags(result.message))
                                        .padding(.horizontal,12)
                                        .padding(.vertical,5)
                                        .background(result.isIncoming ? Color.blue : Color.gray)
                                        .foregroundStyle(.white)
                                        .cornerRadius(10)
                                        .contextMenu(menuItems: {
                                            Button{
                                                UIPasteboard.general.setValue(stripParagraphTags(result.message),
                                                           forPasteboardType: UTType.plainText.identifier)
                                            } label: {
                                                Text("Copy")
                                            }
                                        })
                                    if !result.reactions.isEmpty {
                                        HStack(spacing: 4) {
                                            ForEach(Array(result.reactions.prefix(2)), id: \.self) { emoji in
                                                Text(emoji)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(.ultraThinMaterial)
                                                    .clipShape(Capsule())
                                            }
                                            if result.reactions.count > 2 {
                                                Text("+\(result.reactions.count - 2)")
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(.ultraThinMaterial)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                                if result.isIncoming { // incoming aligns left
                                    Spacer()
                                }
                            }
                        }
                        Spacer()
                    }.padding()
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onAppear {
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
           
            .navigationTitle(chatTitle)
            HStack {
                TextField("", text: $abc,
                          prompt: Text("Message").bold().foregroundStyle(.white)
                )
                .onSubmit {
                    let trimmed = abc.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    if let chat = chat {
                        let msg = ChatMessage(message: trimmed, isIncoming: false, chat: chat)
                        chat.messages.append(msg)
                        do { try modelContext.save() } catch { print("ChatView: Failed to save outgoing message: \(" + String(describing: error) + ")") }
                    }
                    if let chat = chat {
                        if let token = chat.dmToken {
                            // DM chat: send direct message
                            if let pubKey = Data(base64Encoded: chat.id) {
                                xxdkServ.xxdk.sendDM(msg: trimmed, toPubKey: pubKey, partnerToken: token)
                            }
                        } else {
                            // Channel chat: send via Channels Manager using channelId (stored in id)
                            xxdkServ.xxdk.sendDM(msg: trimmed, channelId: chat.id)
                        }
                    }
                    abc = ""
                }
                .padding(.vertical,8).padding(.horizontal,14)
                .background(Color(red: 110/255, green: 110/255, blue: 110/255))
                .clipShape(RoundedRectangle(cornerRadius: 40))
                Spacer()
                Button(action: {
                    let trimmed = abc.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    if xxdkServ.xxdk.cmix?.readyToSend() == true {
                        if let chat = chat {
                            let msg = ChatMessage(message: trimmed, isIncoming: false, chat: chat)
                            chat.messages.append(msg)
                            do { try modelContext.save() } catch { print("ChatView: Failed to save outgoing message: \(" + String(describing: error) + ")") }
                        }
                        if let chat = chat {
                            if let token = chat.dmToken {
                                if let pubKey = Data(base64Encoded: chat.id) {
                                    xxdkServ.xxdk.sendDM(msg: trimmed, toPubKey: pubKey, partnerToken: token)
                                }
                            } else {
                                xxdkServ.xxdk.sendDM(msg: trimmed, channelId: chat.id)
                            }
                        }
                        abc = ""
                    }
                }, label: {
                    Image(systemName: "paperplane")
                })
                .buttonStyle(.borderedProminent)
            }.padding().background(.ultraThinMaterial)
            
        }
        
    }
}

#Preview {
    // In-memory SwiftData container for previewing ChatView with mock data
    let container = try! ModelContainer(
        for: Chat.self, ChatMessage.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    // Create a mock chat and some messages
    let previewChatId = "previewChatId"
    let chat = Chat(channelId: previewChatId, name: "Mayur")

    let mockSender = Sender(id: "mock-sender-id", pubkey: Data(), codename: "Mayur")
    var msgs = [
        ChatMessage(message: "All good! Working on the demo.", isIncoming: true, chat: chat, sender: mockSender),
        ChatMessage(message: "How's it going?", isIncoming: false, chat: chat),
        ChatMessage(message: "Hi there 👋", isIncoming: true, chat: chat, sender: mockSender),
        ChatMessage(message: "Hey Mayur!", isIncoming: false, chat: chat),
        ChatMessage(message: "All good! Working on the demo.", isIncoming: true, chat: chat, sender: mockSender),
        ChatMessage(message: "How's it going?", isIncoming: false, chat: chat),
        ChatMessage(message: "Hi there 👋", isIncoming: true, chat: chat, sender: mockSender),
        ChatMessage(message: "Hey Mayur!", isIncoming: false, chat: chat),
        ChatMessage(message: "All good! Working on the demo.", isIncoming: true, chat: chat, sender: mockSender),
        ChatMessage(message: "How's it going?", isIncoming: false, chat: chat),
        ChatMessage(message: "Hi there 👋", isIncoming: true, chat: chat, sender: mockSender),
        ChatMessage(message: "Hey Mayur!", isIncoming: false, chat: chat),
        ChatMessage(message: "All good! Working on the demo.", isIncoming: true, chat: chat, sender: mockSender),
        ChatMessage(message: "How's it going?", isIncoming: false, chat: chat),
        ChatMessage(message: "Hi there 👋", isIncoming: true, chat: chat, sender: mockSender),
        ChatMessage(message: "Hey Mayur!", isIncoming: false, chat: chat),
        ChatMessage(message: "All good! Working on the demo.", isIncoming: true, chat: chat, sender: mockSender),
        ChatMessage(message: "How's it going?", isIncoming: false, chat: chat),
        ChatMessage(message: "Hi there 👋", isIncoming: true, chat: chat, sender: mockSender),
        ChatMessage(message: "<p>Hey Mayur!</p>", isIncoming: false, chat: chat)
    ]
    
    // Add sample reactions to preview messages
    msgs[1].addReaction("👍")
    msgs[1].addReaction("❤️")
    msgs[3].addReaction("😂")
    msgs[3].addReaction("🔥")
    msgs[5].addReaction("👍")
    msgs[5].addReaction("😂")
    msgs[5].addReaction("😂")
    msgs[10].addReaction("👀")
    msgs.forEach { container.mainContext.insert($0) }

    // Return the view wired up with our model container and mock XXDK service
    return ChatView(width: UIScreen.w(100), chatId: chat.id, chatTitle: chat.name)
        .modelContainer(container)
        .environmentObject(XXDKService(XXDKMock()))
}

