//
//  AppDelegate.swift
//  DIYDragy
//
//  Created by Chris Whiteford on 2020-04-26.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//

import UIKit
import Logging
import DIYDragy_Framework
import QuartzCore.CAAnimation


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, ObservableObject, DDBLEInterfaceDelegate, DDGPSProcessorDelegate, DDPerformanceProcessorDelegate {

    var logger = Logger(label: "main");
    
    @Published var lastLon: String = ""
    @Published var lastLat: String = ""
    @Published var lastVAcc: String = ""
    @Published var lastHAcc: String = ""
    @Published var status: String = ""
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        logger.logLevel = .debug
        logger.info("Starting up...")
        
        application.isIdleTimerDisabled = true
        
        _ = DDResultsStore.shared
        
        DDBLEDevice.shared.delegates.add(delegate: self)
        DDGPSProcessor.shared.delegates.add(delegate: self)
        DDPerformanceProcessor.shared.delegates.add(delegate: self)
        
        DDBLEDevice.shared.delegates.add(delegate: DDGPSProcessor.shared)
        DDGPSProcessor.shared.delegates.add(delegate: DDPerformanceProcessor.shared)
                        
        return true
    }

    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    //MARK: DDBLEInterfaceDelegate
    func didUpdateState(state: DDBLEDeviceState) {
        logger.info("Dragy device state changed: \(state.description)")
        
        if (state == .connected) {
            byteCount = 0
        }
    }
    
    func didReadRSSI(didReadRSSI RSSI: NSNumber) {
        //print("Dragy RSSI: \(RSSI)dB")
    }
    
    var byteCount: UInt32 = 0
    var callCount: UInt32 = 0
    var startTime  : Double = CACurrentMediaTime()
    func hasBytesAvailable(bytesAvailable: Data ) {
        byteCount += UInt32(bytesAvailable.count)
        let currentTime: Double = CACurrentMediaTime()
        
        let speed: Double = Double(byteCount)/(currentTime - startTime)
        callCount += 1
        if (callCount % 50 == 0) {
            print("Received \(byteCount) bytes (\(String(format:"%0.2f", speed)))")
        }
    }
    
    //MARK: DDGPSProcessorDelegate
    func processedPOSLLH(message: DDUBX_NAV_POSLLH) {
    }
    
    func didUpdateState(state: DDGPSState) {
        logger.info("GPS state changed: \(state.description)")
    }
    
    //MARK: DDPerformanceProcessorDelegate
    func didUpdateState(state: DDPerformanceProcessorState) {
        logger.info("Performance Processor state changed: \(state.description)")
    }
}

