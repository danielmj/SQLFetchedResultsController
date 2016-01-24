//
//  TableViewController.m
//  SQL Fetch Example
//
//  Created by Daniel Jackson on 1/24/16.
//  Copyright © 2016 Daniel Jackson. All rights reserved.
//

#import "TableViewController.h"
#import "SQLFRC.h"
#import "SQL_Fetch_Example-Swift.h"

@interface TableViewController ()
@property (nonatomic, weak) IBOutlet UITableView* tableView;
@property (nonatomic,strong) SQLFetchedResultsController* fetchController;
@end

@implementation TableViewController
@synthesize fetchController;

- (void)viewDidLoad
{
    SQLFetchRequest* request = [[SQLFetchRequest alloc] init];
    request.table = @"(SELECT id, title FROM TEST)";
    request.fields = @[@"id", @"title"];
    request.predicate = @"id % 100 = 0";
    SQLSortDescriptor* descriptor = [[SQLSortDescriptor alloc] initWithKey:@"cast(id as text)" ascending:true];
    request.sortDescriptors = @[descriptor];
    fetchController = [[SQLFetchedResultsController alloc] initWithRequest:request pathToDatabase:[DatabaseSetup getDatabasePath] uniqueKey:@"id" sectionKey:@"id"];
    
    [fetchController previewSQL];
}

-(NSArray*)sectionIndexTitlesForTableView:(UITableView*)tableView
{
    return fetchController.sectionIndexTitles;
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return fetchController.sections.count;
}

-(NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return [fetchController sectionForSectionIndexTitle:title atIndex:index];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"ReuseCell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ReuseCell"];
    }
    
    NSDictionary* result = [fetchController objectAtIndexPath:indexPath];
    NSObject* rowId = result[@"id"];
    NSObject* rowTitle = result[@"title"];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ : %@", rowId, rowTitle];
    
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [(SQLSectionInfo*)fetchController.sections[section] numberOfObjects];
}

@end
