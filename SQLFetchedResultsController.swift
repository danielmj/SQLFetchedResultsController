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
private let DEBUG = false

public class SQLFetchedResultsController: NSObject {
    
    private var loadedIndexStart:Int = 0
    private var loadedResults:[[NSObject:AnyObject]] = []
    private var lastTableIndex:Int = -1
    private var primaryKey:String = ""
    private var _databasePath:String
    
    public var databasePath:String {   get { return _databasePath }    }
    
    public var fetchRequest:SQLFetchRequest
    
    public var numberOfRows = 0
    
    
    /*

    
    a a 1
    a a 4
    a a 7
    a a 10 <- Piv
    a a 13
    
     OFFSET = X + (SELECT count(*) FROM (SELECT id FROM Test Where $1 > a AND $2 > a id <= 10 ORDER BY $1 ASC, $2 ASC, id ASC))
    
    a b 2
    a b 5
    a b 8
    a b 11
    a b 14
    
    a f 3
    a f 6
    a f 9 <- N
    a f 12
    a f 15
    
    REMOVE id from condition statement
    KEEP id in order by statement
    MODIFY id
    
    OFFSET = 8 + 4
    
*/
    
    init(request:SQLFetchRequest, pathToDatabase:String) {
        fetchRequest = request.copy() as! SQLFetchRequest
        _databasePath = pathToDatabase
        
        super.init()

        primaryKey = fetchPrimaryKey() ?? ""
        if count(primaryKey) == 0
        {
            NSLog("[ERROR] Table does not include a primary key")
            abort()
        }
        
        numberOfRows = fetchTotalRowCount()
        if DEBUG { println("ROW COUNT: \(numberOfRows)") }
        
        if fetchRequest.sortDescriptors.count == 0
        {
            fetchRequest.sortDescriptors += [(key:primaryKey,isASC:true)]
        }
    }
    
    public func objectAt(indexPath:NSIndexPath)->[NSObject:AnyObject]? {
        var result:[NSObject:AnyObject]? = nil
        
        //Clean up anything created
        if DEBUG { println("\n  Accessing Index: \(indexPath.row)") }
        
        var assessment = assessIndex(indexPath.row)
        if DEBUG { println("Assessment: \(assessment)") }
        
        if assessment.shouldLoadMore
        {
            var window = generateWindow(indexPath.row, isAscending: assessment.isAscending)
            var sqlVar = generateLimitOffset(assessment.isAscending, newWindowStartIndex: window.startIndex, newCount: window.count)
            if DEBUG { println("Updating Results \(window) \(sqlVar)") }
            
            updateResults(assessment.isAscending, limit: sqlVar.limit, offset: sqlVar.offset)
            
            loadedIndexStart = window.startIndex
        }
        
        if DEBUG { printResults() }
        
        var index = getActualIndex(indexPath.row)
        if DEBUG { println("Accessing Loaded Index: \(index)") }
        if index >= 0 && index < loadedResults.count
        {
            result = loadedResults[index]
            if DEBUG { println("Object: \(result)") }
        }
        
        if DEBUG { println("NEW currentIndexStart: \(loadedIndexStart) count:\(loadedResults.count)") }
        
        return result
    }
    
    public func previewSQL()->(SQL:String, Parameters:[AnyObject])
    {
        var param:[AnyObject] = []
        return (makeUpdateSQL(&param, pivotResult: nil, isAscending: true, limit: fetchRequest.batchSize, offset: 0), param)
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
            count = fetchRequest.batchSize * BLOCKS_IN_MEMORY
            start = numberOfRows - count
        }
        
        if start < 0
        {
            count = fetchRequest.batchSize * BLOCKS_IN_MEMORY
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
        
        autoreleasepool { () -> () in
            let pivot = getPivot(isAscending)
            
            if offset >= bufferSize() //A JUMP!
            {
                //Completely replace the array
                loadedResults = []
            }
            else //INCREMENTAL
            {
                //Results adjusted at end
            }
            
            var parameters:[AnyObject] = []
            let sql = makeUpdateSQL(&parameters, pivotResult: pivot?.result, isAscending: isAscending, limit: limit, offset: offset)
            
            queryAndInsertIntoArray(isAscending, sql:sql, parameters:parameters)
            
            trimTheFat(isAscending)
        }
    }
    
    private func bufferSize()->Int
    {
        return fetchRequest.batchSize
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
        var currentRecord = 0;
        while (s?.next() ?? false) {
            autoreleasepool({ () -> () in
                
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
                currentRecord++
            })
        }
        db?.close()
        db = nil
    }
    
