//
//  MessageItem.swift
//  iOSExample
//
//  Created by Om More on 28/09/25.
//
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct CSpacer: View {
    let show: Bool
    init(_ show: Bool) {
        self.show = show
    }
    var body: some View {
        show ? Spacer() : nil
    }
}

struct MessageItem: View {
    let text: String
    let isIncoming: Bool
    let repliedTo: String?
    let sender: String?
    let reactionsSet: Set<String>
    let myReactions: Set<String>
    let timeStamp: Date = Date()
    var calendar = Calendar.current
    var onReply: (() -> Void)?
    enum Emoji: String, CaseIterable, Identifiable {
        case laugh, laughLound, redHeart, Cry, Like, custom, None
        var id: Self { self }
    }

    @State private var selectedFlavor: Emoji = .None

    var time: String = ""
    @State private var isEmojiSheetPresented: Bool = false
    @State private var reaction: String? = nil
    @State private var shouldTriggerReply: Bool = false

    init(text: String, isIncoming: Bool, repliedTo: String?, sender: String?, reactionsSet: Set<String> = [], myReactions: Set<String> = [], onReply: (() -> Void)? = nil) {
        self.text = text
        self.isIncoming = isIncoming
        self.repliedTo = repliedTo
        self.sender = sender
        self.reactionsSet = reactionsSet
        self.myReactions = myReactions
        self.onReply = onReply
        let hour = calendar.component(.hour, from: timeStamp)
        let minute = calendar.component(.minute, from: timeStamp)
        let second = calendar.component(.second, from: timeStamp)

        time = "\(hour):\(minute)"
    }
    
    private func getEmojiTag(for emoji: String) -> Emoji {
        switch emoji {
        case "😂": return .laugh
        case "😭": return .Cry
        case "👍": return .Like
        case "❤️": return .redHeart
        default: return .None
        }
    }

