//
//  DMRB.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

// DmReceiverBuilder is a wrapper for a stateful (database-based)
// DMReceiver implementation.

import Bindings
class DMReceiverBuilder: NSObject, Bindings.BindingsDMReceiverBuilderProtocol {
    private var r: DMReceiver
    
    init(receiver: DMReceiver) {
        self.r = receiver
        super.init()
    }
    
    func build(_ path: String?) -> (any BindingsDMReceiverProtocol)? {
        return r
    }
}
