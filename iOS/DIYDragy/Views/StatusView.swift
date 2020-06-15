//
//  Status.swift
//  DIYDragy
//
//  Created by Chris Whiteford on 2020-05-14.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//

import SwiftUI
import DIYDragy_Framework

struct StripesView: View {
    @EnvironmentObject var userData: DDAppData
    
    var body: some View {
        var stripeColor: Color = Color.init(hue: 0, saturation: 0, brightness: 0.83)
        
        if (userData.gpsState == .medresfix || userData.gpsState == .highresfix) {
            //Only colour the stripes when we are in the state we want to be
            switch (userData.processorState) {
            case .armed:
                stripeColor = Color.init(red: 1, green: 1, blue: 71.0/255.0)
            case .running:
                stripeColor = Color.init(red: 0.0/255.0, green: 184.0/255.0, blue: 115.0/255.0)
            default:
                break
            }
        }
        
        return VStack(spacing: 20) {
            Group {
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
            }
            Group {
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
                Rectangle().fill(stripeColor).frame(width: 1000, height: 20, alignment: .center)
            }
        }
        .background(Color.black)
        .rotationEffect(Angle(degrees: 45))
    }
}

struct StatusView: View {
    @EnvironmentObject var userData: DDAppData
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    @State var hitEnd: Bool = false
    
    var body: some View {
        var statusLabel: Text? = nil
        var sliderLabel: String? = nil
        var displaySlider: Bool = true
        
        if (userData.gpsState == .medresfix || userData.gpsState == .highresfix) {
            //We required at least a medium resolution fix to allow us to do stuff
            switch (userData.processorState) {
            case .idle:
                statusLabel = Text("Ready")
                sliderLabel = "Slide to Arm"
            case .armed:
                statusLabel = Text("Armed")
                sliderLabel = "Slide to disarm"
            case .running:
                statusLabel = Text("Running")
                sliderLabel = "Slide to cancel"
            case .complete:
                statusLabel = Text("Complete")
                sliderLabel = ""
                displaySlider = false
            default:
                break
            }
        }
        
        if (statusLabel == nil) {
            //If we have fallen through this far we arn't in a ready state
            statusLabel = Text("Not Ready")
            displaySlider = false
        }
        
        return ZStack {
            StripesView().frame(width: UIScreen.main.bounds.width * 0.95, height: 130).cornerRadius(10).clipped()
        
            VStack(spacing: 0) {
                
                statusLabel.frame(width: nil, height: 41).font(Font.system(size: 36, weight: .bold)).foregroundColor(.white).shadow(color: .black, radius: 4)
                
                if displaySlider {
                    SwipeToView(label: sliderLabel!)
                        .onSwipeSuccess {
                            self.slideComplete()
                    }
                    .padding(EdgeInsets(top: 10, leading: 0, bottom: 5, trailing: 0))
                }
            }
        }
    }
    
    func slideComplete() {
        if (userData.processorState == .idle) {
            DDPerformanceProcessor.shared.arm()
        } else if (userData.processorState == .armed) {
            DDPerformanceProcessor.shared.disarm()
        } else if (userData.processorState == .running) {
            DDPerformanceProcessor.shared.cancel()
        }
        
        self.hitEnd = false
    }
}

struct StatusView_Previews: PreviewProvider {
    static var previews: some View {
        
        DDAppData.shared.deviceState = .connected
        DDAppData.shared.gpsState = .medresfix
        DDAppData.shared.processorState = .idle

        return StatusView().previewLayout(PreviewLayout.sizeThatFits).padding()
            .environmentObject(DDAppData.shared)
    }
}
    
