//
//  PerformanceProcessor.swift
//  DIYDragy_Framework
//
//  Created by Chris Whiteford on 2020-05-05.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//

import Foundation

public protocol DDPerformanceProcessorDelegate: AnyObject {
    func didUpdateState(state: DDPerformanceProcessorState)
}

public enum DDPerformanceProcessorState: UInt {
    case unknown = 0
    case idle
    case armed
    case running
    case complete
    
    public var description: String {
      get {
        switch self {
            case .unknown:
                return "Unknown"
            case .idle:
                return "Idle"
            case .armed:
                return "Armed"
            case .running:
                return "Running"
            case .complete:
                return "Complete"
        }
      }
    }
}

public class DDPerformanceProcessor : NSObject, DDGPSProcessorDelegate {
    static public let shared = DDPerformanceProcessor()
    public let delegates: MulticastDelegate<DDPerformanceProcessorDelegate> = MulticastDelegate<DDPerformanceProcessorDelegate>()
    
    var _messageQueue: DDByteQueue<DDUBX_NAV_POSLLH> = DDByteQueue<DDUBX_NAV_POSLLH>()
    var _currentState: DDPerformanceProcessorState = DDPerformanceProcessorState.unknown
    
    public var state: DDPerformanceProcessorState {
        get {
            return _currentState
        }
    }
    
    var _armRequested: Bool = false
    var _disarmRequested: Bool = false
    var _cancelRequested: Bool = false
    
    var _oneFootInMM = 304.8
    
    var conditionsToCheck: [DDPerformanceCondition_Base] = [
                                                DDPerformanceCondition_Distance(id: "60ft", toDistance: 18288, withName:"60'"),
                                                DDPerformanceCondition_Distance(id: "330ft", toDistance: 100584, withName:"330'"),
                                                DDPerformanceCondition_Distance(id: "1000ft", toDistance: 304800, withName:"1000'"),
                                                
                                                DDPerformanceCondition_Speed(id: "0-30mi", toSpeed: 48.28032, withName:"0-30mph"),
                                                DDPerformanceCondition_Speed(id: "0-50k", toSpeed: 50.0, withName:"0-50km/h"),
                                                
                                                DDPerformanceCondition_Speed(id: "0-60mi", toSpeed: 96.56064, withName:"0-60mph"),
                                                DDPerformanceCondition_Speed(id: "0-100k", toSpeed: 100.0, withName:"0-100km/h"),
                                                
                                                DDPerformanceCondition_Speed(id: "0-100mi", toSpeed: 160.9344, withName:"0-100mph"),
                                                DDPerformanceCondition_Speed(id: "0-200k", toSpeed: 200.0, withName:"0-200km/h"),
                                                DDPerformanceCondition_Speed(id: "0-130mi", toSpeed: 209.2147, withName:"0-130mph"),
                                                
                                                DDPerformanceCondition_Speed(id: "100-200k", fromSpeed: 100, toSpeed: 200, withName:"100-200km/h"),
                                                DDPerformanceCondition_Speed(id: "60-130mi", fromSpeed: 96.56064, toSpeed: 209.2147, withName:"60-130mph"),
                                                
                                                DDPerformanceCondition_Distance(id: "1/8mi", toDistance: 201168, captureSpeed: true, withName:"1/8 mile"),
                                                DDPerformanceCondition_Distance(id: "1/4mi", toDistance: 402336, captureSpeed: true, withName:"1/4 mile"),
                                                DDPerformanceCondition_Distance(id: "1/2mi", toDistance: 804672, captureSpeed: true, withName:"1/2 mile"),
                                                
                                                DDPerformanceCondition_Slope(),
                                                DDPerformanceCondition_TopSpeed(),
                                                DDPerformanceCondition_TotalDistance()
                                            ]
    
    private override init() {
        super.init()
        
        //Start up our processing thread
        DispatchQueue.global(qos: .background).async {
            self._process()
        }
    }
    
    //MARK: DDGPSProcessorDelegate
    public func processedPOSLLH(message: DDUBX_NAV_POSLLH) {
        self._messageQueue.enqueue(val: message)
    }
    
