//
//  MockXXDK.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import Kronos
import Bindings
import SwiftData
@MainActor
public class XXDKMock: XXDKP {
    public func setModelContext(_ ctx: ModelContext) {
        // No-op for mock
        dmReceiver.modelContext = ctx
    }
    func sendDM(msg: String, toPubKey: Data, partnerToken: Int32) {
        
    }
    func sendDM(msg: String, channelId: String) {
        // Mock channel send: no-op
    }
    var codename: String? = "Manny"
    func joinChannel(_ prettyPrint: String) async throws -> ChannelJSON {
        throw MyError.runtimeError("join chnnale")
    }
    func load() async {}
    var cmix: Bindings.BindingsCmix?
    init() {}
    var ndf: Data?
    var DM: Bindings.BindingsDMClient?
    var dmReceiver: DMReceiver = DMReceiver()
}
