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
            NewChatView()
        }
    }
}

struct NewChatView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @State private var inviteLink: String = ""
    
    var body: some View {
            Form {
                Text("Enter invite link")
                TextField("Enter codename", text: $inviteLink)
            }
            .toolbar(content: {
                Button(action: {}, label: {Image(systemName: "xmark")})
            })
     
            
            Button(action: {
                let trimmed = inviteLink.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
//                let chat = Chat(codename: trimmed)
//                modelContext.insert(chat)
                dismiss()
            }, label: {
                Text("Start Conversation")
            })
            .buttonStyle(.borderedProminent)
            .padding()
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
    return HomeView<XXDKMock>(width: UIScreen.w(100))
        .modelContainer(container)
        .environmentObject(XXDKMock())
}

