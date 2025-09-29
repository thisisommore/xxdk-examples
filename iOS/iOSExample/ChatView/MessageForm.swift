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
struct MessageForm: View {
    @State private var abc: String = ""
    var chat: Chat?
    @EnvironmentObject private var xxdkServ: XXDKService
    var body: some View {
        HStack(spacing: 0) {
            TextField(
                "",
                text: $abc,
                prompt: Text("Message").foregroundStyle(Color.placeHolder)
            )
            .onSubmit {
                let trimmed = abc.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                guard !trimmed.isEmpty else { return }
                if let chat = chat {
                    if let token = chat.dmToken {
                        // DM chat: send direct message
                        if let pubKey = Data(base64Encoded: chat.id) {
                            xxdkServ.xxdk.sendDM(
                                msg: trimmed,
                                toPubKey: pubKey,
                                partnerToken: token
                            )
                        }
                    } else {
                        // Channel chat: send via Channels Manager using channelId (stored in id)
                        xxdkServ.xxdk.sendDM(
                            msg: trimmed,
                            channelId: chat.id
                        )
                    }
                }
                abc = ""
            }
            .padding(.vertical, 8).padding(.horizontal, 14)
            .background(
                Color(.LG)
            )
            .clipShape(RoundedRectangle(cornerRadius: 40))
            Button(
                action: {
                    let trimmed = abc.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    guard !trimmed.isEmpty else { return }
                    if xxdkServ.xxdk.cmix?.readyToSend() == true {
                        if let chat = chat {
                            if let token = chat.dmToken {
                                if let pubKey = Data(base64Encoded: chat.id) {
                                    xxdkServ.xxdk.sendDM(
                                        msg: trimmed,
                                        toPubKey: pubKey,
                                        partnerToken: token
                                    )
                                }
                            } else {
                                xxdkServ.xxdk.sendDM(
                                    msg: trimmed,
                                    channelId: chat.id
                                )
                            }
                        }
                        abc = ""
                    }
                },
                label: {
                    Image(systemName: "chevron.right").padding(.vertical, 8)
                }
            )
            .buttonStyle(.borderedProminent).padding(.horizontal, 6).buttonBorderShape(.circle)
        }.padding(.horizontal, 16).padding(.top, 10).background(.white)

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
        MessageForm(chat: previewChat)
            .modelContainer(container)
            .environmentObject(XXDKService(XXDKMock()))
    }
}
