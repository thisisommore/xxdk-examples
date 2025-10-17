//
//  UIScreen.swift
//  iOSExample
//
//  Created by Om More on 17/10/25.
//
import SwiftUI
extension UIScreen {
    static let screenWidth = UIScreen.main.bounds.size.width
    static let screenHeight = UIScreen.main.bounds.size.height
    static let screenSize = UIScreen.main.bounds.size
    
    // Width percentage function
    static func w(_ percentage: CGFloat) -> CGFloat {
        return screenWidth * (percentage / 100)
    }
    
    // Height percentage function
    static func h(_ percentage: CGFloat) -> CGFloat {
        return screenHeight * (percentage / 100)
    }
}
