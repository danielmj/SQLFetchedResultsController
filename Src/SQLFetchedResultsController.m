//
//  SQLFetchedResultsController.m
//  SQL Fetch Example
//
//  Created by Daniel Jackson on 7/8/15.
//  Copyright (c) 2015 Daniel Jackson. All rights reserved.
//

#import "FMDB.h"
#import "SQLFetchedResultsController.h"
#import "SQLFetchRequest.h"
#import "SQLSortDescriptor.h"

#define SQLFRC_DEBUG 0
#define BLOCKS_IN_MEMORY 3

@interface LimitOffset : NSObject
@property (nonatomic) NSInteger limit;
@property (nonatomic) NSInteger offset;
@end
@implementation LimitOffset
@end

@interface SQLFetchedResultsController ()
{
    NSInteger loadedIndexStart;
    NSMutableArray* loadedResults;
    NSInteger lastTableIndex;
    NSString* primaryKey;
}

@property (readwrite, nonatomic, strong) NSString* databasePath;
@property (readwrite, nonatomic, strong) SQLFetchRequest* fetchRequest;

@end

@implementation SQLFetchedResultsController

@synthesize numberOfRows, databasePath, fetchRequest;


- (id)initWithRequest:(SQLFetchRequest*)request pathToDatabase:(NSString*)path
{
    self = [super init];
    if (self)
    {
        fetchRequest = [request copy];
        databasePath = [path copy];
        loadedResults = [[NSMutableArray alloc] init];
        lastTableIndex = -1;
        loadedIndexStart = 0;
        primaryKey = [self fetchPrimaryKey];
        if(primaryKey.length == 0)
        {
            NSLog(@"[ERROR] Table does not include a primary key");
            abort();
        }
        
        numberOfRows = [self fetchTotalRowCount];
        if(SQLFRC_DEBUG) NSLog(@"ROW COUNT: %ld", (long)numberOfRows);
        
        if(fetchRequest.sortDescriptors.count == 0)
        {
            fetchRequest.sortDescriptors = @[[[SQLSortDescriptor alloc] initWithKey:primaryKey ascending:true]];
        }
    }
    return self;
}

- (NSDictionary*)objectAtIndexPath:(NSIndexPath*)indexPath
{
    NSDictionary* result = nil;
    
    NSInteger tableIndex = indexPath.row;
    
    if(SQLFRC_DEBUG) NSLog(@"\n");
    if(SQLFRC_DEBUG) NSLog(@"Accessing Index %ld", (long)indexPath.row);
    
    BOOL isAscending = [self isAscendingAtTableIndex:tableIndex];
    BOOL shouldLoadMore = [self shouldLoadMoreAtTableIndex:tableIndex isAscending:isAscending];
    
    if(SQLFRC_DEBUG) NSLog(@"Assessmenet asc:%d shouldLoadMore:%d",isAscending, shouldLoadMore);
    
    if( shouldLoadMore )
    {
        NSRange window = [self generateWindowAtTableIndex:tableIndex isAscending:isAscending];
        LimitOffset* sqlVar = [self generateLimitOffsetWithWindow:window isAscending:isAscending];
        if(SQLFRC_DEBUG) NSLog(@"Updating Result Window:[%lu,%lu] Limit:%ld Offset:%ld",(unsigned long)window.location,(unsigned long)window.length, (long)sqlVar.limit, (long)sqlVar.offset);
        
        [self updateResultsWithLimit:sqlVar.limit offset:sqlVar.offset isAscending:isAscending];
        
        loadedIndexStart = window.location;
    }
    
    if(SQLFRC_DEBUG) [self printResults];
    
    NSInteger index = [self getActualIndexAtTableIndex:tableIndex];
    if(SQLFRC_DEBUG) NSLog(@"Accessing Loaded Index: %ld", (long)index);
    if(index >=0 && index < loadedResults.count)
    {
        result = loadedResults[index];
        if(SQLFRC_DEBUG) NSLog(@"Object: %@",result);
    }
    
    if(SQLFRC_DEBUG) NSLog(@"NEW currentIndexStart: \(%ld) count:\(%lu)", (long)loadedIndexStart, (unsigned long)loadedResults.count);
    
    return result;
}

