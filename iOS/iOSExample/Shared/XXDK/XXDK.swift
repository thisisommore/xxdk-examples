//
//  XXDK.swift
//  iOSExample
//
//  Created by Richard Carback on 3/6/24.
//

import Bindings
import Foundation
import Kronos
import SwiftData

// NDF is the configuration file used to connect to the xx network. It
// is a list of known hosts and nodes on the network.
// A new list is downloaded on the first connection to the network
public var MAINNET_URL =
    "https://elixxir-bins.s3.us-west-1.amazonaws.com/ndf/mainnet.json"

let XX_GENERAL_CHAT =
  "<Speakeasy-v3:xxGeneralChat|description:Talking about the xx network|level:Public|created:1674152234202224215|secrets:rb+rK0HsOYcPpTF6KkpuDWxh7scZbj74kVMHuwhgUR0=|RMfN+9pD/JCzPTIzPk+pf0ThKPvI425hye4JqUxi3iA=|368|1|/qE8BEgQQkXC6n0yxeXGQjvyklaRH6Z+Wu8qvbFxiuw=>";

// This resolves to "Resources/mainnet.crt" in the project folder for iOSExample
public var MAINNET_CERT =
    Bundle.main.path(forResource: "mainnet", ofType: "crt")
    ?? "unknown resource path"
enum MyError: Error {
    case runtimeError(String)
}
@MainActor
public class XXDK: XXDKP {
    // Channels Manager retained for channel sends
    private var channelsManager: Bindings.BindingsChannelsManager?
    
    func sendDM(msg: String) {
        
    }
    
    private var networkUrl = MAINNET_URL
    private var networkCert = MAINNET_CERT
    private var stateDir: URL

    @Published var codename: String?
    // These are initialized after loading
    @Published var ndf: Data?
    private var storageTagListener: RemoteKVKeyChangeListener?
    private var remoteKV: Bindings.BindingsRemoteKV?
    var cmix: Bindings.BindingsCmix?
    @Published var DM: Bindings.BindingsDMClient?
    // This will not start receiving until the network follower starts
    @Published var dmReceiver = DMReceiver()
    var eventModelBuilder: EventModelBuilder?
    // Retained SwiftData model context for lifecycle operations
    private var modelContext: ModelContext?
    // modelContext for dmReceiver is injected from SwiftUI (e.g., ContentView.onAppear)
    
    // Channel UI callbacks for handling channel events
    private let channelUICallbacks: ChannelUICallbacks

    public func setModelContext(_ ctx: ModelContext) {
        // Retain context and inject into receivers/callbacks
        self.modelContext = ctx
        self.dmReceiver.modelContext = ctx
        self.channelUICallbacks.configure(modelContext: ctx)
        self.eventModelBuilder?.configure(modelContext: ctx)
    }

    init(url: String, cert: String) {
        self.channelUICallbacks = ChannelUICallbacks()
        networkUrl = url
        networkCert = cert

        let netTime = NetTime()
        // xxdk needs accurate time to connect to the live network
        Bindings.BindingsSetTimeSource(netTime)

        // Note: this will resolve to the documents folder on Mac OS
        // or the app's local data folder on iOS.
        do {
            let basePath = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            stateDir = basePath.appendingPathComponent("xxAppState")
            if !FileManager.default.fileExists(atPath: stateDir.path) {
                try FileManager.default.createDirectory(
                    at: stateDir,
                    withIntermediateDirectories: true
                )
            }
            stateDir = stateDir.appendingPathComponent("ekv")
        } catch let err {
            fatalError(
                "failed to get state directory: " + err.localizedDescription
            )
        }

    }

