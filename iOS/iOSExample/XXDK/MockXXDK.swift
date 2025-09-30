//
//  MockXXDK.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import Kronos
import Bindings
import SwiftData

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
    func sendReply(msg: String, channelId: String, replyToMessageIdB64: String) {
        // Mock channel reply: no-op
    }
    func sendReply(msg: String, toPubKey: Data, partnerToken: Int32, replyToMessageIdB64: String) {
        // Mock DM reply: no-op
    }
    var codename: String? = "Manny"
    func joinChannel(_ prettyPrint: String) async throws -> ChannelJSON {
        throw MyError.runtimeError("join chnnale")
    }
    func load() async {
        do {
            print("starting wait")
            try await Task.sleep(nanoseconds: 2_000_000_000) // Reduced to 2 seconds for testing
            print("wait done")
        } catch {
            fatalError("error in load fake sleep: \(error)")
        }
        
    }
    var cmix: Bindings.BindingsCmix?
    init() {}
    var ndf: Data?
    var DM: Bindings.BindingsDMClient?
    var dmReceiver: DMReceiver = DMReceiver()
}
