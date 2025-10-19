//
//  Navigation.swift
//  iOSExample
//
//  Created by Om More on 29/09/25.
//

import SwiftUI

class AppNavigationPath: Observable, ObservableObject {
    public var path = NavigationPath()
}

extension EnvironmentValues {
    @Entry var navigation: AppNavigationPath = AppNavigationPath()
}

enum Destination: Hashable {
    case home
    case landing
    case codenameGenerator
    case password
    case chat(chatId: String, chatTitle: String)   // add whatever "props" you need
}

// MARK: - Navigation Destination Views
extension Destination {
    @MainActor @ViewBuilder
    func destinationView() -> some View {
        switch self {
        case .landing:
            LandingPage<XXDK>()
                .navigationBarBackButtonHidden()
        case .home:
            HomeView<XXDK>(width: UIScreen.w(100))
                .navigationBarBackButtonHidden()
        case .codenameGenerator:
            CodenameGeneratorView()
                .navigationBarBackButtonHidden()
        case .password:
            PasswordCreationView()
                .navigationBarBackButtonHidden()
        case let .chat(chatId, chatTitle):
            ChatView<XXDK>(width: UIScreen.w(100), chatId: chatId, chatTitle: chatTitle)
            
        }
    }
}
