//
//  LinearInterpolation.swift
//  DIYDraggy
//
//  Created by Chris Whiteford on 2020-05-01.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//

import Foundation

public class LinearInterpolation {
    private var n : Int
    private var x : [Double]
    private var y : [Double]
    init (x: [Double], y: [Double]) {
        assert(x.count == y.count)
        self.n = x.count-1
        self.x = x
        self.y = y
    }

    func Interpolate(t: Double) -> Double {
        if t <= x[0] { return y[0] }
        for i in 1...n {
            if t <= x[i] {
                let ans = (t-x[i-1]) * (y[i] - y[i-1]) / (x[i]-x[i-1]) + y[i-1]
                return ans
            }
        }
        return y[n]
    }
}
