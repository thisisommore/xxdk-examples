/*
 Adaptive Chat Interface - Custom Layout (No Sidebar)
 
 Key Features:
 - Two equal panels side-by-side on large screens
 - Single view navigation on small screens
 - No sidebar styling or behavior
 - Remembers which view was active when resizing
 - Custom back navigation for compact mode
 - Smooth transitions between layouts
 
 How it works:
 - Large screens: Shows chat list and detail view as equal panels
 - Small screens: Shows only the active view with navigation
 - When resizing: Preserves the active view state
 - Navigation: Custom implementation without NavigationSplitView
 */

import SwiftUI

// MARK: - Data Models
struct ChatItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let lastMessage: String
    let timestamp: Date
    let isOnline: Bool
    
    static let sampleChats = [
        ChatItem(name: "Om", lastMessage: "Hi there! How are you?", timestamp: Date().addingTimeInterval(-300), isOnline: true),
        ChatItem(name: "Tom", lastMessage: "Let's meet tomorrow", timestamp: Date().addingTimeInterval(-1800), isOnline: false),
        ChatItem(name: "Sam", lastMessage: "Thanks for your help!", timestamp: Date().addingTimeInterval(-3600), isOnline: true)
    ]
}

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp: Date
}

// MARK: - Navigation State Management
@Observable
class ChatNavigationState {
    var selectedChat: ChatItem?
    var isShowingChatDetail: Bool = false
    
    func selectChat(_ chat: ChatItem) {
        selectedChat = chat
        isShowingChatDetail = true
    }
    
    func goBackToList() {
        isShowingChatDetail = false
    }
    
    func clearSelection() {
        selectedChat = nil
        isShowingChatDetail = false
    }
}

