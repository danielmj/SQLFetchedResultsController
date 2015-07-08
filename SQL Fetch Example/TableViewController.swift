//
//  DataTableViewController.swift
//  SQL Fetch Example
//
//  Created by Daniel Jackson on 6/29/15.
//  Copyright (c) 2015 Daniel Jackson. All rights reserved.
//

import UIKit

class TableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate
{
    @IBOutlet var tableView:UITableView?
    var fetchController:SQLFetchedResultsController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var request = SQLFetchRequest()
        request.table = "Test" //Not tested with > 1 table
        request.fields = ["id","title"]
//        request.predicate = "id % 100 = 0"
//        request.sortDescriptors = [(key:"title", isASC:true), (key:"subtitle", isASC:true), (key:"id", isASC:true)]
//        request.groupBy = "title"
//        request.having = "count(*) > 3"
        fetchController = SQLFetchedResultsController(request: request, pathToDatabase: DatabaseSetup.getDatabasePath())
        
        let preview = fetchController!.previewSQL()
        println("--SQL Preview: \(preview.SQL) \n--Parameters: \(preview.Parameters)")
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier("ReuseCell") as? UITableViewCell

        if (cell == nil) {
            cell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: "ReuseCell")
        }

        let result = fetchController?.objectAt(indexPath)
        var id:AnyObject! = result?["id"]
        var title:AnyObject! = result?["title"]
        cell!.textLabel?.text = "\(indexPath.row).) \(id) : \(title)"

        return cell!
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchController?.numberOfRows ?? 0
    }
}
