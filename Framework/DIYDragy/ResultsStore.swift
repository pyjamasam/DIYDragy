//
//  Results.swift
//  DIYDragy_Framework
//
//  Created by Chris Whiteford on 2020-05-14.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//

import Foundation
import Logging

import SQLite
import QuartzCore.CAAnimation

public struct DDRunResult: Identifiable {
    public var id: Int64
    public var startTime: Int64
    public var movementStartTime: Int64?
    public var onefootrolloutStartTime: Int64?
    public var endTime: Int64?
    public var completed: Bool
    
    public init(id:Int64, startTime: Int64, movementStartTime: Int64?, onefootrolloutStartTime: Int64?, endTime: Int64?, completed: Bool){
        self.id = id
        self.startTime = startTime
        self.movementStartTime = movementStartTime
        self.onefootrolloutStartTime = onefootrolloutStartTime
        self.endTime = endTime
        self.completed = completed
    }
    
    public var startTimeAsDate: Date {
        get {
            let startTimeSinceReferenceDate = (Double(self.startTime) - (Date.timeIntervalBetween1970AndReferenceDate * 1000.0)) / 1000.0
            return Date(timeIntervalSinceReferenceDate: startTimeSinceReferenceDate)
        }
    }
}

public struct DDPerformanceResult: Identifiable {
    public var id: Int64
    public var type: String
    public var identifier: String
    public var completed: Bool
    public var jsonData: String
    
    public init(id:Int64, type: String, identifier: String, completed: Bool, jsonData: String) {
        self.id = id
        self.type = type
        self.identifier = identifier
        self.completed = completed
        self.jsonData = jsonData
    }
}

public class DDResultsStore : NSObject {
    var logger = Logger(label: "ResultsStore")
    static public let shared = DDResultsStore()
    
    var _db:SQLite.Connection? = nil
    
    let idColumn = Expression<Int64>("id")
    let runIdColumn = Expression<Int64>("runId")
    let completedColumn = Expression<Int64>("completed")
    
    let rawlogTable = Table("rawlog")
    let timestampColumn = Expression<Int64>("timestamp")
    let rawdataColumn = Expression<SQLite.Blob?>("rawdata")
    
    let runsTable = Table("runs")
    let starttimeColumn = Expression<Int64>("starttime")
    let movementStartColumn = Expression<Int64?>("movementstart")
    let oneFootRolloutStartColoumn = Expression<Int64?>("onefootrolloutstart")
    let endtimeColumn = Expression<Int64?>("endstime")
    
    let resultsTable = Table("results")
    let typeColumn = Expression<String>("type")
    let identifierColumn = Expression<String>("identifier")
    let dataColumn = Expression<String>("data")

    let trendsTable = Table("trends")
    let speedColumn = Expression<Double>("speed")
    let heightColumn = Expression<Int64>("height")
    let accelerationColumn = Expression<Double>("acceleration")
    
    private override init() {
        super.init()
        
        logger.logLevel = .debug
        logger.info("Starting up...")
        
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let url = NSURL(fileURLWithPath: path)
        
        let dbPath = url.appendingPathComponent("DIYDragy.db")
        logger.info("Using \(dbPath!.path) as storage database")
        _db = try! Connection(dbPath!.path)
        
        //_db!.trace { print($0) }
        
        try! _db!.run(rawlogTable.create(ifNotExists: true) { t in
            t.column(idColumn, primaryKey: .autoincrement)
            t.column(timestampColumn)
            t.column(rawdataColumn)
            t.column(runIdColumn)
        })
        
        try! _db!.run(runsTable.create(ifNotExists: true) { t in
            t.column(idColumn, primaryKey: .autoincrement)
            t.column(starttimeColumn)
            t.column(movementStartColumn)
            t.column(oneFootRolloutStartColoumn)
            t.column(endtimeColumn)
            t.column(completedColumn)
        })
        
        try! _db!.run(resultsTable.create(ifNotExists: true) { t in
            t.column(idColumn, primaryKey: .autoincrement)
            t.column(typeColumn)
            t.column(identifierColumn)
            t.column(runIdColumn)
            t.column(completedColumn)
            t.column(dataColumn)
        })
                
        try! _db!.run(trendsTable.create(ifNotExists: true) { t in
            t.column(idColumn, primaryKey: .autoincrement)
            t.column(runIdColumn)
            t.column(timestampColumn)
            t.column(speedColumn)
            t.column(heightColumn)
            t.column(accelerationColumn)
        })
    }
    
