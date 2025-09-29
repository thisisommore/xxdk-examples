//
//  XXDKService.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//
import Foundation
@MainActor
public class XXDKService: ObservableObject {
    var xxdk: any XXDKP
    init(_ xxdk: any XXDKP) {
        self.xxdk = xxdk
    }
}
