//
//  RelationImporter.swift
//  ParseZero
//
//  Created by Florent Vilmart on 15-11-23.
//  Copyright © 2015 flovilmart. All rights reserved.
//

import Foundation
import Bolts
import Parse

typealias StringsMap = [String:[String]]

typealias RelationDefinition = (key:String, ownerClassName:String, targetClassName:String)


struct RelationImporter:Importer {
  
  static func parseClassNameToRelation(className:String) -> RelationDefinition {
    let components = className.componentsSeparatedByString(":")
    return (components[1],components[2], components.last!)
  }
  
  static func importOnKeyName(relationDefinitionString:String, _ objects:ResultArray) -> BFTask {
    
    let relation = parseClassNameToRelation(relationDefinitionString)
    
    return importRelations(relation, objects: objects)
  }
  
  static func validateObjects(objects: ResultArray) -> BFTask? {

    let errors = objects.reduce([BFTask]()) { (var memo, object) -> [BFTask] in
      if let _ = object["owningId"] as? String,
        let _ = object["relatedId"] as? String {
          // do nothing
      } else {
          memo.append(BFTask.pzero_error(.InvalidRelationObject, userInfo: ["object": object]))
      }
      return memo
    }
    
    if errors.count > 0 {
      return BFTask(forCompletionOfAllTasksWithResults: errors)
    }
    
    return nil
  }
  
  static func importRelations(relationDefinition: RelationDefinition, objects:ResultArray) -> BFTask {
    
    let ownerClassName = relationDefinition.ownerClassName
    let targetClassName = relationDefinition.targetClassName
    let ownerKey = relationDefinition.key
    let d0 = NSDate.timeIntervalSinceReferenceDate()
    pzero_log("Importing relations on", ownerClassName, ":", ownerKey, "->", targetClassName)
    
    if let error = self.validateObjects(objects) {
      pzero_log("Found invalid objects", error)
      return error
    }
    
    return objects.reduce(StringsMap()) { (var memo, object) -> StringsMap in
      
      // we can force unpack here as it's validated
      let owningId = object["owningId"] as! String
      let relatedId = object["relatedId"] as! String
      
      if memo[owningId] == nil {
        memo[owningId] = [String]()
      }
      
      memo[owningId]!.append(relatedId)
      
      return memo
      
    }.map { (relations) -> BFTask in
      
      let owningId = relations.0
      let sourceObjectTask = PFObject(withoutDataWithClassName: ownerClassName, objectId: owningId).fetchFromLocalDatastoreInBackground()
      pzero_log("Processing relations for", ownerClassName, ":", owningId, "->", relations.1.count, "objects")
      
      let relationTask = PFQuery(className: targetClassName).whereKey("_id", containedIn: relations.1).fromLocalDatastore().findObjectsInBackground()
      // Fetch the owning id
      return BFTask(forCompletionOfAllTasksWithResults: [sourceObjectTask, relationTask])
          .continueWithBlock({ (task) -> AnyObject! in
            guard let result = task.result as? [AnyObject] where result.count == 2,
              let sourceObject = result[0] as? PFObject,
              let relatedObjects = result[1] as? [PFObject] else {
                return BFTask(result: "Object not found \(ownerClassName) \(owningId)")
            }

            let relation = sourceObject.relationForKey(ownerKey)
            for relatedObject in relatedObjects {
              relation.addObject(relatedObject)
            }
            let d1 = NSDate.timeIntervalSinceReferenceDate()
            
            return sourceObject.pinInBackground().continueWithSuccessBlock({ task in
              sourceObject.cleanupOperationQueue()
              return sourceObject.pinInBackground()
             
            }).continueWithSuccessBlock({ (task) -> AnyObject! in
              let ids = relatedObjects.map({ (object) -> String in
                return object.objectId!
              })
              pzero_log("🎉 Done relations for", ownerClassName, ":", owningId, "->", relations.1.count, "objects", "in", NSDate.timeIntervalSinceReferenceDate() - d1)
              return BFTask(result: "Saved Relations from:\(ownerClassName) \(sourceObject.objectId)\nto \(targetClassName) - \(ids)")
            })
        })
      
    }.taskForCompletionOfAll().continueWithBlock({ (task) -> AnyObject? in
      pzero_log("🎉 🎉 Done importing relations on", ownerClassName, ":", ownerKey, "->", targetClassName, "in", NSDate.timeIntervalSinceReferenceDate() - d0)
      return task
    })
  }
  
}