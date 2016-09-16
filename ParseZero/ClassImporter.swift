//
//  ClassImporter.swift
//  ParseZero
//
//  Created by Florent Vilmart on 15-11-23.
//  Copyright © 2015 flovilmart. All rights reserved.
//

import Foundation
import Bolts
import Parse

internal struct ClassImporter: Importer {
  
  static func importOnKeyName(className: String, _ objects: ResultArray) -> BFTask {
    // Create a task that waits for all to complete
    pzero_log("Importing", objects.count, className)
    
    let objectIds = objects.filter({ (object) -> Bool in
      return (object["_id"] is String)
    }).map { (object) -> String in
      return object["_id"] as! String
    }
    
    let d0 = NSDate.timeIntervalSinceReferenceDate()
    let query = PFQuery(className: className)
    query.whereKey("objectId", containedIn: objectIds)
    return query
      .fromLocalDatastore()
      .ignoreACLs()
      .findObjectsInBackground()
      .continueWithSuccessBlock({ (task) -> AnyObject? in
        
        let resultHash = (task.result as! [PFObject]).reduce([String:PFObject](), combine: { (hash, object) -> [String:PFObject] in
          var hash = hash
          hash[object.objectId!] = object
          return hash
        })
        
        if let result = task.result as? [PFObject] where result.count >= objects.count {
          pzero_log("🎉 🎉 Skipping import for ", className)
          return BFTask.pzero_error(.SkippingClass, userInfo: ["className":className])
        }
        var erroredTasks = [BFTask]()
        
        let pfObjects = objects.map { (objectJSON) -> BFTask in
            
            guard let objectId = objectJSON["_id"] as? String else {
              return BFTask.pzero_error(.MissingObjectIdKey)
            }
            if let originalObject = resultHash[objectId] {
              return BFTask(result: originalObject.updateWithDictionary(objectJSON))
            }
          
            return BFTask(result: PFObject.mockedServerObject(className, objectId: objectId, data: objectJSON))
            
        }.filter({ (task) -> Bool in
          if task.result is PFObject {
            return true
          } else {
            erroredTasks.append(task)
            return false
          }
        }).map({ (task) -> PFObject in
          return task.result as! PFObject
        })
        
        if erroredTasks.count > 0 {
          return erroredTasks.taskForCompletionOfAll()
        }
        
        return PFObject.pinAllInBackground(pfObjects).continueWithBlock({ (task) -> AnyObject? in
          pzero_log("🎉 🎉 Successfully imported", pfObjects.count, "on", className, "in", NSDate.timeIntervalSinceReferenceDate()-d0)
          return BFTask(result: "Successfully imported \(pfObjects.count) on \(className)")
        })

      })
  }

}
