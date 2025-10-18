//
//  iOSExampleApp.swift
//  iOSExample
//
//  Created by Richard Carback on 3/4/24.
//

import SwiftData
import SwiftUI

@main
struct iOS_ExampleApp: App {
    @StateObject var logOutput = LogViewer()
    @StateObject var xxdk = XXDK()
    @StateObject private var sM = SecretManager()
    var modelContainer: ModelContainer = {
        // Include all SwiftData models used by the app
        let schema = Schema([
            Chat.self,
            ChatMessage.self,
            MessageReaction.self,
            Sender.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }();


    var body: some Scene {
        WindowGroup {
            if sM.isPasswordSet {
                LandingPage<XXDK>()
                    .environmentObject(logOutput)
                    .environmentObject(xxdk)
                    .environmentObject(SwiftDataActor(modelContainer: modelContainer))
            } else {
                PasswordCreationView(onPasswordCreated: {
                    
                })
            }
        }
        .modelContainer(modelContainer)
        .environmentObject(sM)
    }
}
