# SQLFetchedResultsController

An attempt at making it easier to setup tables with SQLite. There arent many examples of how to properly page through results in a database. I want to fix this. For those that enjoy the flexibility that SQL has to offer but dont want to give up the ease of setting up tables that you would get with Core Data's NSFetchedResultsController, this class is for you.

**WARNING** This script is still being developed. It might not always show the list correctly. Please bear with me while I get things worked out. If you want to help me address some of my Todo topics below, please do.

# How Does It Work?

The class attempts to progressively load objects using the where clause and the first sort descriptor. Basically if you are ascending in the table the where clause will use sortKey >= sortValue to page the next results and if you are descending in the table the where clause will use sortKey <= sortValue to page the next results. The problem with this is duplicates. To get around this, we use the OFFSET value. Because OFFSET is inherently slow, it is better to use a sortKey that does not have that many duplicates.

This class also uses the table's primary key to help distinguish the tuple in a group of duplicate sorted values. The primary key is derived from the first table specified. This primary key will always be given in the resulting object.

When the class detects a large jump in the table, it will set the OFFSET from the closest known value.

# Requires

- FMDB

# Todo

- Fix bugs with ensuring that all data appears with short tables and large tables
- Fix bugs with group by and having fetch parameters
- Add section support
- Add section index title support
- Add method to jump to arbitrary location based on primary key value. This should improve the efficiency of jumping to arbitrary locations.

# How to use

Initialize the fetch controller:
```
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var request = SQLFetchRequest()
        request.table = "Test as t" //Not tested with > 1 table
        request.fields = ["id","title", "(SELECT AVG(id) FROM Test WHERE title=t.title) as idAvg"]
        request.predicate = "id % 10 = 0 AND title != 'SomeString'"
        request.sortDescriptors = [(key:"title", isASC:true)]
        request.groupBy = "title"
        request.having = "count(*) > 3"
        fetchController = SQLFetchedResultsController(request: request, pathToDatabase: DatabaseSetup.getDatabasePath())
        
        let preview = fetchController!.previewSQL()
        println("--SQL Preview: \(preview.SQL) \n--Parameters: \(preview.Parameters)")
    }
```

Then just setup the table
```
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: "standard")
        
        var result = fetchController?.objectAt(indexPath)
        var id:AnyObject! = result?["id"]
        var title:AnyObject! = result?["title"]
        var idAvg:AnyObject! = result?["idAvg"]
        
        cell.textLabel?.text = "\(id). \(title)"
        
        return cell
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchController?.numberOfRows ?? 0
    }
```