    var body: some View {
        HStack {
            CSpacer(!isIncoming)
            VStack(alignment: .leading, spacing: 2) {
                if let repliedTo {

                    HStack {
                        CSpacer(!isIncoming)

                        // reply preview
                        HTMLText(repliedTo, textColor: .black)
                            .fontSize(12)
                            .padding(.leading, 12)
                            .padding(.top, 12)
                            .foregroundStyle(.black).opacity(0.4).font(
                                .footnote
                            )
                            .contextMenu(menuItems: {
                                Button {
                                    UIPasteboard.general.setValue(
                                        stripParagraphTags(text),
                                        forPasteboardType: UTType.plainText
                                            .identifier
                                    )
                                } label: {
                                    Text("Copy")
                                }
                            }).lineLimit(4)
                        CSpacer(isIncoming)
                    }.frame(maxWidth: UIScreen.w(80))

                }
                HStack {
                    CSpacer(!isIncoming)

                    // sender
                    if !isIncoming {
                        Text("You")
                            .font(.caption)
                            .foregroundStyle(.secondary).padding(
                                .top,
                                repliedTo != nil ? 0 : 12
                            )
                    } else if let sender {
                        Text(sender)
                            .font(.caption)
                            .foregroundStyle(.black).opacity(0.8).padding(
                                .top,
                                repliedTo != nil ? 0 : 12
                            )
                    }
                    CSpacer(isIncoming)
                }
                HStack {
                    CSpacer(!isIncoming)

                    // Message
                    HTMLText(text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(isIncoming ? Color.blue : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 10,
                                bottomLeadingRadius: isIncoming ? 0 : 10,  // Left bottom = 0
                                bottomTrailingRadius: isIncoming ? 10 : 0,
                                topTrailingRadius: 10
                            )
                        )
                        .contextMenu(menuItems: {
                            Picker("React", selection: $selectedFlavor) {
                              
                                
                                Button(action: {}) {
                                    Image(systemName: "plus")
                                }
                                    .tag(Emoji.custom)
                            }
                            .pickerStyle(.palette)

                            Button {
                                shouldTriggerReply = true
                            } label: {
                                Label("Reply", systemImage: "arrowshape.turn.up.left")
                            }

                            Button {
                                UIPasteboard.general.setValue(
                                    stripParagraphTags(text),
                                    forPasteboardType: UTType.plainText
                                        .identifier
                                )
                            } label: {
                                Text("Copy")
                            }
                        })
                        .onChange(of: selectedFlavor) { newValue in
                            if newValue == .custom {
                                // Defer until after the context menu dismisses
                                DispatchQueue.main.async {
                                    isEmojiSheetPresented = true
                                }
                                // Reset selection so it doesn't stay on custom
                                selectedFlavor = .None
                            }
                        }

                    CSpacer(isIncoming)
                }

                // Time
                //                HStack{
                //                    CSpacer(!isIncoming)
                //                    Text(time)
                //                        .font(.caption).font(.system(size:1))
                //                        .foregroundStyle(.black).opacity(0.5).padding(0)
                //                    CSpacer(isIncoming)
                //                }

            }
            CSpacer(isIncoming)

        }
        .sheet(isPresented: $isEmojiSheetPresented) {
            EmojiKeyboard { emoji in
                reaction = emoji.isEmpty ? nil : emoji
                isEmojiSheetPresented = false
            }
        }
        .onChange(of: shouldTriggerReply) { _, newValue in
            if newValue {
                onReply?()
                shouldTriggerReply = false
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 0) {  // Add this VStack with spacing: 0
            MessageItem(
                text: "<p>Yup here you go</p>",
                isIncoming: true,
                repliedTo:
                    "Wow lets go Wow lets go Wow lets go Wow lets go Wow lets go Wow lets go Wow lets go Wow lets go Wow lets go Wow lets go Wow lets go Wow lets go Wow lets go",
                sender: "Mayur",
                reactionsSet: ["😂", "❤️", "👍"],
                myReactions: ["😂", "🔥"]
            )
            MessageItem(
                text: """
                <a href="https://www.theguardian.com/technology/2025/sep/28/why-i-gave-the-world-wide-web-away-for-free" rel="noopener noreferrer" target="_blank">
                https://www.theguardian.com/technology/2025/sep/28/why-i-gave-the-world-wide-web-away-for-free
                </a>
                """,
                isIncoming: true,
                repliedTo: "Wow lets go",
                sender: "Mayur",
                reactionsSet: ["😭", "😂"],
                myReactions: ["💯", "✨", "🙏"]
            )
            MessageItem(
                text: "Yup here you go",
                isIncoming: false,
                repliedTo: "Wow lets go",
                sender: nil,
                reactionsSet: ["👏", "🔥"],
                myReactions: ["😎"]
            )
            MessageItem(
                text: "Yup here you go",
                isIncoming: true,
                repliedTo: nil,
                sender: "Mayur",
                reactionsSet: ["❤️"],
                myReactions: []
            )
            MessageItem(
                text: "Yup here you go",
                isIncoming: true,
                repliedTo: nil,
                sender: "Mayur",
                reactionsSet: [],
                myReactions: ["👍", "😂"]
            )
            MessageItem(
                text: "Yup here you go",
                isIncoming: true,
                repliedTo: nil,
                sender: nil
            )
            MessageItem(
                text: "Yup here you go",
                isIncoming: true,
                repliedTo: nil,
                sender: nil
            )
            MessageItem(
                text: "Yup here you go",
                isIncoming: true,
                repliedTo: nil,
                sender: nil
            )
            MessageItem(
                text: "Yup here you go",
                isIncoming: true,
                repliedTo: nil,
                sender: nil
            )
            MessageItem(
                text: "Yup here you go",
                isIncoming: true,
                repliedTo: nil,
                sender: "Mayur"
            )
            MessageItem(
                text: "Yup here you go",
                isIncoming: true,
                repliedTo: nil,
                sender: "Mayur"
            )
            MessageItem(
                text: "Yup here you go",
                isIncoming: true,
                repliedTo: nil,
                sender: "Mayur"
            )
            Spacer()
        }  // Close VStack
    }.padding()
}
