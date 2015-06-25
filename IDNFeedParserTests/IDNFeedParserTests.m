//
//  IDNFeedParserTests.m
//  IDNFeedParserTests
//
//  Created by photondragon on 15/6/26.
//  Copyright (c) 2015年 iosdev.net. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "IDNFeedParser.h"

@interface IDNFeedParserTests : XCTestCase

@end

@implementation IDNFeedParserTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testFeedParser {
	// This is an example of a functional test case.
	IDNFeedInfo* info = [IDNFeedParser feedInfoWithUrl:@"http://news.163.com/special/00011K6L/rss_newstop.xml"];
	XCTAssertNotNil(info, @"解析IDNFeedInfo失败");
	NSArray* items = [IDNFeedParser feedItemsWithUrl:@"http://news.163.com/special/00011K6L/rss_newstop.xml"];
	XCTAssertNotEqual(items.count, 0, @"解析IDNFeedItems失败");
}

//- (void)testPerformanceExample {
//    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
//}

@end
