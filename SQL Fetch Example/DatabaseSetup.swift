//
//  Database.swift
//  SQL Fetch Example
//
//  Created by Daniel Jackson on 6/29/15.
//  Copyright (c) 2015 Daniel Jackson. All rights reserved.
//

import UIKit

public class DatabaseSetup: NSObject {

    public class func recreateDatabase()->FMDatabase?
    {
        if databaseExists()
        {
            deleteDatabase()
        }
        
        let db = FMDatabase(path: getDatabasePath())
        if db.open()
        {
            print("Creating Database")
            create(db)
            return db
        }
        
        print("DATABASE ERROR: Could not recreate databse!")
        return nil
    }
    
    public class func initializeData(progressHandler:((progress:Double)->Void))
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
            
            NSLog("Enqueueing Insert Statements")
            //Open a new copy for thread safety
            var queue = FMDatabaseQueue(path: self.getDatabasePath())
            queue?.inTransaction({ (db, rollback) -> Void in
                
                let total = Int(20000.0/3.0)
                let percentToAdvance = 0.7
                let progressDenom = (Double(total) * percentToAdvance)
                NSLog("Beginning Enqueuing")
                
                let sql1 = "INSERT INTO Test (title, subtitle, imageLink) VALUES ('Beach Pic', 'The sun sets on the beach', 'image1.png');"
                let sql2 = "INSERT INTO Test (title, subtitle, imageLink) VALUES ('Wave Pic #1', 'A cool picture of a wave from a distance', 'image2.png');"
                let sql3 = "INSERT INTO Test (title, subtitle, imageLink) VALUES ('Wave Pic #2', 'A cool picture of a wave at sunset', 'image3.png');"
                
                for var i=0; i < total; i++
                {
                    autoreleasepool({ () -> () in
                        db.executeUpdate(sql1, withArgumentsInArray: nil)
                        db.executeUpdate(sql2, withArgumentsInArray: nil)
                        db.executeUpdate(sql3, withArgumentsInArray: nil)
                        
                        if i % total == 0 && progressDenom != 0
                        {
                            let progress = Double(i) / progressDenom
                            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                progressHandler(progress: progress)
                            })
                        }
                    })
                }
                NSLog("Ending Enqueuing")
            })
            
            queue?.close()
            queue = nil
            
            NSLog("Finished Executing")
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                progressHandler(progress: 1.0)
            })
        })
    }
    
    public class func getDatabasePath()->String
    {
        let documentsPath = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.CachesDirectory, NSSearchPathDomainMask.UserDomainMask, true)[0] as NSString
        let path = documentsPath.stringByAppendingPathComponent("database.sqlite")
        
        return path
    }
    
    public class func databaseExists()->Bool
    {
        return NSFileManager.defaultManager().fileExistsAtPath(getDatabasePath())
    }
    
    public class func deleteDatabase()
    {
        var error:NSError? = nil
        do {
            try NSFileManager.defaultManager().removeItemAtPath(getDatabasePath())
        } catch let error1 as NSError {
            error = error1
        }
        if error != nil
        {
            print("[ERROR] Could not delete database. \(error?.localizedDescription)")
        }
    }
    
    public class func printAllData()
    {
        let db = FMDatabase(path: self.getDatabasePath())
        if db.open()
        {
            //FMResultSet *s = [db executeQuery:@"SELECT * FROM myTable"];
            if let rs = db?.executeQuery("SELECT * FROM Test", withArgumentsInArray: nil) {
                while rs.next() {
                    let title = rs.stringForColumn("title")
                    let subtitle = rs.stringForColumn("subtitle")
                    let imageLink = rs.stringForColumn("imageLink")
                    print("Title=\(title) Subtitle=\(subtitle) Image=\(imageLink)")
                }
            }
        }
    }
    
    private class func create(db:FMDatabase)
    {
        let sql =   "CREATE TABLE Test (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, subtitle TEXT, imageLink TEXT);" +
                    "CREATE INDEX titleIndex ON Test(title);"
        db.executeStatements(sql)
    }
    
    
}