    public var logAllTheTime: Bool {
        get {
            return _logAllTheTime
        }
        set {
            _logAllTheTime = newValue
            UserDefaults.standard.set(_logAllTheTime, forKey: "logAllTheTime")
        }
    }
    var _logAllTheTime: Bool = UserDefaults.standard.bool(forKey: "logAllTheTime")

    
    public func logRawMessage(_ message:DDUBX_NAV_POSLLH, runId: Int64 ) {
        if (logAllTheTime || (!logAllTheTime && runId != 0)) {
            let messageData: SQLite.Blob = SQLite.Blob(bytes: message.generateBinary())
        
            let insertStatement = rawlogTable.insert(timestampColumn <- Date.quickMSSince1970(), rawdataColumn <- messageData, runIdColumn <- runId)
            _ = try! _db!.run(insertStatement)
        }
    }
    
    public func markNewRun() -> Int64 {
        let insertStatement = runsTable.insert(starttimeColumn <- Date.quickMSSince1970(), completedColumn <- 0)
        return try! _db!.run(insertStatement)
    }
    
    public func endRun(runId: Int64, canceled: Bool) {
        let run = runsTable.filter(idColumn == runId)
        try! _db!.run(run.update(endtimeColumn <- Date.quickMSSince1970(), completedColumn <- canceled ? 0 : 1))
    }
    
    public func update(run: Int64, movementStart: Int64, oneFootRolloutStart: Int64) {
        let run = runsTable.filter(idColumn == run)
        try! _db!.run(run.update(movementStartColumn <- movementStart, oneFootRolloutStartColoumn <- oneFootRolloutStart))
    }
    
    public func record(results: DDPerformanceCondition_Base, forRun: Int64) {
        let resultType: String = String("\(type(of: results))")
        let insertStatement = resultsTable.insert(typeColumn <- resultType, identifierColumn <- results.identifier, runIdColumn <- forRun, completedColumn <- (results.completed == true ? 1 : 0), dataColumn <- results.json)
        _ = try! _db!.run(insertStatement)
    }
    
    public func logTrendData(runId: Int64, speed: Double, acceleration: Double, height: Int32) {
        let insertStatement = trendsTable.insert(runIdColumn <- runId, timestampColumn <- Date.quickMSSince1970(), speedColumn <- speed, heightColumn <- Int64(height), accelerationColumn <- acceleration)
        _ = try! _db!.run(insertStatement)
    }
    
    
    public func flushAllData() {
        self.flushRawLogs()
        self.flushRunsAndResults()
        self.flushTrendData()
    }
    
    public func flushRawLogs() {
        try! _db!.run(rawlogTable.delete())
    }
    
    public func flushRunsAndResults() {
        try! _db!.run(runsTable.delete())
        try! _db!.run(resultsTable.delete())
    }
    
    public func flushTrendData() {
        try! _db!.run(trendsTable.delete())
    }
    
    public func fetchRuns() -> [DDRunResult] {
        var returnList: [DDRunResult] = [DDRunResult]()
        
        let query = runsTable //where(completedColumn == 1)
        
        for run in try! _db!.prepare(query) {
            let aResult: DDRunResult = DDRunResult(id: run[idColumn], startTime: run[starttimeColumn], movementStartTime: run[movementStartColumn], onefootrolloutStartTime: run[oneFootRolloutStartColoumn], endTime: run[endtimeColumn], completed: run[completedColumn] == 1 ? true : false)
            returnList.append(aResult)
        }
        return returnList
    }
        
    public func loadPerformanceResults(forRun: Int64) -> [DDPerformanceResult] {
        var returnList: [DDPerformanceResult] = [DDPerformanceResult]()
        
        let query = resultsTable.where(runIdColumn == forRun)
        
        for perfdata in try! _db!.prepare(query) {
            let aResult: DDPerformanceResult = DDPerformanceResult(id: perfdata[idColumn], type: perfdata[typeColumn], identifier: perfdata[identifierColumn], completed: perfdata[completedColumn] == 1 ? true : false, jsonData: perfdata[dataColumn])
            
            returnList.append(aResult)
        }
        return returnList
    }
    
    
    public func remove(run: Int64) {
        let runsQuery = runsTable.where(idColumn == run)
        let resultsQuery = resultsTable.where(runIdColumn == run)
        
        try! _db!.run(runsQuery.delete())
        try! _db!.run(resultsQuery.delete())
    }
}
