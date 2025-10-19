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
    @StateObject private var navigation = AppNavigationPath()
    var modelData  = {
        // Include all SwiftData models used by the app
        let schema = Schema([
            Chat.self,
            ChatMessage.self,
            MessageReaction.self,
            Sender.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema)
        
        do {
            let mC = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            return (mC: mC, da: SwiftDataActor(modelContainer: mC))
        } catch {
            fatalError("Could not create ModelContainer: \(error.localizedDescription)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigation.path) {
                Color.clear
                .navigationDestination(for: Destination.self) { destination in
                    destination.destinationView()
                        .toolbarBackground(.ultraThinMaterial)
                }.onAppear{
                    
                    xxdk.setModelContainer(mActor: modelData.da, sm: sM)
                    
                    print("ON appear")
                    if !sM.isPasswordSet {
                        navigation.path.append(Destination.password)
                    } else {
                        navigation.path.append(Destination.home)
                    }
                }
            }
            .modelContainer(modelData.mC)
            .environmentObject(sM)
            .environmentObject(xxdk)
            .environmentObject(logOutput)
            .environment(\.navigation, navigation)
            .environmentObject(modelData.da)
        }
    }
}
