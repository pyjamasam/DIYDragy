//
//  GPSProcessor.swift
//  DIYDragy_Framework
//
//  Created by Chris Whiteford on 2020-05-02.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//

import Foundation
import CoreLocation
import Logging

/*extension Data {
    func append(to: URL) throws {
        if let fileHandle = FileHandle((forWritingAtPath: to.path) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        }
        else {
            try write(to: to, options: .atomic)
        }
    }
}*/

public protocol DDGPSProcessorDelegate: AnyObject {
    func processedPOSLLH(message: DDUBX_NAV_POSLLH)
    func didUpdateState(state: DDGPSState)
}

public enum DDGPSState: UInt {
    case unknown = 0
    case scanning = 1
    case lowresfix = 2
    case medresfix = 3
    case highresfix = 4
    
    public var description: String {
      get {
        switch self {
            case .unknown:
                return "Unknown"
            case .scanning:
                return "Scanning"
            case .lowresfix:
                return "Low Resolution Fix"
            case .medresfix:
                return "Medium Resolution Fix"
            case .highresfix:
                return "High Resolution Fix"
        }
      }
    }
}

public class DDGPSProcessor : NSObject, DDBLEInterfaceDelegate, CLLocationManagerDelegate {
    var logger = Logger(label: "GPSProcessor")
    
    static public let shared = DDGPSProcessor()
    public let delegates: MulticastDelegate<DDGPSProcessorDelegate> = MulticastDelegate<DDGPSProcessorDelegate>()
    
#if TARGET_OS_IPHONE
    var locationManager: CLLocationManager? = nil
    var _lastLocationFromPhone: CLLocation? = nil
#endif
    
    var _byteQueue: DDByteQueue<UInt8> = DDByteQueue<UInt8>()
    var _currentState: DDGPSState = DDGPSState.unknown
    
    public var state: DDGPSState {
        get {
            return _currentState
        }
    }
        
    private override init() {
        super.init()
        
        logger.logLevel = .debug
        logger.info("Starting up...")

#if TARGET_OS_IPHONE
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        
        if CLLocationManager.authorizationStatus() == .notDetermined {
               locationManager?.requestWhenInUseAuthorization()
        }
        
        //Fetch a location fix so we can use it if we need get new AGPS data
        //We are useing this method because it results getting a response faster.
        locationManager?.startUpdatingLocation()
#endif
        
        //Start up our processing thread
        DispatchQueue.global(qos: .background).async {
            self._process()
        }
    }
    
    //MARK: DDBLEInterfaceDelegate
    public func didUpdateState(state: DDBLEDeviceState) {
        //Sort out if our data source is online or not so we can update our state to reflect that
        //Wait till the byte queue is empty (since it shouldn't be filled now as our source doesn't exist)
        while (self._byteQueue.count() > 0) {
            usleep(50000)
        }
        
        //Now that we have no bytes mark us as in an unknown state
        self._setState(state: .unknown)
        
        if (state == .connected) {
            //We just connected to the BLE device/GPS.  Lets ensure that we get a quick GPS lock by sorting out the AGPS data
            
            self._disablePOSLLH()
            self._loadAGPS()
            self._enablePOSLLH()
        }
    }
    
    public func didReadRSSI(didReadRSSI RSSI: NSNumber) { }
    
    public func hasBytesAvailable(bytesAvailable: Data ) {
        //Consume these bytes
        bytesAvailable.forEach{
        //bytesAvailable.forEach {
            self._byteQueue.enqueue(val: $0)
        }
    }

#if TARGET_OS_IPHONE
    //MARK: CLLocationManagerDelegate
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        //We have a location.  Lets contnue to build up our AGPS request here based on what we have just gotten
        
        _lastLocationFromPhone = locations[0]
        
