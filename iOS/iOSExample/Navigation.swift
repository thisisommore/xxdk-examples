//
//  Navigation.swift
//  iOSExample
//
//  Created by Om More on 29/09/25.
//

enum Destination: Hashable {
    case home
    case chat(chatId: String, chatTitle: String)   // add whatever “props” you need
}