    func load() async {
        // Always start from a clean SwiftData state per request
        if let container = modelContext?.container {
            do {
//                try container.erase()
                print("SwiftData: Deleted all local data at startup")
            } catch {
                print("SwiftData: Failed to delete all data at startup: \(error)")
            }
        } else {
            print("SwiftData: No modelContext set; skipping deleteAllData()")
        }
        
        ndf = downloadNDF(url: self.networkUrl, certFilePath: self.networkCert)

        // NOTE: Secret should be pulled from keychain
        let secret = "Hello".data
        // NOTE: Empty string forces defaults, these are settable but it is recommended that you use the defaults.
        let cmixParamsJSON = "".data
        if !FileManager.default.fileExists(atPath: stateDir.path) {
            var err: NSError?
            Bindings.BindingsNewCmix(ndf?.utf8, stateDir.path, secret, "", &err)
            if err != nil {
                fatalError(
                    "could not create new Cmix: " + err!.localizedDescription
                )
            }
        }
        var err: NSError?
        cmix = Bindings.BindingsLoadCmix(
            stateDir.path,
            secret,
            cmixParamsJSON,
            &err
        )
        if err != nil {
            fatalError("could not load Cmix: " + err!.localizedDescription)
        }

        let receptionID = cmix?.getReceptionID()!.base64EncodedString()
        print("cMix Reception ID: \(receptionID ?? "<nil value>")")

        let dmID: Data
        do {
            dmID = try cmix!.ekvGet("MyDMID")
        } catch {
            print("Generating DM Identity...")
            // NOTE: This will be deprecated in favor of generateCodenameIdentity(...)
            dmID = Bindings.BindingsGenerateChannelIdentity(
                cmix!.getID(),
                &err
            )!
            if err != nil {
                fatalError(
                    "could not generate codename id: "
                        + err!.localizedDescription
                )
            }
            print("Exported Codename Blob: " + dmID.base64EncodedString())
            do {
                try cmix!.ekvSet("MyDMID", value: dmID)
            } catch let error {
                fatalError("could not set ekv: " + error.localizedDescription)
            }
        }
        print("Exported Codename Blob: " + dmID.base64EncodedString())

        // Derive public identity JSON from the private identity and decode codename
        let publicIdentity: Data?
        publicIdentity = Bindings.BindingsGetPublicChannelIdentityFromPrivate(
            dmID,
            &err
        )
        if err != nil {
            fatalError(
                "could not derive public identity: " + err!.localizedDescription
            )
        }
        
        if let pubId = publicIdentity {
            do {
                let identity = try! Parser.decodeIdentity(from: pubId)
                self.codename = identity.codename
                // Persist codename for later reads
                if let nameData = identity.codename.data(using: .utf8) {
                    do { try cmix!.ekvSet("MyCodename", value: nameData) } catch
                    {
                        print(
                            "could not persist codename: \(error.localizedDescription)"
                        )
                    }
                }
            } catch {
                print(
                    "failed to decode public identity json: \(error.localizedDescription)"
                )
            }
        }

        let notifications = Bindings.BindingsLoadNotifications(
            cmix!.getID(),
            &err
        )
        if err != nil {
            fatalError(
                "could not load notifications: " + err!.localizedDescription
            )
        }

        let receiverBuilder = DMReceiverBuilder(receiver: dmReceiver)

        //Note: you can use `newDmManagerMobile` here instead if you want to work with
        //an SQLite database.
        // This interacts with the network and requires an accurate clock to connect or you'll see
        // "Timestamp of request must be within last 5 seconds." in the logs.
        // If you have trouble shutdown and start your emulator.
        DM = Bindings.BindingsNewDMClient(
            cmix!.getID(),
            (notifications?.getID())!,
            dmID,
            receiverBuilder,
            dmReceiver,
            &err
        )
        if err != nil {
            fatalError("could not load dm client: " + err!.localizedDescription)
        }

        print(
            "DMPUBKEY: \(DM?.getPublicKey()?.base64EncodedString() ?? "empty pubkey")"
        )
        print("DMTOKEN: \(DM?.getToken() ?? 0)")

        do {
            try cmix!.startNetworkFollower(5000)
            cmix!.wait(forNetwork: 30000)
        } catch let error {
            fatalError("cannot start network: " + error.localizedDescription)
        }

        remoteKV = cmix!.getRemoteKV()

        // Start RemoteKV listener for the storage tag during load so it's ready before channel join
        do {
            storageTagListener = try RemoteKVKeyChangeListener(
                key: "channels-storage-tag",
                remoteKV: remoteKV!,
                version: 0,
                localEvents: true
            )
        } catch {
            print("Failed to start RemoteKV listener during load: \(error)")
        }

        // Run readiness + Channels Manager creation in the background, retrying every 2 seconds until success
  
        Task {
            while true {
                let readyData =   try! self.cmix!.isReady(0.1)
                let readinessInfo =  try! Parser.decodeIsReadyInfo(from: readyData)
                if !readinessInfo.isReady {
                    print("cMix not ready yet (howClose=\(readinessInfo.howClose)) — retrying in 2s…")
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    continue
                }
                let cmixId =  cmix!.getID()
                // Attempt to create Channels Manager on the MainActor
                let noti = Bindings.BindingsLoadNotificationsDummy(cmixId, &err)
                var channelsErr: NSError?
                
      
//                let dbPath = channelsDir.appendingPathComponent("channels.sqlite").path

                eventModelBuilder = EventModelBuilder(model: EventModel(storageTag: String(describing: storageTagListener!.data)))
     
                    if let ctx = self.modelContext {
                        self.eventModelBuilder?.configure(modelContext: ctx)
                    }
      
                 let cm = Bindings.BindingsNewChannelsManager(
                    self.cmix!.getID(),
                    dmID,
                    eventModelBuilder,
                    nil,
                    noti!.getID(),
                    channelUICallbacks,
                    &channelsErr
                )
                
                // Retain Channels Manager for future channel sends
                self.channelsManager = cm
                
                storageTagListener!.data = Data(cm!.getStorageTag().utf8)

                if let e = channelsErr {
               
                } else {
//                     Successfully created Channels Manager; join channel in background and exit loop
                    Task { [weak self] in
                        do {
                            _ = try await self?.joinChannel(XX_GENERAL_CHAT)
                        } catch {
                            print("Failed to join channel in background: \(error)")
                        }
                    }
                    break
                }
               
        }
        }
        // After loading, if we have a codename, ensure a self chat exists
        let name = codename?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let codename = name, !codename.isEmpty {
            // Use the DM public key (base64) as the Chat.id for DMs
            let selfPubKeyData = DM!.getPublicKey()
            let selfPubKeyB64 = selfPubKeyData!.base64EncodedString()
            do {
                try await MainActor.run {
                    // Check if a DM chat already exists for this public key (id == pubkey b64)
                    let descriptor = FetchDescriptor<Chat>(predicate: #Predicate { $0.id == selfPubKeyB64 })
                    let existing = try modelContext!.fetch(descriptor)
                    if existing.isEmpty {
                        let token64 = DM!.getToken()
                        let tokenU32 = UInt32(truncatingIfNeeded: token64)
                        let selfToken = Int32(bitPattern: tokenU32)
                        let chat = Chat(pubKey: selfPubKeyData!, name: codename, dmToken: selfToken)
                        modelContext!.insert(chat)
                        try modelContext!.save()
                    }
                }
            } catch {
                print("HomeView: Failed to create self chat for \(codename): \(error)")
            }
        }
        // Ensure initial channel exists locally and join only if not present
        do {
            let cd = try await joinChannel(XX_GENERAL_CHAT)
            let channelId = cd.channelId ?? "xxGeneralChat"
            try await MainActor.run {
                let check = FetchDescriptor<Chat>(predicate: #Predicate { $0.id == channelId })
                let existingChannel = try modelContext!.fetch(check)
                if existingChannel.isEmpty {
                    let channelChat = Chat(channelId: channelId, name: cd.name)
                    modelContext!.insert(channelChat)
                    try modelContext!.save()
                }
            }
        } catch {
            print("HomeView: Failed to ensure initial channel xxGeneralChat: \(error)")
        }
    }

    func sendDM(msg: String, toPubKey: Data, partnerToken: Int32) {
        do {
            try DM!.sendText(
                toPubKey,
                partnerToken: partnerToken,
                message: msg,
                leaseTimeMS: 0,
                cmixParamsJSON: "".data
            )
        } catch let error {
            fatalError("Unable to send: " + error.localizedDescription)
        }
    }
    // Send a message to a channel by Channel ID (base64-encoded). If tags are provided, they are JSON-encoded and passed along.
    func sendDM(msg: String, channelId: String) {
        guard let cm = channelsManager else {
            print("sendDM(channel): Channels Manager not initialized")
            return
        }
        // Channel IDs are base64 in our storage; attempt base64 decode first, fallback to UTF-8 bytes
        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()
        do {
            // Lease time and params mimic JS example: MESSAGE_LEASE equivalent 0 (or tune as needed), empty cmix params
            try cm.sendMessage(
                channelIdData,
                message: msg,
                validUntilMS: 0,
                cmixParamsJSON: "".data,
                pingsJSON: nil
            )
        } catch {
            print("sendDM(channel) failed: \(error.localizedDescription)")
        }
    }

    func joinChannel(_ prettyPrint: String) async throws -> ChannelJSON {
        try await Task.sleep(for: .seconds(5))
        guard cmix != nil else { throw MyError.runtimeError("no net") }
        var err: NSError?
        let cmixId = cmix!.getID()
        let storageTag = String(
            data: storageTagListener!.data!,
            encoding: .utf8
        )
        
        // Use the same Channels DB path as created during initialization
        let channelsDir = stateDir.deletingLastPathComponent().appendingPathComponent("channels", isDirectory: true)
//        let dbPath = channelsDir.appendingPathComponent("channels.sqlite").path

        let noti = Bindings.BindingsLoadNotificationsDummy(cmixId, &err)
        if let e = err { throw MyError.runtimeError("could not load notifications dummy: \(e.localizedDescription)") }
        if noti == nil { throw MyError.runtimeError("notifications dummy was nil") }

        let cm = Bindings.BindingsLoadChannelsManager(
            cmixId,
            storageTag,
            /* dbFilePath: */ eventModelBuilder,
            /* extensionBuilderIDsJSON: */ nil,
            /* notificationsID: */ noti!.getID(),
            /* uiCallbacks: */ channelUICallbacks,
            &err
        )
        if let e = err { throw MyError.runtimeError("could not load channels manager: \(e.localizedDescription)") }
        if cm == nil { throw MyError.runtimeError("channels manager was nil") }
        
        // Retain Channels Manager for channel operations
        self.channelsManager = cm
     
        // Join the channel and parse the returned JSON
        let raw = try cm!.joinChannel(prettyPrint)
        let channel = try Parser.decodeChannel(from: raw)
        print("Joined channel: \(channel.name)")
        return channel
    }

    // Convenience: join a known channel by human-readable name (non-throwing)
    func joinChannel(name: String) async {
        // Map friendly names to the precomputed pretty-printed channel descriptor
        let descriptor: String?
        switch name {
        case "xxGeneralChat", "#general":
            descriptor = XX_GENERAL_CHAT
        default:
            descriptor = nil
        }
        guard let pretty = descriptor else {
            print("joinChannel(name:): Unknown channel name \(name); no-op")
            return
        }
        do {
            _ = try await joinChannel(pretty)
        } catch {
            print("joinChannel(name:): failed to join \(name): \(error)")
        }
    }

    // downloadNdf uses the mainnet URL to download and verify the
    // network definition file for the xx network.
    // As of this writing, using the xx network is free and using the public
    // network is OK. Check the xx network docs for updates.
    // You can test locally, with the integration or localenvironment
    // repositories with their own ndf files here:
    //  * https://git.xx.network/elixxir/integration
    //  * https://git.xx.network/elixxir/localenvironment
    // integration will run messaging tests against a local network,
    // and localenvironment will run a fixed network local to your machine.
    func downloadNDF(url: String, certFilePath: String) -> Data {
        let certString: String
        do {
            certString = try String(contentsOfFile: certFilePath)
        } catch let error {
            fatalError(
                "Missing network certificate, please include a mainnet, testnet,"
                    + "or localnet certificate in the Resources folder: "
                    + error.localizedDescription
            )
        }

        var err: NSError?
        let ndf = Bindings.BindingsDownloadAndVerifySignedNdfWithUrl(
            url,
            certString,
            &err
        )
        if err != nil {
            fatalError(
                "DownloadAndverifySignedNdfWithUrl(\(url), \(certString)) error: "
                    + err!.localizedDescription
            )
        }
        // Golang functions uss a `return val or nil, nil or err` pattern, so ndf will be valid data after
        // checking if the error has anything in it.
        return ndf!
    }

}
