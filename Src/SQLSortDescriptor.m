//
//  SQLSortDescriptor.m
//  SQL Fetch Example
//
//  Created by Daniel Jackson on 7/8/15.
//  Copyright (c) 2015 Daniel Jackson. All rights reserved.
//

#import "SQLSortDescriptor.h"

@implementation SQLSortDescriptor

- (id)initWithKey:(NSString*)key ascending:(BOOL)ascending
{
    self = [super init];
    if (self) {
        _key = key;
        _ascending = ascending;
    }
    return self;
}

@end
