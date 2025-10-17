//
//  Reactions.swift
//  iOSExample
//
//  Created by Om More on 28/09/25.
//

import SwiftData
import SwiftUI
struct Reactions: View {
    let reactions: [MessageReaction]
    var body: some View {
        if !reactions.isEmpty {
            HStack(spacing: 4) {
                ForEach(Array(reactions.prefix(2)), id: \.self) { reaction in
                    Text(reaction.emoji)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                if reactions.count > 2 {
                    Text("+" + String(reactions.count - 2))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
        }
    }
}
