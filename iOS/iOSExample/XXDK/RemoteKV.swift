//
//  RemoteKV.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//
import Kronos
import Bindings
import OSLog

final class RemoteKVKeyChangeListener: NSObject, Bindings.BindingsKeyChangedByRemoteCallbackProtocol {
    let key: String
    var data: Data?
    private var handle: Int = 0
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.app",
                             category: "RemoteKV")


    // Convenience initializer that starts listening immediately
    init(key: String, remoteKV: Bindings.BindingsRemoteKV, version: Int64 = 0, localEvents: Bool = true) throws {
        log.debug("are we there")
        self.key = key
        self.data = nil
        super.init()
        do {
            let v = try remoteKV.get(key, version: version)
            self.data = v
            log.debug("RemoteKV initial get succeeded for key: \(self.key, privacy: .public), bytes: \(v.count, privacy: .public)")
        } catch {
            log.warning("RemoteKV initial get failed for key: \(self.key, privacy: .public) — \(String(describing: error), privacy: .public)")
            print("RemoteKV initial get failed for key: \(self.key): \(error)")
        }

        try remoteKV.listen(onRemoteKey: key, version: version, callback: self, localEvents: localEvents, ret0_: &handle)
    }

    // Called by the Bindings RemoteKV when the key changes. Adjust the method name/signature
    // if the generated Swift interface differs.
    func callback(_ key: String?, old: Data?, new: Data?, opType: Int8) {
        print("new data for \(self.key), new: \(String(describing: new))")
        self.data = new
    }
    
}

