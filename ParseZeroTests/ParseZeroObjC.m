//
//  ParseZeroObjC.m
//  ParseZero
//
//  Created by Florent Vilmart on 15-11-23.
//  Copyright © 2015 flovilmart. All rights reserved.
//

#import "ParseZeroTests-Bridging-Header.h"
@import Parse;
@import Bolts;
@import ParseZero;

@implementation ParseZeroObjC

- (NSString *)objectsDirectory {
   return [[NSBundle bundleForClass:[ParseZeroObjC class]].bundlePath stringByAppendingString:@"/ParseObjects"];
}

- (NSString *)objectsFile {
  return [[NSBundle bundleForClass:[ParseZeroObjC class]] pathForResource:@"AllObjects" ofType:@"json"];
}

+ (void)initializeParse
{
  if (![Parse isLocalDatastoreEnabled]) {
    NSString *library = [NSHomeDirectory() stringByAppendingPathComponent:@"Library"];
    NSString *privateDocuments = [library stringByAppendingPathComponent:@"Private Documents"];
    NSString *directoryPath = [privateDocuments stringByAppendingPathComponent:@"Parse"];
    [[NSFileManager defaultManager] removeItemAtPath:directoryPath error:nil];
    NSLog(@"%@", directoryPath);
    [Parse enableLocalDatastore];
    [Parse setApplicationId:@"AAAAAAAAAAAA" clientKey:@"AAAAAAAAAAAA"];
  }
}

- (void)setUp {
    [super setUp];
    ParseZero.trace = YES;
    [ParseZeroObjC initializeParse];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  [super tearDown];
}
//
- (void)testFromFile {
  
  // This is an example of a functional test case.
  // Use XCTAssert and related functions to verify your tests produce the correct results.
  XCTestExpectation *expectation  = [self expectationWithDescription:@"Wait for it"];

  [[[ParseZero loadJSONAtPath:[self objectsFile]] continueWithBlock:^id(BFTask *task) {
    XCTAssert(task.error == nil);
    XCTAssert(task.exception == nil, @"Should have no exception %@", task.exception);
    NSLog(@"%@", task.result);
    [self checkIntegrity];
    return task;
  }] continueWithBlock:^id(BFTask *task) {
    XCTAssertNil(task.error);
    XCTAssertNil(task.exception);
    [expectation fulfill];
    return nil;
  }];
  
  [self waitForExpectationsWithTimeout:3000 handler:nil];
}

- (void)testConsecutiveImports {
  XCTestExpectation *expectation  = [self expectationWithDescription:@"Wait for it"];

  [[[[ParseZero loadJSONAtPath:[self objectsFile]] continueWithBlock:^id(BFTask *task) {
    XCTAssert(task.error == nil);
    XCTAssert(task.exception == nil, @"Should have no exception %@", task.exception);
    NSLog(@"%@", task.result);
    [self checkIntegrity];
    return [ParseZero loadDirectoryAtPath:[self objectsDirectory]];
  }] continueWithBlock:^id(BFTask *task) {
    XCTAssert(task.error == nil);
    XCTAssert(task.exception == nil, @"Should have no exception %@", task.exception);
    NSLog(@"%@", task.result);
    [self checkIntegrity];
    return task;
  }] continueWithBlock:^id(BFTask *task) {
    XCTAssertNil(task.error);
    XCTAssert(task.exception == nil, @"Should have no exception %@", task.exception);
    [expectation fulfill];
    return nil;
  }];
  
  [self waitForExpectationsWithTimeout:3000 handler:nil];
}

- (void)testFromFolder {
  
  // This is an example of a functional test case.
  // Use XCTAssert and related functions to verify your tests produce the correct results.
  XCTestExpectation *expectation  = [self expectationWithDescription:@"Wait for it"];

  [[[ParseZero loadDirectoryAtPath:[self objectsDirectory]] continueWithBlock:^id(BFTask *task) {
    XCTAssert(task.error == nil);
    XCTAssert(task.exception == nil, @"Should have no exception %@", task.exception);
    [self checkIntegrity];
    return task;
  }] continueWithBlock:^id(BFTask *task) {
    XCTAssert(task.error == nil);
    XCTAssert(task.exception == nil, @"Should have no exception %@", task.exception);
    [expectation fulfill];
    return nil;
  }];
  
  [self waitForExpectationsWithTimeout:3000 handler:nil];
}

- (void)checkIntegrity
{
  // Make sure we imported enought objects
  NSInteger aCount = [[[PFQuery queryWithClassName:@"ClassA"] fromPin] countObjects];
  XCTAssertEqual(aCount, 3);
  
  // Make sure we imported enought objects
  NSInteger bCount = [[[PFQuery queryWithClassName:@"ClassB"] fromPin] countObjects];
  XCTAssertEqual(bCount, 3);
  
  NSArray *objs = [[[PFQuery queryWithClassName:@"ClassB"] fromPin] findObjects];
  
  XCTAssertEqual([objs count], 3);
  
  PFObject *A2 = [[PFObject objectWithoutDataWithClassName:@"ClassA" objectId:@"2"] fetchFromLocalDatastore];
  PFObject *A1 = [[PFObject objectWithoutDataWithClassName:@"ClassA" objectId:@"1"] fetchFromLocalDatastore];
  // Test if the relation is properly set
  NSArray *objects = [[[[[A2 relationForKey:@"bs"] query] fromPin] ignoreACLs] findObjects];
  
  XCTAssertEqual([objects count], 1);
  [self ensureOperationSetQueueIsEmpty:objs];
    // Test if the relations are properly set
  NSError *error;
 objects = [[[[[A1 relationForKey:@"bs"] query] fromPin] ignoreACLs] findObjects:&error];
  XCTAssertEqual([objects count], 3);
  XCTAssertNil(error);
  [self ensureOperationSetQueueIsEmpty:objects];
  

  objects = [[[[[A1 relationForKey:@"bs"] query] fromLocalDatastore] ignoreACLs] findObjects];
  XCTAssertEqual([objects count], 3);
  [self ensureOperationSetQueueIsEmpty:objs];
  
  // Check if we can query by pointer
  PFObject *pObj = [PFObject objectWithoutDataWithClassName:@"ClassB" objectId:@"4"];
  PFQuery *query = [PFQuery queryWithClassName:@"ClassA"];
  [query whereKey:@"learningPath" equalTo:pObj];
  NSArray *arr = [[[[query copy] fromPinWithName:PFObjectDefaultPin] ignoreACLs] findObjects];
  XCTAssertEqual([arr count], 1);
  PFObject *obj = arr[0];
  XCTAssert([obj.objectId isEqualToString:@"1"]);
  
  // Fetch A1 to test if the Pointer is properly set
  NSString *bName = [A1[@"learningPath"] fetchFromLocalDatastore][@"name"];
  XCTAssert([bName isEqualToString:@"Object4"], @"bname should be set to Object4 instead %@", bName);
   [self ensureOperationSetQueueIsEmpty:@[A1]];
}

- (void)ensureOperationSetQueueIsEmpty:(NSArray *)objects {
  for (PFObject *object in objects) {
    NSDictionary *operationSetDictionary = [[[object valueForKey:@"operationSetQueue"] firstObject] valueForKey:@"_dictionary"];
    XCTAssertEqual([[operationSetDictionary allKeys] count], 0);
  }
}

@end
