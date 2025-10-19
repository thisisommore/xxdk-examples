//
//  MessageSender.swift
//  iOSExample
//
//  Created by Om More on 19/10/25.
//

import SwiftUI

/// Displays the sender's name/codename for a message
struct MessageSender: View {
    let isIncoming: Bool
    let sender: Sender?
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        HStack {

            if !isIncoming {
                Text("You")
                    .font(.caption)
                    .foregroundStyle(.primary)
            } else if let sender {
                Text(sender.codename).bold()
                    .font(.caption)
                    .foregroundStyle(
                        Color(hexNumber: sender.color).adaptive(
                            for: colorScheme
                        )
                    )
            }

        }
    }
}
