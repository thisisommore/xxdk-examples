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
    
    func joinChannelFromURL(_ url: String) async throws -> ChannelJSON {
        // Mock: simulate URL decode and join
        return try await joinChannel(url) // For mock, treat URL as prettyPrint
    }
    
    func joinChannel(_ prettyPrint: String) async throws -> ChannelJSON {
        // Mock: return sample joined channel data after a short delay
        try await Task.sleep(for: .seconds(1))
        return ChannelJSON(
            receptionId: "mock-reception-id",
            channelId: "mock-channel-id-\(UUID().uuidString)",
            name: "Mock Joined Channel",
            description: "This is a mock joined channel"
        )
    }
    
    func getChannelPrivacyLevel(url: String) throws -> PrivacyLevel {
        // Mock: return public by default
        return .publicChannel
    }
    
    func getChannelFromURL(url: String) throws -> ChannelJSON {
        // Mock: return sample channel data
        return ChannelJSON(
            receptionId: "mock-reception-id",
            channelId: "mock-channel-id",
            name: "Mock Channel",
            description: "This is a mock channel for testing"
        )
    }
    
    func decodePrivateURL(url: String, password: String) throws -> String {
        // Mock: return the URL as prettyPrint
        return url
    }
    
    func getPrivateChannelFromURL(url: String, password: String) throws -> ChannelJSON {
        // Mock: return sample private channel data
        return ChannelJSON(
            receptionId: "mock-reception-id",
            channelId: "mock-private-channel-id",
            name: "Mock Private Channel",
            description: "This is a mock private channel for testing"
        )
    }
    
    func enableDirectMessages(channelId: String) throws {
        // Mock: no-op
        print("Mock: Enabled direct messages for channel: \(channelId)")
    }
    
    func disableDirectMessages(channelId: String) throws {
        // Mock: no-op
        print("Mock: Disabled direct messages for channel: \(channelId)")
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
