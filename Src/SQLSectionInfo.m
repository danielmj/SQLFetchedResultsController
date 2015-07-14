//
//  SQLSectionInfo.m
//  SQL Fetch Example
//
//  Created by Daniel Jackson on 7/12/15.
//  Copyright (c) 2015 Daniel Jackson. All rights reserved.
//

#import "SQLSectionInfo.h"

@interface SQLSectionInfo ()

@property (readwrite, nonatomic) NSInteger numberOfObjects;
@property (readwrite, nonatomic, strong) NSString* name;
@property (readwrite, nonatomic, strong) NSString* indexTitle;
@property (readwrite, nonatomic) NSInteger positionInTable;

@end

@implementation SQLSectionInfo

- (id)initWithName:(NSString*)name indexTitle:(NSString*)indexTitle numberOfObjects:(NSInteger)numObjects positionInTable:(NSInteger)position
{
    self = [super init];
    if (self)
    {
        self.indexTitle = indexTitle;
        self.name = name;
        self.numberOfObjects = numObjects;
        self.positionInTable = position;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    SQLSectionInfo* new = [[SQLSectionInfo alloc] init];
    
    new.indexTitle          = self.indexTitle;
    new.name                = self.name;
    new.numberOfObjects     = self.numberOfObjects;
    
    return new;
}

@end
