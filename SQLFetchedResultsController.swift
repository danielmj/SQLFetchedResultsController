//
//  SQLFetchedResultsController.swift
//  SQL Fetch Example
//
//  Created by Daniel Jackson on 6/29/15.
//  Copyright (c) 2015 Daniel Jackson. All rights reserved.
//

import UIKit

//REQUIRES FMDB

/*

Loading objects incrementally is fast. This is because it uses the sort descriptors as part of the WHERE 
clause to improve speed. It is recommended that you use indexed sort descriptors for maximum speed.

Loading objects at arbitrary locations will be slow(er). This is because the program does not know the
values of the sort descriptors and it does not know the primary key value at this location. Because of this, the program must
use the closest known values as pivots, and then do an offset from that location. Offset is inherently bad 
because it causes the database to do a sequential search. This is not a big deal if the jump you are making 
is a distance of 5 values. However, if you are making a jump of 1 million values, you will see slowing.

    Coming soon, the ability to jump to a location based on a key. This will mitigate the problem described above

    Coming soon, sections

*/

private var BLOCKS_IN_MEMORY = 3

public class SQLFetchedResultsController: NSObject {
    
    private var loadedIndexStart:Int = 0
    private var loadedResults:[[NSObject:AnyObject]] = []
    private var lastTableIndex:Int = -1
    private var primaryKey:String = ""
    private var _databasePath:String
    
    
    public var databasePath:String {   get { return _databasePath }    }
    
    public var fetchRequest:SQLFetchRequest
    
    public var numberOfRows = 0
    
    
    init(request:SQLFetchRequest, pathToDatabase:String) {
        fetchRequest = request
        _databasePath = pathToDatabase
        
        super.init()
        
        numberOfRows = fetchTotalRowCount()
        println("ROW COUNT: \(numberOfRows)")
        primaryKey = fetchPrimaryKey() ?? ""
        if count(primaryKey) == 0
        {
            NSLog("[ERROR] Table does not include a primary key")
            abort()
        }
        
        var found = false
        for sorter in fetchRequest.sortDescriptors ?? []
        {
            if sorter.key == primaryKey
            {
                found = true
                break
            }
        }
        
        if !found {
            fetchRequest.sortDescriptors += [(key:primaryKey, isASC:true)]
        }
    }
    
    public func objectAt(indexPath:NSIndexPath)->[NSObject:AnyObject]? {
        var result:[NSObject:AnyObject]? = nil
        
//        println("\n  Accessing Index: \(indexPath.row)")
        
        var assessment = assessIndex(indexPath.row)
//        println("Assessment: \(assessment)")
        if assessment.shouldLoadMore
        {
            var window = generateWindow(indexPath.row, isAscending: assessment.isAscending)
            var sqlVar = generateLimitOffset(assessment.isAscending, newWindowStartIndex: window.startIndex, newCount: window.count)
//            println("Updating Results \(window) \(sqlVar)")
            updateResults(assessment.isAscending, limit: sqlVar.limit, offset: sqlVar.offset)
            
            loadedIndexStart = window.startIndex
        }
        
//        printResults()
        
        var index = getActualIndex(indexPath.row)
        if index >= 0 && index < loadedResults.count-1
        {
            result = loadedResults[index]
//            println("Object: \(result)")
        }
        
//        println("NEW currentIndexStart: \(loadedIndexStart) count:\(loadedResults.count)")
        
        return result
    }
    
    
    //MARK: Determing Direction, Limit, & Offset (from pivot)
    
    private func generateWindow(tableIndex:Int, isAscending:Bool)->(startIndex:Int, count:Int) {
        var start = 0
        var count = 0
        
        if isAscending
        {
            count = fetchRequest.batchSize * BLOCKS_IN_MEMORY
            start = tableIndex - (count / 3)
        }
        else
        {
            count = fetchRequest.batchSize * BLOCKS_IN_MEMORY
            start = tableIndex - (count * 2 / 3)
        }
        
        if start+count > numberOfRows
        {
            count = fetchRequest.batchSize * BLOCKS_IN_MEMORY * 2 / 3
            start = numberOfRows - count
        }
        
        if start < 0
        {
            count = fetchRequest.batchSize * BLOCKS_IN_MEMORY * 2 / 3
            start = 0
        }
        
        return (start, count)
    }
    
    private func generateLimitOffset(isAscending:Bool, newWindowStartIndex:Int, newCount:Int)->(limit:Int, offset:Int) {
        var offset = 0
        var limit = 0
        
        var pivot = getPivot(isAscending)
        
        if isAscending
        {
            //Last row closest to the end of loaded
            var pivotIndex = pivot?.indexInTable ?? 0
            
            var distanceToWindow = (newWindowStartIndex - pivotIndex)
            if distanceToWindow > 0
            {
                offset = distanceToWindow
                limit = newCount
            }
            else //If window start alread is loaded
            {
                offset = 0
                limit = newCount - abs(distanceToWindow)
            }
        }
        else //DESC
        {
            var pivotIndex = pivot?.indexInTable ?? 0
            
            var topOfWindow = (newWindowStartIndex+newCount)
            var distanceToWindow = pivotIndex - topOfWindow
            if distanceToWindow > 0
            {
                offset = distanceToWindow
                limit = newCount
            }
            else //If window start alread is loaded
            {
                offset = 0
                limit = newCount - abs(distanceToWindow)
            }
        }
        
        return (limit,offset)
    }
    
