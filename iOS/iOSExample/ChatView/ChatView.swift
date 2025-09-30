//
//  ChatView.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import SwiftData
import SwiftUI

struct ChatView: View {
    let width: CGFloat
    let chatId: String
    let chatTitle: String

    @Environment(\.modelContext) private var modelContext
    @Query private var chatResults: [Chat]

    private var chat: Chat? { chatResults.first }
    private var messages: [ChatMessage] {
        guard let chat else { return [] }
        // Sort by timestamp ascending
        return chat.messages.sorted { $0.timestamp < $1.timestamp }
    }

    @Environment(\.dismiss) private var dismiss
    @State var abc: String = ""
    @State private var replyingTo: ChatMessage? = nil

    init(width: CGFloat, chatId: String, chatTitle: String) {
        self.width = width
        self.chatId = chatId
        self.chatTitle = chatTitle
        _chatResults = Query(
            filter: #Predicate<Chat> { chat in
                chat.id == chatId
            }
        )
    }

    var body: some View {
            ZStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(messages, id: \.id) { result in
                                ChatMessageRow(result: result, onReply: { message in
                                    replyingTo = message
                                })
                                if result == messages.last {
                                    HStack {}.padding(.vertical, 20)
                                }
                            }
                            Spacer()
                        }.padding()
                    }
                    .onChange(of: messages.count) {
                        if let last = messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                VStack {
                    Spacer()
                    MessageForm<XXDK>(
                        chat: chat,
                        replyTo: replyingTo,
                        onCancelReply: {
                            replyingTo = nil
                        }
                    )
                }
                .navigationTitle(chatTitle)
            }


    }
}

#Preview {
    // In-memory SwiftData container for previewing ChatView with mock data
    let container = try! ModelContainer(
        for: Chat.self,
        ChatMessage.self,
        MessageReaction.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    );

    {
        mockMsgs.forEach { container.mainContext.insert($0) }

        reactions.forEach { container.mainContext.insert($0) }
    }()
    // Return the view wired up with our model container and mock XXDK service
    return ChatView(
        width: UIScreen.w(100),
        chatId: chat.id,
        chatTitle: chat.name
    )
    .modelContainer(container)
    .environmentObject(XXDKMock())
}