    public func didUpdateState(state: DDGPSState) {
        if (state == .unknown || state == .scanning) {
            if (_currentState == .armed) {
                //We were armed, but we lost our GPS processor.  Disarm
                self.disarm()
            } else if (_currentState == .running) {
                //We were running but we lost our GPS processor.  Cancel
                self.cancel()
            }
        }
    }
    
    //MARK: Implementaion
    func _setState(state: DDPerformanceProcessorState) {
        if (state != _currentState) {
            _currentState = state
            
            self.delegates.invoke {
                $0.didUpdateState(state: _currentState)
            }
        }
    }
    
    public func arm() {
        if (_currentState == .idle) {
            _armRequested = true
        }
    }
    
    public func disarm() {
        //We can only disarm if we are armed (i.e. not actually do anyting)
        if (_currentState == .armed)
        {
            _disarmRequested = true
        }
    }
    
    public func cancel() {
        if (_currentState == .running)
        {
            _cancelRequested = true
        }
    }
    
    func _process() {
        
        var previousMessage: DDUBX_NAV_POSLLH? = nil
        var previousDifference: DDUBX_NAV_POSLLH_Difference? = nil
        
        var towMovementStart: UInt32 = 0
        var towOneFootRolloutStart: UInt32 = 0
        var timestampOfMovementStart: Int64 = 0
        var timestampOfOneFootRolloutStart: Int64 = 0
        
        var timeOfSlowdownStart: UInt32 = 0
        
        var distanceMoved: Double = 0
        var topSpeed: Double = 0
        
        var runId: Int64 = 0
        
        var previousState: DDPerformanceProcessorState = DDPerformanceProcessorState.unknown
        while (true)
        {
            switch(_currentState)
            {
            case .unknown:
                //logPathComponent = nil
                
                self._setState(state: DDPerformanceProcessorState.idle)
                
            case .idle:
                //We won't leave this state until an arm is manually triggered
                
                //Just consume any messages we have been given
                //Consume messages in a non blocking way and sleep when there aren't any messages
                if (_messageQueue.count() > 0) {
                    previousMessage = _messageQueue.dequeue()
                    
                    //Log all the time when we are connected we can see all the
                    DDResultsStore.shared.logRawMessage(previousMessage!, runId: runId)
                } else {
                    usleep(50000);
                }
                
            case .armed:
                //We leave this state when a launch is detected
                
                if (_currentState != previousState) {
                    //We just were armed.  Time to initialize for a run
                    //Lets start logging this data for analysis later
                    
                    timestampOfMovementStart = 0
                    timestampOfOneFootRolloutStart = 0
                    towMovementStart = 0
                    towOneFootRolloutStart = 0
                    
                    timeOfSlowdownStart = 0
                    
                    distanceMoved = 0
                    topSpeed = 0
                    
                    //Log a new run to the DB
                    runId = DDResultsStore.shared.markNewRun()
                }
                                
                //We care about messages now.  Lets process them and watch for a launch
                let currentMessage: DDUBX_NAV_POSLLH = _messageQueue.dequeue()
                
                //Log to our log file for this run
                DDResultsStore.shared.logRawMessage(currentMessage, runId: runId)
                
                if ((currentMessage.gpsState == DDGPSState.medresfix ||
                    currentMessage.gpsState == DDGPSState.highresfix) &&
                    (previousMessage != nil &&
                        (previousMessage?.gpsState == DDGPSState.medresfix ||
                        previousMessage?.gpsState == DDGPSState.highresfix)
                )) {
                    //Both messages needed to perform our caluclations are of good enough quality.
                    //Lets crunch the numbers
                    let messageDifference: DDUBX_NAV_POSLLH_Difference = currentMessage.difference(from: previousMessage!)
                    
                    if (previousDifference != nil) {
                        let speedDifference_MperS: Double = (messageDifference.speed - previousDifference!.speed) * 0.2777778
                        let timeDifference_S: Double = Double(messageDifference.time) / 1000.0
                        
                        let acceleration_MperS2 = (speedDifference_MperS/timeDifference_S);
                        //let acceleration_G = acceleration_MperS2 * 0.101972
                        
                        DDResultsStore.shared.logTrendData(runId: runId, speed: messageDifference.speed, acceleration: acceleration_MperS2, height: currentMessage.height)
                    }
                    
                    
                    //Try and detect a launch now
                    var possibleLaunch: Bool = false
                    if (messageDifference.distanceInMM == 0) {
                        //We aren't moving.  Lets record this as a possible launch time
                        possibleLaunch = true
                        
                        timestampOfMovementStart = 0
                        timestampOfOneFootRolloutStart = 0
                        towMovementStart = 0
                        towOneFootRolloutStart = 0
                        
                        distanceMoved = 0
                        
                    } else if (messageDifference.distanceInMM == 0 && towMovementStart > 0) {
                        //We aren't moving, but we were in the past.  Might be GPS jitter.  Reset things
                        possibleLaunch = false
                        
                        timestampOfMovementStart = 0
                        timestampOfOneFootRolloutStart = 0
                        towMovementStart = 0
                        towOneFootRolloutStart = 0
                        
                        distanceMoved = 0
                    }
                    
                    if (possibleLaunch) {
                        //print("\n\nPossible launch starting at \(currentMessage.iTOW)")
                        towMovementStart = currentMessage.iTOW
                        timestampOfMovementStart = currentMessage.timestamp
                        
                    }
                    
                    if (towMovementStart > 0) {
                        //We are moving.  Count up the distance we have moved
                        distanceMoved += messageDifference.distanceInMM
                        topSpeed = max(topSpeed, messageDifference.speed)
                    
                        //We think that a launch has happened.  Lets see if we continue to keep moving forwards
                        //We'll watch for the 1' roll out and that will be the signal to switch to the running state and process this run
                        
                        if (distanceMoved > _oneFootInMM && towOneFootRolloutStart == 0) {
                            //We hit the 1' mark.  Lets try and resolve where we hit it (since it might have happened in between GPS samples)
                            let offsetFrom1Foot = distanceMoved - _oneFootInMM
                            let y = LinearInterpolation(x:  [0, messageDifference.distanceInMM], y: [0, Double(messageDifference.time)]).Interpolate(t: offsetFrom1Foot)
                            
                            towOneFootRolloutStart = previousMessage!.iTOW + UInt32(y)
                            timestampOfOneFootRolloutStart = previousMessage!.timestamp + Int64(y)
                            //print("Launch at \(timeOfMovementStart)")
                            //print("    1' at \(timeOfOneFootRolloutStart)")
                            
                            //We have a 1' roll out time now.  Time to switch to the running processing state for further processing
                            self._setState(state: DDPerformanceProcessorState.running)
                            
                            DDResultsStore.shared.update(run: runId, movementStart: timestampOfMovementStart, oneFootRolloutStart: timestampOfOneFootRolloutStart)
                            
                            //Reset all our conditions and record our origin times
                            conditionsToCheck.forEach {
                                $0.reset()
                                $0.setOriginTimes(startTime: towMovementStart, oneFootStartTime: towOneFootRolloutStart)
                            }
                        }
                    } else {
                        distanceMoved = 0
                    }
                    
                    previousDifference = messageDifference
                } else {
                    //fix resolution was too low.  Don't calculate anything based off this message
                }

                previousMessage = currentMessage
            case .running:
                //Here we go...  Lets see how we do
                //We will leave this state when we detect a deceleration event (i.e. the vehicle started to slow down)
                let currentMessage: DDUBX_NAV_POSLLH = _messageQueue.dequeue()
                
                //Log to our log file for this run
                DDResultsStore.shared.logRawMessage(currentMessage, runId: runId)
                
                if ((currentMessage.gpsState == DDGPSState.medresfix ||
                    currentMessage.gpsState == DDGPSState.highresfix) &&
                    (previousMessage != nil &&
                        (previousMessage?.gpsState == DDGPSState.medresfix ||
                        previousMessage?.gpsState == DDGPSState.highresfix)
                )) {
                    //Both messages needed to perform our caluclations are of good enough quality.
                    //Lets crunch the numbers
                    let messageDifference: DDUBX_NAV_POSLLH_Difference = currentMessage.difference(from: previousMessage!)
                    
                    //Calculate Acceleration
                    if (previousDifference != nil) {
                        let speedDifference_MperS: Double = (messageDifference.speed - previousDifference!.speed) * 0.2777778
                        let timeDifference_S: Double = Double(messageDifference.time) / 1000.0
                        
                        let acceleration_MperS2 = (speedDifference_MperS/timeDifference_S);
                        //let acceleration_G = acceleration_MperS2 * 0.101972
                        
                        DDResultsStore.shared.logTrendData(runId: runId, speed: messageDifference.speed, acceleration: acceleration_MperS2, height: currentMessage.height)
                        //print("speedDifference_MperS: \(speedDifference_MperS), timeDifference_S: \(timeDifference_S), acceleration_MperS2: \(acceleration_MperS2), acceleration_G: \(acceleration_G)")
                    }
                    
                    distanceMoved += messageDifference.distanceInMM
                    topSpeed = max(topSpeed, messageDifference.speed)
                    
                    //Lets ensure that we are still moving forward and either speeding up or moving at a constant speed.
                    //If we slow down (some threshold) then we will switch over to complete
                    
                    conditionsToCheck.forEach {
                        $0.check(rollingDistance: distanceMoved, previousMessage: previousMessage!, previousDifference: previousDifference!, currentMessage: currentMessage, newDifference: messageDifference)
                    }

                    previousDifference = messageDifference

                    if (messageDifference.speed < (topSpeed * 0.85)) {
                        //We are slowing down (and are at least 20% down from our top speed).  Check to see if we need to move on to the complete state
                        if (timeOfSlowdownStart == 0)
                        {
                            timeOfSlowdownStart = currentMessage.iTOW
                            print("Possible Slowdown detected")
                        }
                    }
                    else
                    {
                        timeOfSlowdownStart = 0
                    }
                    
                    //print("Distance: \(distanceMoved), Speed: \(messageDifference.speed), topSpeed: \(topSpeed), topSpeed-80%: \((topSpeed * 0.85)), diff: \(currentMessage.iTOW - timeOfSlowdownStart)")
                    
                    //if we have been slowing down for more then 2 seconds we can concider this run complete.
                    if (timeOfSlowdownStart > 0 && currentMessage.iTOW - timeOfSlowdownStart > 2000) {
                        self._setState(state: DDPerformanceProcessorState.complete)
                    }
                    
                } else {
                    //fix resolution was too low.  Don't calculate anything based off this message
                    //TODO: Should we abandon this run?  Did we loose GPS signal and we can't actually sort out anything any more
                }
                
                previousMessage = currentMessage
            case .complete:
                
                DDResultsStore.shared.endRun(runId: runId, canceled: _cancelRequested)
                
                //Write out the resulting captured performace data to a file we can archive with the run
                conditionsToCheck.forEach {
                   $0.finish()
                }
                
                conditionsToCheck.forEach {
                    let conditionString: String = $0.description
                        
                    print(conditionString)
                        
                    //Log results to the DB
                    DDResultsStore.shared.record(results: $0, forRun: runId)
                }
                
                runId = 0
                
                if (_cancelRequested) {
                    _cancelRequested = false
                }
                            
                //All done.  Publish results and back to idle
                self._setState(state: DDPerformanceProcessorState.idle)
            }
            
            previousState = _currentState
            
            if (_armRequested) {
               self._setState(state: DDPerformanceProcessorState.armed)
               _armRequested = false
            } else if (_disarmRequested) {
                self._setState(state: DDPerformanceProcessorState.idle)
                _disarmRequested = false
            } else if (_cancelRequested) {
                self._setState(state: DDPerformanceProcessorState.complete)
                //Complete state will check for cancelrequested and clear as needed
            }
        }
    }
}
