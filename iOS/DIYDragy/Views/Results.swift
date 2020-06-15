//
//  Results.swift
//  DIYDragy
//
//  Created by Chris Whiteford on 2020-05-14.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//

import SwiftUI
import SwiftyJSON
import DIYDragy_Framework

extension View {
    func asImage() -> UIImage {
        let controller = UIHostingController(rootView: self)

        // locate far out of screen
        controller.view.frame = CGRect(x: 0, y: CGFloat(Int.max), width: 1, height: 1)
        UIApplication.shared.windows.first!.rootViewController?.view.addSubview(controller.view)

        let size = controller.sizeThatFits(in: UIScreen.main.bounds.size)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.sizeToFit()
        controller.view.backgroundColor = .white

        let image = controller.view.asImage()
        controller.view.removeFromSuperview()
        return image
    }
}

extension UIView {
    func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            // [!!] Uncomment to clip resulting image
              //rendererContext.cgContext.addPath(
              //   UIBezierPath(roundedRect: bounds, cornerRadius: 5).cgPath)
              //rendererContext.cgContext.clip()
            layer.render(in: rendererContext.cgContext)
        }
    }
}


struct MetricResultView: View {
    var details: DDPerformanceResult
    
    var body: some View {
        
        var value1: String = ""
        var value2: String? = nil
        
        if details.completed {
            let json = try! JSON(data: details.jsonData.data(using: .utf8)!)
            switch (details.type) {
                
            case "DDPerformanceCondition_Speed":
                if let value = json["time"].string {
                    value1 = value + " s"
                } else {
                    value1 = "Unknown"
                }

                if let value = json["time-1ft"].string {
                    value2 = value + " s (1')"
                }
            case "DDPerformanceCondition_Distance":
                if let value = json["time"].string {
                    value1 = value + " s"
                } else {
                    value1 = "Unknown"
                }
                
                if let value = json["speed"].string {
                    if (DDAppData.shared.mph) {
                        value2 = String(format:" %0.2f", Double(value)! * 0.6213712) + " mph"
                    } else {
                        value2 = value + " km/h"
                    }
                }
            case "DDPerformanceCondition_Slope":
                if let value = json["percent"].string {
                    value1 = value + "%"
                } else {
                    value1 = "Unknown"
                }
                
                if let value = json["slope"].string {
                    value2 = value + "°"
                }
            case "DDPerformanceCondition_TopSpeed":
                if let value = json["speed"].string {
                    if (DDAppData.shared.mph) {
                        value1 = String(format:" %0.2f", Double(value)! * 0.6213712) + " mph"
                    } else {
                        value1 = value + " km/h"
                    }
                } else {
                    value1 = "Unknown"
                }
            case "DDPerformanceCondition_TotalDistance":
                if let value = json["distance"].string {
                    if (DDAppData.shared.mph) {
                        value1 = String(format:" %0.2f", Double(value)! * 3.28084) + " '"
                    } else {
                        value1 = value + " m"
                    }
                } else {
                    value1 = "Unknown"
                }
                
            default:
                value1 = "Unknown Type: " + details.type
            }
        } else {
            value1 = "----"
        }
        
        
        return VStack(alignment: .trailing) {
            if (value2 != nil) {
                Text(value1)
                Text(value2!)
            } else {
                Text(value1)
            }
        }
    }
}


struct PerformanceResultRow: View {
    var details: DDPerformanceResult
    
