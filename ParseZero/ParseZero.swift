//
//  ParseZero.swift
//  ParseZero
//
//  Created by Florent Vilmart on 15-11-23.
//  Copyright © 2015 flovilmart. All rights reserved.
//

import Foundation
import Parse
import Bolts

private let kJoinPrefixString = "_Join"

typealias JSONObject = [String: AnyObject]
typealias ResultArray = [JSONObject]
typealias ResultTuple = (String, ResultArray)
typealias KeyedResultArray = [String: ResultArray]
typealias SplitResultTuples = (classes: [ResultTuple], joins: [ResultTuple])
typealias SplitNSURLTuples = (classes: [NSURL], joins: [NSURL])

/// ParseZero preloads data into the Parse local datastore
@objc(ParseZero)
public class ParseZero: NSObject {
  
  /**
   Load data from a JSON file at the specified path
   
   - parameter path: the path to find the JSON file
   
   - returns: a BFTask that completes when all data in the JSON file is imported
   - The JSON file should be in the following format:
   
   ```
   { 
    "ClassName" : [{ 
      "_id": "id1",
      "key" : "param", ...
    }, ... ] ,
   
    "AnotherClass": [],
   
    "_Join:relationKey:OwnerClass:TargetClass" : [{
      "owningId":"id_owner", // ID of the object that owns the relation
      "relatedId": "id_related" // ID of the object in the relation
    }, ...]
   }
   ```
   
   - All objects can/should be generated from a JSON of the object with the JS/node api
   - Relations follow the same format as the Parse Export options
   - **!! You need to specify the relationships in the given format !!**
   */
  public static func loadJSONAtPath(path: String) -> BFTask {
    guard let data = NSData(contentsOfURL: NSURL(fileURLWithPath: path))
      else { return BFTask.pzero_error(.CannotLoadFile, userInfo: ["path": path]) }
    
    let JSONObject: KeyedResultArray
    
    do
    {
      JSONObject = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as! KeyedResultArray
    } catch { return BFTask.pzero_error(.InvalidJSON, userInfo: ["path": path]) }
    
    let initial = SplitResultTuples([], [])
    
    let result = JSONObject.reduce(initial) { (memo, value) -> SplitResultTuples in
      var memo = memo
      // We have a _Join prefix
      if value.0.hasPrefix(kJoinPrefixString) {
        memo.joins.append(value)
      } else {
        memo.classes.append(value)
      }
      return memo
    }
    
    return importAll(result)
  }
  
  internal static func hasDataForClasses(classes:[ResultTuple]) -> BFTask {
    
    var dict = [String:Int]();
    return classes.reduce(BFTask(result: nil), combine: { (previousTask, tuple) -> BFTask in
      dict[tuple.0] = 0
      return previousTask.then({ (task) -> AnyObject? in
        return PFQuery(className: tuple.0).fromLocalDatastore().ignoreACLs().countObjectsInBackground()
      }).then({ (task) -> AnyObject? in
        dict[tuple.0] = task.result as? Int
        return BFTask(result: dict)
      })
    })
  }
  