- (void)updateResultsWithLimit:(NSInteger)limit offset:(NSInteger)offset isAscending:(BOOL)isAscending
{
    NSDictionary* pivot = [self getPivotIsAscending:isAscending];
    
    if( offset >= fetchRequest.batchSize)
    {
        //A Jump!
        loadedResults = [[NSMutableArray alloc] init];
    }
    
    NSMutableArray* parameters = [[NSMutableArray alloc] init];
    NSString* sql = [self makeUpdateSQLWithParameters:&parameters pivot:pivot isAscending:isAscending limit:limit offset:offset];
    
    [self queryAndAppendWithSQL:(NSString*)sql parameters:(NSMutableArray*)parameters isAscending:(BOOL)isAscending];
    
    [self trimTheFatIsAscending:(BOOL)isAscending];
}

- (void)trimTheFatIsAscending:(BOOL)isAscending
{
    NSInteger totalResultsAllowed = fetchRequest.batchSize * BLOCKS_IN_MEMORY;
    NSInteger difference = loadedResults.count - totalResultsAllowed;
    if( difference > 0 )
    {
        if( isAscending )
        {
            for( int i=0; i < difference; i++ )
            {
                [loadedResults removeObjectAtIndex:0];
            }
        }
        else
        {
            for( int i=0; i < difference; i++ )
            {
                [loadedResults removeObjectAtIndex:loadedResults.count-1];
            }
        }
    }
}

- (void)queryAndAppendWithSQL:(NSString*)sql parameters:(NSMutableArray*)parameters isAscending:(BOOL)isAscending
{
    NSMutableArray* queryParameters = nil;
    if( parameters.count != 0 )
    {
        queryParameters = parameters;
    }
    
    FMDatabase* db = [self openDatabase];
    FMResultSet* s = [db executeQuery:sql withArgumentsInArray:queryParameters];
    NSInteger currentRecord = 0;
    while ([s next]) {
        @autoreleasepool {
            
            NSMutableDictionary* newResult = [[NSMutableDictionary alloc] init];
            
            for( int i = 0; i < [s columnCount]; i++ )
            {
                NSString* key = [s columnNameForIndex:i];
                id value = [s objectForColumnIndex:i];
                newResult[key] = value;
            }
            
            if( isAscending ) {
                [loadedResults addObject:newResult];
            }
            else {
                [loadedResults insertObject:newResult atIndex:0];
            }
            currentRecord++;
        }
    }
    [db close];
    db = nil;
}

- (NSString*)makeUpdateSQLWithParameters:(NSMutableArray**)parameters pivot:(NSDictionary*)pivot
                             isAscending:(BOOL)isAscending limit:(NSInteger)limit
                                  offset:(NSInteger)offset
{
    NSMutableString* result = nil;
    
    result = [self getSelectFields];
    [self appendTableNameToResult:&result];
    [self appendWhereToResult:&result useEqualSign:false parameters:parameters pivot:pivot isAscending:isAscending];
    [self appendGroupByToResult:&result];
    [self appendHavingToResult:&result];
    [self appendOrderByToResult:&result isAscending:isAscending];
    [self appendLimitToResult:&result limit:limit];
    [self appendOffsetToResult:&result parameters:parameters pivot:pivot offset:offset isAscending:isAscending];
    
    if(SQLFRC_DEBUG) NSLog(@"SQL: %@ Parameters: %@", result,*parameters);
    
    [result appendString:@";"];
    
    return result;
}

