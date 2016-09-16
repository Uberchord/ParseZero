//
//  ParseZeroError.swift
//  ParseZero
//
//  Created by Florent Vilmart on 15-11-23.
//  Copyright © 2015 flovilmart. All rights reserved.
//

import Foundation
import Bolts

internal let kPZeroErrorDomain = "com.flovilmart.parsezero"

enum PZeroErrorCode: Int {
  
  case CannotStatDirectory
  case InvalidRelationObject
  case CannotLoadFile
  case InvalidJSON
  case MissingObjectIdKey
  case SkippingClass
  
  func localizedDescription() -> String {
    switch self {
    case .CannotStatDirectory:
      return "Cannot read content of directory"
    case .InvalidRelationObject:
      return "The relation is badly formed, should have properties owningId AND relatedId"
    case .CannotLoadFile:
      return "Cannot Load File, it may not exist"
    case .InvalidJSON:
      return "The JSON in the file is badly formed"
    case .MissingObjectIdKey:
      return "The object doesn't have an object id"
    case .SkippingClass:
      return "Skipping class"
    }
  }
  
  func toError(userInfo: [NSObject:AnyObject] = [NSObject:AnyObject]()) -> NSError {
    return NSError.pzero_error(self, userInfo: userInfo)
  }
}

internal extension NSError {
  
  internal static func pzero_error(code: PZeroErrorCode, userInfo: [NSObject:AnyObject] = [:]) -> NSError {
    
    var userInfo = userInfo
    
    if userInfo[NSLocalizedDescriptionKey] == nil
    {
      userInfo[NSLocalizedDescriptionKey] = code.localizedDescription()
    }
    
    return NSError(domain: kPZeroErrorDomain, code: code.rawValue, userInfo: userInfo)
  }
}
