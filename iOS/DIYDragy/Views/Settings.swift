//
//  Settings.swift
//  DIYDragy
//
//  Created by Chris Whiteford on 2020-05-14.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//

import SwiftUI
import DIYDragy_Framework

struct SettingsView: View {
    @EnvironmentObject var userData: DDAppData
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    
    var body: some View {
        VStack(spacing: 5) {
            Group {
                Text("Settings").font(.largeTitle)
                
                
                Toggle(isOn: $userData.logAllTheTime) {
                    Text("Log all the time")
                }.padding()
                HStack {
                    Text("km/h")
                    Toggle("kphmph", isOn: $userData.mph).labelsHidden()
                    Text("mph")
                }
            }
            Spacer()
            Group {
                Text("Cleanup Data").font(.title)
                Button(action: { self.cleanupRawLogs() }) {
                    Text("Clear Raw Logs").font(.body).padding(EdgeInsets(top: 20, leading: 30, bottom: 20, trailing: 30)).foregroundColor(colorScheme == .light ? Color.white : Color.black)
                }.background(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                Button(action: { self.cleanupRunsAndResults() }) {
                    Text("Clear Runs and Results").font(.body).padding(EdgeInsets(top: 20, leading: 30, bottom: 20, trailing: 30)).foregroundColor(colorScheme == .light ? Color.white : Color.black)
                }.background(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                Button(action: { self.cleanupTrends() }) {
                    Text("Clear Trend Data").font(.body).padding(EdgeInsets(top: 20, leading: 30, bottom: 20, trailing: 30)).foregroundColor(colorScheme == .light ? Color.white : Color.black)
                }.background(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            Spacer()
            Group {
                Text("Utilities").font(.title)
                Button(action: { self.doExit() }) {
                    Text("Exit").foregroundColor(colorScheme == .light ? Color.white : Color.black).padding(EdgeInsets(top: 20, leading: 40, bottom: 20, trailing: 40))
                }.background(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            Spacer()
        }
        .background(colorScheme == .light ? Color.white : Color.black)
    }
    
    
    func cleanupRawLogs() {
        DDResultsStore.shared.flushRawLogs()
    }
    
    func cleanupRunsAndResults() {
        DDResultsStore.shared.flushRunsAndResults()
        DDResultsData.shared.reloadResults()
    }
    
    func cleanupTrends() {
        DDResultsStore.shared.flushTrendData()
    }
    
    func doExit() {
        exit(0)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
           SettingsView().previewLayout(PreviewLayout.sizeThatFits)
            .environmentObject(DDAppData.shared)
                .environment(\.colorScheme, .light)

           SettingsView().previewLayout(PreviewLayout.sizeThatFits)
            .environmentObject(DDAppData.shared)
            .environment(\.colorScheme, .dark)
       }
    }
}
    

