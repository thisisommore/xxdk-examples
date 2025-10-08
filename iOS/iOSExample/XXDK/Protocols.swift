//
//  Helpers.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import Kronos
import Bindings
import SwiftData


 protocol XXDKP: ObservableObject, AnyObject {
    var ndf: Data? { get set }
    var DM: Bindings.BindingsDMClient? { get set }
    var dmReceiver: DMReceiver { get set }
    var codename: String? {get set}
    var cmix: Bindings.BindingsCmix? {get set}
    func setModelContext(_ ctx: ModelContext)
    func load() async
    func sendDM(msg: String, toPubKey: Data, partnerToken: Int32)
    func sendDM(msg: String, channelId: String)
    func sendReply(msg: String, channelId: String, replyToMessageIdB64: String)
    func sendReply(msg: String, toPubKey: Data, partnerToken: Int32, replyToMessageIdB64: String)
    func joinChannelFromURL(_ url: String) async throws -> ChannelJSON
    func joinChannel(_ prettyPrint: String) async throws -> ChannelJSON
    func getChannelPrivacyLevel(url: String) throws -> PrivacyLevel
    func getChannelFromURL(url: String) throws -> ChannelJSON
}
// These are common helpers extending the string class which are essential for working with XXDK
extension StringProtocol {
    var data: Data { .init(utf8) }
    var bytes: [UInt8] { .init(utf8) }
}
extension DataProtocol {
    var utf8: String { String(decoding: self, as: UTF8.self) }
}
