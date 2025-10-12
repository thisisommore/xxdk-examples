import Foundation
import SwiftData

@Model
class Sender {
    @Attribute(.unique) var id: String
    var pubkey: Data
    //codename
    var codename: String
    // DM token for direct messaging (optional - nil means DM is disabled)
    var dmToken: Int32
    init(id: String, pubkey: Data, codename: String, dmToken: Int32 = 0) {
        self.id = id
        self.pubkey = pubkey
        self.codename = codename
        self.dmToken = dmToken
    }
}

