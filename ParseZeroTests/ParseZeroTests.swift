//
//  ParseZeroTests.swift
//  ParseZeroTests
//
//  Created by Florent Vilmart on 15-11-23.
//  Copyright © 2015 flovilmart. All rights reserved.
//

import XCTest
import Parse
import Bolts
@testable import ParseZero



@objc
class ParseZeroTests: XCTestCase {

    override func setUp() {
      super.setUp()
      ParseZeroObjC.initializeParse()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
      PFQuery.clearAllCachedResults()
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
      let expectation = self.expectationWithDescription("Wait for it...")
      
      ParseZero.loadDirectoryAtPath(NSBundle(forClass: ParseZeroTests.self).bundlePath+"/ParseObjects").continueWithBlock { (task) -> AnyObject! in
        XCTAssert(task.error == nil)
        XCTAssert(task.exception == nil)
        expectation.fulfill()
        return nil
      }
      
      waitForExpectationsWithTimeout(3000.0, handler: nil)
    }
  
  func testLoadInvalidFile() {
    XCTAssertNil(ClassImporter.loadFileAtURL(NSURL(fileURLWithPath:"/some/file")))
  }
  
  func testLoadInvalidDirectory() {
    XCTAssertNotNil(ParseZero.loadDirectoryAtPath("/some/file").error)
  }
  func testLoadInvalidJSON() {
    XCTAssertNotNil(ParseZero.loadJSONAtPath("/some/file").error)
  }
  
  func testLoadMalformedJSON() {
    let jsonPath = NSBundle(forClass: ParseZeroTests.self).pathForResource("Malformed", ofType: "json")!
    let jsonURL = NSURL(fileURLWithPath: jsonPath)
    XCTAssertNotNil(ParseZero.loadJSONAtPath(jsonPath))
    
    XCTAssertNil(ClassImporter.loadFileAtURL(jsonURL))
    XCTAssertNotNil(ClassImporter.importFileAtURL(jsonURL).result, "Should return a task with result")
  }
  
  func testNoResultInJSON() {
    let jsonPath = NSBundle(forClass: ParseZeroTests.self).pathForResource("AllObjects", ofType: "json")!
    let jsonURL = NSURL(fileURLWithPath: jsonPath)
    XCTAssertNil(ClassImporter.loadFileAtURL(jsonURL))
  }
  
  func testInvalidRelationKeys() {
    XCTAssertNotNil(RelationImporter.importRelations(forClassName: "AClass", onKey: "a", targetClassName: "OtherClass", objects: [["key":"value", "otherKey": "OtherVlaue"]]).error)
  }
  
  func testRelationNotFoundObject() {
    let expectation = self.expectationWithDescription("wait")
    
    RelationImporter.importRelations(forClassName: "ClassA", onKey: "a", targetClassName: "ClassA", objects: [["owningId":"value", "relatedId": "OtherVlaue"]]).continueWithBlock { (task) -> AnyObject! in
      XCTAssertNotNil(task.result)
      expectation.fulfill()
      return task
    }
    waitForExpectationsWithTimeout(10.0, handler: nil)
    
  }

}