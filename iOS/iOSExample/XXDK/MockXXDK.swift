//
//  MockXXDK.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import Kronos
import Bindings
import SwiftData
import SwiftUI
import Foundation
public class XXDKMock: XXDKP {
    @Published var status: String = "Initiating";
    @Published var statusPercentage: Double = 0;
    public func setModelContainer(mActor: SwiftDataActor, sm: SecretManager) {
        // Retain container and inject into receivers/callbacks
    
        self.dmReceiver.modelActor = mActor
        self.channelUICallbacks.configure(modelActor: mActor)
        self.eventModelBuilder = EventModelBuilder(model: EventModel(storageTag: "mock-storage-tag"))
        self.eventModelBuilder?.configure(modelActor: mActor)
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
    
    func areDMsEnabled(channelId: String) throws -> Bool {
        // Mock: return true by default
        return true
    }
    
    func leaveChannel(channelId: String) throws {
        // Mock: no-op
        print("Mock: Left channel: \(channelId)")
    }
    
    func setUpCmix() async {
        withAnimation {
            statusPercentage = 10
            status = "Setting cmix"
        }
    }
    
    func startNetworkFollower() async {
        withAnimation {
            statusPercentage = 20
            status = "Starting network follower"
        }
    }
    
    func load(privateIdentity _privateIdentity: Data?) async {
        do {
            print("starting wait")
            try await Task.sleep(nanoseconds: 2_000_000_000) // Reduced to 2 seconds for testing
            withAnimation {
                statusPercentage = 30
                status = "Connecting to network"
            }
            
           
            try await Task.sleep(nanoseconds: 2_000_000_000) // Reduced to 2 seconds for testing
            withAnimation {
                statusPercentage = 40
                status = "Joining xxNetwork channel"
            }
            
            try await Task.sleep(nanoseconds: 2_000_000_000) // Reduced to 2 seconds for testing
            withAnimation {
                statusPercentage = 60
                status = "Setting up KV"
            }
           
            try await Task.sleep(nanoseconds: 2_000_000_000) // Reduced to 2 seconds for testing
            withAnimation {
                statusPercentage = 100
                print("wait done")
            }
            
        } catch {
            fatalError("error in load fake sleep: \(error)")
        }
        
    }
    var cmix: Bindings.BindingsCmix?
    var channelsManager: Bindings.BindingsChannelsManager?
    var eventModelBuilder: EventModelBuilder?
    var remoteKV: Bindings.BindingsRemoteKV?
    var storageTagListener: RemoteKVKeyChangeListener?
    private var modelContainer: ModelContainer?
    private let channelUICallbacks: ChannelUICallbacks

    init() {
        self.channelUICallbacks = ChannelUICallbacks()
    }

    var ndf: Data?
    var DM: Bindings.BindingsDMClient?
    var dmReceiver: DMReceiver = DMReceiver()

    /// Mock implementation of generateIdentities
    /// - Parameter amountOfIdentities: Number of identities to generate
    /// - Returns: Array of mock GeneratedIdentity objects
    func generateIdentities(amountOfIdentities: Int) -> [GeneratedIdentity] {
        var identities: [GeneratedIdentity] = []

        for i in 0..<amountOfIdentities {
            // Generate mock private identity data
            let mockPrivateIdentity = "mock_private_identity_\(i)_\(UUID().uuidString)".data(using: .utf8) ?? Data()

            // Generate mock identity details
            let mockCodename = "MockUser\(i)_\(UUID().uuidString.prefix(8))"
            let mockCodeset = 1
            let mockPubkey = "mock_pubkey_\(i)_\(UUID().uuidString)"

            let mockIdentity = GeneratedIdentity(
                privateIdentity: mockPrivateIdentity,
                codename: mockCodename,
                codeset: mockCodeset,
                pubkey: mockPubkey
            )

            identities.append(mockIdentity)
        }

        return identities
    }
}
