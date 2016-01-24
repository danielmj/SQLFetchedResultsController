//
//  DataTableViewController.swift
//  SQL Fetch Example
//
//  Created by Daniel Jackson on 6/29/15.
//  Copyright (c) 2015 Daniel Jackson. All rights reserved.
//

import UIKit

class TableViewController_SwiftVersion: UIViewController, UITableViewDataSource, UITableViewDelegate
{
    @IBOutlet var tableView:UITableView?
    var fetchController:SQLFetchedResultsController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let request = SQLFetchRequest()
        request.table = "(SELECT id, title FROM Test)" // Do not use > 1 table or sql expression
        request.fields = ["id","title"]
        request.predicate = "id % 100 = 0"
        request.sortDescriptors = [SQLSortDescriptor(key: "cast(id as text)", ascending: true)] //Sort id like a string
//        request.groupBy = "title"
//        request.having = "count(*) > 3"
        fetchController = SQLFetchedResultsController(request: request, pathToDatabase: DatabaseSetup.getDatabasePath(), uniqueKey:"id", sectionKey: "id")
        
        fetchController?.previewSQL()
    }
    
    func sectionIndexTitlesForTableView(tableView: UITableView) -> [String]! {
        return (fetchController?.sectionIndexTitles as? [String]) ?? [];
    }
    
    func tableView(tableView: UITableView, sectionForSectionIndexTitle title: String, atIndex index: Int) -> Int {
        return fetchController?.sectionForSectionIndexTitle(title, atIndex: index) ?? 0
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return fetchController?.sections.count ?? 0
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier("ReuseCell")

        if (cell == nil) {
            cell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: "ReuseCell")
        }

        let result = fetchController?.objectAtIndexPath(indexPath)
        let id:AnyObject! = result?["id"]
        let title:AnyObject! = result?["title"]
        cell!.textLabel?.text = "\(id) : \(title)"

        return cell!
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (fetchController?.sections[section] as? SQLSectionInfo)?.numberOfObjects ?? 0
    }
}
