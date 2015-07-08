//
//  SQLFetchRequest.m
//  SQL Fetch Example
//
//  Created by Daniel Jackson on 7/8/15.
//  Copyright (c) 2015 Daniel Jackson. All rights reserved.
//

#import "SQLFetchRequest.h"

@implementation SQLFetchRequest

//@synthesize sortDescriptors, table, fields, predicate, groupBy, having, batchSize;

- (id)init
{
    self = [super init];
    if(self)
    {
        _batchSize = 20;
    }
    return self;
}

-(id)copyWithZone:(NSZone *)zone
{
    SQLFetchRequest* theCopy = [[SQLFetchRequest alloc] init];
    
    theCopy.table = _table;
    theCopy.sortDescriptors = _sortDescriptors;
    theCopy.fields = _fields;
    theCopy.predicate = _predicate;
    theCopy.groupBy = _groupBy;
    theCopy.having = _having;
    theCopy.batchSize = _batchSize;
    
    return theCopy;
}

@end