    private func assessIndex(indexInTable:Int)->(shouldLoadMore:Bool, isAscending:Bool) {
        var maxResultCount = BLOCKS_IN_MEMORY * fetchRequest.batchSize
        var inset = Int(maxResultCount/3)
        
        var shouldLoadMore = false
        var isAscending = false
        
        var currentIndex = getActualIndex(indexInTable)
        
//        println("currentIndexStart: \(loadedIndexStart) count:\(loadedResults.count)")
//        println("relativeIndex:\(currentIndex)")
        
        if indexInTable > lastTableIndex {
            isAscending = true
        }
        else {
            isAscending = false
        }
        lastTableIndex = indexInTable
        
        if currentIndex < inset && !isAscending
        {
            shouldLoadMore = true
        }
        else if currentIndex > (loadedResults.count)-inset+1 && isAscending
        {
            shouldLoadMore = true
        }
        
        return (shouldLoadMore, isAscending)
    }
    
    private func getActualIndex(indexInTable:Int)->Int {
        return indexInTable - loadedIndexStart
    }
    
    private func getPivot(isAscending:Bool)->(indexInTable:Int, result:[NSObject:AnyObject])? {
        if loadedResults.count > 0
        {
            if isAscending
            {
                return (indexInTable:loadedIndexStart+loadedResults.count, result:loadedResults[loadedResults.count-1])
            }
            else
            {
                return (indexInTable:loadedIndexStart, result:loadedResults[0])
            }
        }
        return nil
    }
    
    
    //MARK: Update Results
    
    private func updateResults(isAscending:Bool, limit:Int, offset:Int) {
        var pivot = getPivot(isAscending)
        
        if offset >= fetchRequest.batchSize //A JUMP!
        {
            //Completely replace the array
            loadedResults = []
        }
        else //INCREMENTAL
        {
            //Results adjusted at end
        }
        
        var parameters:[AnyObject] = []
        var sql = makeUpdateSQL(&parameters, pivotResult: pivot?.result, isAscending: isAscending, limit: limit, offset: offset)
        
        queryAndInsertIntoArray(isAscending, sql:sql, parameters:parameters)
        
        trimTheFat(isAscending)
    }
    
    private func trimTheFat(isAscending:Bool) {
        let totalResultsAllowed = fetchRequest.batchSize * BLOCKS_IN_MEMORY
        let difference = loadedResults.count - totalResultsAllowed
        if difference > 0
        {
            if isAscending
            {
                for var i=0; i < difference; i++
                {
                    loadedResults.removeAtIndex(0)
                }
            }
            else
            {
                for var i=0; i < difference; i++
                {
                    loadedResults.removeAtIndex(loadedResults.count-1)
                }
            }
        }
    }
    
    
    //MARK Fetching
   
    private func queryAndInsertIntoArray(isAscending:Bool, sql:String, parameters:[AnyObject]) {
//        println("SQL: \(sql)     ------ \(parameters)")
        
        var queryParameters:[AnyObject]? = nil
        if parameters.count != 0
        {
            queryParameters = parameters
        }
        
        var db = openDatabase()
        var s = db?.executeQuery(sql, withArgumentsInArray: queryParameters)
        var i=0;
        while (s?.next() ?? false) {
            
            var newResult = [NSObject:AnyObject]()
            
            for var i:Int32 = 0; i < s!.columnCount(); i++
            {
                var key:String = s!.columnNameForIndex(i)
                var value:AnyObject! = s!.objectForColumnIndex(i)
                newResult[key] = value
            }
            
            if isAscending {
                loadedResults.append(newResult)
            }
            else {
                loadedResults.insert(newResult, atIndex: 0)
            }
        }
        db?.close()
    }
    
    private func fetchTotalRowCount()->Int {
        var db = openDatabase()
        var sql = makeCountSQL();
        var rs = db?.executeQuery(sql, withArgumentsInArray: nil)
        if (rs?.next() ?? false)
        {
            return Int(rs!.intForColumn("count(*)"))
        }
        return 0
    }
    
    private func fetchPrimaryKey()->String? {
        var result:String? = nil
        
        var db = openDatabase()
        var sql = "PRAGMA table_info(\(fetchRequest.table));";
        var rs = db?.executeQuery(sql, withArgumentsInArray: nil)
        while (rs?.next() ?? false)
        {
            if rs!.intForColumn("pk") == 1
            {
                result = rs!.stringForColumn("name")
                break
            }
        }
        
        return result
    }
    
    private func fetchRowCount()->Int {
        var result = 0
        var db = openDatabase()
        
        var s = db?.executeQuery(makeCountSQL(), withArgumentsInArray: nil)
        if (s?.next() ?? false) {
            result = Int(s!.intForColumnIndex(0))
        }
        
        return result
    }
    
    
    //MARK: Make the Update SQL
    