    private func fetchTotalRowCount()->Int {
        var db = openDatabase()
        var sql = makeCountSQL();
        var rs = db?.executeQuery(sql, withArgumentsInArray: nil)
        if (rs?.next() ?? false)
        {
            return Int(rs!.intForColumn("count(*)"))
        }
        db?.close()
        return 0
    }
    
    private func fetchPrimaryKey()->String? {
        var result:String? = nil
        
        var table = fetchRequest.table.componentsSeparatedByString(" ")[0]
        
        var db = openDatabase()
        var sql = "PRAGMA table_info(\(table));";
        var rs = db?.executeQuery(sql, withArgumentsInArray: nil)
        while (rs?.next() ?? false)
        {
            if rs!.intForColumn("pk") == 1
            {
                result = rs!.stringForColumn("name")
                break
            }
        }
        db?.close()
        db = nil
        return result
    }
    
    private func fetchRowCount()->Int {
        var result = 0
        var db = openDatabase()
        
        var s = db?.executeQuery(makeCountSQL(), withArgumentsInArray: nil)
        if (s?.next() ?? false) {
            result = Int(s!.intForColumnIndex(0))
        }
        db?.close()
        db = nil
        return result
    }
    
    
    //MARK: Make the Update SQL
    
    private func makeUpdateSQL(inout parameters:[AnyObject], pivotResult:[NSObject:AnyObject]?, isAscending:Bool, limit: Int, offset: Int)->String {
        var result = ""
        
        result = getSelectFieldsClause()
        result = appendTableName(result)
        result = appendWhereClause(result, useEqualSigns:false, parameters:&parameters, pivotResult: pivotResult, isAscending: isAscending)
        result = appendGroupByClause(result)
        result = appendHavingClause(result)
        result = appendOrderByClause(result, isAscending: isAscending)
        result = appendLimitClause(result, limit: limit)
        result = appendOffsetClause(result, parameters: &parameters, isAscending: isAscending, pivotResult: pivotResult, offset: offset)
        
        if DEBUG { println("SQL: \(result) \nParameters: \(parameters)") }
        
        return result + ";"
    }
    
    private func testOffset(isAscending:Bool, pivotResult:[NSObject:AnyObject]?, offset:Int)->Int
    {
        var parameters:[AnyObject] = []
        if pivotResult != nil //&& false
        {
            var table = fetchRequest.table.componentsSeparatedByString(" ")[0]
            //Offsets from the duplicates
            var duplicateOffsetSQL = "SELECT count(*) FROM ( SELECT \(primaryKey) FROM \(table) "
            
            duplicateOffsetSQL = appendWhereClause(duplicateOffsetSQL, useEqualSigns:true, parameters: &parameters, pivotResult: pivotResult, isAscending: isAscending)
            
            //Reverse to query only results between start of duplicates and current
            var reversedDirection = !isAscending
            var directionStatement = "<="
            if reversedDirection {
                directionStatement = ">="
            }
            
            var pkValue:AnyObject! = pivotResult![primaryKey]
            var reverseCondition = "\(primaryKey) \(directionStatement) ?"
            parameters.append(pkValue)
            
            if duplicateOffsetSQL.rangeOfString("WHERE") == nil
            {
                duplicateOffsetSQL += " WHERE \(reverseCondition)"
            }
            else {
                duplicateOffsetSQL += " AND \(reverseCondition)"
            }
            
            duplicateOffsetSQL += " )"
            
            var offsetAddition = " \(duplicateOffsetSQL) ;"
            
            var result = -1
            var db = openDatabase()
            
            var s = db?.executeQuery(offsetAddition, withArgumentsInArray: parameters)
            if (s?.next() ?? false) {
                result = Int(s!.intForColumnIndex(0))
            }
            
            db?.close()
            db = nil
            
            return result
        }
        else
        {
            return -1
        }
    }
    
    private func getSelectFieldsClause()->String {
        var fields = fetchRequest.fields ?? []
        
        for descriptor in fetchRequest.sortDescriptors ?? []
        {
            var found = false
            for f in fields
            {
                if f == descriptor.key
                {
                    found = true
                }
            }
            
            if !found {
                fields.append(descriptor.key)
            }
        }
        
        var fieldString = ""
        for var i=0; i < fields.count; i++
        {
            if i != 0 {
                fieldString += ","
            }
            
            fieldString += fields[i]
        }
        
        return "SELECT \(fieldString)"
    }
    
    private func appendTableName(sql:String)->String {
        var result = sql.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        result += " FROM \(fetchRequest.table)"
        return result
    }
    
