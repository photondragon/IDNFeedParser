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
	// 获取RSS源信息
	IDNFeedInfo* info = [IDNFeedParser feedInfoWithUrl:@"http://www.zhihu.com/rss"];
	XCTAssertNotNil(info, @"解析IDNFeedInfo失败");
	// 获取文章列表
	NSArray* items = [IDNFeedParser feedItemsWithUrl:@"http://www.zhihu.com/rss"];
	XCTAssertNotEqual(items.count, 0, @"解析IDNFeedItems失败");
}

- (void)testFeedParserTwoStep {
	NSString* rssUrl = @"http://www.zhihu.com/rss";
	// 获取rss原始Data
	NSData* rssData = [IDNFeedParser dataFromUrl:rssUrl];

	// 解析RSS源信息
	IDNFeedInfo* info = [IDNFeedParser feedInfoWithData:rssData fromUrl:rssUrl];
	XCTAssertNotNil(info, @"解析IDNFeedInfo失败");

	// 获取文章列表
	NSArray* items = [IDNFeedParser feedItemsWithData:rssData fromUrl:rssUrl];
	XCTAssertNotEqual(items.count, 0, @"解析IDNFeedItems失败");
}

//- (void)testPerformanceExample {
//    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
//}

@end
