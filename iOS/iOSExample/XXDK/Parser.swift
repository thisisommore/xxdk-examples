//
//  Parser.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import Foundation

// MARK: - Decoders / Parsers centralization
// This file centralizes JSON models and decode helpers used across the app.
// Add new payload models and decode helpers here to keep parsing consistent.

// Mirrors the TypeScript decoder mapping { IsReady: boolean, HowClose: number }
public struct IsReadyInfoJSON: Decodable {
    public let isReady: Bool
    public let howClose: Double

    private enum CodingKeys: String, CodingKey {
        case isReady = "IsReady"
        case howClose = "HowClose"
    }

    // Be tolerant of number-like strings or integers for HowClose
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isReady = try container.decode(Bool.self, forKey: .isReady)

        if let d = try? container.decode(Double.self, forKey: .howClose) {
            self.howClose = d
        } else if let i = try? container.decode(Int.self, forKey: .howClose) {
            self.howClose = Double(i)
        } else if let s = try? container.decode(String.self, forKey: .howClose),
                  let d = Double(s) {
            self.howClose = d
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [CodingKeys.howClose],
                      debugDescription: "Expected Double/Int/String convertible to Double for HowClose")
            )
        }
    }
}

// Public identity derived from a private identity blob
// Keys map to: PubKey, Codename, Color, Extension, CodesetVersion
public struct IdentityJSON: Decodable {
    public let pubkey: String
    public let codename: String
    public let color: String
    public let ext: String
    public let codeset: Int

    private enum CodingKeys: String, CodingKey {
        case pubkey = "PubKey"
        case codename = "Codename"
        case color = "Color"
        case ext = "Extension"
        case codeset = "CodesetVersion"
    }
}

// Channel info returned by JoinChannel
// Keys map to: ReceptionID, ChannelID, Name, Description
public struct ChannelJSON: Decodable {
    public let receptionId: String?
    public let channelId: String?
    public let name: String
    public let description: String

    private enum CodingKeys: String, CodingKey {
        case receptionId = "ReceptionID"
        case channelId = "ChannelID"
        case name = "Name"
        case description = "Description"
    }
}

// Channel send report returned by sendText/sendMessage
// Keys map to: messageID ([]byte -> base64 in JSON), ephId (int64)
public struct ChannelSendReportJSON: Decodable {
    public let messageID: Data?
    public let ephId: Int64?

    private enum CodingKeys: String, CodingKey {
        case messageID
        case ephId
    }
}

// Model message for getMessage responses
// Minimal struct containing only required fields: PubKey and MessageID
public struct ModelMessageJSON: Codable {
    public let pubKey: Data
    public let messageID: Data
    
    private enum CodingKeys: String, CodingKey {
        case pubKey = "PubKey"
        case messageID = "MessageID"
    }
    
    public init(pubKey: Data, messageID: Data) {
        self.pubKey = pubKey
        self.messageID = messageID
    }
}

public enum Parser {
    // Shared JSONDecoder for consistency
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // We use explicit CodingKeys above, so default strategy is fine.
        return d
    }()
    
    // Shared JSONEncoder for consistency
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    // MARK: - Decode helpers

    public static func decodeIsReadyInfo(from data: Data) throws -> IsReadyInfoJSON {
        try decoder.decode(IsReadyInfoJSON.self, from: data)
    }

    public static func decodeIdentity(from data: Data) throws -> IdentityJSON {
        try decoder.decode(IdentityJSON.self, from: data)
    }
    
    public static func decodeChannel(from data: Data) throws -> ChannelJSON {
        try decoder.decode(ChannelJSON.self, from: data)
    }

    public static func decodeChannelSendReport(from data: Data) throws -> ChannelSendReportJSON {
        try decoder.decode(ChannelSendReportJSON.self, from: data)
    }
    
    // MARK: - Encode helpers
    
    public static func encodeModelMessage(_ message: ModelMessageJSON) throws -> Data {
        try encoder.encode(message)
    }
}
