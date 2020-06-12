//
//  RollingAverage.swift
//  DIYDragy_Framework
//
//  Created by Chris Whiteford on 2020-05-29.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//

import Foundation

public class DDRollingAverage {
    var _items: [Double] = [Double]()
    var _windowSize: Int32 = 5
    
    public init (windowSize: Int32) {
        self._windowSize = windowSize
    }
    
    public func add(_ item: Double) -> Double {
        var average: Double = 0
        
        if self._items.count >= self._windowSize {
            self._items.remove(at: 0)
        }
        self._items.append(item)
        
        self._items.forEach {
            average += $0
        }
        
        return average/Double(self._items.count)
    }
    
    public func reset() {
        self._items.removeAll()
    }
}
