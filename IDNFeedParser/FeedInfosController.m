//
//  ViewController.m
//  IDNFeedParser
//
//  Created by photondragon on 15/6/26.
//  Copyright (c) 2015年 iosdev.net. All rights reserved.
//

#import "FeedInfosController.h"
#import "IDNFeedParser.h"
#import "UIViewController+IDNPrompt.h"
#import "FeedItemsController.h"

@interface FeedInfosController ()

@property(nonatomic,strong) NSMutableArray* feedInfos;

@end

@implementation FeedInfosController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"订阅";

	self.feedInfos = [NSMutableArray new];

	[self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];

	[self.navigationController prompting:@"正在读取RSS源信息"];
	// 在后台线程下载解析RSS
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

		// 获取RSS源信息
		IDNFeedInfo* info = [IDNFeedParser feedInfoWithUrl:@"http://www.zhihu.com/rss"];

		if(info==nil) //失败
			[self.navigationController prompt:@"读取RSS源信息失败" duration:2];
		else //成功
		{
			[self.navigationController stopPrompt];

			// 解析完成后在主线程更新显示
			dispatch_async(dispatch_get_main_queue(), ^{
				[self addFeedInfo:info];
			});
		}
	});
}

- (void)addFeedInfo:(IDNFeedInfo*)feedInfo
{
	[self.feedInfos addObject:feedInfo];
	[self.tableView reloadData];
}

#pragma mark table view

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return self.feedInfos.count;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell" forIndexPath:indexPath];

	IDNFeedInfo* info = self.feedInfos[indexPath.row];
	cell.textLabel.text = info.title;

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	IDNFeedInfo* info = self.feedInfos[indexPath.row];

	FeedItemsController* c = [FeedItemsController new];
	[self.navigationController pushViewController:c animated:YES];
	c.title = info.title;
	c.feedInfo = info;
}

@end
