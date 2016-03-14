//
//  SocketIO+Rx.swift
//  RxChat
//
//  Created by Junior B. on 14/03/16.
//  Copyright © 2016 Sideeffects.xyz. All rights reserved.
//

import Foundation
import RxSwift
import SocketIOClientSwift

private var rxKey: UInt8 = 0 // We still need this boilerplate
extension SocketIOClient {
    
    var rx_event: Observable<SocketAnyEvent> {
        get {
            return associatedObject(self, key: &rxKey) {
                return Observable.create { observer -> Disposable in
                    
                    self.onAny() { event in
                        observer.onNext(event)
                    }
                    
                    return AnonymousDisposable {
                        //self.disconnect() //side effect, risky
                    }
                }.shareReplayLatestWhileConnected()
            } // Set the initial value of the var
        }
        set { associateObject(self, key: &rxKey, value: newValue) }
    }
}

//Ref: https://medium.com/@ttikitu/swift-extensions-can-add-stored-properties-92db66bce6cd#.2t442w1hp
func associatedObject<ValueType: AnyObject>(base: AnyObject, key: UnsafePointer<UInt8>, initialiser: () -> ValueType) -> ValueType {
    if let associated = objc_getAssociatedObject(base, key) as? ValueType {
        return associated
    }
    
    let associated = initialiser()
    objc_setAssociatedObject(base, key, associated, .OBJC_ASSOCIATION_RETAIN)
    
    return associated
}

func associateObject<ValueType: AnyObject>(base: AnyObject, key: UnsafePointer<UInt8>, value: ValueType) {
    objc_setAssociatedObject(base, key, value,.OBJC_ASSOCIATION_RETAIN)
}