  internal static func importAll(tuples:SplitResultTuples) -> BFTask {
    return hasDataForClasses(tuples.classes).then({ (task) -> AnyObject! in
    
      var classes:[ResultTuple]
      var toDoAndToSkip = ([ResultTuple](),[ResultTuple]())
      if let result = task.result as? [String:Int] {
        toDoAndToSkip = tuples.classes.reduce(toDoAndToSkip, combine: { (value, tuple) -> ([ResultTuple],[ResultTuple]) in
          
          var value = value
          
          if result[tuple.0] == 0 {
            value.0.append(tuple)
          } else {
            value.1.append(tuple)
          }
          return value
        })
        classes = toDoAndToSkip.0
      } else {
        classes = tuples.classes
      }
      
      
      var skippedClasses:[AnyObject] = toDoAndToSkip.1.map {
        pzero_log("Found objects on", $0.0, "---", "Skipping")
        return PZeroErrorCode.SkippingClass.toError(["className": $0.0])
      }
      return ClassImporter.importAll(classes).then({ (task) -> AnyObject? in
      
        if let result = task.result as? [AnyObject] {
          skippedClasses.appendContentsOf(result)
        }
        return BFTask(result: skippedClasses)
      })
    
    }).then({ (task) -> AnyObject! in
      
      let joins:[ResultTuple]
      if let result = task.result as? [AnyObject] {
        
        let skippedClasses = result.map { (result:AnyObject) -> String? in
          guard let error = result as? NSError where
            error.code == PZeroErrorCode.SkippingClass.rawValue else {
              return nil
          }
         return error.userInfo["className"] as? String
        }.filter({ $0 != nil })
        
        joins = tuples.joins.filter { (tuple) -> Bool in
          let split = tuple.0.componentsSeparatedByString(":")
          if split.count == 4 {
            let className = split[2]
            let include = skippedClasses.indexOf({ $0 == className }) == nil
            if !include {
              pzero_log("🎉 🎉 Skipping import relation", split[1], split[2], split[3])
            }
            return include
          }
          return true
        }
      } else {
        joins = tuples.joins;
      }
      
      return RelationImporter.importAll(joins).mergeResultsWith(task)
    }).continueWithBlock({ (task) -> AnyObject? in
      return processErrors(task)
    })
  }
  
  /**
   Load data from a all the .json files found in the directory at the sepecified path
   
   - parameter path: a path to a directory holding all the data
   
   - returns: a BFTask that completes when all data in the JSON files is imported
   
   - Relation file names should follow the following format:
   
   **_Join:relationKey:OwnerClass:TargetClass.json**
   
   (it differs from Parse's export as the TargetClass should be specified)
   */
  public static func loadDirectoryAtPath(path: String) -> BFTask {
    
    let contents:[String]
    do {
      contents = try NSFileManager.defaultManager().contentsOfDirectoryAtPath(path)
    } catch {
      return BFTask.pzero_error(.CannotStatDirectory, userInfo: ["path":path])
    }
    
    
    let files = contents.map { (filePath) -> NSURL in
      NSURL(fileURLWithPath: path).URLByAppendingPathComponent(filePath)!
    }
    pzero_log(files)
    return loadFiles(files)
  }
  
  /**
   Loads the data from a set of file with their full URL's
   
   - parameter files: the list of JSON files that hold the data to import
   
   - returns: a BFTask that completes when all data in the JSON files is imported
   */
  public static func loadFiles(files: [NSURL]) -> BFTask {
    
    let initial = SplitNSURLTuples([],[])
    
    let urls = files.reduce(initial) { (memo, url) -> SplitNSURLTuples in
      var memo = memo
      
      if url.lastPathComponent!.hasPrefix(kJoinPrefixString)
      {
        memo.joins.append(url)
      } else {
        memo.classes.append(url)
      }
      return memo
    }

    let classesTuples = urls.classes.map { (url) -> ResultTuple in
      return ClassImporter.loadFileAtURL(url)!
    }
    
    let relationsTuples = urls.joins.map { (url) -> ResultTuple in
      return RelationImporter.loadFileAtURL(url)!
    }
    
    return importAll((classesTuples, relationsTuples))
  }
  
  /// set to true to log the trace of the imports
  public static var trace:Bool = false
  
}

private extension ParseZero {
  static func processErrors(task:BFTask) -> BFTask {
    if let error = task.error {
      if let errors = error.userInfo["errors"] as? [NSError] {
        return errors.map({ (error) -> BFTask in
          if error.code == PZeroErrorCode.SkippingClass.rawValue {
            return BFTask(result: PZeroErrorCode.SkippingClass.localizedDescription())
          }
          return BFTask(error: error)
        }).taskForCompletionOfAll()
      }
      if error.code == PZeroErrorCode.SkippingClass.rawValue {
        return BFTask(result: PZeroErrorCode.SkippingClass.localizedDescription())
      }
    }
    
    return task
  }
}
