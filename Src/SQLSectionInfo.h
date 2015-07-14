//
//  SQLSectionInfo.h
//  SQL Fetch Example
//
//  Created by Daniel Jackson on 7/12/15.
//  Copyright (c) 2015 Daniel Jackson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SQLSectionInfo : NSObject <NSCopying>

@property (readonly, nonatomic) NSInteger numberOfObjects;
@property (readonly, nonatomic, strong) NSString* name;
@property (readonly, nonatomic, strong) NSString* indexTitle;

//If all items in table were given in one list, this would be the index.
@property (readonly, nonatomic) NSInteger positionInTable;


- (id)initWithName:(NSString*)name indexTitle:(NSString*)indexTitle numberOfObjects:(NSInteger)numObjects positionInTable:(NSInteger)position;

@end
