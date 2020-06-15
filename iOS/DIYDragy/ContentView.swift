//
//  ContentView.swift
//  DIYDragy
//
//  Created by Chris Whiteford on 2020-04-26.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//

import SwiftUI
import Darwin


struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    var body: some View {
        return VStack(spacing: 0) {
            if colorScheme == .light {
                Color.init(red: 0.97, green:0.97, blue: 0.97).edgesIgnoringSafeArea(.top).frame(width: nil, height:1)
            } else {
                Color.init(red: 0.07, green: 0.07, blue: 0.07).edgesIgnoringSafeArea(.top).frame(width: nil, height:1)
            }
            
            DDHeaderView()
            TabView {
                MainView()
                    .tabItem {
                        Image(systemName: "house") .font(.system(size: 21))
                        Text("Home")
                    }
                ResultsView().environmentObject(DDResultsData.shared)
                    .tabItem {
                        Image(systemName: "list.dash") .font(.system(size: 21))
                        Text("Results")
                    }
               
                SettingsView()
                    .tabItem {
                        Image(systemName: "gear") .font(.system(size: 24))
                        Text("Settings")
                    }
            }.accentColor(colorScheme == .light ? .black : .white)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView().previewLayout(PreviewLayout.device).environmentObject(DDAppData.shared).environment(\.colorScheme, .light)

            ContentView().previewLayout(PreviewLayout.device).environmentObject(DDAppData.shared).environment(\.colorScheme, .dark)
        }
    }
}
    
