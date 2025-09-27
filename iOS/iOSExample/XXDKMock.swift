//
//  Untitled.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//
import Foundation

import Bindings
import Kronos

protocol XXDKServiceRepresentable {
    var xxdk: XXDK { get }
}

// Service implementation
@Observable
final class XXDKService: XXDKServiceRepresentable {
    private(set) var xxdk: XXDK
}

// Service mock
@Observable
final class XXDKServiceMock: XXDKServiceRepresentable {
    let xxdk: XXDK = .mock
}