    var body: some View {
        var labelString = ""
        switch (details.identifier) {
        case "60ft":
            fallthrough
        case "330ft":
            fallthrough
        case "1000ft":
            labelString = details.identifier
            
        case "0-30mi":
            labelString = "0-30 mph"
        case "0-60mi":
            labelString = "0-60 mph"
        case "0-100mi":
            labelString = "0-100 mph"
        case "0-130mi":
            labelString = "0-130 mph"
        case "60-130mi":
            labelString = "60-130 mph"
            
        case "0-50k":
            labelString = "0-50 km/h"
        case "0-100k":
            labelString = "0-100 km/h"
        case "0-200k":
            labelString = "0-200 km/h"
        case "100-200k":
            labelString = "100-200 km/h"
            
        case "1/8mi":
            labelString = "1/8 mile"
        case "1/4mi":
            labelString = "1/4 mile"
        case "1/2mi":
            labelString = "1/2 mile"
            
            
        case "slope":
            labelString = "Slope"
            
        case "topspeed":
            labelString = "Top Speed"
        
        case "totaldistance":
            labelString = "Total Distance"
            
        default:
            labelString = "Unknown Metric: " + details.identifier
        }
        
        return HStack {
            if details.completed {
                Image(systemName: "checkmark.seal").foregroundColor(.green)
            } else {
                Image(systemName: "xmark.seal").foregroundColor(.red)
            }
            Text(labelString)
            Spacer()
            MetricResultView(details: details)
        }
    }
}

struct ResultsDetailShareView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    let runResult: DDRunResult
    let performanceResults: [DDPerformanceResult]
    
    var body: some View {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let dividerHeight: CGFloat = 40.0
        
        return VStack {
            Text("DIYDragy Results").font(.largeTitle)
            Text(dateFormatter.string(from: runResult.startTimeAsDate))
            Spacer().frame(height:20.0)
            Divider()
            Group {
                Text("Acceleration").font(.title)
                HStack {
                    PerformanceResultRow(details: performanceResults.first(where: {$0.identifier == "0-30mi"})!)
                    Divider().frame(height: dividerHeight)
                    PerformanceResultRow(details: performanceResults.first(where: {$0.identifier == "0-50k"})!)
                }
                HStack {
                    PerformanceResultRow(details: performanceResults.first(where: {$0.identifier == "0-60mi"})!)
                    Divider().frame(height: dividerHeight)
                    PerformanceResultRow(details: performanceResults.first(where: {$0.identifier == "0-100k"})!)
                }
                HStack {
                    PerformanceResultRow(details: performanceResults.first(where: {$0.identifier == "0-100mi"})!)
                    Divider().frame(height: dividerHeight)
                    Spacer().frame(width: 249.5)
                }
                HStack {
                    PerformanceResultRow(details: performanceResults.first(where: {$0.identifier == "0-130mi"})!)
                    Divider().frame(height: dividerHeight)
                    PerformanceResultRow(details: performanceResults.first(where: {$0.identifier == "0-200k"})!)
                }
                HStack {
                    PerformanceResultRow(details: performanceResults.first(where: {$0.identifier == "60-130mi"})!)
                    Divider().frame(height: dividerHeight)
                    PerformanceResultRow(details: performanceResults.first(where: {$0.identifier == "100-200k"})!)
                }
            }
            Divider()
            Group {
                Text("Distance").font(.title)
                PerformanceResultRow(details: performanceResults.first(where: {$0.identifier == "60ft"})!)
                PerformanceResultRow(details: performanceResults.first(where: {$0.identifier == "330ft"})!)
                PerformanceResultRow(details: performanceResults.first(where: {$0.identifier == "1000ft"})!)
                PerformanceResultRow(details: performanceResults.first(where: {$0.identifier == "1/8mi"})!).frame(height: dividerHeight)
                PerformanceResultRow(details: performanceResults.first(where: {$0.identifier == "1/4mi"})!).frame(height: dividerHeight)
                PerformanceResultRow(details: performanceResults.first(where: {$0.identifier == "1/2mi"})!).frame(height: dividerHeight)
            }
            Divider()
            Group {
                Text("Other").font(.title)
                PerformanceResultRow(details: performanceResults.first(where: {$0.identifier == "totaldistance"})!)
                PerformanceResultRow(details: performanceResults.first(where: {$0.identifier == "topspeed"})!)
                PerformanceResultRow(details: performanceResults.first(where: {$0.identifier == "slope"})!)
            }
        }
        .frame(width: 500, height: nil)
        .background(Color.white)
        .padding()
    }
}


struct ResultsDetailView: View {
    var runResult: DDRunResult
    
    @State private var showShareSheet = false
    @State var resultsImage: UIImage? = nil
    
    var _performanceResults: [DDPerformanceResult]? = nil
    
