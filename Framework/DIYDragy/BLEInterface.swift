//
//  BLEInterface.swift
//  DIYDragy_Framework
//
//  Created by Chris Whiteford on 2020-05-04.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//

import Foundation
import CoreBluetooth
import Logging


#if targetEnvironment(simulator)
import SwiftSocket
#endif

let kBLEDeviceName: String = "DIYDragy"
let kUartServiceUUID = CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
let kUartCharacteristicRXDUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
let kUartCharacteristicTXDUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

public enum DDBLEDeviceState: UInt {
    case unknown = 0
    case scanning
    case connecting
    case connected
    case disconected
    case error
    
    public var description: String {
      get {
        switch self {
            case .unknown:
                return "Unknown"
            case .scanning:
                return "Scanning"
            case .connecting:
                return "Connecting"
            case .connected:
                return "Connected"
            case .disconected:
                return "Disconnected"
            case .error:
                return "Error"
        }
      }
    }
}

public protocol DDBLEInterfaceDelegate: AnyObject {
    func didUpdateState(state: DDBLEDeviceState)
    func didReadRSSI(didReadRSSI RSSI: NSNumber)
    func hasBytesAvailable(bytesAvailable: Data )
}

public final class DDBLEDevice : NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var logger = Logger(label: "BLEInterface")
    
    static public let shared = DDBLEDevice()
    public let delegates: MulticastDelegate<DDBLEInterfaceDelegate> = MulticastDelegate<DDBLEInterfaceDelegate>()
    
    var _currentState: DDBLEDeviceState = DDBLEDeviceState.unknown
    
    public var state: DDBLEDeviceState {
        get {
            return _currentState
        }
    }
    
    var centralManager:CBCentralManager! = nil
    var peripheral:CBPeripheral! = nil
    
    var rxdCharacteristic:CBCharacteristic! = nil
    var txdCharacteristic:CBCharacteristic! = nil
    
    var connectionTimeoutTask: DispatchWorkItem! = nil
    
#if targetEnvironment(simulator)
    let server = UDPServer(address: "127.0.0.1", port: 9999)
