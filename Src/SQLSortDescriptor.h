//
//  SQLSortDescriptor.h
//  SQL Fetch Example
//
//  Created by Daniel Jackson on 7/8/15.
//  Copyright (c) 2015 Daniel Jackson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SQLSortDescriptor : NSObject

@property (nonatomic, strong) NSString* key;
@property (nonatomic) BOOL ascending;

- (id)initWithKey:(NSString*)key ascending:(BOOL)ascending;

@end
