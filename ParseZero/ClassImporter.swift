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
    let d0 = NSDate.timeIntervalSinceReferenceDate()
    let query = PFQuery(className: className)
    query.limit = 1;
    
    return query
      .fromLocalDatastore()
      .ignoreACLs()
      .findObjectsInBackground()
      .continueWithBlock({ (task) -> AnyObject? in
        if let result = task.result as? [PFObject] where result.count > 0 {
          pzero_log("🎉 🎉 Skipping import for ", className)
          return BFTask.pzero_error(.SkippingClass, userInfo: ["className":className])
        
        }
        var erroredTasks = [BFTask]()
        
        let pfObjects = objects.map { (objectJSON) -> BFTask in
            
            guard let objectId = objectJSON["objectId"] as? String else {
              return BFTask.pzero_error(.MissingObjectIdKey)
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
          return task
        })

      })
  }
  
  
  private static func pinObject(className: String, objectId: String, objectJSON: JSONObject) -> BFTask {
    
    let parseObject = PFObject.mockedServerObject(className, objectId: objectId, data: objectJSON)
    
    return parseObject.pinInBackground().continueWithSuccessBlock({ (task) -> AnyObject! in
      return BFTask(result: "Saved \(className) \(objectId)")
    })
  }

}