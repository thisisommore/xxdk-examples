//
//  iOSExampleApp.swift
//  iOSExample
//
//  Created by Richard Carback on 3/4/24.
//

import SwiftUI
import SwiftData

@main
struct iOS_ExampleApp: App {
    @StateObject var logOutput = LogViewer()
    @StateObject var xxdk = XXDK(url: MAINNET_URL, cert: MAINNET_CERT)
    
    var sharedModelContainer: ModelContainer = {
        // Include all SwiftData models used by the app
        let schema = Schema([
            User.self,
            Chat.self,
            ChatMessage.self,
            Item.self,
            MessageReaction.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            LandingPage<XXDK>()
                .environmentObject(logOutput)
                .environmentObject(xxdk)
        }
        .modelContainer(sharedModelContainer)
    }
}
