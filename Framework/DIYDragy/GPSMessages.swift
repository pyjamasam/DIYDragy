//
//  GPSMessages.swift
//  DIYDragy_Framework
//
//  Created by Chris Whiteford on 2020-05-01.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//

import Foundation


let kRadiusOfEarthInMM: Double = 6371010000

struct DDUBX_Constants {
    static let header1: UInt8 = 0xB5
    static let header2: UInt8 = 0x62
    struct NAV {
        static let classID: UInt8 = 0x01
        
        struct SAT {
            static let messageID: UInt8 = 0x35
        }
        
        struct POSLLH {
            static let messageID: UInt8 = 0x02
        }
    }
    
    struct ACK {
        static let classID: UInt8 = 0x05
        
        struct ACK {
            static let messageID: UInt8 = 0x01
        }
        
        struct NAK {
            static let messageID: UInt8 = 0x00
        }
    }
    
    struct CFG {
        static let classID: UInt8 = 0x06
        
        struct MSG {
            static let messageID: UInt8 = 0x01
        }
    }
    
}

public class DDUBX_Base : CustomStringConvertible {
    func parseFrom(data: Data) {  }
    
    public var description: String {
        return "<\(type(of: self))>"
    }
    
    public func __assembleUBXPacket(message: [UInt8]) -> [UInt8] {
        var finaldata: [UInt8] = [DDUBX_Constants.header1, DDUBX_Constants.header2]

        var runningCheckSum_A: UInt32 = 0;
        var runningCheckSum_B: UInt32 = 0;
        
        message.forEach {
            finaldata.append($0)
            
            runningCheckSum_A += UInt32($0)
            runningCheckSum_A = runningCheckSum_A & 0xFF
            runningCheckSum_B += runningCheckSum_A
            runningCheckSum_B = runningCheckSum_B & 0xFF
        }
        
        finaldata.append(UInt8(runningCheckSum_A))
        finaldata.append(UInt8(runningCheckSum_B))

        return finaldata
    }
    
    public func generateBinary() -> [UInt8] { return [] }
}

public class DDUBX_CGF_MSG : DDUBX_Base {
    public var msgClass: UInt8 = 0
    public var msgID: UInt8 = 0
    public var rate: UInt8 = 0
    
    override func parseFrom(data: Data) {
        self.msgClass = data[0]
        self.msgID = data[1]
        self.rate = data[2]
    }
    
    override public var description: String {
        return "<\(type(of: self)): msgClass = \(String(format:"0x%02X", msgClass))\tmsgID: \(String(format:"0x%02X", msgID))>"
    }
    
    override public func generateBinary() -> [UInt8] {
           //Lets get the binary representation of ourself
           var messageData: [UInt8] = []
           
           //Write class and message ids
           messageData.append(contentsOf: [DDUBX_Constants.CFG.classID, DDUBX_Constants.CFG.MSG.messageID])
           
           //Write out the length bytes
           messageData.append(contentsOf: [0x03, 0x00])
           
           //Write our payload bytes
           messageData.append(self.msgClass)
           messageData.append(self.msgID)
           messageData.append(self.rate)
           
           //Generate the checksum
           return self.__assembleUBXPacket(message: messageData)
       }
}

public class DDUBX_NAV_SAT : DDUBX_Base {
    public var iTOW: UInt32 = 0
    public var version: UInt8 = 0
    public var numSvs: UInt8 = 0
    
    override func parseFrom(data: Data) {
        let iTOWBytes:[UInt8] = [UInt8](data.subdata(in: 0...3))
        self.iTOW = iTOWBytes.withUnsafeBytes { $0.load(as: UInt32.self) }
        
        self.version = UInt8(data[4])
        self.numSvs = UInt8(data[5])
    }
    
    override public var description: String {
        return "<\(type(of: self)): iTOW = \(iTOW)\n\tversion: \(String(format:"0x%02X", version)), numSvs: \(numSvs)>"
    }
}


public class DDUBX_NAV_POSLLH : DDUBX_Base {
    public var iTOW: UInt32 = 0
    public var timestamp: Int64 = 0
    public var lon: Int32 = 0
    public var lat: Int32 = 0
    public var height: Int32 = 0
    public var hMSL: Int32 = 0
    public var hAcc: UInt32 = 0
    public var vAcc: UInt32 = 0

    public var gpsState: DDGPSState = DDGPSState.unknown
    
