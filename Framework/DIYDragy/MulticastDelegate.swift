//
//  MulticastDelegate.swift
//  DIYDragy_Framework
//
//  Created by Chris Whiteford on 2020-05-06.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//

import Foundation
public class MulticastDelegate <T> {
  private let delegates: NSHashTable<AnyObject> = NSHashTable.weakObjects()
  
  public func add(delegate: T) {
    delegates.add(delegate as AnyObject)
  }
  
  public func remove(delegate: T) {
    for oneDelegate in delegates.allObjects.reversed() {
      if oneDelegate === delegate as AnyObject {
        delegates.remove(oneDelegate)
      }
    }
  }
  
  public func invoke(invocation: (T) -> ()) {
    for delegate in delegates.allObjects.reversed() {
      invocation(delegate as! T)
    }
  }
}

public func += <T: AnyObject> (left: MulticastDelegate<T>, right: T) {
  left.add(delegate: right)
}

public func -= <T: AnyObject> (left: MulticastDelegate<T>, right: T) {
  left.remove(delegate: right)
}
