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
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

 
    @EnvironmentObject private var swiftDataActor: SwiftDataActor
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
    @State private var navigateToDMChat: Chat? = nil
    @EnvironmentObject var xxdk: T
    func createDMChatAndNavigate(codename: String, dmToken: Int32, pubKey: Data)
    {
        // Create a new DM chat
        let dmChat = Chat(pubKey: pubKey, name: codename, dmToken: dmToken)

        do {
            swiftDataActor.insert(dmChat)
            try swiftDataActor.save()

            // Navigate to the new chat using the created chat object
            navigateToDMChat = dmChat
        } catch {
            print("Failed to create DM chat: \(error)")
        }
    }
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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    EmptyView().navigationBarBackButtonHidden(true)
                        .navigationBarItems(leading: Button(action: {
                            self.presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "chevron.left").aspectRatio(contentMode: .fit)
                                    Text("Back")
                                }
                            })
                    ForEach(messages, id: \.id) { result in
                        ChatMessageRow(
                            result: result,
                            onReply: { message in
                                replyingTo = message
                            },
                            onDM: { codename, dmToken, pubKey in
                                createDMChatAndNavigate(
                                    codename: codename,
                                    dmToken: dmToken,
                                    pubKey: pubKey
                                )
                            }
                        )
                        if result == messages.last {
                            HStack {}.padding(.vertical, 20)
                        }
                    }
                    Spacer()
                }.padding().scrollTargetLayout()
            }.defaultScrollAnchor(.bottom)
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
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showChannelOptions) {
            ChannelOptionsView<T>(chat: chat) {
                Task {
                    do {
                        try xxdk.leaveChannel(channelId: chatId)
                        await MainActor.run {
                            if let chat = chat {
                                swiftDataActor.delete(chat)
                                do {
                                    try swiftDataActor.save()
                                } catch {
                                    print(
                                        "Failed to save context after deleting chat: \(error)"
                                    )
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
        .navigationDestination(item: $navigateToDMChat) { dmChat in
            ChatView<XXDK>(
                width: width,
                chatId: dmChat.id,
                chatTitle: dmChat.name
            )
        }
        
        
        .background(Color.appBackground)

 
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
        .environmentObject(SwiftDataActor(previewModelContainer: container))
        .environmentObject(XXDKMock())
    }
}
