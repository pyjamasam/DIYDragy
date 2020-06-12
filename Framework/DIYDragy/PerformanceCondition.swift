//
//  Condition.swift
//  DIYDraggy
//
//  Created by Chris Whiteford on 2020-05-02.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//

import Foundation
import SwiftyJSON

public class DDPerformanceCondition_Base : CustomStringConvertible {
    var _originTime: UInt32 = 0
    var _originOneFootTime: UInt32 = 0
    
    var _name: String = ""
    var _id: String = ""
    
    var identifier: String {
        return _id
    }
    
    var _time_start: UInt32 = 0
    var _time_end: UInt32 = 0
    
    var _needsCheck: Bool = true
    public var completed: Bool = false
    
    init(id:String, name: String) {
        self._name = name
        self._id = id
    }
    
    public func reset() {
        self._time_start = 0
        self._time_end = 0
        self._needsCheck = true
        self.completed = false
    }
    
    public func finish() {
    }
    
    public func setOriginTimes(startTime: UInt32, oneFootStartTime: UInt32) {
        self._originTime = startTime
        self._originOneFootTime = oneFootStartTime
    }
    
    public func check(rollingDistance: Double, previousMessage: DDUBX_NAV_POSLLH, previousDifference: DDUBX_NAV_POSLLH_Difference, currentMessage: DDUBX_NAV_POSLLH , newDifference:DDUBX_NAV_POSLLH_Difference) {
    }
    
    public var description: String {
        return "<\(type(of: self)): \(self._name)>"
    }
    
    public var json: String {
        return "{}"
    }
}

public class DDPerformanceCondition_Speed : DDPerformanceCondition_Base {
    var _speed_start: Double? = nil
    var _speed_end: Double? = nil
    
    public init(id: String, toSpeed: Double, withName: String) {
        super.init(id: id, name: withName)
        
        self._speed_end = toSpeed
    }
    
    public init(id: String, fromSpeed: Double, toSpeed: Double, withName: String) {
        super.init(id: id, name: withName)
        
        self._speed_start = fromSpeed
        self._speed_end = toSpeed
    }
    
    func _completionTime(use1FootTime: Bool) -> Double {
        var used_start_time: UInt32 = 0
        if (self._time_start != 0) {
            used_start_time = self._time_start
        } else {
            if (use1FootTime) {
                used_start_time = self._originOneFootTime
            } else {
                used_start_time = self._originTime
            }
        }
        
        return (Double(self._time_end - used_start_time) / 1000.0)
    }
    
    override public var description: String {
        var returnString: String = ""
            
        if (self.completed) {
            returnString = "in "
            
            returnString += String(format:"%0.2fs", _completionTime(use1FootTime: false))
            if (self._time_start == 0) {
                returnString += String(format:" (1ft - %0.2fs)", _completionTime(use1FootTime: true))
            }
        } else {
            returnString += "incomplete"
        }
            
         return "\(self._name) - \(returnString)"
    }
    
    override public var json: String {
        var returnJson = JSON()
        
        if (completed) {
            returnJson["time"] = JSON(String(format:"%0.2f", _completionTime(use1FootTime: false)))
            if (self._time_start == 0) {
                returnJson["time-1ft"]  = JSON(String(format:"%0.2f", _completionTime(use1FootTime: true)))
            }
        }
        
        return returnJson.rawString([writingOptionsKeys.castNilToNSNull: true])!
    }
    
