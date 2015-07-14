//
//  SQLFetchedResultsController.h
//  SQL Fetch Example
//
//  Created by Daniel Jackson on 7/8/15.
//  Copyright (c) 2015 Daniel Jackson. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SQLFetchRequest;

@interface SQLFetchedResultsController : NSObject

/// Count of all objects returned from the request
@property (readonly, nonatomic) NSInteger numberOfRows;

/** 
 Fetches all objects from the request. This does not keep all objects in memory.
 It is a simply performs a fetch and returns an array
 */
@property (readonly, nonatomic) NSArray* fetchedObjects;

@property (readonly, nonatomic, strong) NSString* databasePath;

@property (readonly, nonatomic, strong) SQLFetchRequest* fetchRequest;

@property (readonly, nonatomic, strong) NSString *sectionNameKeyPath;

/// Returns array of SQLSectionInfo classes. Based on the first sort descriptor.
@property (readonly, nonatomic, strong) NSArray* sections;

@property (readonly, nonatomic, strong) NSArray* sectionIndexTitles;


/**
 Creates a new instance of SQLFetchedResultsController
 
 @param request An instance of SQLFetchRequest. 
 @param path A path to the SQLite database file
 @param uniqueKey A unique key that will be used to distinguish the tuple in a set of duplicates. Just use the primary key if you are unsure.
 @param keyPath Used to setup sections.
 */
- (id)initWithRequest:(SQLFetchRequest*)request
       pathToDatabase:(NSString*)path
            uniqueKey:(NSString*)uniqueKey
           sectionKey:(NSString*)keyPath;

- (NSDictionary*)objectAtIndexPath:(NSIndexPath*)indexPath;

- (NSInteger)sectionForSectionIndexTitle:(NSString*)title atIndex:(NSInteger)index;

- (void)printResults;

- (void)previewSQL;

@end