    private func appendWhereClause(sql:String, useEqualSigns:Bool, inout parameters:[AnyObject], pivotResult:[NSObject:AnyObject]?, isAscending:Bool)->String {
        var result = sql.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        
        var whereResult = ""
        
        if pivotResult != nil
        {
            whereResult += " ("
            if fetchRequest.sortDescriptors.count > 0
            {
                var descriptor = fetchRequest.sortDescriptors[0]
                
                
                var directionStatement = "="
                if !useEqualSigns
                {
                    directionStatement = "<="
                    if isAscending {
                        directionStatement = ">="
                    }
                }
                
//                if i != 0
//                {
//                    whereResult += " AND"
//                }
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
            result += " WHERE (" + whereResult + ")"
        }
        
        return result
    }
    
    private func appendOrderByClause(sql:String, isAscending:Bool)->String {
        var result = sql.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        result += " ORDER BY"
        
        
        var primaryKeyFound = false
        for var i=0; i < (fetchRequest.sortDescriptors.count); i++
        {
            let descriptor = fetchRequest.sortDescriptors[i]

            //Determine if primary key is included
            // IF FOUND, because the primary key is unique, there is no need for any other sort descriptors
            
            autoreleasepool({ () -> () in
                var descriptorIsASC = descriptor.isASC
                if !isAscending {
                    descriptorIsASC = !descriptorIsASC
                }
                
                var direction = "DESC"
                if descriptorIsASC {
                    direction = "ASC"
                }
                
                result += " \(descriptor.key) \(direction)"
            })
            
            if descriptor.key == primaryKey
            {
                primaryKeyFound = true
                break
//                    i = fetchRequest.sortDescriptors.count
            }
            
            if i+1 < fetchRequest.sortDescriptors.count {
                result += ","
            }
        }

        if !primaryKeyFound
        {
            var direction = "DESC"
            if isAscending {
                direction = "ASC"
            }
            result += ",\(primaryKey) \(direction)"
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
    
    private func appendOffsetClause(sql:String, inout parameters:[AnyObject], isAscending:Bool, pivotResult:[NSObject:AnyObject]?, offset:Int)->String
    {
        var offsetAddition = ""
        if pivotResult != nil //&& false
        {
            
            //Offsets from the duplicates
            var duplicateOffsetSQL = "(SELECT count(*) FROM ("
            
            duplicateOffsetSQL += getSelectFieldsClause()
            
            duplicateOffsetSQL += " FROM \(fetchRequest.table) "
            
            duplicateOffsetSQL = appendWhereClause(duplicateOffsetSQL, useEqualSigns:true, parameters: &parameters, pivotResult: pivotResult, isAscending: isAscending)
           
            //Reverse to query only results between start of duplicates and current
            var reversedDirection = !isAscending
            var directionStatement = "<="
            if reversedDirection {
                directionStatement = ">="
            }
            
            var pkValue:AnyObject! = pivotResult![primaryKey]
            var reverseCondition = "\(primaryKey) \(directionStatement) ?"
            parameters.append(pkValue)
            
            if duplicateOffsetSQL.rangeOfString("WHERE") == nil
            {
                duplicateOffsetSQL += " WHERE \(reverseCondition)"
            }
            else {
                duplicateOffsetSQL += " AND \(reverseCondition)"
            }
            
            duplicateOffsetSQL = appendOrderByClause(duplicateOffsetSQL, isAscending: isAscending)
            duplicateOffsetSQL = appendGroupByClause(duplicateOffsetSQL)
            duplicateOffsetSQL = appendHavingClause(duplicateOffsetSQL)
            
            duplicateOffsetSQL += " ))"
            
            var sign = "+"
            var modifier = ""
            if !isAscending
            {
//                sign = "-"
//                var modifier = " - 1"
            }
            
            offsetAddition = "\(sign) ( \(duplicateOffsetSQL) \(modifier) )"
        }
        
        var trimmedSQL = sql.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        return trimmedSQL + " OFFSET ( \(offset) \(offsetAddition) )"
    }
    
    private func openDatabase()->FMDatabase? {
        var db = FMDatabase(path: databasePath)
        if db.open()
        {
            db.setShouldCacheStatements(true)
            return db
        }
        return nil
    }
    
    private func makeCountSQL()->String {
        
        var result = "SELECT count(*) FROM (SELECT \(primaryKey) FROM \(fetchRequest.table)"
        var whereClause = fetchRequest.predicate ?? ""
        if count(whereClause) > 0
        {
            result += " WHERE \(whereClause)"
        }
        result = appendGroupByClause(result)
        result = appendHavingClause(result)
        result += ");"
        
        if DEBUG { println("COUNT: \(result)") }
        
        return result
    }
    
    
    //MARK: Displaying Data
    
    private func printResults() {
        var i = 0
        for item in loadedResults
        {
            autoreleasepool({ () -> () in
                println("\(++i). \(item)")
            })
        }
    }
}
