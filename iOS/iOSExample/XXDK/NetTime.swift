//
//  NetTime.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//
import Kronos
import Bindings
class NetTime: NSObject, Bindings.BindingsTimeSourceProtocol {
    override init() {
        super.init()
        Kronos.Clock.sync()
    }
    
    func nowMs() -> Int64 {
        let curTime = Kronos.Clock.now
        if curTime == nil {
            Kronos.Clock.sync()
            return Int64(Date.now.timeIntervalSince1970)
        }
        return Int64(Kronos.Clock.now!.timeIntervalSince1970)
    }
}