// MARK: - Main Chat App
struct ChatApp: View {
    @State private var navigationState = ChatNavigationState()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // Determine if we should show both views side by side
    private var shouldShowSideBySide: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                if shouldShowSideBySide {
                    // Side-by-side layout for large screens
                    HStack(spacing: 0) {
                        // Left panel - Chat List
                        ChatListView()
                            .frame(width: geometry.size.width * 0.4)
                            .background(Color(.systemGroupedBackground))
                        
                        // Divider
                        Divider()
                        
                        // Right panel - Chat Detail
                        ChatDetailView()
                            .frame(width: geometry.size.width * 0.6)
                            .background(Color(.systemBackground))
                    }
                } else {
                    // Single view layout for compact screens
                    if navigationState.isShowingChatDetail {
                        ChatDetailView()
                            .transition(.move(edge: .trailing))
                    } else {
                        ChatListView()
                            .transition(.move(edge: .leading))
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .environment(navigationState)
        .onChange(of: horizontalSizeClass) { _, newValue in
            // Handle size class transitions
            if newValue == .compact && navigationState.selectedChat != nil {
                // When going to compact, show detail if chat is selected
                navigationState.isShowingChatDetail = true
            }
        }
        .animation(.easeInOut(duration: 0.3), value: navigationState.isShowingChatDetail)
        .animation(.easeInOut(duration: 0.3), value: shouldShowSideBySide)
    }
}

// MARK: - Chat List View
struct ChatListView: View {
    @Environment(ChatNavigationState.self) private var navigationState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        VStack {
            // Custom header for side-by-side mode
            if horizontalSizeClass == .regular {
                HStack {
                    Text("Chats")
                        .font(.largeTitle)
                        .bold()
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)
            }
            
            List(ChatItem.sampleChats) { chat in
                Button {
                    withAnimation {
                        navigationState.selectChat(chat)
                    }
                } label: {
                    ChatListRow(chat: chat)
                        .background(
                            // Highlight selected chat in side-by-side mode
                            navigationState.selectedChat?.id == chat.id && horizontalSizeClass == .regular
                            ? Color(.systemGray5)
                            : Color.clear
                        )
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle(horizontalSizeClass == .compact ? "Chats" : "")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ChatListRow: View {
    let chat: ChatItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile picture
            Circle()
                .fill(chat.isOnline ? Color.green : Color.gray)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(chat.name.prefix(1)))
                        .foregroundColor(.white)
                        .font(.headline)
                        .bold()
                )
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(chat.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(chat.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(chat.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Chat Detail View
struct ChatDetailView: View {
    @Environment(ChatNavigationState.self) private var navigationState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var messages: [Message] = []
    @State private var newMessageText: String = ""
    
    var body: some View {
        Group {
            if let chat = navigationState.selectedChat {
                VStack(spacing: 0) {
                    // Custom header for side-by-side mode
                    if horizontalSizeClass == .regular {
                        HStack {
                            Text(chat.name)
                                .font(.headline)
                                .bold()
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .overlay(
                            Divider(),
                            alignment: .bottom
                        )
                    }
                    
                    // Messages area
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 20)
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let lastMessage = messages.last {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Message input
                    VStack {
                        Divider()
                        MessageInputView(
                            messageText: $newMessageText,
                            onSend: sendMessage
                        )
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    .background(Color(.systemBackground))
                }
                .navigationTitle(horizontalSizeClass == .compact ? chat.name : "")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if horizontalSizeClass == .compact {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                withAnimation {
                                    navigationState.goBackToList()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Chats")
                                        .font(.body)
                                }
                            }
                        }
                    }
                }
                .onAppear {
                    loadMessages(for: chat)
                }
                .onChange(of: navigationState.selectedChat?.id) { _, _ in
                    if let chat = navigationState.selectedChat {
                        loadMessages(for: chat)
                    }
                }
            } else {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        Text("No Chat Selected")
                            .font(.title2)
                            .bold()
                        
                        Text("Choose a conversation to start chatting")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
        }
    }
    
    private func loadMessages(for chat: ChatItem) {
        messages = generateSampleMessages(for: chat)
    }
    
    private func sendMessage() {
        guard !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let newMessage = Message(
            content: newMessageText,
            isFromUser: true,
            timestamp: Date()
        )
        
        withAnimation(.easeInOut(duration: 0.3)) {
            messages.append(newMessage)
        }
        newMessageText = ""
        
        // Simulate response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let response = Message(
                content: generateResponse(to: newMessage.content),
                isFromUser: false,
                timestamp: Date()
            )
            withAnimation(.easeInOut(duration: 0.3)) {
                messages.append(response)
            }
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 6) {
                HStack {
                    Text(message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            message.isFromUser
                            ? Color.blue
                            : Color(.systemGray5)
                        )
                        .foregroundColor(
                            message.isFromUser
                            ? .white
                            : .primary
                        )
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 20,
                                bottomLeadingRadius: message.isFromUser ? 20 : 4,
                                bottomTrailingRadius: message.isFromUser ? 4 : 20,
                                topTrailingRadius: 20
                            )
                        )
                }
                
                Text(message.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if !message.isFromUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Message Input View
struct MessageInputView: View {
    @Binding var messageText: String
    let onSend: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                TextField("Message", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($isTextFieldFocused)
                    .lineLimit(1...6)
                    .onSubmit {
                        onSend()
                    }
                
                if !messageText.isEmpty {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .animation(.easeInOut(duration: 0.2), value: messageText.isEmpty)
    }
}

// MARK: - Helper Functions
func generateSampleMessages(for chat: ChatItem) -> [Message] {
    let responses: [String: [String]] = [
        "Om": [
            "Hi there! How are you?",
            "I'm doing great, thanks for asking!",
            "What have you been up to lately?",
            "Want to grab coffee this weekend?"
        ],
        "Tom": [
            "Hey! Let's meet tomorrow",
            "How about 2 PM at the coffee shop?",
            "Perfect, see you there!",
            "Don't forget to bring the documents"
        ],
        "Sam": [
            "Thanks for your help!",
            "I really appreciate it",
            "Let me know if you need anything",
            "The project is going really well"
        ]
    ]
    
    let chatMessages = responses[chat.name] ?? ["Hello!", "How are you?"]
    var messages: [Message] = []
    
    for (index, content) in chatMessages.enumerated() {
        messages.append(Message(
            content: content,
            isFromUser: index % 2 == 1,
            timestamp: Date().addingTimeInterval(TimeInterval(-7200 + index * 900))
        ))
    }
    
    return messages
}

func generateResponse(to message: String) -> String {
    let responses = ["That's interesting!", "I see what you mean.", "Thanks for sharing that."]
    let moreResponses = ["How are you feeling about that?", "That sounds great!", "I understand."]
    let additionalResponses = ["Tell me more about that.", "Really? That's awesome!", "You're absolutely right."]
    
    let allResponses = responses + moreResponses + additionalResponses
    return allResponses.randomElement() ?? "That's cool!"
}

// MARK: - App Entry Point
struct AdaptiveChatView: View {
    var body: some View {
        ChatApp()
    }
}

#Preview {
    AdaptiveChatView()
}