    init(runResult: DDRunResult) {
        self.runResult = runResult
        
        //Load this runs performance results
        _performanceResults = DDResultsStore.shared.loadPerformanceResults(forRun: runResult.id)
    }

    var body: some View {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return List {
            Section(header: Text("Acceleration")) {
                PerformanceResultRow(details: self._performanceResults!.first(where: {$0.identifier == "0-30mi"})!)
                PerformanceResultRow(details: self._performanceResults!.first(where: {$0.identifier == "0-60mi"})!)
                PerformanceResultRow(details: self._performanceResults!.first(where: {$0.identifier == "0-100mi"})!)
                PerformanceResultRow(details: self._performanceResults!.first(where: {$0.identifier == "60-130mi"})!)

                PerformanceResultRow(details: self._performanceResults!.first(where: {$0.identifier == "0-50k"})!)
                PerformanceResultRow(details: self._performanceResults!.first(where: {$0.identifier == "0-100k"})!)
                PerformanceResultRow(details: self._performanceResults!.first(where: {$0.identifier == "0-200k"})!)
                PerformanceResultRow(details: self._performanceResults!.first(where: {$0.identifier == "100-200k"})!)
            }
            Section(header: Text("Distance")) {
                PerformanceResultRow(details: self._performanceResults!.first(where: {$0.identifier == "60ft"})!)
                PerformanceResultRow(details: self._performanceResults!.first(where: {$0.identifier == "330ft"})!)
                PerformanceResultRow(details: self._performanceResults!.first(where: {$0.identifier == "1000ft"})!)
                PerformanceResultRow(details: self._performanceResults!.first(where: {$0.identifier == "1/8mi"})!)
                PerformanceResultRow(details: self._performanceResults!.first(where: {$0.identifier == "1/4mi"})!)
                PerformanceResultRow(details: self._performanceResults!.first(where: {$0.identifier == "1/2mi"})!)
            }
            Section(header: Text("Other")) {
                PerformanceResultRow(details: self._performanceResults!.first(where: {$0.identifier == "totaldistance"})!)
                PerformanceResultRow(details: self._performanceResults!.first(where: {$0.identifier == "topspeed"})!)
                PerformanceResultRow(details: self._performanceResults!.first(where: {$0.identifier == "slope"})!)
            }
        }
        .navigationBarTitle(Text(dateFormatter.string(from: runResult.startTimeAsDate)), displayMode: .inline)
        .navigationBarItems(trailing:
            Button(action: {
                self.showShareSheet = true
                self.resultsImage = ResultsDetailShareView(runResult: self.runResult, performanceResults: self._performanceResults!)
                    .environment(\.colorScheme, .light) //Force this to always be a white background view (even if the phone is in dark mode)
                    .asImage()
            }) {
                Image(systemName: "square.and.arrow.up").resizable().frame(width: 22, height: 30)
            }/**/
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [self.resultsImage!], excludedActivityTypes: [UIActivity.ActivityType.assignToContact, UIActivity.ActivityType.addToReadingList])
            }
        )
    }
}

struct RunResultRow: View {
    var runResult: DDRunResult

    var body: some View {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return HStack {
            if runResult.completed {
                Image(systemName: "checkmark.seal").foregroundColor(.green)
            } else {
                Image(systemName: "xmark.seal").foregroundColor(.red)
            }
            Text(dateFormatter.string(from: runResult.startTimeAsDate))
        }
    }
}

struct ResultsView: View {
    @EnvironmentObject var resultsData: DDResultsData
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    var body: some View {
        NavigationView{
            List{
                if resultsData.runResults!.count > 0 {
                    ForEach(resultsData.runResults!) { runResult in
                        if runResult.completed {
                            NavigationLink(destination: ResultsDetailView(runResult: runResult)) {
                                RunResultRow(runResult: runResult)
                            }
                        } else {
                            RunResultRow(runResult: runResult)
                        }
                    }.onDelete(perform: deleteRun)
                } else {
                    Text("No Results")
                }
            }
            .navigationBarTitle(Text("Results"), displayMode: .inline)
        }
    }
    
