//
//  ByteQueue.swift
//  DIYDraggy
//
//  Created by Chris Whiteford on 2020-05-01.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//

import Foundation

public class DDByteQueue<T> {
    
    var arr:[T] = []
    
    public init() {
        
    }
    
    public func _synced(_ lock: Any, closure: () -> ()) {
        objc_sync_enter(lock)
        closure()
        objc_sync_exit(lock)
    }
    
    public func isEmpty() -> Bool {
        var returnValue: Bool = false
        
        _synced(self) {
            returnValue = arr.isEmpty
        }
        return returnValue
    }
    
    public func count() -> Int {
        var returnValue: Int = 0
        
        _synced(self) {
            returnValue = arr.count
        }
        return returnValue
    }
    
    public func enqueue(val:T) {
        _synced(self) {
            arr.append(val)
        }
    }
    
    public func insert(val:T, at:Int) {
        _synced(self) {
            arr.insert(val, at: at)
        }
    }
    public func dequeue() -> T {
        var returnValue: T?
        if !isEmpty() {
            _synced(self) {
                returnValue = arr.removeFirst()
            }
        } else {
            //Lets wait till we get some data
            while isEmpty() {
                usleep(10000)
            }
            
            _synced(self) {
                returnValue = arr.removeFirst()
            }
        }
        
        return returnValue!
    }
}