    override func parseFrom(data: Data) {
        self.timestamp = Date.quickMSSince1970()
        
        let iTOWBytes:[UInt8] = [UInt8](data.subdata(in: 0...3))
        self.iTOW = iTOWBytes.withUnsafeBytes { $0.load(as: UInt32.self) }
        
        let lonBytes:[UInt8] = [UInt8](data.subdata(in: 4...7))
        self.lon = lonBytes.withUnsafeBytes { $0.load(as: Int32.self) }
        
        let latBytes:[UInt8] = [UInt8](data.subdata(in: 8...11))
        self.lat = latBytes.withUnsafeBytes { $0.load(as: Int32.self) }
        
        let heightBytes:[UInt8] = [UInt8](data.subdata(in: 12...15))
        self.height = heightBytes.withUnsafeBytes { $0.load(as: Int32.self) }
        
        let hMSLBytes:[UInt8] = [UInt8](data.subdata(in: 16...19))
        self.hMSL = hMSLBytes.withUnsafeBytes { $0.load(as: Int32.self) }
        
        let hAccBytes:[UInt8] = [UInt8](data.subdata(in: 20...23))
        self.hAcc = hAccBytes.withUnsafeBytes { $0.load(as: UInt32.self) }
        
        let vAccBytes:[UInt8] = [UInt8](data.subdata(in: 24...27))
        self.vAcc = vAccBytes.withUnsafeBytes { $0.load(as: UInt32.self) }
               
        if (self.hAcc <= 2000) {
            //We should have enough resolution now to be as good as we can get
            self.gpsState = DDGPSState.highresfix
        } else if (self.hAcc <= 10000) {
            //This is a good enough lock for us to do what we need to do
            self.gpsState = DDGPSState.medresfix
        } else if (self.hAcc <= 50000) {
            //We should really wait for a better lock
            self.gpsState = DDGPSState.lowresfix
        } else if (self.hAcc > 50001) {
            //This isn't good enough to even attemt anything
            self.gpsState = DDGPSState.scanning
        }
    }
    
    public func difference(from: DDUBX_NAV_POSLLH) -> DDUBX_NAV_POSLLH_Difference {
        let returnVar:DDUBX_NAV_POSLLH_Difference = DDUBX_NAV_POSLLH_Difference()

        //Lets see how far we moved
        let lat1Degrees = Double(from.lat) / 10000000.0
        let lon1Degrees = Double(from.lon) / 10000000.0

        let lat2Degrees = Double(self.lat) / 10000000.0
        let lon2Degrees = Double(self.lon) / 10000000.0

        let dLat = (lat2Degrees-lat1Degrees).deg2rad()
        let dLon = (lon2Degrees-lon1Degrees).deg2rad()
        
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1Degrees.deg2rad()) * cos(lat2Degrees.deg2rad()) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        returnVar.distanceInMM = kRadiusOfEarthInMM * c; // Distance in mm

        if (returnVar.distanceInMM.isNaN) {
            returnVar.distanceInMM = 0
        }
        
        returnVar.time = Int32(self.iTOW) - Int32(from.iTOW)
        
        returnVar.speed = 3600.0/Double(returnVar.time)*returnVar.distanceInMM/1000.0
        
        return returnVar
    }
    
     override public func generateBinary() -> [UInt8] {
        //Lets get the binary representation of ourself
        var messageData: [UInt8] = []
        
        //Write class and message ids
        messageData.append(contentsOf: [DDUBX_Constants.NAV.classID, DDUBX_Constants.NAV.POSLLH.messageID])
        
        //Write out the length bytes
        messageData.append(contentsOf: [0x1C, 0x00])
        
        //Write our payload bytes
        messageData.append(contentsOf: self.iTOW.toBytes)
        messageData.append(contentsOf: self.lon.toBytes)
        messageData.append(contentsOf: self.lat.toBytes)
        messageData.append(contentsOf: self.height.toBytes)
        messageData.append(contentsOf: self.hMSL.toBytes)
        messageData.append(contentsOf: self.hAcc.toBytes)
        messageData.append(contentsOf: self.vAcc.toBytes)
        
        //Generate the checksum
        return self.__assembleUBXPacket(message: messageData)
    }
    
    
    override public var description: String {
        return "<\(type(of: self)): iTOW = \(iTOW)\n\tlat: \(lat), lon: \(lon)\n\theight: \(height), hMSL: \(hMSL)\n\thAcc: \(hAcc), vAcc: \(vAcc)>"
    }
}

public class DDUBX_NAV_POSLLH_Difference : CustomStringConvertible {
    public var time: Int32 = 0
    public var distanceInMM: Double = 0
    public var speed: Double = 0
    public var height: Int32 = 0
    
    public var description: String {
        return "<\(type(of: self)): time: \(time)ms\n\tdistance: \(distanceInMM)mm\n\tspeed: \(speed)\n\theight: \(height)m>"
    }
}


public class UBX_ACK_Base : DDUBX_Base {
    var clsID: UInt8 = 0
    var msgID: UInt8 = 0
    
    override func parseFrom(data: Data) {
        self.clsID = UInt8(data[0])
        self.msgID = UInt8(data[1])
    }
    
    override public var description: String {
        return "<\(type(of: self)): clsID = \(clsID)\n\tmsgID: \(msgID)>"
    }
}

public class UBX_ACK_ACK : DDUBX_Base {
    
}

public class UBX_ACK_NAK : DDUBX_Base {
    
}
