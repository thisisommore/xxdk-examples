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
    "<Speakeasy-v3:xxGeneralChat|description:Talking about the xx network|level:Public|created:1674152234202224215|secrets:rb+rK0HsOYcPpTF6KkpuDWxh7scZbj74kVMHuwhgUR0=|RMfN+9pD/JCzPTIzPk+pf0ThKPvI425hye4JqUxi3iA=|368|1|/qE8BEgQQkXC6n0yxeXGQjvyklaRH6Z+Wu8qvbFxiuw=>"

// This resolves to "Resources/mainnet.crt" in the project folder for iOSExample
public var MAINNET_CERT =
    Bundle.main.path(forResource: "mainnet", ofType: "crt")
    ?? "unknown resource path"
enum MyError: Error {
    case runtimeError(String)
}


public class XXDK: XXDKP {
    // Channels Manager retained for channel sends
    private var channelsManager: Bindings.BindingsChannelsManager?
    func sendDM(msg: String) {

    }

    private var networkUrl = MAINNET_URL
    private var networkCert = MAINNET_CERT
    private var stateDir: URL
    private var selfPubKey: Data?

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

        // Always create a fresh, unique temp working directory per init
        // e.g., <system tmp>/<UUID> and use "ekv" within it for state
        do {
            let basePath = try FileManager.default.url(
                           for: .documentDirectory,
                           in: .userDomainMask,
                           appropriateFor: nil,
                           create: false)
                       stateDir = basePath.appendingPathComponent("xxAppState")
                       if !FileManager.default.fileExists(atPath: stateDir.path) {
                           try FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
                       }
                       stateDir = stateDir.appendingPathComponent("ekv")
        } catch let err {
            print(
                "ERROR: failed to get state directory: "
                    + err.localizedDescription
            )
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
                print(
                    "SwiftData: Failed to delete all data at startup: \(error)"
                )
            }
        } else {
            print("SwiftData: No modelContext set; skipping deleteAllData()")
        }

        let downloadedNdf = downloadNDF(url: self.networkUrl, certFilePath: self.networkCert)
        await MainActor.run {
            ndf = downloadedNdf
        }

        // NOTE: Secret should be pulled from keychain
        let secret = "Hello".data
        // NOTE: Empty string forces defaults, these are settable but it is recommended that you use the defaults.
        let cmixParamsJSON = "".data
        if !FileManager.default.fileExists(atPath: stateDir.path) {
            var err: NSError?
            Bindings.BindingsNewCmix(ndf?.utf8, stateDir.path, secret, "", &err)
            if let err {
                print(
                    "ERROR: could not create new Cmix: "
                        + err.localizedDescription
                )
                fatalError(
                    "could not create new Cmix: " + err.localizedDescription
                )
            }
        }
        var err: NSError?
        let loadedCmix = Bindings.BindingsLoadCmix(
            stateDir.path,
            secret,
            cmixParamsJSON,
            &err
        )
        await MainActor.run {
            cmix = loadedCmix
        }
        if let err {
            print("ERROR: could not load Cmix: " + err.localizedDescription)
            fatalError("could not load Cmix: " + err.localizedDescription)
        }

        guard let cmix else {
            print("ERROR: cmix is not available")
            fatalError("cmix is not available")
        }

        let receptionID = cmix.getReceptionID()?.base64EncodedString()
        print("cMix Reception ID: \(receptionID ?? "<nil value>")")

        let dmID: Data
        do {
            dmID = try cmix.ekvGet("MyDMID")
        } catch {
            print("Generating DM Identity...")
            // NOTE: This will be deprecated in favor of generateCodenameIdentity(...)
            let _dmID = Bindings.BindingsGenerateChannelIdentity(
                cmix.getID(),
                &err
            )
            if _dmID == nil {
                print("ERROR: dmId is nil")
                fatalError("dmId is nil")
            }
            dmID = _dmID!
            if let err {
                print(
                    "ERROR: could not generate codename id: "
                        + err.localizedDescription
                )
                fatalError(
                    "could not generate codename id: "
                        + err.localizedDescription
                )
            }
            print("Exported Codename Blob: " + dmID.base64EncodedString())
            do {
                try cmix.ekvSet("MyDMID", value: dmID)
            } catch let error {
                print("ERROR: could not set ekv: " + error.localizedDescription)
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
        if let err {
            print(
                "ERROR: could not derive public identity: "
                    + err.localizedDescription
            )
            fatalError(
                "could not derive public identity: " + err.localizedDescription
            )
        }

        if let pubId = publicIdentity {
            do {
                let identity = try Parser.decodeIdentity(from: pubId)
                await MainActor.run {
                    self.codename = identity.codename
                }
                // Persist codename for later reads
                if let nameData = identity.codename.data(using: .utf8) {
                    do { try cmix.ekvSet("MyCodename", value: nameData) } catch
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
            cmix.getID(),
            &err
        )
        if let err {
            print(
                "ERROR: could not load notifications: "
                    + err.localizedDescription
            )
            fatalError(
                "could not load notifications: " + err.localizedDescription
            )
        }

        let receiverBuilder = DMReceiverBuilder(receiver: dmReceiver)

        //Note: you can use `newDmManagerMobile` here instead if you want to work with
        //an SQLite database.
        // This interacts with the network and requires an accurate clock to connect or you'll see
        // "Timestamp of request must be within last 5 seconds." in the logs.
        // If you have trouble shutdown and start your emulator.
        let dmClient = Bindings.BindingsNewDMClient(
            cmix.getID(),
            (notifications?.getID())!,
            dmID,
            receiverBuilder,
            dmReceiver,
            &err
        )
        await MainActor.run {
            DM = dmClient
        }
        if let err {
            print(
                "ERROR: could not load dm client: " + err.localizedDescription
            )
            fatalError("could not load dm client: " + err.localizedDescription)
        }

        print(
            "DMPUBKEY: \(DM?.getPublicKey()?.base64EncodedString() ?? "empty pubkey")"
        )
        print("DMTOKEN: \(DM?.getToken() ?? 0)")

        do {
            try cmix.startNetworkFollower(5000)
            cmix.wait(forNetwork: 30000)
        } catch let error {
            print("ERROR: cannot start network: " + error.localizedDescription)
            fatalError("cannot start network: " + error.localizedDescription)
        }

        remoteKV = cmix.getRemoteKV()

        let storageTagListener: RemoteKVKeyChangeListener
        // Start RemoteKV listener for the storage tag during load so it's ready before channel join
        do {
            storageTagListener = try RemoteKVKeyChangeListener(
                key: "channels-storage-tag",
                remoteKV: remoteKV!,
                version: 0,
                localEvents: true
            )
        } catch {
            print("ERROR: failed to set storageTagListener \(error)")
            fatalError("failed to set storageTagListener \(error)")
        }

        self.storageTagListener = storageTagListener
        // Run readiness + Channels Manager creation in the background, retrying every 2 seconds until success

        Task {
            while true {
                let readyData = try cmix.isReady(0.1)
                let readinessInfo = try Parser.decodeIsReadyInfo(
                    from: readyData
                )
                if !readinessInfo.isReady {
                    print(
                        "cMix not ready yet (howClose=\(readinessInfo.howClose)) — retrying in 2s…"
                    )
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    continue
                }
                let cmixId = cmix.getID()
                // Attempt to create Channels Manager on the MainActor
                var err: NSError?

                guard
                    let noti = Bindings.BindingsLoadNotificationsDummy(
                        cmixId,
                        &err
                    )
                else {
                    print("ERROR: BindingsLoadNotificationsDummy returned nil")
                    fatalError("BindingsLoadNotificationsDummy returned nil")
                }

                //                let dbPath = channelsDir.appendingPathComponent("channels.sqlite").path

                await MainActor.run {
                    eventModelBuilder = EventModelBuilder(
                        model: EventModel(
                            storageTag: String(describing: storageTagListener.data)
                        )
                    )
                }
               

                if let ctx = self.modelContext {
                    self.eventModelBuilder?.configure(modelContext: ctx)
                }

                guard
                    let cm = Bindings.BindingsNewChannelsManager(
                        cmix.getID(),
                        dmID,
                        eventModelBuilder,
                        nil,
                        noti.getID(),
                        channelUICallbacks,
                        &err
                    )
                else {
                    print("ERROR: no cm")
                    fatalError("no cm")
                }

                // Retain Channels Manager for future channel sends
                await MainActor.run {
                    self.channelsManager = cm
                    storageTagListener.data = Data(cm.getStorageTag().utf8)
                }

                if let e = err {
                    print("ERROR: \(err)")
                } else {
                    //                     Successfully created Channels Manager; join channel in background and exit loop
                    Task {
                        do {
                            _ = try await self.joinChannel(XX_GENERAL_CHAT)
                        } catch {
                            print(
                                "Failed to join channel in background: \(error)"
                            )
                        }
                    }
                    break
                }
                
            }
        }

        guard let codename, let DM, let modelContext else {
            print("ERROR: codename/DM/modelContext not there")
            fatalError("codename/DM/modelContext not there")
        }
        // After loading, if we have a codename, ensure a self chat exists
        let name = codename.trimmingCharacters(in: .whitespacesAndNewlines)
        if !codename.isEmpty {
            // Use the DM public key (base64) as the Chat.id for DMs
            guard let selfPubKeyData = DM.getPublicKey() else {
                print("ERROR: self pub key data is nil")
                fatalError("self pub key data is nil")
            }
            let selfPubKeyB64 = selfPubKeyData.base64EncodedString()
            do {
                try await MainActor.run {
                    // Check if a DM chat already exists for this public key (id == pubkey b64)
                    let descriptor = FetchDescriptor<Chat>(
                        predicate: #Predicate { $0.id == selfPubKeyB64 }
                    )
                    let existing = try modelContext.fetch(descriptor)
                    if existing.isEmpty {
                        let token64 = DM.getToken()
                        let tokenU32 = UInt32(truncatingIfNeeded: token64)
                        let selfToken = Int32(bitPattern: tokenU32)
                        let chat = Chat(
                            pubKey: selfPubKeyData,
                            name: name,
                            dmToken: selfToken
                        )
                        modelContext.insert(chat)
                        try modelContext.save()
                        print("[XXDK] is ready = true")
                    }
                }
            } catch {
                print(
                    "HomeView: Failed to create self chat for \(codename): \(error)"
                )
            }
        }
        // Ensure initial channel exists locally and join only if not present
        do {
            let cd = try await joinChannel(XX_GENERAL_CHAT)
            let channelId = cd.channelId ?? "xxGeneralChat"
            try await MainActor.run {
                let check = FetchDescriptor<Chat>(
                    predicate: #Predicate { $0.id == channelId }
                )
                let existingChannel = try modelContext.fetch(check)
                if existingChannel.isEmpty {
                    let channelChat = Chat(channelId: channelId, name: cd.name)
                    modelContext.insert(channelChat)
                    try modelContext.save()
                }
            }
        } catch {
            print(
                "HomeView: Failed to ensure initial channel xxGeneralChat: \(error)"
            )
        }
    }

    // Persist an outgoing message to SwiftData using the given message ID
    private func persistOutgoingMessage(
        chatId: String,
        defaultName: String,
        message: String,
        messageIdB64: String,
        dmToken: Int32? = nil,
        replyTo: String? = nil
    ) {
        guard let ctx = self.modelContext else {
            fatalError("persistOutgoingMessage: modelContext not set")
        }
        do {
            let descriptor = FetchDescriptor<Chat>(
                predicate: #Predicate { $0.id == chatId }
            )
            guard let chat = try ctx.fetch(descriptor).first else {
                fatalError(
                    "persistOutgoingMessage: Chat not found for id=\(chatId)"
                )
            }
            print("XXDK: ChatMessage(message: \"\(message)\", isIncoming: false, chat: \(chat.id), id: \(messageIdB64), replyTo: \(replyTo ?? "nil"))")
            let outMsg = ChatMessage(
                message: message,
                isIncoming: false,
                chat: chat,
                id: messageIdB64,
                replyTo: replyTo
            )
            chat.messages.append(outMsg)
            try ctx.save()
        } catch {
            fatalError("persistOutgoingMessage failed: \(error)")
        }
    }

    // Persist a reaction to SwiftData
    private func persistReaction(
        messageIdB64: String,
        emoji: String,
        targetMessageId: String,
        isMe: Bool = true
    ) {
        guard let ctx = self.modelContext else {
            print("persistReaction: modelContext not set")
            return
        }
        Task { @MainActor in
            do {
                let reaction = MessageReaction(
                    id: messageIdB64, targetMessageId: targetMessageId, emoji: emoji, isMe: isMe
                )
                ctx.insert(reaction)
                try ctx.save()
            } catch {
                print("persistReaction failed: \(error)")
            }
        }
    }

    // Send a message to a channel by Channel ID (base64-encoded). If tags are provided, they are JSON-encoded and passed along.
    func sendDM(msg: String, channelId: String) {
        guard let cm = channelsManager else {
            fatalError("sendDM(channel): Channels Manager not initialized")
        }
        // Channel IDs are base64 in our storage; attempt base64 decode first, fallback to UTF-8 bytes
        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
            ?? Data()
        do {
            let reportData = try cm.sendMessage(
                channelIdData,
                message: encodeMessage(msg),
                validUntilMS: 0,
                cmixParamsJSON: "".data,
                pingsJSON: nil
            )
            do {
                let report = try Parser.decodeChannelSendReport(
                    from: reportData
                )
                if let mid = report.messageID {
                    print(
                        "Channel sendMessage messageID: \(mid.base64EncodedString())"
                    )
                    let chatId = channelId
                    let defaultName: String = {
                        if let ctx = self.modelContext {
                            let descriptor = FetchDescriptor<Chat>(
                                predicate: #Predicate { $0.id == chatId }
                            )
                            if let found = try? ctx.fetch(descriptor).first {
                                return found.name
                            }
                        }
                        return "Channel \(String(chatId.prefix(8)))"
                    }()
                    self.persistOutgoingMessage(
                        chatId: chatId,
                        defaultName: defaultName,
                        message: msg,
                        messageIdB64: mid.base64EncodedString(),
                        dmToken: nil
                    )
                } else {
                    print("Channel sendMessage returned no messageID")
                }
            } catch {
                print("Failed to decode ChannelSendReport: \(error)")
            }
        } catch {
            print("sendDM(channel) failed: \(error.localizedDescription)")
        }
    }

    // Send a reply to a specific message in a channel
    func sendReply(msg: String, channelId: String, replyToMessageIdB64: String) {
        guard let cm = channelsManager else {
            fatalError("sendReply(channel): Channels Manager not initialized")
        }
        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
            ?? Data()
        guard let replyToMessageId = Data(base64Encoded: replyToMessageIdB64) else {
            print("sendReply(channel): invalid reply message id base64")
            return
        }
        do {
            let reportData = try cm.sendReply(
                channelIdData,
                message: encodeMessage(msg),
                messageToReactTo: replyToMessageId,
                validUntilMS: 0,
                cmixParamsJSON: "".data,
                pingsJSON: nil
            )
            do {
                let report = try Parser.decodeChannelSendReport(
                    from: reportData
                )
                if let mid = report.messageID {
                    print(
                        "Channel sendReply messageID: \(mid.base64EncodedString())"
                    )
                    let chatId = channelId
                    let defaultName: String = {
                        if let ctx = self.modelContext {
                            let descriptor = FetchDescriptor<Chat>(
                                predicate: #Predicate { $0.id == chatId }
                            )
                            if let found = try? ctx.fetch(descriptor).first {
                                return found.name
                            }
                        }
                        return "Channel \(String(chatId.prefix(8)))"
                    }()
                    self.persistOutgoingMessage(
                        chatId: chatId,
                        defaultName: defaultName,
                        message: msg,
                        messageIdB64: mid.base64EncodedString(),
                        dmToken: nil,
                        replyTo: replyToMessageIdB64
                    )
                } else {
                    print("Channel sendReply returned no messageID")
                }
            } catch {
                print("Failed to decode ChannelSendReport (reply): \(error)")
            }
        } catch {
            print("sendReply(channel) failed: \(error.localizedDescription)")
        }
    }

    // Send a reaction to a specific message in a channel
    public func sendReaction(
        emoji: String,
        toMessageIdB64: String,
        inChannelId channelId: String
    ) {
        guard let cm = channelsManager else {
            fatalError(
                "sendReaction(channel): Channels Manager not initialized"
            )
        }
        // Channel IDs are base64 in our storage; attempt base64 decode first, fallback to UTF-8 bytes
        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
            ?? Data()
        guard let targetMessageId = Data(base64Encoded: toMessageIdB64) else {
            print("sendReaction(channel): invalid target message id base64")
            return
        }
        do {
            // Attempt to send the reaction via Channels Manager
            let reportData = try cm.sendReaction(
                channelIdData,
                reaction: emoji,
                messageToReactTo: targetMessageId,
                validUntilMS: Bindings.BindingsValidForeverBindings,
                cmixParamsJSON: "".data,
            )
            // Decode send report with the shared Parser
            do {
                let report = try Parser.decodeChannelSendReport(
                    from: reportData
                )
                if let mid = report.messageID {
                    print(
                        "Channel sendReaction messageID: \(mid.base64EncodedString())"
                    )
                } else {
                    print("Channel sendReaction returned no messageID")
                }
                // Persist locally as 'me'
                self.persistReaction(
                    messageIdB64: report.messageID!.base64EncodedString(),
                    emoji: emoji,
                    targetMessageId: toMessageIdB64,
                    isMe: true,
                )
            } catch {
                print("Failed to decode ChannelSendReport (reaction): \(error)")
            }
        } catch {
            print("sendReaction(channel) failed: \(error.localizedDescription)")
        }
        
    }

    func sendDM(msg: String, toPubKey: Data, partnerToken: Int32) {
        guard let DM else {
            print("ERROR: DM not there")
            fatalError("DM not there")
        }
        do {
            let reportData = try DM.sendText(
                toPubKey,
                partnerToken: partnerToken,
                message: msg,
                leaseTimeMS: 0,
                cmixParamsJSON: "".data
            )

            do {
                let report = try Parser.decodeChannelSendReport(
                    from: reportData
                )
                if let mid = report.messageID {
                    print("DM sendText messageID: \(mid.base64EncodedString())")
                    let chatId = toPubKey.base64EncodedString()
                    let defaultName: String = {
                        if let ctx = self.modelContext {
                            let descriptor = FetchDescriptor<Chat>(
                                predicate: #Predicate { $0.id == chatId }
                            )
                            if let found = try? ctx.fetch(descriptor).first {
                                return found.name
                            }
                        }
                        return "Direct Message"
                    }()
                     self.persistOutgoingMessage(
                         chatId: chatId,
                         defaultName: defaultName,
                         message: msg,
                         messageIdB64: mid.base64EncodedString(),
                         dmToken: partnerToken
                     )
                } else {
                    print("DM sendText returned no messageID")
                }
            } catch {
                print("Failed to decode ChannelSendReport: \(error)")
            }
        } catch let error {
            print("ERROR: Unable to send: " + error.localizedDescription)
            fatalError("Unable to send: " + error.localizedDescription)
        }
    }

    // Send a reply to a specific message in a DM conversation
    func sendReply(msg: String, toPubKey: Data, partnerToken: Int32, replyToMessageIdB64: String) {
        guard let DM else {
            print("ERROR: DM not there")
            fatalError("DM not there")
        }
        guard let replyToMessageId = Data(base64Encoded: replyToMessageIdB64) else {
            print("sendReply(DM): invalid reply message id base64")
            return
        }
        do {
            let reportData = try DM.sendReply(
                toPubKey,
                partnerToken: partnerToken,
                replyMessage: msg,
                replyToBytes: replyToMessageId,
                leaseTimeMS: 0,
                cmixParamsJSON: "".data
            )
            do {
                let report = try Parser.decodeChannelSendReport(
                    from: reportData
                )
                if let mid = report.messageID {
                    print("DM sendReply messageID: \(mid.base64EncodedString())")
                    let chatId = toPubKey.base64EncodedString()
                    let defaultName: String = {
                        if let ctx = self.modelContext {
                            let descriptor = FetchDescriptor<Chat>(
                                predicate: #Predicate { $0.id == chatId }
                            )
                            if let found = try? ctx.fetch(descriptor).first {
                                return found.name
                            }
                        }
                        return "Direct Message"
                    }()
                    self.persistOutgoingMessage(
                        chatId: chatId,
                        defaultName: defaultName,
                        message: msg,
                        messageIdB64: mid.base64EncodedString(),
                        dmToken: partnerToken,
                        replyTo: replyToMessageIdB64
                    )
                } else {
                    print("DM sendReply returned no messageID")
                }
            } catch {
                print("Failed to decode ChannelSendReport (DM reply): \(error)")
            }
        } catch let error {
            print("ERROR: Unable to send reply: " + error.localizedDescription)
            fatalError("Unable to send reply: " + error.localizedDescription)
        }
    }

    // Send a reaction to a specific message in a DM conversation
    public func sendReaction(
        emoji: String,
        toMessageIdB64: String,
        toPubKey: Data,
        partnerToken: Int32
    ) {
        guard let DM else {
            print("ERROR: DM not there")
            fatalError("DM not there")
        }
        guard let targetMessageId = Data(base64Encoded: toMessageIdB64) else {
            print("sendReaction(DM): invalid target message id base64")
            return
        }
        do {
            let reportData = try DM.sendReaction(
                toPubKey,
                partnerToken: partnerToken,
                reaction: emoji,
                reactToBytes: targetMessageId,
                cmixParamsJSON: "".data
            )
            // Decode send report with the shared Parser (same as text send)
            do {
                let report = try Parser.decodeChannelSendReport(
                    from: reportData
                )
                if let mid = report.messageID {
                    print(
                        "DM sendReaction messageID: \(mid.base64EncodedString())"
                    )
                } else {
                    print("DM sendReaction returned no messageID")
                }
                // Persist locally as 'me'
                self.persistReaction(
                    messageIdB64: report.messageID!.base64EncodedString(),
                    emoji: emoji, targetMessageId: toMessageIdB64,
                    isMe: true
                )
            } catch {
                print(
                    "Failed to decode ChannelSendReport (DM reaction): \(error)"
                )
            }
        } catch let error {
            print(
                "ERROR: Unable to send reaction: " + error.localizedDescription
            )
            fatalError("Unable to send reaction: " + error.localizedDescription)
        }

    }

    /// Join a channel using a URL (public share link)
    /// - Parameter url: The channel share URL
    /// - Returns: Decoded ChannelJSON containing channel information
    /// - Throws: Error if DecodePublicURL or joinChannel fails
    func joinChannelFromURL(_ url: String) async throws -> ChannelJSON {
        var err: NSError?
        
        // Decode the URL to get pretty print format
        let prettyPrint = Bindings.BindingsDecodePublicURL(url, &err)
        
        if let error = err {
            throw error
        }
        
        // Join using the pretty print format
        return try await joinChannel(prettyPrint)
    }
    
    /// Join a channel using pretty print format
    /// - Parameter prettyPrint: The channel descriptor in pretty print format
    /// - Returns: Decoded ChannelJSON containing channel information
    /// - Throws: Error if joining fails
    func joinChannel(_ prettyPrint: String) async throws -> ChannelJSON {
        try await Task.sleep(for: .seconds(20))
        guard let cmix else { throw MyError.runtimeError("no net") }
        guard let storageTagListener else {
            print("ERROR: no storageTagListener")
            fatalError("no storageTagListener")
        }
        guard let storageTagData = storageTagListener.data else {
            print("ERROR: no storageTagListener data")
            fatalError("no storageTagListener data")
        }
        var err: NSError?
        let cmixId = cmix.getID()
        let storageTag = String(
            data: storageTagData,
            encoding: .utf8
        )

        // Use the same Channels DB path as created during initialization
        let channelsDir = stateDir.deletingLastPathComponent()
            .appendingPathComponent("channels", isDirectory: true)
        //        let dbPath = channelsDir.appendingPathComponent("channels.sqlite").path

        guard let noti = Bindings.BindingsLoadNotificationsDummy(cmixId, &err)
        else {
            print("ERROR: notifications dummy was nil")
            fatalError("notifications dummy was nil")
        }
        if let e = err {
            throw MyError.runtimeError(
                "could not load notifications dummy: \(e.localizedDescription)"
            )
        }

        let cm = Bindings.BindingsLoadChannelsManager(
            cmixId,
            storageTag,
            /* dbFilePath: */ eventModelBuilder,
            /* extensionBuilderIDsJSON: */ nil,
            /* notificationsID: */ noti.getID(),
            /* uiCallbacks: */ channelUICallbacks,
            &err
        )
        if let e = err {
            throw MyError.runtimeError(
                "could not load channels manager: \(e.localizedDescription)"
            )
        }
        guard let cm else {
            throw MyError.runtimeError("channels manager was nil")
        }

        // Retain Channels Manager for channel operations
        self.channelsManager = cm

        // Join the channel and parse the returned JSON
        let raw = try cm.joinChannel(prettyPrint)
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
            print(
                "ERROR: Missing network certificate, please include a mainnet, testnet,or localnet certificate in the Resources folder: "
                    + error.localizedDescription
            )
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
        if let err {
            print(
                "ERROR: DownloadAndverifySignedNdfWithUrl(\(url), \(certString)) error: "
                    + err.localizedDescription
            )
            fatalError(
                "DownloadAndverifySignedNdfWithUrl(\(url), \(certString)) error: "
                    + err.localizedDescription
            )
        }
        // Golang functions uss a `return val or nil, nil or err` pattern, so ndf will be valid data after
        // checking if the error has anything in it.
        return ndf!
    }
    
    // MARK: - Channel URL Utilities
    
    /// Get the privacy level for a given channel URL
    /// - Parameter url: The channel share URL
    /// - Returns: PrivacyLevel indicating if password is required (secret) or not (public)
    /// - Throws: Error if GetShareUrlType fails
    public func getChannelPrivacyLevel(url: String) throws -> PrivacyLevel {
        var err: NSError?
        var typeValue: Int = 0
        Bindings.BindingsGetShareUrlType(url, &typeValue, &err)
        
        if let error = err {
            throw error
        }
        
        return typeValue == 2 ? .secret : .publicChannel
    }
    
    /// Get channel data from a channel URL
    /// - Parameter url: The channel share URL
    /// - Returns: Decoded ChannelJSON containing channel information
    /// - Throws: Error if DecodePublicURL, GetChannelJSON, or JSON decoding fails
    public func getChannelFromURL(url: String) throws -> ChannelJSON {
        var err: NSError?
        
        // Step 1: Decode the URL to get pretty print
        let prettyPrint = Bindings.BindingsDecodePublicURL(url, &err)
        
        if let error = err {
            throw error
        }
        
        // Step 2: Get channel JSON from pretty print
        guard let channelJSONString = Bindings.BindingsGetChannelJSON(prettyPrint, &err) else {
            throw err ?? NSError(domain: "XXDK", code: -2, userInfo: [NSLocalizedDescriptionKey: "GetChannelJSON returned nil"])
        }
        
        if let error = err {
            throw error
        }
        
        return try Parser.decodeChannel(from: channelJSONString)
    }
    
    /// Decode a private channel URL with password
    /// - Parameters:
    ///   - url: The private channel share URL
    ///   - password: The password to decrypt the URL
    /// - Returns: Pretty print format of the channel
    /// - Throws: Error if DecodePrivateURL fails
    public func decodePrivateURL(url: String, password: String) throws -> String {
        var err: NSError?
        let prettyPrint = Bindings.BindingsDecodePrivateURL(url, password, &err)
        
        if let error = err {
            throw error
        }
        
        return prettyPrint
    }
    
    /// Get channel data from a private channel URL with password
    /// - Parameters:
    ///   - url: The private channel share URL
    ///   - password: The password to decrypt the URL
    /// - Returns: Decoded ChannelJSON containing channel information
    /// - Throws: Error if DecodePrivateURL, GetChannelJSON, or JSON decoding fails
    public func getPrivateChannelFromURL(url: String, password: String) throws -> ChannelJSON {
        var err: NSError?
        
        // Step 1: Decode the private URL with password to get pretty print
        let prettyPrint = try decodePrivateURL(url: url, password: password)
        
        // Step 2: Get channel JSON from pretty print
        guard let channelJSONString = Bindings.BindingsGetChannelJSON(prettyPrint, &err) else {
            throw err ?? NSError(domain: "XXDK", code: -2, userInfo: [NSLocalizedDescriptionKey: "GetChannelJSON returned nil"])
        }
        
        if let error = err {
            throw error
        }
        
        return try Parser.decodeChannel(from: channelJSONString)
    }
    
    /// Enable direct messages for a channel
    /// - Parameter channelId: The channel ID (base64-encoded)
    /// - Throws: Error if EnableDirectMessages fails or channels manager is not initialized
    public func enableDirectMessages(channelId: String) throws {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }
        
        // Channel IDs are base64 in our storage; attempt base64 decode first, fallback to UTF-8 bytes
        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()
        
        do {
            try cm.enableDirectMessages(channelIdData)
        } catch {
            fatalError("failed to enable direct messages \(error)")
        }
        
        print("Successfully enabled direct messages for channel: \(channelId)")
    }
    
    /// Disable direct messages for a channel
    /// - Parameter channelId: The channel ID (base64-encoded)
    /// - Throws: Error if DisableDirectMessages fails or channels manager is not initialized
    public func disableDirectMessages(channelId: String) throws {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }
        
        // Channel IDs are base64 in our storage; attempt base64 decode first, fallback to UTF-8 bytes
        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()
        
        do {
            try cm.disableDirectMessages(channelIdData)
        } catch {
            fatalError("failed to disable direct messages \(error)")
        }
        
        print("Successfully disabled direct messages for channel: \(channelId)")
    }
    
    /// Check if direct messages are enabled for a channel
    /// - Parameter channelId: The channel ID (base64-encoded)
    /// - Returns: True if DMs are enabled, false otherwise
    /// - Throws: Error if AreDMsEnabled fails or channels manager is not initialized
    public func areDMsEnabled(channelId: String) throws -> Bool {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }
        
        // Channel IDs are base64 in our storage; attempt base64 decode first, fallback to UTF-8 bytes
        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()
        
        var result = ObjCBool(false)
 
        
        try cm.areDMsEnabled(channelIdData, ret0_: &result)
        
      
        
        return result.boolValue
    }
    
    /// Leave a channel
    /// - Parameter channelId: The channel ID (base64-encoded)
    /// - Throws: Error if LeaveChannel fails or channels manager is not initialized
    public func leaveChannel(channelId: String) throws {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }
        
        // Channel IDs are base64 in our storage; attempt base64 decode first, fallback to UTF-8 bytes
        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()
        
        do {
            try cm.leaveChannel(channelIdData)
        } catch {
            fatalError("failed to leave channel \(error)")
        }
        
        print("Successfully left channel: \(channelId)")
    }

}