    override public func check(rollingDistance: Double, previousMessage: DDUBX_NAV_POSLLH, previousDifference: DDUBX_NAV_POSLLH_Difference, currentMessage: DDUBX_NAV_POSLLH , newDifference:DDUBX_NAV_POSLLH_Difference) {
        if (!self._needsCheck) { return; }
        
        if (self._speed_start != nil) {
            if (newDifference.speed >= self._speed_start! && self._time_start == 0) {
                //print("Hit start speed \(self.speed_start!) between \(previousMessage.iTOW) and \(newMessage.iTOW).  Extroplating...")
                let original_times:[Double] = [0, Double(newDifference.time)]
                let original_speeds: [Double] = [previousDifference.speed, newDifference.speed]

                let ipol = LinearInterpolation(x: original_speeds, y: original_times)

                let y = ipol.Interpolate(t: self._speed_start!)
                self._time_start = previousMessage.iTOW + UInt32(y);
            }
        }
        
        if (self._speed_end != nil) {
            if (newDifference.speed >= self._speed_end! && self._time_end == 0) {
                //print("Hit end speed \(self.speed_end!) between \(previousMessage.iTOW) and \(newMessage.iTOW).  Extroplating...")
                let original_times:[Double] = [0, Double(newDifference.time)]
                let original_speeds: [Double] = [previousDifference.speed, newDifference.speed]

                let ipol = LinearInterpolation(x: original_speeds, y: original_times)

                let y = ipol.Interpolate(t: self._speed_end!)
                self._time_end = previousMessage.iTOW + UInt32(y);
            }
        }
        
        if (self._speed_start != nil && self._time_start != 0 && self._speed_end != nil && self._time_end != 0) {
            _needsCheck = false
            completed = true
        } else if (self._speed_end != nil && self._time_end != 0) {
            _needsCheck = false
            completed = true
        }
    }
}

public class DDPerformanceCondition_Distance : DDPerformanceCondition_Base {
    var _distance_end: Double? = nil
    
    var _capture_speed: Bool = false
    var _captured_speed: Double = 0
    
    public init(id: String, toDistance: Double, withName: String) {
        super.init(id: id, name: withName)
        
        self._distance_end = toDistance
        self._capture_speed = false
    }
    
    public init(id: String, toDistance: Double, captureSpeed: Bool, withName: String) {
        super.init(id: id, name: withName)
        
        self._distance_end = toDistance
        self._capture_speed = captureSpeed
    }
    
    override public func reset() {
        super.reset()
        
        self._captured_speed = 0
    }
    
    func _completionTime() -> Double {
        var used_start_time: UInt32 = 0
        if (self._time_start != 0) {
            used_start_time = self._time_start
        } else {
            //When calculating distance times we use the 1foot time (this emulates a drag strips timing equipment)
            used_start_time = self._originOneFootTime
        }
        
        return (Double(self._time_end - used_start_time) / 1000.0)
    }
    
    override public var description: String {
        var returnString: String = ""
            
        if (self.completed) {
            returnString = "in "
            
            returnString += String(format:"%0.2fs", _completionTime())
            
            if (self._capture_speed) {
                returnString += String(format:" (speed: %0.2fkm/h)", self._captured_speed)
            }
            
        } else {
            returnString += "incomplete"
        }
            
         return "\(self._name) - \(returnString)"
    }
    
    override public var json: String {
        var returnJson = JSON()
        
        if (completed) {
            returnJson["time"] = JSON(String(format:"%0.2f", _completionTime()))
            if (self._capture_speed) {
                returnJson["speed"] = JSON(String(format:"%0.2f", _captured_speed))
           }
        }
           
        return returnJson.rawString([writingOptionsKeys.castNilToNSNull: true])!
    }
    
    override public func check(rollingDistance: Double, previousMessage: DDUBX_NAV_POSLLH, previousDifference: DDUBX_NAV_POSLLH_Difference, currentMessage: DDUBX_NAV_POSLLH , newDifference:DDUBX_NAV_POSLLH_Difference) {
        if (!self._needsCheck) { return; }
        
        if (self._distance_end != nil) {
            if (rollingDistance >= self._distance_end!) {
                let original_times:[Double] = [0.0, Double(newDifference.time)]
                let original_distances: [Double] = [0.0, newDifference.distanceInMM]
                
                let ipol = LinearInterpolation(x: original_distances, y: original_times)
                
                let offsetFromConditionDistance = rollingDistance - self._distance_end!
                let y = ipol.Interpolate(t: offsetFromConditionDistance)
                
                self._time_end = previousMessage.iTOW + UInt32(y)
                
                if (self._capture_speed) {
                    
                    let speed_ipol = LinearInterpolation(x: [0.0, Double(newDifference.time)], y: [previousDifference.speed, newDifference.speed])
                    self._captured_speed = speed_ipol.Interpolate(t: y)
                }
            }
        }
        
        if (self._distance_end != nil && self._time_end != 0) {
             _needsCheck = false
             completed = true
         }
    }
}

