//
//  Main.swift
//  DIYDragy
//
//  Created by Chris Whiteford on 2020-05-14.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//

import SwiftUI


struct GaugeView_SwiftUI: UIViewRepresentable {
    @EnvironmentObject var userData: DDAppData
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    func makeUIView(context: Context) -> GaugeView {
        let gauge = GaugeView()
        gauge.showLimitDot = true
        
        
        if (DDAppData.shared.mph) {
            gauge.unitOfMeasurement = "mph"
            gauge.maxValue = 160
            gauge.limitValue = 60
        } else {
            gauge.unitOfMeasurement = "km/h"
            gauge.maxValue = 250.0
            gauge.limitValue = 100
        }
        
        return gauge
    }

    func updateUIView(_ uiView: GaugeView, context: Context) {
        
        if (colorScheme == .light) {
            uiView.backgroundColor = .white
            uiView.ringBackgroundColor = UIColor(white: 0.9, alpha: 1)
            uiView.valueTextColor = UIColor(white: 0.1, alpha: 1)
            uiView.unitOfMeasurementTextColor = UIColor(white: 0.3, alpha: 1)
            uiView.divisionsColor = UIColor(white: 0.5, alpha: 1)
            uiView.subDivisionsColor = UIColor(white: 0.5, alpha: 0.5)
        } else {
            uiView.backgroundColor = .black
            uiView.ringBackgroundColor = UIColor(white: 0.6, alpha: 1)
            uiView.valueTextColor = .white
            uiView.unitOfMeasurementTextColor = UIColor(white: 0.7, alpha: 1)
            uiView.divisionsColor = UIColor(white: 0.8, alpha: 1)
            uiView.subDivisionsColor = UIColor(white: 0.8, alpha: 0.5)
        }
        
        if (DDAppData.shared.mph) {
            uiView.value = DDAppData.shared.currentSpeed * 0.6213712
        } else {
            uiView.value = DDAppData.shared.currentSpeed
        }
    }
}

struct MainView: View {
    @EnvironmentObject var userData: DDAppData
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    var body: some View {
        return VStack(spacing: 30) {
            StatusView().padding(EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0))
            GaugeView_SwiftUI().frame(width: UIScreen.main.bounds.width * 0.90, height: nil)
            Spacer()
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView().previewLayout(PreviewLayout.sizeThatFits).padding()
            .environmentObject(DDAppData.shared)
    }
}
    