- (void)appendOffsetToResult:(NSMutableString**)sql parameters:(NSMutableArray**)parameters pivot:(NSDictionary*)pivot offset:(NSInteger)offset isAscending:(BOOL)isAscending
{
    NSString* offsetAddition = @"";
    if( pivot != nil )//&& false
    {
        
        //Offsets from the duplicates
        NSMutableString* duplicateOffsetSQL = [NSMutableString stringWithString:@"(SELECT count(*) FROM ("];
        
        [duplicateOffsetSQL appendString:[self getSelectFields]];
        
        [duplicateOffsetSQL appendFormat:@" FROM %@ ",fetchRequest.table];

        [self appendWhereToResult:&duplicateOffsetSQL useEqualSign:true parameters:parameters pivot:pivot isAscending:isAscending];
        
        //Reverse to query only results between start of duplicates and current
        BOOL reversedDirection = !isAscending;
        NSString* directionStatement = @"<=";
        if( reversedDirection ) {
            directionStatement = @">=";
        }
        
        id pkValue = pivot[primaryKey];
        NSString* reverseCondition = [NSString stringWithFormat:@"%@ %@ ?",primaryKey, directionStatement];
        [*parameters addObject:pkValue];
        
        if( [duplicateOffsetSQL rangeOfString:@"WHERE"].location == NSNotFound )
        {
            [duplicateOffsetSQL appendFormat:@" WHERE %@",reverseCondition];
        }
        else {
            [duplicateOffsetSQL appendFormat:@" AND %@",reverseCondition];
        }
        
        [self appendOrderByToResult:&duplicateOffsetSQL isAscending:isAscending];
        [self appendGroupByToResult:&duplicateOffsetSQL];
        [self appendHavingToResult:&duplicateOffsetSQL];
        
        [duplicateOffsetSQL appendString:@" ))"];
        
        NSString* sign = @"+";
        NSString* modifier = @"";
        if( !isAscending )
        {
            //                sign = "-"
            //                var modifier = " - 1"
        }
        
        offsetAddition = [NSString stringWithFormat:@"%@ ( %@ %@ )", sign, duplicateOffsetSQL, modifier];
    }
    
    *sql = [NSMutableString stringWithString:[*sql stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    [*sql appendFormat:@" OFFSET ( %ld %@ )",(long)offset, offsetAddition];
}

- (void)appendLimitToResult:(NSMutableString**)sql limit:(NSInteger)limit
{
    *sql = [NSMutableString stringWithString:[*sql stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    [*sql appendFormat:@" LIMIT %ld",(long)limit];
}

- (void)appendOrderByToResult:(NSMutableString**)sql isAscending:(BOOL)isAscending
{
    *sql = [NSMutableString stringWithString:[*sql stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    [*sql appendString:@" ORDER BY"];
    
    
    BOOL primaryKeyFound = false;
    for( NSInteger i=0; i < (fetchRequest.sortDescriptors.count); i++ )
    {
        SQLSortDescriptor* descriptor = fetchRequest.sortDescriptors[i];
        
        //Determine if primary key is included
        // IF FOUND, because the primary key is unique, there is no need for any other sort descriptors
        
        @autoreleasepool {
            BOOL descriptorIsASC = descriptor.ascending;
            if( !isAscending ) {
                descriptorIsASC = !descriptorIsASC;
            }
            
            NSString* direction = @"DESC";
            if( descriptorIsASC ) {
                direction = @"ASC";
            }
            
            [*sql appendFormat:@" %@ %@",descriptor.key, direction];
        }
        
        if( [descriptor.key isEqualToString: primaryKey] )
        {
            primaryKeyFound = true;
            break;
            //                    i = fetchRequest.sortDescriptors.count
        }
        
        if( i+1 < fetchRequest.sortDescriptors.count ) {
            [*sql appendString:@","];
        }
    }
    
    if( !primaryKeyFound )
    {
        NSString* direction = @"DESC";
        if( isAscending ) {
            direction = @"ASC";
        }
        [*sql appendFormat:@",%@ %@", primaryKey, direction];
    }
}

- (void)appendGroupByToResult:(NSMutableString**)sql
{
    *sql = [NSMutableString stringWithString:[*sql stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    NSString* groupBy = fetchRequest.groupBy;
    if( [groupBy length] > 0 )
    {
        [*sql appendFormat:@" GROUP BY %@",groupBy];
    }
}

- (void)appendHavingToResult:(NSMutableString**)sql
{
    *sql = [NSMutableString stringWithString:[*sql stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    NSString* having = fetchRequest.having;
    if( [having length] > 0 )
    {
        [*sql appendFormat:@" HAVING %@",having];
    }
}

- (void)appendWhereToResult:(NSMutableString**)sql useEqualSign:(BOOL)useEqualSigns
                 parameters:(NSMutableArray**)parameters pivot:(NSDictionary*)pivot isAscending:(BOOL)isAscending
{
    *sql = [NSMutableString stringWithString:[*sql stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    
    NSMutableString* whereResult = [[NSMutableString alloc] init];
    
    if( pivot != nil )
    {
        [whereResult appendString:@" ("];
        if( fetchRequest.sortDescriptors.count > 0 )
        {
            SQLSortDescriptor* descriptor = fetchRequest.sortDescriptors[0];
            
            
            NSString* directionStatement = @"=";
            if( !useEqualSigns )
            {
                directionStatement = @"<=";
                if( isAscending ) {
                    directionStatement = @">=";
                }
            }
            
            //                if i != 0
            //                {
            //                    whereResult += " AND"
            //                }
            [whereResult appendFormat:@" %@ %@ ?",descriptor.key, directionStatement];
            id descriptorValue = pivot[descriptor.key];
            [*parameters addObject:descriptorValue];
        }
        [whereResult appendString:@" )"];
    }
    
    if( fetchRequest.predicate.length > 0 )
    {
        if( pivot != nil ){
            [whereResult appendString:@" AND"];
        }
        [whereResult appendFormat:@" %@ ",fetchRequest.predicate];
    }
    
    if( whereResult.length > 0 )
    {
        [*sql appendString:@" WHERE ("];
        [*sql appendString:whereResult];
        [*sql appendString:@")"];
    }
}

- (void)appendTableNameToResult:(NSMutableString**)sql
{
    *sql = [NSMutableString stringWithString:[*sql stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    [*sql appendFormat:@" FROM %@",fetchRequest.table];
}

- (NSMutableString*)getSelectFields
{
    NSMutableArray* fields = [NSMutableArray arrayWithArray:fetchRequest.fields];
    
    for(SQLSortDescriptor* descriptor in fetchRequest.sortDescriptors)
    {
        BOOL found = false;
        for( NSString* f in fields )
        {
            if( [f isEqualToString:descriptor.key] )
            {
                found = true;
            }
        }
        
        if( !found ) {
            [fields addObject:descriptor.key];
        }
    }
    
    NSMutableString* fieldString = [[NSMutableString alloc] init];
    for( NSInteger i=0; i < fields.count; i++ )
    {
        if( i != 0 ) {
            [fieldString appendString:@","];
        }
        
        [fieldString appendString:fields[i]];
    }
    
    [fieldString insertString:@"SELECT " atIndex:0];
    
    return fieldString;
}

- (NSInteger)getActualIndexAtTableIndex:(NSInteger)tableIndex
{
    return tableIndex - loadedIndexStart;
}

- (void)previewSQL
{
    NSMutableArray* param = [[NSMutableArray alloc] init];
    NSLog(@"SQL: %@ ----- PARAMS: %@",[self makeUpdateSQLWithParameters:&param pivot:nil isAscending:true limit:fetchRequest.batchSize offset:0], param);
}

- (void)printResults
{
    int i = 0;
    for( NSDictionary* item in loadedResults )
    {
        @autoreleasepool {
            NSLog(@"%d. %@", ++i, item);
        }
    }
}

- (NSRange)generateWindowAtTableIndex:(NSInteger)tableIndex isAscending:(BOOL)isAscending
{
    NSInteger start = 0;
    NSInteger count = 0;
    
    if (isAscending)
    {
        count = fetchRequest.batchSize * BLOCKS_IN_MEMORY;
        start = tableIndex - (count / 3);
    }
    else
    {
        count = fetchRequest.batchSize * BLOCKS_IN_MEMORY;
        start = tableIndex - (count * 2 / 3);
    }
    
    if (start+count > numberOfRows)
    {
        count = fetchRequest.batchSize * BLOCKS_IN_MEMORY;
        start = numberOfRows - count;
    }
    
    if (start < 0)
    {
        count = fetchRequest.batchSize * BLOCKS_IN_MEMORY;
        start = 0;
    }
    
    return NSMakeRange(start, count);
}


- (LimitOffset*)generateLimitOffsetWithWindow:(NSRange)window isAscending:(BOOL)isAscending
{
    LimitOffset* result = [[LimitOffset alloc] init];
    
    NSInteger startIndex = window.location;
    NSInteger count = window.length;
    
    NSInteger pivotIndex = [self getPivotIndexIsAscending:isAscending];
    
    if(isAscending)
    {
        NSInteger distanceToWindow = (startIndex - pivotIndex);
        if( distanceToWindow > 0 )
        {
            result.offset = distanceToWindow;
            result.limit = count;
        }
        else //If window start alread is loaded
        {
            result.offset = 0;
            result.limit = count - labs(distanceToWindow);
        }
    }
    else //DESC
    {
        NSInteger topOfWindow = (startIndex+count);
        NSInteger distanceToWindow = pivotIndex - topOfWindow;
        if( distanceToWindow > 0 )
        {
            result.offset = distanceToWindow;
            result.limit = count;
        }
        else //If window start alread is loaded
        {
            result.offset = 0;
            result.limit = count - ABS(distanceToWindow);
        }
    }
    
    return result;
}


- (NSInteger)getPivotIndexIsAscending:(BOOL)isAscending
{
    NSInteger result = 0;
    if( loadedResults.count > 0 )
    {
        if( isAscending )
        {
            result = loadedIndexStart+loadedResults.count;
        }
        else
        {
            result = loadedIndexStart;
        }
    }
    return result;
}

- (NSDictionary*)getPivotIsAscending:(BOOL)isAscending
{
    NSDictionary* result = nil;
    
    if( loadedResults.count > 0 )
    {
        if( isAscending )
        {
            result = loadedResults[loadedResults.count-1];
        }
        else
        {
            result = loadedResults[0];
        }
    }
    return result;
}


- (BOOL)shouldLoadMoreAtTableIndex:(NSInteger)tableIndex isAscending:(BOOL)isAscending
{
    BOOL result = false;
    
    NSInteger maxResultCount = BLOCKS_IN_MEMORY * fetchRequest.batchSize;
    NSInteger inset = (NSInteger)((double)maxResultCount/3.0);
    NSInteger currentIndex = [self getActualIndexAtTableIndex:tableIndex];
    if( currentIndex < inset && !isAscending )
    {
        result = true;
    }
    else if( currentIndex > (NSInteger)((loadedResults.count)-inset+1) && isAscending )
    {
        result = true;
    }
    
    return result;
}

- (BOOL)isAscendingAtTableIndex:(NSInteger)tableIndex
{
    BOOL result = false;
    
    if( tableIndex > lastTableIndex ) {
        result = true;
    }
    else {
        result = false;
    }
    lastTableIndex = tableIndex;
    
    return result;
}

- (NSInteger)fetchTotalRowCount
{
    NSInteger result = 0;
    FMDatabase* db = [self openDatabase];
    NSString* sql = [self makeCountSQL];
    FMResultSet* rs = [db executeQuery:sql];
    if ([rs next])
    {
        result = [rs longForColumn:@"count(*)"];
    }
    return result;
}

- (NSString*)fetchPrimaryKey
{
    NSString* result = nil;
    NSString* table = [fetchRequest.table componentsSeparatedByString:@" "][0];
    FMDatabase* db = [self openDatabase];
    NSString* sql = [NSString stringWithFormat:@"PRAGMA table_info(%@);", table];
    FMResultSet* rs = [db executeQuery:sql];
    while([rs next])
    {
        if ([rs intForColumn:@"pk"] == 1)
        {
            result = [rs stringForColumn:@"name"];
            break;
        }
    }
    return result;
}

- (FMDatabase*)openDatabase
{
    FMDatabase* db = [[FMDatabase alloc] initWithPath:databasePath];
    if([db open])
    {
        [db setShouldCacheStatements:true];
        return db;
    }
    return nil;
}

-(NSString*)makeCountSQL
{
    NSMutableString* result = [[NSMutableString alloc] init];
    [result appendFormat:@"SELECT count(*) FROM (SELECT %@ FROM %@", primaryKey, fetchRequest.table];
    NSString* whereClause = fetchRequest.predicate;
    if ([whereClause length] > 0)
    {
        [result appendFormat:@" WHERE %@",whereClause];
    }
    [self appendGroupByToResult:&result];//appendGroupByClause(result)
    [self appendHavingToResult:&result];//appendHavingClause(result)
    [result appendString:@");"];
    
    if( SQLFRC_DEBUG ) NSLog(@"COUNT: %@", result);
    
    return result;
}


@end