public class DDPerformanceCondition_Slope : DDPerformanceCondition_Base {
    var _start_altitude: Int32 = 0
    var _start_altitude_recorded: Bool = false
    var _end_altitude: Int32 = 0
    
    var _distance_traveled: Double = 0
    
    init() {
        super.init(id: "slope", name: "Slope")
    }
    
    var slopeDegrees: Double {
        return Double(_end_altitude - _start_altitude) / Double(_distance_traveled)
    }
    
    var slopePercent: Double {
        return tan(self.slopeDegrees) * 100
    }
    
    override public var description: String {
        var returnString: String = ""
            
        if (self.completed) {
            returnString += String(format:"%0.3f", self.slopeDegrees.rad2deg()) + "° - " + String(format:"%0.2f", self.slopePercent) + "%"
        } else {
            returnString += "incomplete"
        }
            
         return "\(self._name) - \(returnString)"
    }
    
    override public var json: String {
        var returnJson = JSON()
        
        if (completed) {
            returnJson["slope"] = JSON(String(format:"%0.3f", self.slopeDegrees.rad2deg()))
            returnJson["percent"] = JSON(String(format:"%0.2f", self.slopePercent))
        }
           
        return returnJson.rawString([writingOptionsKeys.castNilToNSNull: true])!
    }
    
    override public func check(rollingDistance: Double, previousMessage: DDUBX_NAV_POSLLH, previousDifference: DDUBX_NAV_POSLLH_Difference, currentMessage: DDUBX_NAV_POSLLH , newDifference:DDUBX_NAV_POSLLH_Difference) {
        if (!self._needsCheck) { return; }
        
        if (!_start_altitude_recorded) {
            _start_altitude = currentMessage.height
            _start_altitude_recorded = true
            
            //This is always a completed calculation once we have a start altitude
            completed = true
        }
        
        _end_altitude = currentMessage.height
        _distance_traveled = rollingDistance
    }
}

public class DDPerformanceCondition_TopSpeed : DDPerformanceCondition_Base {
    var _top_speed: Double = 0
    
    init() {
        super.init(id: "topspeed", name: "Top Speed")
    }
    
    override public var json: String {
        var returnJson = JSON()
        
        if (completed) {
            returnJson["speed"] = JSON(String(format:"%0.2f", self._top_speed))
        }
        
        return returnJson.rawString([writingOptionsKeys.castNilToNSNull: true])!
   }
    
    override public var description: String {
        var returnString: String = ""
            
        if (self.completed) {
            returnString += String(format:"%0.2f", _top_speed) + "km/h"
        } else {
            returnString += "incomplete"
        }
            
         return "\(self._name) - \(returnString)"
    }
    
    override public func check(rollingDistance: Double, previousMessage: DDUBX_NAV_POSLLH, previousDifference: DDUBX_NAV_POSLLH_Difference, currentMessage: DDUBX_NAV_POSLLH , newDifference:DDUBX_NAV_POSLLH_Difference) {
        if (!self._needsCheck) { return; }
        
        _top_speed = max(newDifference.speed, _top_speed)
        completed = true
    }
}

public class DDPerformanceCondition_TotalDistance : DDPerformanceCondition_Base {
    var _total_distance: Double = 0
    
    init() {
        super.init(id: "totaldistance", name: "Total Distance")
    }
    
    override public var json: String {
        var returnJson = JSON()
               
        if (completed) {
            returnJson["distance"] = JSON(String(format:"%0.2f", _total_distance * 0.001))
        }

        return returnJson.rawString([writingOptionsKeys.castNilToNSNull: true])!
    }
    
    override public var description: String {
        var returnString: String = ""
            
        if (self.completed) {
            returnString += String(format:"%0.2f", _total_distance * 0.001) + "m"
        } else {
            returnString += "incomplete"
        }
            
         return "\(self._name) - \(returnString)"
    }
    
    override public func check(rollingDistance: Double, previousMessage: DDUBX_NAV_POSLLH, previousDifference: DDUBX_NAV_POSLLH_Difference, currentMessage: DDUBX_NAV_POSLLH , newDifference:DDUBX_NAV_POSLLH_Difference) {
        if (!self._needsCheck) { return; }
        
        _total_distance = rollingDistance
        completed = true
    }
}
