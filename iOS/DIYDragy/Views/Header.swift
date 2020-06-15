//
//  Header.swift
//  DIYDragy
//
//  Created by Chris Whiteford on 2020-05-15.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//


import SwiftUI

import DIYDragy_Framework

struct DDHeaderView: View {
    @EnvironmentObject var userData: DDAppData
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    var body: some View {
        var deviceColor: Color = .gray
        
        switch (userData.deviceState) {
        case .unknown:
            deviceColor = Color.gray
        case .scanning:
            deviceColor = Color.yellow
        case .connecting:
            deviceColor = Color.blue
        case .connected:
            deviceColor = Color.green
        case .disconected:
            deviceColor = Color.gray
        case .error:
            deviceColor = Color.red
        }
        
        var gpsColor: Color = .gray
        var gpsImageName: String = "location"
        var gpsImageName_Pulse: String = "location.fill"
        
        switch (userData.gpsState) {
        case .unknown:
            gpsColor = Color.gray
            gpsImageName = "location.slash"
            gpsImageName_Pulse = "location.slash"
            
        case .scanning:
            gpsColor = Color.red
            gpsImageName = "location"
            gpsImageName_Pulse = "location.fill"
            
        case .lowresfix:
            gpsColor = Color.yellow
            gpsImageName = "location"
            gpsImageName_Pulse = "location.fill"
            
        case .medresfix:
            gpsColor = Color.blue
            gpsImageName = "location"
            gpsImageName_Pulse = "location.fill"
            
        case .highresfix:
            gpsColor = Color.green
            gpsImageName = "location"
            gpsImageName_Pulse = "location.fill"
        }
        
        let gpsImageName_Final: String = userData.gpsIconPulseState ? gpsImageName_Pulse : gpsImageName
        
        return HStack {
            Button(action: { DDBLEDevice.shared.toggleConnection() }) {
                Image(systemName: "dot.radiowaves.left.and.right").resizable().frame(width: 42, height:28, alignment: .center)
                    .padding(EdgeInsets(top: 10, leading: 10, bottom: 0, trailing: 0))
                    .foregroundColor(deviceColor)
            }
            Spacer()
            Text("DIYDragy").font(.largeTitle).foregroundColor(colorScheme == .light ? .black : .white)
            Spacer()
            Image(systemName: (gpsImageName_Final)).resizable().frame(width: 32, height: 32, alignment: .center)
                    .padding(EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 10))
                    .foregroundColor(gpsColor)
        }.padding(EdgeInsets(top:0, leading: 0, bottom: 10, trailing: 0))
            .background(colorScheme == .light ? Color.init(red: 0.97, green:0.97, blue: 0.97) : Color.init(red: 0.07, green: 0.07, blue: 0.07))
    }
}

struct DDHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DDHeaderView().previewLayout(PreviewLayout.sizeThatFits).padding()
                .environmentObject(DDAppData.shared)
                .environment(\.colorScheme, .light)

            DDHeaderView().previewLayout(PreviewLayout.sizeThatFits).padding()
                .environmentObject(DDAppData.shared)
                .environment(\.colorScheme, .dark)
        }
    }
}
