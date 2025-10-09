//
//  ChatView.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import SwiftData
import SwiftUI

struct ChatView<T: XXDKP>: View {
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
    @State private var showChannelOptions: Bool = false
    @EnvironmentObject var xxdk: T

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
            }
            .navigationTitle(chatTitle)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button {
                        showChannelOptions = true
                    } label: {
                        Text(chatTitle)
                            .font(.headline)
                    }
                }
            }
            .sheet(isPresented: $showChannelOptions) {
                ChannelOptionsView<T>(chat: chat) {
                    Task {
                        do {
                            try xxdk.leaveChannel(channelId: chatId)
                            await MainActor.run {
                                if let chat = chat {
                                    modelContext.delete(chat)
                                    do {
                                        try modelContext.save()
                                    } catch {
                                        print("Failed to save context after deleting chat: \(error)")
                                    }
                                }
                                dismiss()
                            }
                        } catch {
                            print("Failed to leave channel: \(error)")
                        }
                    }
                }
                .environmentObject(xxdk)
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
  
    return NavigationStack {
        ChatView<XXDKMock>(
        width: UIScreen.w(100),
        chatId: chat.id,
        chatTitle: chat.name
    )
    .modelContainer(container)
    .environmentObject(XXDKMock())}
}
