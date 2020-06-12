//
//  main.swift
//  DIYDragy
//
//  Created by Chris Whiteford on 2020-05-01.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//

import Foundation
import Lilliput

import DIYDragy_Framework

func _doReadByte(from: ReadOnlyFile) -> UInt8? {
    let readBytes = OrderedBuffer<LittleEndian>(count: 1)
    
    if (try! from.read(into: readBytes) == 0) {
        return nil
    }
    
    return readBytes.getUInt8(at: 0)
}

class Main : NSObject, DDBLEInterfaceDelegate, DDGPSProcessorDelegate, DDPerformanceProcessorDelegate {
    
    //DDBLEInterfaceDelegate
    func didUpdateState(state: DDBLEDeviceState) {
        print("Dragy device state changed: " + state.description)
    }
    
    func didReadRSSI(didReadRSSI RSSI: NSNumber) {
        //print("Dragy RSSI: \(RSSI)dB")
    }
    
    func hasBytesAvailable(bytesAvailable: Data) {
    }
    
    
    //DDGPSProcessorDelegate
    func processedPOSLLH(message: DDUBX_NAV_POSLLH) {
    }
    
    func didUpdateState(state: DDGPSState) {
        print("GPS state changed: " + state.description)
    }
    
    //DDPerformanceProcessorDelegate
    func didUpdateState(state: DDPerformanceProcessorState) {
        print("Performance Processor state changed: " + state.description)
    }
    
    
    
    func run() {
        _ = DDResultsStore.shared
        DDBLEDevice.shared.delegates.add(delegate: self)
        DDGPSProcessor.shared.delegates.add(delegate: self)
        DDPerformanceProcessor.shared.delegates.add(delegate: self)


        DDBLEDevice.shared.delegates.add(delegate: DDGPSProcessor.shared)
        DDGPSProcessor.shared.delegates.add(delegate: DDPerformanceProcessor.shared)
        
        /*DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1)) {
                DDBLEDevice.shared.connect()
        }*/
        
        /*DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(5)) {
                DDPerformanceProcessor.shared.arm()
        }*/
        
        
        
        DDPerformanceProcessor.shared.arm()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1)) {
            let binaryFile = try! BinaryFile.open(forReadingAtPath: "/Users/chris/Desktop/pull1.txt")
            while true {
                let readByte:UInt8?  = _doReadByte(from: binaryFile)

                if (readByte == nil)
                {
                    break
                }
                
                DDGPSProcessor.shared.hasBytesAvailable(bytesAvailable: Data([readByte!]))
            }
        }
        
        dispatchMain()
    }
}

//let main: Main = Main()
//main.run()

class RollingAverage {
    var _items: [Double] = [Double]()
    var _windowSize: Int32 = 5
    
    init (windowSize: Int32) {
        self._windowSize = windowSize
    }
    
    public func add(item: Double) -> Double {
        
        var average: Double = 0
        
        if self._items.count >= self._windowSize {
    
        }
        
        return average
    }
}

