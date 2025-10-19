//
//  MessageContextMenu.swift
//  iOSExample
//
//  Created by Om More on 19/10/25.
//

import SwiftUI
import UniformTypeIdentifiers

/// Context menu options for message interactions
struct MessageContextMenu: View {
    let text: String
    let isIncoming: Bool
    let sender: Sender?
    
    @Binding var selectedEmoji: MessageEmoji
    @Binding var shouldTriggerReply: Bool
    
    var onDM: ((String, Int32, Data) -> Void)?
    
    var body: some View {
        // Emoji picker
        Picker("React", selection: $selectedEmoji) {
            Button(action: {}) {
                Image(systemName: "plus")
            }
            .tag(MessageEmoji.custom)
        }
        .pickerStyle(.palette)
        
        // Reply button
        Button {
            shouldTriggerReply = true
        } label: {
            Label("Reply", systemImage: "arrowshape.turn.up.left")
        }
        
        // DM button (only for incoming messages with DM token)
        if isIncoming,
           let sender = sender,
           sender.dmToken != 0 {
            Button {
                onDM?(sender.codename, sender.dmToken, sender.pubkey)
            } label: {
                Label("Send DM", systemImage: "message")
            }
        }
        
        // Copy button
        Button {
            UIPasteboard.general.setValue(
                stripParagraphTags(text),
                forPasteboardType: UTType.plainText.identifier
            )
        } label: {
            Text("Copy")
        }
    }
}