#endif
    
    private override init() {
        super.init()
        
        logger.logLevel = .debug
        logger.info("Starting up...")
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func _setState(state: DDBLEDeviceState) {
        if (state != _currentState) {
            _currentState = state
            
            self.delegates.invoke {
                $0.didUpdateState(state: _currentState)
            }
        }
    }
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
#if !targetEnvironment(simulator)
        if central.state == CBManagerState.poweredOn {
            logger.info("Bluetooh Online")
        } else {
            logger.info("Bluetooh Offline")
        }
#else
        logger.info("Using UDP listener for GPS data")
        DispatchQueue.global(qos: .background).async {
            while true {
                let receivedBytes = self.server.recv(1024)
                //print(receivedBytes)
                
                //print("Received \(receivedBytes.0!)")
            
                if self._currentState == .connected {
                    //Only forward along bytes if we are "connected" during testing
                    var receivedData: Data = Data()
                    
                    receivedBytes.0!.forEach{
                        //print("\(String(format:"0x%02X  ", $0))", terminator: "")
                        receivedData.append($0)
                    }
            
                    self.delegates.invoke {
                        $0.hasBytesAvailable(bytesAvailable: receivedData)
                    }
                }
            }
        }
#endif
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber) {
        let deviceName = (advertisementData as NSDictionary).object(forKey: CBAdvertisementDataLocalNameKey) as? NSString

        if deviceName?.contains(kBLEDeviceName) == true {
            //We found a device we want.  Time to stop looking and connect
            self.centralManager.stopScan()

            logger.debug("DIYDragy found.  Connecting peripheral...")
            
            self._setState(state: DDBLEDeviceState.connecting)
            
            self.peripheral = peripheral
            self.peripheral.delegate = nil

            central.connect(self.peripheral, options: nil)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if (self.peripheral.delegate == nil) {
            logger.debug("Peripheral connected.  Finding services...")

            self.peripheral.delegate = self
            peripheral.discoverServices(nil)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.disconnect()
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        //When error is set it was most likley some kinda connection error.  If its nil it was because we asked to disconnect
        if (error != nil) {
            
            self._setState(state: DDBLEDeviceState.connected)
            
            self.disconnect()
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
            let thisService = service as CBService

            if service.uuid == kUartServiceUUID {
                logger.debug("Service found.  Finding characteristics...")
                peripheral.discoverCharacteristics(nil, for: thisService)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics! {
            let thisCharacteristic = characteristic as CBCharacteristic

            if (thisCharacteristic.uuid == kUartCharacteristicRXDUUID) {
                //This is inbound TO the device
                logger.debug("Found RXD characteristic")
                
                self.rxdCharacteristic = thisCharacteristic
            } else if (thisCharacteristic.uuid == kUartCharacteristicTXDUUID) {
                //This is outbound FROM the device
                logger.debug("Found TXD characteristic")
                
                self.txdCharacteristic = thisCharacteristic
                self.peripheral.setNotifyValue(true, for: self.txdCharacteristic)
            }
        }

        if (self.txdCharacteristic != nil && self.rxdCharacteristic != nil)
        {
            self._setState(state: DDBLEDeviceState.connected)
            
            connectionTimeoutTask.cancel()
            connectionTimeoutTask = nil
            
            self.peripheral.readRSSI()
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        self.delegates.invoke {
            $0.didReadRSSI(didReadRSSI: RSSI)
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1)) { [weak self] in
            if (self?.peripheral != nil && self?.peripheral.state == CBPeripheralState.connected) {
                self?.peripheral.readRSSI()
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if (characteristic == self.txdCharacteristic) {
            if let data = characteristic.value {
                self.delegates.invoke {
                    $0.hasBytesAvailable(bytesAvailable: data)
                }
            }
        }
    }
    
    public func send(data: Data) {
#if !targetEnvironment(simulator)
        let maxWriteSize: Int = self.peripheral.maximumWriteValueLength(for: CBCharacteristicWriteType.withoutResponse)
        //print(maxWriteSize)
        
        var dataPos: Int = 0
        var dataLeft: Int = data.count
        
        while (dataLeft > 0) {
            
            let bufferSize: Int = min(dataLeft, maxWriteSize)
            //print("send loop \(bufferSize)")
            
            let lowerBounds: Int = dataPos
            let upperBounds: Int = dataPos + bufferSize-1
            
            peripheral.writeValue(data.subdata(in: lowerBounds...upperBounds), for: self.rxdCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
            
            dataPos += bufferSize
            dataLeft -= bufferSize
        }
#endif
    }
    
    public func connect() {
        logger.info("Searching for DIYDragy...")
        self._setState(state: DDBLEDeviceState.scanning)
        
#if !targetEnvironment(simulator)
        connectionTimeoutTask = DispatchWorkItem { [weak self] in
            self?.logger.info("Timeout connecting")
            self?._setState(state: DDBLEDeviceState.error)


            self?.centralManager.stopScan()
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(5), execute: self.connectionTimeoutTask)
        
        //Start the scan
        centralManager.scanForPeripherals(withServices: nil)
#else
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1)) {
            self._setState(state: DDBLEDeviceState.connected)
        }
        
#endif

    }
    
    public func disconnect() {
        logger.info("Disconnecting...")
       
        
        connectionTimeoutTask?.cancel()
#if targetEnvironment(simulator)
         
#else
        
        if (self.peripheral?.state == CBPeripheralState.connected) {
            self.peripheral?.setNotifyValue(false, for: self.txdCharacteristic)
        }
        
        self.txdCharacteristic = nil
        self.rxdCharacteristic = nil
        
        if (self.peripheral != nil) {
            self.peripheral.delegate = nil
            self.centralManager.cancelPeripheralConnection(self.peripheral)
            self.peripheral = nil
        }
#endif
        
        if (_currentState != .error) {
            //Change our state to disconnected as long as we aren't currently in error
            //This helps the UI show the error state and not just loose it in a blink
            self._setState(state: DDBLEDeviceState.disconected)
        }
    }
    
    public func toggleConnection() {
        if (_currentState == DDBLEDeviceState.connected) {
            self.disconnect()
        } else if(_currentState == DDBLEDeviceState.unknown ||
                    _currentState == DDBLEDeviceState.disconected ||
                    _currentState == DDBLEDeviceState.error) {
            self.connect()
        }
    }
}
