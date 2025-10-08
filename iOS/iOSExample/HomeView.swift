import SwiftUI
import SwiftData

struct HomeView<T:XXDKP>: View {
    @State private var showingSheet = false
    @Query private var chats: [Chat]
    @EnvironmentObject var xxdk: T
    @State private var didStartLoad = false
    @Environment(\.modelContext) private var modelContext
    
    var width: CGFloat
    
    var body: some View {
        List {
            ForEach(chats) { chat in
                NavigationLink(value: Destination.chat(chatId: chat.id, chatTitle: chat.name)) {
                    VStack(alignment: .leading) {
                        Text(chat.name).foregroundStyle(.primary)
                        Text("No messages yet").foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .tint(.gray.opacity(0.3))
        .toolbar {
            Button {
                showingSheet.toggle()
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingSheet) {
            NewChatView<T>()
        }
    }
}

struct NewChatView<T:XXDKP>: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var xxdk: T
    @State private var inviteLink: String = ""
    @State private var channelData: ChannelJSON?
    @State private var errorMessage: String?
    @State private var isJoining: Bool = false
    
    var body: some View {
        VStack {
            Form {
                Text("Enter invite link")
                TextField("haven", text: $inviteLink)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .toolbar(content: {
                Button(action: { dismiss() }, label: {Image(systemName: "xmark")})
            })
     
            Button(action: {
                let trimmed = inviteLink.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                
                do {
                    print("getting channel from url")
                    let channel = try xxdk.getChannelFromURL(url: trimmed)
                    print("channel data \(channel)")
                    channelData = channel
                    errorMessage = nil
                } catch {
                    errorMessage = "Failed to get channel: \(error.localizedDescription)"
                }
            }, label: {
                Text("Start Conversation")
            })
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .sheet(item: $channelData) { channel in
            ChannelConfirmationView(
                channelName: channel.name,
                channelURL: inviteLink,
                isJoining: $isJoining,
                onConfirm: {
                    Task {
                        await joinChannel(url: inviteLink, channelData: channel)
                    }
                }
            )
        }
    }
    
    private func joinChannel(url: String, channelData: ChannelJSON) async {
        isJoining = true
        errorMessage = nil
        
        do {
            print("Joining channel: \(channelData.name)")
            let joinedChannel = try await xxdk.joinChannelFromURL(url)
            print("Successfully joined channel: \(joinedChannel)")
            
            // Create and save the chat to the database
            guard let channelId = joinedChannel.channelId else {
                throw MyError.runtimeError("Channel ID is missing")
            }
            
            let newChat = Chat(channelId: channelId, name: joinedChannel.name)
            modelContext.insert(newChat)
            try modelContext.save()
            
            print("Chat saved to database: \(newChat.name)")
            
            // Dismiss both sheets
            self.channelData = nil
            dismiss()
        } catch {
            print("Failed to join channel: \(error)")
            errorMessage = "Failed to join channel: \(error.localizedDescription)"
            self.channelData = nil
        }
        
        isJoining = false
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Chat.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    ["Tom", "Mayur", "Shashank"].forEach { name in
        container.mainContext.insert(Chat(pubKey: Data(), name: name, dmToken: 0))
    }
    return NavigationStack {
        HomeView<XXDKMock>(width: UIScreen.w(100))
            .modelContainer(container)
            .environmentObject(XXDKMock())
    }
    
}

