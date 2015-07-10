Pod::Spec.new do |s|

  s.name         = "SQLFetchedResultsController"
  s.version      = "0.0.3"
  s.summary      = "An attempt at making it easier to setup tables with SQLite."
  s.description  = <<-DESC
                   An attempt at making it easier to setup tables with SQLite. There arent many examples of how to properly page through results in a database. I want to fix this. For those that enjoy the flexibility that SQL has to offer but dont want to give up the ease of setting up tables that you would get with Core Data's NSFetchedResultsController, this class is for you.
                   DESC

  s.homepage     = "https://github.com/danielmj/SQLFetchedResultsController"
  s.license      = { :type => "MIT", :file => "LICENSE.txt" }
  s.author             = "Daniel Jackson"
  s.social_media_url   = "http://www.danmjacks.com"
  
  s.platform     = :ios, "7.1"
  s.source       = { :git => "https://github.com/danielmj/SQLFetchedResultsController.git", :tag => "0.0.3" }
  
  s.source_files  = "Src/*"

  s.library  = "sqlite3"
  s.requires_arc = true
  
  s.dependency "FMDB", "~> 2"

end
