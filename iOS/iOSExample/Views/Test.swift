//
//  Test.swift
//  iOSExample
//
//  Created by Om More on 19/10/25.
//

import SwiftUI

struct TestV: View {
    var body: some View {
       NavigationStack {
         Text("Hello, world!")
           .toolbar {
             ToolbarItem(placement: .navigationBarTrailing) {
               Button(action: {
                 // Code for button action goes here
               }) {
                 Image(systemName: "gear")
                   .foregroundStyle(.primary)
               }
               .buttonStyle(.borderless)
             }
           }
           .navigationTitle("Hello")
       }
     }
}

#Preview {
    TestV()
}
