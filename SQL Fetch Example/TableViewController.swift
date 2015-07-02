//
//  DataTableViewController.swift
//  SQL Fetch Example
//
//  Created by Daniel Jackson on 6/29/15.
//  Copyright (c) 2015 Daniel Jackson. All rights reserved.
//

import UIKit

class TableViewController: UITableViewController
{
    var fetchController:SQLFetchedResultsController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var request = SQLFetchRequest()
        request.table = "Test as t" //Not tested with > 1 table
        request.fields = ["id","title", "(SELECT AVG(id) FROM Test WHERE title=t.title) as idAvg"]
        request.predicate = "id % 10 = 0 AND title != 'SomeString'"
//        request.sortDescriptors = [(key:"title", isASC:true)]
//        request.groupBy = "title"
//        request.having = "count(*) > 3"
        fetchController = SQLFetchedResultsController(request: request, pathToDatabase: DatabaseSetup.getDatabasePath())
        
        let preview = fetchController!.previewSQL()
        println("--SQL Preview: \(preview.SQL) \n--Parameters: \(preview.Parameters)")
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: "standard")
        
        var result = fetchController?.objectAt(indexPath)
        var id:AnyObject! = result?["id"]
        var title:AnyObject! = result?["title"]
        cell.textLabel?.text = "\(id). \(title)"
        
        return cell
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchController?.numberOfRows ?? 0
    }
}
