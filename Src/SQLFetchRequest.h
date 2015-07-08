//
//  SQLFetchRequest.h
//  SQL Fetch Example
//
//  Created by Daniel Jackson on 7/8/15.
//  Copyright (c) 2015 Daniel Jackson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SQLSortDescriptor.h"

@interface SQLFetchRequest : NSObject <NSCopying>

/**
 Required. Please enter the table(s) for which you are querying. This value corresponds to [table] in the example below.
 
 SELECT * FROM [table] WHERE ...
 */
@property (nonatomic, strong) NSString* table;


/** OPTIONAL: This is where the magic happens.

 This takes an array of SQLSortDescriptors
 */

@property (nonatomic, strong) NSArray* sortDescriptors;

/** Optional. Please enter field values (other SQL expressions allowed) formatted for SQLite. This value corresponds to [fields] in the example below.
 
 SELECT [fields] FROM ...
 
 This takes an array of NSStrings.
 */
@property (nonatomic, strong) NSArray* fields;


/** Optional. Please enter a predicate (other SQL expressions allowed) formatted for SQLite. This will take the place of a WHERE clause.
 
 ... WHERE [predicate] ...
 
 **Example:**  predicate = "Date='062915' AND id=103"
 
 **Example:**  predicate = "Date='062915' AND id=(SELECT id FROM Users WHERE email='test@domain.com')"
 */
@property (nonatomic, strong) NSString* predicate;



/** Optional. Please enter a GROUP BY clause formatted for SQLite.
 
 ... GROUP BY [groupBy] ...
 
 **Example:**  groupBy = "title"
 */
@property (nonatomic, strong) NSString* groupBy;


/** Optional. Please enter a HAVING clause formatted for SQLite.
 
 ... HAVING [having] ...
 
 **Example:**  having = "COUNT(*) > 2"
 */
@property (nonatomic, strong) NSString* having;

/// 3 batches will remain in memory.This is to ensure that there is always available data to pull.
///  Ensure that the batch size is large enough to cover the length of your view (or at least most of it).
@property (nonatomic) NSInteger batchSize;

@end
