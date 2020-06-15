//
//  SceneDelegate.swift
//  DIYDragy
//
//  Created by Chris Whiteford on 2020-04-26.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//

import UIKit
import SwiftUI
import DIYDragy_Framework

final public class DDAppData: ObservableObject {
    static public let shared = DDAppData()
    
    private init () {
    }
    
    @Published public var deviceState: DDBLEDeviceState = .unknown
    @Published public var gpsState: DDGPSState = .unknown
    @Published public var processorState: DDPerformanceProcessorState = .unknown
    
    @Published public var gpsIconPulseState: Bool = false
    
    @Published public var currentSpeed: Double = 0.0
    
    public var logAllTheTime: Bool = DDResultsStore.shared.logAllTheTime {
        didSet {
            DDResultsStore.shared.logAllTheTime = logAllTheTime
        }
    }
    
    public var mph: Bool = UserDefaults.standard.bool(forKey: "mph") {
        didSet {
            UserDefaults.standard.set(mph, forKey: "mph")
        }
    }
}

final public class DDResultsData: ObservableObject {
    static public let shared = DDResultsData()

    @Published var runResults: [DDRunResult]? = nil
    
    private init () {
        self.reloadResults()
    }
    
    func reloadResults() {
        //print("Reloading results")
        self.runResults = DDResultsStore.shared.fetchRuns().reversed()
    }
}


class SceneDelegate: UIResponder, UIWindowSceneDelegate, DDBLEInterfaceDelegate, DDGPSProcessorDelegate, DDPerformanceProcessorDelegate {
    var lastByteTime: Double = 0
    
    func didUpdateState(state: DDBLEDeviceState) {
        
        //Ensure that this happens on the main thread (cause we are updateing the UI)
        DispatchQueue.main.async {
            DDAppData.shared.deviceState = state
            
            let generator = UINotificationFeedbackGenerator()
            switch (state) {
            case .unknown:
                break
            case .scanning:
                break
            case .connecting:
                break
            case .connected:
                generator.notificationOccurred(.success)
            case .disconected:
                self.lastByteTime = 0
            case .error:
                generator.notificationOccurred(.error)
            }
        }
    }
    
    func didReadRSSI(didReadRSSI RSSI: NSNumber) {
    }
    
    func hasBytesAvailable(bytesAvailable: Data) {
        lastByteTime = CACurrentMediaTime()
    }
    
    var currentSpeedRollingAverage: DDRollingAverage = DDRollingAverage(windowSize: 10)
    
    var previousMessage: DDUBX_NAV_POSLLH? = nil
    func processedPOSLLH(message: DDUBX_NAV_POSLLH) {
        if ([.medresfix, .highresfix].contains(DDAppData.shared.gpsState)) {
            if (previousMessage != nil) {
                let positionDifference: DDUBX_NAV_POSLLH_Difference = message.difference(from: previousMessage!)
            
                let newSpeed = currentSpeedRollingAverage.add(positionDifference.speed);
                
                if (DDAppData.shared.currentSpeed != newSpeed) {
                    DispatchQueue.main.async {
                        DDAppData.shared.currentSpeed = newSpeed
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                self.currentSpeedRollingAverage.reset()
                DDAppData.shared.currentSpeed = 0
            }
        }
        
        previousMessage = message
    }
    
    func didUpdateState(state: DDGPSState) {
        DispatchQueue.main.async {
            DDAppData.shared.gpsState = state
            
            if (state == .unknown) {
                //We don't have any GPS info.  Time to just 0 out our speed
                self.currentSpeedRollingAverage.reset()
                DDAppData.shared.currentSpeed = 0
            }
        }
    }
    
    func didUpdateState(state: DDPerformanceProcessorState) {
         DispatchQueue.main.async {
            if DDAppData.shared.processorState == .complete && state == .idle {
                //If a run just completed we should force our results to reload
                DDResultsData.shared.reloadResults()
            }
            
            DDAppData.shared.processorState = state
        }
     }
    

    var window: UIWindow?
    
    var pulseTimer: Timer? = nil
    
    override init() {
        super.init()
        
        DDAppData.shared.deviceState = DDBLEDevice.shared.state
        DDBLEDevice.shared.delegates.add(delegate: self)
        
        DDAppData.shared.gpsState = DDGPSProcessor.shared.state
        DDGPSProcessor.shared.delegates.add(delegate: self)
        
        DDAppData.shared.processorState = DDPerformanceProcessor.shared.state
        DDPerformanceProcessor.shared.delegates.add(delegate: self)
        
        pulseTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(bytePulse), userInfo: nil, repeats: true)
    }
    
    @objc func bytePulse() {
        
        if (lastByteTime > 0) {
            let currentTime: Double = CACurrentMediaTime()
            let timeSinceLastByte = currentTime - lastByteTime
        
            if (timeSinceLastByte > 5.0) {
                //No more bytes are coming in.
                //TODO we need to handle this
            } else {
                //Bytes are still flowing in.  Toggle the pulse state
                DDAppData.shared.gpsIconPulseState = !DDAppData.shared.gpsIconPulseState
            }
        }
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: ContentView().environmentObject(DDAppData.shared))
            self.window = window
            window.makeKeyAndVisible()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

