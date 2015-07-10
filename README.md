# SQLFetchedResultsController

An attempt at making it easier to setup tables with SQLite. There arent many examples of how to properly page through results in a database. I want to fix this. For those that enjoy the flexibility that SQL has to offer but dont want to give up the ease of setting up tables that you would get with Core Data's NSFetchedResultsController, this class is for you.

**WARNING** This script is still being developed. It might not always show the list correctly. Please bear with me while I get things worked out. If you want to help me address some of my Todo topics below, please do.

# How Does It Work?

The class attempts to progressively load objects using the where clause and the first sort descriptor. Basically if you are ascending in the table the where clause will use sortKey >= sortValue to page the next results and if you are descending in the table the where clause will use sortKey <= sortValue to page the next results. The problem with this is duplicates. To get around this, we use the OFFSET value. Because OFFSET is inherently slow, it is better to use a sortKey that does not have that many duplicates.

This class also uses the table's primary key to help distinguish the tuple in a group of duplicate sorted values. The primary key is derived from the first table specified. This primary key will always be given in the resulting object.

When the class detects a large jump in the table, it will set the OFFSET from the closest known value.

Want to see it in action? Download the example and feel free to enable the DEBUG mode in the SQLFetchedResultsController

# Dependencies

- FMDB
- Sqlite3

# Installation

**If you use Cocoapods, the feel free to add the following to your podfile:**

```
pod 'SQLFetchedResultsController'

# Or if you prefer:
# pod 'SQLFetchedResultsController', '~> X.X.X'
```

**If you do not use Cocoapods, do the following:**

1. Add the files within Src/ to your project
2. Grab the latest FMDB version from: https://github.com/ccgus/fmdb
3. Add the Sqlite3 library in your app settings

**Using Swift?**

Add the following to your bridging header:

```
#import "FMDB.h"
#import "SQLFRC.h"
```

# Todo

- Fix bugs with ensuring that all data appears with short tables and large tables
- Fix bugs with group by and having fetch parameters
- Add section support
- Add section index title support
- Add method to jump to arbitrary location based on primary key value. This should improve the efficiency of jumping to arbitrary locations.
- Run speed comparisons between NSFetchedResultsController and SQLFetchedResultsController

# How to use

Initialize the fetch controller:
```
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var request = SQLFetchRequest()
        request.table = "Test" //Not tested with > 1 table
        request.fields = ["id","title"]
        request.predicate = "id % 100 = 0"
        request.sortDescriptors = [SQLSortDescriptor(key: "title", ascending: true)]
        request.groupBy = "title"
        request.having = "count(*) > 3"
        fetchController = SQLFetchedResultsController(request: request, pathToDatabase: DatabaseSetup.getDatabasePath())
        
        fetchController?.previewSQL()
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

# Thread Safety

There has not been much work done on ensuring complete thread safety. In regards to the database, FMDB claims "It has always been OK to make a FMDatabase object per thread." This is exactly what I am doing. I instantiate an FMDatabase as needed and then immediately close it.

# References

This is a great post, albeit outdated, about using SQLite in conjunction with a scrolling cursor. It dives into the does and donts of parsing through a large result set:

http://www.sqlite.org/cvstrac/wiki?p=ScrollingCursor
