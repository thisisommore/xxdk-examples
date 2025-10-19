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

extension Color {
    init(hexNumber: Int) {
        var r = Double((hexNumber & 0xFF0000) >> 16) / 255.0
        var g = Double((hexNumber & 0x00FF00) >> 8) / 255.0
        var b = Double(hexNumber & 0x0000FF) / 255.0
        
        // Calculate perceived brightness (using luminance formula)
        let brightness = (0.299 * r + 0.587 * g + 0.114 * b)
        
        // If too light (brightness > 0.7), darken the color
        if brightness > 0.7 {
            let darkenFactor = 0.5
            r *= darkenFactor
            g *= darkenFactor
            b *= darkenFactor
        }
        
        self.init(red: r, green: g, blue: b)
    }
}
