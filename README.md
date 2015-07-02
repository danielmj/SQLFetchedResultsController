# SQLFetchedResultsController

An attempt at making it easier to setup tables with SQLite. There are few examples of how to properly page through results in a database. I want to fix this.

**WARNING** This script is still being developed. It might not always show the list correctly. Please bear with me while I get things worked out. If you want to help me address some of my Todo topics below, please do.

# How Does It Work?

Loading objects incrementally is fast. This is because it uses the sort descriptors as part of the WHERE 
clause to improve speed. It is recommended that you use indexed sort descriptors for maximum speed.

Loading objects at arbitrary locations will be slow(er). This is because the program does not know the
values of the sort descriptors and it does not know the primary key value at this location. Because of this, the program must
use the closest known values as pivots, and then do an offset from that location. Offset is inherently bad 
because it causes the database to do a sequential search. This is not a big deal if the jump you are making 
is a distance of 5 values. However, if you are making a jump of 1 million values, you will see slowing.

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
        request.table = "Test as t"
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
        cell.textLabel?.text = "\(id). \(title)"
        
        return cell
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchController?.numberOfRows ?? 0
    }
```
