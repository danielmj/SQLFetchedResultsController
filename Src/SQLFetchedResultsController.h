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

@property (nonatomic) NSInteger numberOfRows;
@property (readonly, nonatomic, strong) NSString* databasePath;
@property (readonly, nonatomic, strong) SQLFetchRequest* fetchRequest;

- (id)initWithRequest:(SQLFetchRequest*)request pathToDatabase:(NSString*)path;

- (NSDictionary*)objectAtIndexPath:(NSIndexPath*)indexPath;

- (void)printResults;

- (void)previewSQL;

@end
