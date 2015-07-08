//
//  CreateDataViewController.swift
//  SQL Fetch Example
//
//  Created by Daniel Jackson on 6/29/15.
//  Copyright (c) 2015 Daniel Jackson. All rights reserved.
//

import UIKit

class CreateDataViewController: UIViewController {

    @IBOutlet var progressBar:UIProgressView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let db = DatabaseSetup.recreateDatabase()
        if db != nil
        {
            loadData(db!)
        }
        else
        {
            println("[ERROR] DB not loaded. Unable to load data.")
        }
        db?.close()
    }
    
    func loadData(database:FMDatabase)
    {
        progressBar?.setProgress(0.1, animated: false)
        DatabaseSetup.initializeData { (progress) -> Void in
            if let bar = self.progressBar {
                bar.setProgress(Float(progress), animated: false)
            }
            
            if progress == 1.0
            {
                println("Finished Inserting Data")
                self.presentDataTable()
            }
        }
    }
    
    func presentDataTable()
    {
        self.performSegueWithIdentifier("showTable", sender: self)
    }
}
