import SwiftUI
import SwiftData

struct ChatRowView: View {
    let chat: Chat

    var body: some View {
        HStack {
            if chat.name == "<self>" {
                Image(systemName: "bookmark.circle.fill").font(.system(size: 40)).foregroundStyle(.orange).symbolRenderingMode(.hierarchical)
            }
            
            VStack(alignment: .leading) {
                Text(chat.name == "<self>" ? "Notes" : chat.name).foregroundStyle(.primary)

                if let lastMessage = chat.messages.sorted(by: { $0.timestamp < $1.timestamp }).last {
                    let senderName =
                        lastMessage.isIncoming ? (lastMessage.sender?.codename ?? "unknown") : "you"

                    VStack(alignment: .leading) {
                        Text(senderName)
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                         HTMLText(lastMessage.message,
                                  textColor: .messageText,
                                  customFontSize: 12,
                                  lineLimit: 1)
                    }
                } else {
                    Text("No messages yet")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