    func deleteRun(at offsets: IndexSet) {
        offsets.forEach {
            //Lets find the ID of the item at the index we need to delete
            let resultToDelete: DDRunResult = resultsData.runResults![$0]
            
            DDResultsStore.shared.remove(run: resultToDelete.id)
            
            resultsData.runResults!.remove(at: $0)
        }
    }
}

struct ResultsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ResultsView().previewLayout(PreviewLayout.sizeThatFits).padding()
                 .environmentObject(DDResultsData.shared)
            
            
            ResultsDetailShareView(runResult: DDRunResult(id: 99, startTime: 1590417280453, movementStartTime: 1590417280463, onefootrolloutStartTime: 1590417280473, endTime: 1590417292118, completed: true), performanceResults: [
                DDPerformanceResult(id: 1, type: "DDPerformanceCondition_TotalDistance", identifier: "totaldistance", completed: true, jsonData: "{\"distance\": \"312.80\"}"),
                DDPerformanceResult(id: 1, type: "DDPerformanceCondition_TopSpeed", identifier: "topspeed", completed: true, jsonData: "{\"speed\": \"107.14\"}"),
                DDPerformanceResult(id: 1, type: "DDPerformanceCondition_Slope", identifier: "slope", completed: true, jsonData: "{\"percent\": \"0.59\",\"slope\": \"0.338\"}"),
                
                DDPerformanceResult(id: 1, type: "DDPerformanceCondition_Speed", identifier: "0-30mi", completed: true, jsonData: "{\"time\": \"2.20\",\"time-1ft\": \"1.73\"}"),
                DDPerformanceResult(id: 2, type: "DDPerformanceCondition_Speed", identifier: "0-60mi", completed: true, jsonData: "{\"time-1ft\": \"4.00\",\"time\": \"4.47\"}"),
                DDPerformanceResult(id: 3, type: "DDPerformanceCondition_Speed", identifier: "0-100mi", completed: false, jsonData: "{}"),
                DDPerformanceResult(id: 4, type: "DDPerformanceCondition_Speed", identifier: "0-130mi", completed: false, jsonData: "{}"),
                DDPerformanceResult(id: 5, type: "DDPerformanceCondition_Speed", identifier: "60-130mi", completed: false, jsonData: "{}"),
                
                DDPerformanceResult(id: 5, type: "DDPerformanceCondition_Speed", identifier: "0-50k", completed: true, jsonData: "{\"time\": \"2.31\",\"time-1ft\": \"1.84\"}"),
                DDPerformanceResult(id: 5, type: "DDPerformanceCondition_Speed", identifier: "0-100k", completed: true, jsonData: "{\"time\": \"4.72\",\"time-1ft\": \"4.25\"}"),
                DDPerformanceResult(id: 5, type: "DDPerformanceCondition_Speed", identifier: "0-200k", completed: false, jsonData: "{}"),
                DDPerformanceResult(id: 5, type: "DDPerformanceCondition_Speed", identifier: "100-200k", completed: false, jsonData: "{}"),
                
                DDPerformanceResult(id: 5, type: "DDPerformanceCondition_Distance", identifier: "60ft", completed: true, jsonData: "{\"time\": \"2.13\"}"),
                DDPerformanceResult(id: 5, type: "DDPerformanceCondition_Distance", identifier: "330ft", completed: true, jsonData: "{\"time\": \"5.37\"}"),
                DDPerformanceResult(id: 5, type: "DDPerformanceCondition_Distance", identifier: "1000ft", completed: true, jsonData: "{\"time\": \"14.84\"}"),
                DDPerformanceResult(id: 5, type: "DDPerformanceCondition_Distance", identifier: "1/8mi", completed: true, jsonData: "{\"time\": \"9.15\",\"speed\": \"84.48\"}"),
                DDPerformanceResult(id: 5, type: "DDPerformanceCondition_Distance", identifier: "1/4mi", completed: false, jsonData: "{}"),
                DDPerformanceResult(id: 5, type: "DDPerformanceCondition_Distance", identifier: "1/2mi", completed: false, jsonData: "{}"),
                
                
            ]).previewLayout(PreviewLayout.sizeThatFits)
        }
    }
}
    
