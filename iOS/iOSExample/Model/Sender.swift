import Foundation
import SwiftData

@Model
class Sender {
    var id: String
    var pubkey: Data
    //codename
    var codename: String
    init(id: String, pubkey: Data, codename: String) {
        self.id = id
        self.pubkey = pubkey
        self.codename = codename
    }
}

