//
//  Test.swift
//  iOSExample
//
//  Created by Om More on 19/10/25.
//

import SwiftUI

struct TestV: View {
    var body: some View {
        VStack {
            Text("preview reply")
            VStack {
                Text("message")
            }.background(.pink)
        }
    }
}

#Preview {
    TestV()
}
