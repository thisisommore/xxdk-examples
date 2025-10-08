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
    @State private var showPasswordSheet: Bool = false
    @State private var isPrivateChannel: Bool = false
    @State private var prettyPrint: String?
    
    var body: some View {
        NavigationView {
            VStack {
                Form {
                Section(header: Text("Enter invite link")) {
                    TextEditor(text: $inviteLink)
                        .frame(minHeight: 100, maxHeight: 450)
                        .font(.body)
                }
                    
                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                .toolbar(content: {
                    Button(action: { dismiss() }, label: {Image(systemName: "xmark")})
                })
     
            Button(action: {
                let trimmed = inviteLink.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                
                do {
                    // Check privacy level first
                    let privacyLevel = try xxdk.getChannelPrivacyLevel(url: trimmed)
                    
                    if privacyLevel == .secret {
                        // Private channel - show password input
                        isPrivateChannel = true
                        showPasswordSheet = true
                        errorMessage = nil
                    } else {
                        // Public channel - proceed directly
                        print("getting channel from url")
                        let channel = try xxdk.getChannelFromURL(url: trimmed)
                        print("channel data \(channel)")
                        channelData = channel
                        errorMessage = nil
                    }
                } catch {
                    errorMessage = "Failed to get channel: \(error.localizedDescription)"
                }
            }, label: {
                Text("Start Conversation")
                    .frame(maxWidth: .infinity)
            })
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }
        .sheet(isPresented: $showPasswordSheet) {
            PasswordInputView(
                url: inviteLink,
                onConfirm: { password in
                    do {
                        let pp = try xxdk.decodePrivateURL(url: inviteLink, password: password)
                        prettyPrint = pp
                        let channel = try xxdk.getPrivateChannelFromURL(url: inviteLink, password: password)
                        channelData = channel
                        showPasswordSheet = false
                        errorMessage = nil
                    } catch {
                        errorMessage = "Failed to decrypt channel: \(error.localizedDescription)"
                        showPasswordSheet = false
                    }
                },
                onCancel: {
                    showPasswordSheet = false
                }
            )
        }
        .sheet(item: $channelData) { channel in
            ChannelConfirmationView(
                channelName: channel.name,
                channelURL: inviteLink,
                isJoining: $isJoining,
                onConfirm: { enableDM in
                    Task {
                        await joinChannel(url: inviteLink, channelData: channel, enableDM: enableDM)
                    }
                }
            )
        }
            .navigationTitle("Join Channel")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func joinChannel(url: String, channelData: ChannelJSON, enableDM: Bool) async {
        isJoining = true
        errorMessage = nil
        
        do {
            print("Joining channel: \(channelData.name)")
            
            let joinedChannel: ChannelJSON
            // Use prettyPrint if available (private channel), otherwise decode from URL (public channel)
            if let pp = prettyPrint {
                joinedChannel = try await xxdk.joinChannel(pp)
            } else {
                joinedChannel = try await xxdk.joinChannelFromURL(url)
            }
            
            print("Successfully joined channel: \(joinedChannel)")
            
            // Create and save the chat to the database
            guard let channelId = joinedChannel.channelId else {
                throw MyError.runtimeError("Channel ID is missing")
            }
            
            // Enable or disable direct messages based on toggle
            if enableDM {
                print("Enabling direct messages for channel: \(channelId)")
                try xxdk.enableDirectMessages(channelId: channelId)
            } else {
                print("Disabling direct messages for channel: \(channelId)")
                try xxdk.disableDirectMessages(channelId: channelId)
            }
            
            let newChat = Chat(channelId: channelId, name: joinedChannel.name)
            modelContext.insert(newChat)
            try modelContext.save()
            
            print("Chat saved to database: \(newChat.name)")
            
            // Dismiss both sheets and reset state
            self.channelData = nil
            self.prettyPrint = nil
            dismiss()
        } catch {
            print("Failed to join channel: \(error)")
            errorMessage = "Failed to join channel: \(error.localizedDescription)"
            self.channelData = nil
            self.prettyPrint = nil
        }
        
        isJoining = false
    }
}

struct PasswordInputView: View {
    let url: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void
    
    @State private var password: String = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Private Channel")) {
                    Text("This channel is password protected. Enter the password to continue.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Password")) {
                    SecureField("Enter password", text: $password)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("Enter Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        onConfirm(password)
                        dismiss()
                    }
                    .disabled(password.isEmpty)
                }
            }
        }
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

