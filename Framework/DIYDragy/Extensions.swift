//
//  Extensions.swift
//  DIYDragy_Framework
//
//  Created by Chris Whiteford on 2020-05-07.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//

import Foundation
import SwiftUI

extension Comparable {
    public func clamp<T: Comparable>(lower: T, upper: T) -> T {
        return min(max(self as! T, lower), upper)
    }
}

extension Date {
    static func quickMSSince1970() -> Int64 {
        return Int64((Date.timeIntervalBetween1970AndReferenceDate + Date.timeIntervalSinceReferenceDate) * 1000)
    }
}

extension Double {
    func deg2rad() -> Double {
        return self * (Double.pi/180.0)
    }
    
    func rad2deg() -> Double {
        return self * (180.0/Double.pi)
    }
}

extension Data {
    func subdata(in range: ClosedRange<Index>) -> Data {
        return subdata(in: range.lowerBound ..< range.upperBound + 1)
    }
}


protocol UIntToBytesConvertable {
    var toBytes: [UInt8] { get }
}

extension UIntToBytesConvertable {
    func toByteArr<T>(endian: T, count: Int) -> [UInt8] {
        var _endian = endian
        let bytePtr = withUnsafePointer(to: &_endian) {
            $0.withMemoryRebound(to: UInt8.self, capacity: count) {
                UnsafeBufferPointer(start: $0, count: count)
            }
        }
        return [UInt8](bytePtr)
    }
}

extension UInt16: UIntToBytesConvertable {
    var toBytes: [UInt8] {
        return toByteArr(endian: self.littleEndian,
                         count: MemoryLayout<UInt16>.size)
    }
}

extension Int16: UIntToBytesConvertable {
    var toBytes: [UInt8] {
        return toByteArr(endian: self.littleEndian,
                         count: MemoryLayout<Int16>.size)
    }
}

extension UInt32: UIntToBytesConvertable {
    var toBytes: [UInt8] {
        return toByteArr(endian: self.littleEndian,
                         count: MemoryLayout<UInt32>.size)
    }
}

extension Int32: UIntToBytesConvertable {
    var toBytes: [UInt8] {
        return toByteArr(endian: self.littleEndian,
                         count: MemoryLayout<Int32>.size)
    }
}

extension UInt64: UIntToBytesConvertable {
    var toBytes: [UInt8] {
        return toByteArr(endian: self.littleEndian,
                         count: MemoryLayout<UInt64>.size)
    }
}

extension String {
   func appendLineToURL(fileURL: URL) throws {
        try (self + "\n").appendToURL(fileURL: fileURL)
    }

    func appendToURL(fileURL: URL) throws {
        let data = self.data(using: String.Encoding.utf8)!
        try data.append(fileURL: fileURL)
    }
}

extension Data {
    func append(fileURL: URL) throws {
        if let fileHandle = FileHandle(forWritingAtPath: fileURL.path) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        }
        else {
            try write(to: fileURL, options: .atomic)
        }
    }
}

extension Array where Element: Equatable {
    public func all(where predicate: (Element) -> Bool) -> [Element]  {
        return self.compactMap { predicate($0) ? $0 : nil }
    }
}