        //Since we have a location now (and even if its not that percise its still prob good enough for AGPS lookup)
        locationManager?.startUpdatingLocation()
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    }
#endif
    
    //MARK: Implementaion
    func _setState(state: DDGPSState) {
        if (state != _currentState) {
            _currentState = state
            
            self.delegates.invoke {
                $0.didUpdateState(state: _currentState)
            }
        }
    }
    
    func _process() {
        
        var processState: UInt8 = 0
        var classId: UInt8 = 0
        var messageId: UInt8 = 0
        
        while (true) {
            //Wait for some bytes to process
            let byteToProcess: UInt8  = _byteQueue.dequeue()
            //print("\(String(format:"0x%02X  ", byteToProcess))", terminator: "")
            
            switch(processState)
            {
            case 0:
                //Initial sync byte
                if (byteToProcess == DDUBX_Constants.header1) {
                    processState = 1
                } else {
                    //Not what we are looking for.  Back to the begining
                    processState = 0
                }
            case 1:
                //Second sync byte
                if (byteToProcess == DDUBX_Constants.header2) {
                    processState = 2
                } else {
                    //Not what we are looking for.  Back to the begining
                    processState = 0
                }
            case 2:
                processState = 3
                    
                classId = byteToProcess
            case 3:
                //print("Got message id: \(String(format:"0x%02X", byteToProcess))")
                messageId = byteToProcess
                
                //Check with message we have and gather up the bytes for it
                var runningCheckSum_A: UInt32 = 0;
                var runningCheckSum_B: UInt32 = 0;
                
                //Deal with the class byte for the running checksum
                runningCheckSum_A += UInt32(classId)
                runningCheckSum_A = runningCheckSum_A & 0xFF
                runningCheckSum_B += runningCheckSum_A
                runningCheckSum_B = runningCheckSum_B & 0xFF
                
                //Deal with the id byte for the running checksum
                runningCheckSum_A += UInt32(messageId)
                runningCheckSum_A = runningCheckSum_A & 0xFF
                runningCheckSum_B += runningCheckSum_A
                runningCheckSum_B = runningCheckSum_B & 0xFF
                
                //next two bytes should be length.  Lets see what that is
                let payloadLengthBytes:[UInt8] = [_byteQueue.dequeue(), _byteQueue.dequeue()]
                let payloadLength = payloadLengthBytes.withUnsafeBytes { $0.load(as: UInt16.self) }
                //logger.debug("payloadLength: \(payloadLength)")
                
                payloadLengthBytes.forEach {
                    runningCheckSum_A += UInt32($0)
                    runningCheckSum_A = runningCheckSum_A & 0xFF
                    runningCheckSum_B += runningCheckSum_A
                    runningCheckSum_B = runningCheckSum_B & 0xFF
                }
                
                //now read all the rest of the bytes that the message says we need to (make sure its a sane length first
                //We don't support any messages with a length > 1024 just to protect our self
                if (payloadLength < 1024) {
                    var packetBytes: [UInt8] = []
                    for _ in 0..<payloadLength {
                        let byte: UInt8 = _byteQueue.dequeue()
                        packetBytes.append(byte)
                        
                        runningCheckSum_A += UInt32(byte)
                        runningCheckSum_A = runningCheckSum_A & 0xFF
                        runningCheckSum_B += runningCheckSum_A
                        runningCheckSum_B = runningCheckSum_B & 0xFF
                    }
                        
                    //logger.debug("Finished reading \(payloadLength) bytes")
                    
                    //Read the checksum
                    let checksumBytes:[UInt8] = [_byteQueue.dequeue(), _byteQueue.dequeue()]
                    if (checksumBytes[0] == runningCheckSum_A && checksumBytes[1] == runningCheckSum_B) {
                        //Checksum OK.
                        let packetData: Data = Data(packetBytes)
                        
                        switch (classId) {
                        case DDUBX_Constants.NAV.classID:
                            switch (messageId) {
                            case DDUBX_Constants.NAV.SAT.messageID:
                                let ubxMessage: DDUBX_NAV_SAT = DDUBX_NAV_SAT()
                                ubxMessage.parseFrom(data: packetData)
                            
                                print(ubxMessage.description)
                            case DDUBX_Constants.NAV.POSLLH.messageID:
                                let ubxMessage: DDUBX_NAV_POSLLH = DDUBX_NAV_POSLLH()
                                ubxMessage.parseFrom(data: packetData)
                            
                                self._setState(state: ubxMessage.gpsState)
                            
                                self.delegates.invoke {
                                    $0.processedPOSLLH(message: ubxMessage)
                                }
                            default:
                                logger.warning("Got a ubx message id we don't understand: clsID: \(String(format:"0x%02X", classId)), msgID: \(String(format:"0x%02X", messageId))")
                            }
                        case DDUBX_Constants.ACK.classID:
                            switch (messageId) {
                            case DDUBX_Constants.ACK.NAK.messageID:
                                let ubxMessage: UBX_ACK_NAK = UBX_ACK_NAK()
                                ubxMessage.parseFrom(data: packetData)
                            
                                print(ubxMessage.description)
                            case DDUBX_Constants.ACK.ACK.messageID:
                                let ubxMessage: UBX_ACK_ACK = UBX_ACK_ACK()
                                ubxMessage.parseFrom(data: packetData)
                            
                                print(ubxMessage.description)
                            default:
                                logger.warning("Got a ubx message id we don't understand: clsID: \(String(format:"0x%02X", classId)), msgID: \(String(format:"0x%02X", messageId))")
                            }
                        default:
                           logger.warning("Got a ubx class id we don't understand: clsID: \(String(format:"0x%02X", classId))")
                        }
                        
                        
                        //Back to the start we go
                        processState = 0
                        
                    } else {
                        
                        logger.debug("Bad Checksum")
                        //Checksum Bad.  Un-wind all the bytes back into the queue incase we dropped a byte so we don't miss another message
                        _byteQueue.insert(val: checksumBytes[1], at: 0)
                        _byteQueue.insert(val: checksumBytes[0], at: 0)
                        
                        for i in (0...(packetBytes.count-1)).reversed() {
                            _byteQueue.insert(val: packetBytes[i], at: 0)
                        }
                        
                        //Back to the start we go
                        processState = 0
                        continue
                    }
                } else {
                    logger.error("Got a ubx packet that was too big: \(payloadLength) (class: 0x01, \(byteToProcess)")
                    
                    processState = 0
                    continue
                }
            default:
                processState = 0
            }
        }
    }
    
    public func _loadAGPS() {
#if TARGET_OS_IPHONE
        //Check to see if we have AGPS data on disk and how old it is.
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let url = NSURL(fileURLWithPath: path)
        let pathComponent = url.appendingPathComponent("agps_data.ubx")
        let filePath = pathComponent?.path
        
        var fileUsable: Bool = false
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: filePath!) {
            //File exists.  Check age
            let attrs: NSDictionary = try! FileManager.default.attributesOfItem(atPath: filePath!) as NSDictionary
            
            
            let currentDate = Date()
            if (currentDate.timeIntervalSince(attrs.fileModificationDate()!) >  14400.0)
            {
                //The agps file is too old.  We should fetch it fresh
                fileUsable = false
            } else {
                //The file is new enough that we can use
                //TDOO: check to see if the position we are curretly at is quite diffrent from the files position.  Possible re-fetch is required.
                fileUsable = true
            }
        } else {
            fileUsable = false
        }
        
        
        if (!fileUsable) {
            //Need to fetch a new AGPS file.
            let agpsRequestURL:URL = URL(string: String(format: "https://online-live1.services.u-blox.com/GetOnlineData.ashx?token=G-c88DS2fUKzLKsDh03PNw;gnss=gps,gal;datatype=alm;lat=%f;lon=%f;alt=%f;pacc=%f", _lastLocationFromPhone!.coordinate.latitude, _lastLocationFromPhone!.coordinate.longitude, _lastLocationFromPhone!.altitude, _lastLocationFromPhone!.horizontalAccuracy))!
            print(agpsRequestURL)
            
            let task = URLSession.shared.dataTask(with: agpsRequestURL) { data, response, error in
               
                if let error = error {
                    print(error)
                   //self.handleClientError(error)
                   return
                }
                guard let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode) else {
                   //self.handleServerError(response)
                   return
                }
               
                if let mimeType = httpResponse.mimeType, mimeType == "application/ubx" {
                    //We got the data we wanted.  Lets write it out to disk
                    try! data!.write(to: pathComponent!)
                }
            }
            task.resume()
        }
        
        //At this poin we should have a valid file on disk to send to the GPS.  Lets load it up and send it over
        let aGPSData: Data = try! Data(contentsOf:pathComponent!)
        
        DDBLEDevice.shared.send(data: aGPSData)
#endif
    }
    
    public func _disablePOSLLH() {
        let outboundMessage: DDUBX_CGF_MSG = DDUBX_CGF_MSG()
        outboundMessage.msgClass = DDUBX_Constants.NAV.classID
        outboundMessage.msgID = DDUBX_Constants.NAV.POSLLH.messageID
        outboundMessage.rate = 0
        
        
        DDBLEDevice.shared.send(data: Data.init(outboundMessage.generateBinary()))
    }
    
    public func _enablePOSLLH() {
        let outboundMessage: DDUBX_CGF_MSG = DDUBX_CGF_MSG()
        outboundMessage.msgClass = DDUBX_Constants.NAV.classID
        outboundMessage.msgID = DDUBX_Constants.NAV.POSLLH.messageID
        outboundMessage.rate = 1
        
        DDBLEDevice.shared.send(data: Data.init(outboundMessage.generateBinary()))
    }
}
