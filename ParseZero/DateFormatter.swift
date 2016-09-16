//
//  DateFormatter.swift
//  ParseZero
//
//  Created by Florent Vilmart on 15-12-03.
//  Copyright © 2015 flovilmart. All rights reserved.
//

import Foundation

//  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
//  dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
//  dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
//  dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";

internal func dateFromString(string:String?) -> NSDate? {
  guard let string = string else { return nil }

  let dateFormatter = NSDateFormatter()
  dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
  dateFormatter.timeZone = NSTimeZone.defaultTimeZone()
  dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS+VVVV'"

  return dateFormatter.dateFromString(string)
}