    private func makeUpdateSQL(inout parameters:[AnyObject], pivotResult:[NSObject:AnyObject]?, isAscending:Bool, limit: Int, offset: Int)->String {
        var result = ""
        
        result = getSelectFieldsClause()
        result = appendTableName(result)
        result = appendWhereClause(result, parameters:&parameters, pivotResult: pivotResult, isAscending: isAscending)
        result = appendGroupByClause(result)
        result = appendHavingClause(result)
        result = appendOrderByClause(result, isAscending: isAscending)
        result = appendLimitClause(result, limit: limit)
        result = appendOffsetClause(result, offset: offset)
        
        return result
    }
    
    private func getSelectFieldsClause()->String {
        var fields = fetchRequest.fields ?? ""
        if count(fields) == 0
        {
            fields = "*"
        }
        
        var sortFields = ""
        for descriptor in fetchRequest.sortDescriptors ?? []
        {
            sortFields += "\(descriptor.key)"
        }
        
        return "SELECT \(fields),\(sortFields)"
    }
    
    private func appendTableName(sql:String)->String {
        var result = sql.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        result += " FROM \(fetchRequest.table)"
        return result
    }
    
    private func appendWhereClause(sql:String, inout parameters:[AnyObject], pivotResult:[NSObject:AnyObject]?, isAscending:Bool)->String {
        var result = sql.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        
        var whereResult = ""
        
        if pivotResult != nil
        {
            whereResult += " ("
            for var i=0; i < (fetchRequest.sortDescriptors.count); i++
            {
                var descriptor = fetchRequest.sortDescriptors[i]
                
                var directionStatement = ""
                
                if descriptor.key == primaryKey
                {
                    directionStatement = "<"
                    if isAscending {
                        directionStatement = ">"
                    }
                }
                else
                {
                    directionStatement = "<="
                    if isAscending {
                        directionStatement = ">="
                    }
                }
                
                
                if i != 0
                {
                    whereResult += " AND"
                }
                whereResult += " \(descriptor.key) \(directionStatement) ?"
                var descriptorValue:AnyObject = pivotResult![descriptor.key]!
                parameters.append(descriptorValue)
            }
            whereResult += " )"
        }
        
        if count(fetchRequest.predicate ?? "") > 0
        {
            if pivotResult != nil {
                whereResult += " AND"
            }
            whereResult += " \(fetchRequest.predicate!) "
        }
        
        if count(whereResult) > 0
        {
            result += " WHERE" + whereResult
        }
        
        return result
    }
    
    private func appendOrderByClause(sql:String, isAscending:Bool)->String {
        var result = sql.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        result += " ORDER BY"
        
        for var i=0; i < (fetchRequest.sortDescriptors.count); i++
        {
            let descriptor = fetchRequest.sortDescriptors[i]
            
            var descriptorIsASC = descriptor.isASC
            if !isAscending {
                descriptorIsASC = !descriptorIsASC
            }
            
            var direction = "DESC"
            if descriptorIsASC {
                direction = "ASC"
            }
            
            result += " \(descriptor.key) \(direction)"
            if i != (fetchRequest.sortDescriptors.count - 1) {
                result += ","
            }
        }
        return result
    }
    
    private func appendGroupByClause(sql:String)->String {
        var result = sql.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        var groupBy = fetchRequest.groupBy ?? ""
        if count(groupBy) > 0
        {
            result += " GROUP BY \(groupBy)"
        }
        return result
    }
    
    private func appendHavingClause(sql:String)->String {
        var result = sql.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        var having = fetchRequest.having ?? ""
        if count(having) > 0
        {
            result += " HAVING \(having)"
        }
        return result
    }
    
    private func appendLimitClause(sql:String, limit:Int)->String {
        var trimmedSQL = sql.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        return trimmedSQL + " LIMIT \(limit)"
    }
    
    private func appendOffsetClause(sql:String, offset:Int)->String {
//        if offset == 0
//        {
//            return sql
//        }
        
        var trimmedSQL = sql.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        return trimmedSQL + " OFFSET \(offset)"
    }
    
    private func openDatabase()->FMDatabase? {
        var db = FMDatabase(path: databasePath)
        if db.open()
        {
            return db
        }
        return nil
    }
    
    private func makeCountSQL()->String {
        
        var result = "SELECT count(*) FROM (SELECT * FROM \(fetchRequest.table)"
        var whereClause = fetchRequest.predicate ?? ""
        if count(whereClause) > 0
        {
            result += " WHERE \(whereClause)"
        }
        result = appendGroupByClause(result)
        result = appendHavingClause(result)
        result += ");"
        
        println("COUNT: \(result)")
        
        return result
    }
    
    
    //MARK: Displaying Data
    
    private func printResults() {
        var i = 0
        for item in loadedResults
        {
            var id:AnyObject! = item["id"]
            var title:AnyObject! = item["title"]
            println("\(++i). id: \(id), title: \(title)")
        }
    }
}
