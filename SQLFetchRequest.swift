//
//  SQLFetchRequest.swift
//  SQL Fetch Example
//
//  Created by Daniel Jackson on 6/29/15.
//  Copyright (c) 2015 Daniel Jackson. All rights reserved.
//

import UIKit

public class SQLFetchRequest: NSObject, NSCopying {

/**
Required. Please enter the table(s) for which you are querying. This value corresponds to [table] in the example below.

 SELECT * FROM [table] WHERE ...
 */
    var table:String = ""
    
    
/// OPTIONAL: This is where the magic happens. It is recommended that your sort descriptors be indexed for faster sorting and quering.
///  If you do not include a primary key, one will be included automatically.
    var sortDescriptors:[(key:String, isASC:Bool)] = []
    
    
    
/** Optional. Please enter field values (other SQL expressions allowed) formatted for SQLite. This value corresponds to [fields] in the example below.

 SELECT [fields] FROM ...
    
 Default: *
 */
    var fields:[String]?
    
    
    
/** Optional. Please enter a predicate (other SQL expressions allowed) formatted for SQLite. This will take the place of a WHERE clause.

 ... WHERE [predicate] ...

 **Example:**  predicate = "Date='062915' AND id=103"
    
 **Example:**  predicate = "Date='062915' AND id=(SELECT id FROM Users WHERE email='test@domain.com')"
 */
    var predicate:String?
    
    
    
/** Optional. Please enter a GROUP BY clause formatted for SQLite.

 ... GROUP BY [groupBy] ...

 **Example:**  groupBy = "title"
 */
    var groupBy:String?
    
    
    
/** Optional. Please enter a HAVING clause formatted for SQLite.

 ... HAVING [having] ...

 **Example:**  having = "COUNT(*) > 2"
 */
    var having:String?

/// 3 batches will remain in memory.This is to ensure that there is always available data to pull. 
///  Ensure that the batch size is large enough to cover the length of your view (or at least most of it).
    var batchSize = 15

    
    public func copyWithZone(zone: NSZone) -> AnyObject {
        let theCopy = SQLFetchRequest()
        
        theCopy.table = table
        theCopy.sortDescriptors = sortDescriptors
        theCopy.fields = fields
        theCopy.predicate = predicate
        theCopy.groupBy = groupBy
        theCopy.having = having
        theCopy.batchSize = batchSize
        
        return theCopy
    }
}
