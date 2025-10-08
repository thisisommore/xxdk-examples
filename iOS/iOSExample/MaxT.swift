//
//  MaxT.swift
//  iOSExample
//
//  Created by Om More on 08/10/25.
//

import SwiftUI
import Foundation
struct ContentView: View {
    @State private var showingFirst = false
    @State private var showingSecond = false

    var body: some View {
        VStack {
            Button("Show First Sheet") {
                showingFirst = true
            }
        }
        .sheet(isPresented: $showingFirst) {
            Button("Show Second Sheet") {
                showingSecond = true
            }
            .sheet(isPresented: $showingSecond) {
                Text("Second Sheet")
            }
        }
    }
}

#Preview {
    ContentView()
}
