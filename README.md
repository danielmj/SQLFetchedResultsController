# SQLFetchedResultsController

An attempt at making it easier to setup tables with SQLite

**WARNING** This script is still being developed. It might not always show the list correctly. Please bear with me while I get things worked out. If you want to help me address some of my Todo topics below, please do.

# Requires

- FMDB

# Todo

- Fix bugs with ensuring that all data appears with short tables and large tables
- Fix bugs with group by and having fetch parameters
- Add section support
- Add section index title support

# How to use

Initialize the fetch controller:
```
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var request = SQLFetchRequest()
        request.table = "Test"
        request.fields = "id, title"
        request.predicate = "id % 2 = 0"
        request.sortDescriptors = [(key:"title", isASC:true)]
        fetchController = SQLFetchedResultsController(request: request, pathToDatabase: DatabaseSetup.getDatabasePath())
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
