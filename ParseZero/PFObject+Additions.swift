//
//  PFObject+Additions.swift
//  ParseZero
//
//  Created by Florent Vilmart on 15-12-01.
//  Copyright © 2015 flovilmart. All rights reserved.
//

import Parse

extension PFACL {
  convenience init(dictionary:JSONObject) {
    self.init()
    
    for (k,v) in dictionary {

      let setReadAccess = v.objectForKey("read") as? Bool == true
      let setWriteAccess = v.objectForKey("write") as? Bool == true
      
      if k == "*" {
        self.publicReadAccess = setReadAccess
        self.publicWriteAccess = setWriteAccess
      } else if let _ = k.rangeOfString("role:") {
        let roleName = k.stringByReplacingOccurrencesOfString("role:", withString: "")
        self.setReadAccess(setReadAccess, forRoleWithName: roleName)
        self.setWriteAccess(setWriteAccess, forRoleWithName: roleName)
      } else {
        self.setReadAccess(setReadAccess, forUserId: k)
        self.setWriteAccess(setWriteAccess, forUserId: k)
      }
    }
  }
}

extension PFObject {
  static func mockedServerObject(className: String, objectId:String,data:JSONObject) -> PFObject {
    
    let parseObject = PFObject(className: className)
    parseObject.updateWithDictionary(data)
    // Let parse SDK think it was updated from the server
    return parseObject
  }
  
  func updateWithDictionary(data:JSONObject) -> Self {
    var dictionary = data;

    // template date
    let updatedAt = dateFromString(dictionary["_updated_at"] as? String)
    let createdAt = dateFromString(dictionary["_created_at"] as? String)
    
    if let createdAt = createdAt  {
      self.setValue(createdAt, forKeyPath: "_pfinternal_state._createdAt")
    }
    if let updatedAt = updatedAt {
      self.setValue(updatedAt, forKeyPath: "_pfinternal_state._updatedAt")
    }
    if let objectId = dictionary["_id"] as? String {
      self.setValue(objectId, forKeyPath: "_pfinternal_state._objectId")
    }
    
    // Remove Internals
    dictionary.removeValueForKey("_updated_at")
    dictionary.removeValueForKey("_created_at")
    dictionary.removeValueForKey("_id")
    

    for kv in dictionary {
      let key:String = kv.0
      var value:AnyObject? = kv.1
      
      // parse pointer
      var isPointer = false
      var unprefixedKey: String = key
      let prefix = key.substringToIndex(key.startIndex.advancedBy(3))
      if prefix == "_p_" {
        if let pointer = value as? String {
          isPointer = true
          let pointerStringComponents = pointer.componentsSeparatedByString("$")
          let pointerClassName = pointerStringComponents[0]
          let pointerObjectId = pointerStringComponents[1]
          value = PFObject(withoutDataWithClassName: pointerClassName, objectId: pointerObjectId)
          unprefixedKey = key.substringFromIndex(key.startIndex.advancedBy(3))
        }
      }
      
      // parse different types of data inside another JSONObject
      if let pointer = value as? JSONObject,
        
        let type = pointer["__type"] as? String {
          // Reset the value
          value = nil
          switch type {
            case "Pointer":
              let pointerClassName = pointer["className"] as! String
              let pointerObjectId = pointer["_id"] as? String
              value = PFObject(withoutDataWithClassName: pointerClassName, objectId: pointerObjectId)
            case "Date":
              if let date = dateFromString(pointer["iso"] as? String) {
                value = date
              }
            case "Bytes":
              if let base64 = pointer["base64"] as? String {
                value = NSData(base64EncodedString: base64, options: .IgnoreUnknownCharacters)
              }
            case "File":
              if let url = pointer["url"] as? String,
                let name = pointer["name"] as? String {
                
                let file = PFFile(name: name, data: NSData())
                file?.setValue(url, forKeyPath: "_state._urlString")
                value = file
              }
            case "GeoPoint":
              value = PFGeoPoint(latitude: pointer["latitude"] as! Double, longitude:pointer["longitude"] as! Double)
            default:break
          }
      }
      
      // parse acl
      if let acl = value as? JSONObject where kv.0 == "_acl" {
          value = PFACL(dictionary: acl)
      }
      
      if let value = value {
        if isPointer {
          self[unprefixedKey] = value
        } else {
          self[kv.0] = value
        }
      }
    }
    self.cleanupOperationQueue()
    return self
  }
  
  func cleanupOperationQueue() {
    if let operationSetQueue = self.valueForKey("operationSetQueue") as? [AnyObject] where operationSetQueue.count == 1 {
      operationSetQueue.first?.setValue(NSMutableDictionary(), forKey: "_dictionary")
    }
    let data = self.valueForKeyPath("_estimatedData._dataDictionary") as! JSONObject
    self.setValue(data, forKeyPath: "_pfinternal_state._serverData")
    self.setValue(true, forKeyPath: "_pfinternal_state._complete")
  }

}