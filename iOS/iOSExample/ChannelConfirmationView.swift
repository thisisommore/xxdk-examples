//
//  ChannelConfirmationView.swift
//  iOSExample
//
//  Created by Om More on 08/10/25.
//

import SwiftUI

struct ChannelConfirmationView: View {
    let channelName: String
    let channelURL: String
    @Binding var isJoining: Bool
    let onConfirm: () -> Void
    
    @State private var enableDM = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Channel Details")) {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(channelName)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("URL")) {
                    Text(channelURL)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .textSelection(.enabled)
                }
                
                Section {
                    Toggle("Enable DM", isOn: $enableDM)
                }
                
                if isJoining {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(.circular)
                            Text("Joining channel...")
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Confirm Channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isJoining)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        onConfirm()
                    }
                    .disabled(isJoining)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var isJoining = false
    return ChannelConfirmationView(
        channelName: "xx Network General",
        channelURL: "<Speakeasy-v3:xxGeneralChat|description:Talking about the xx network|level:Public>",
        isJoining: $isJoining,
        onConfirm: {
            print("Confirmed!")
        }
    )
}

