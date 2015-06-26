//
//  ViewController.m
//  IDNFeedParser
//
//  Created by photondragon on 15/6/26.
//  Copyright (c) 2015年 iosdev.net. All rights reserved.
//

#import "FeedItemsController.h"
#import "WebViewController.h"
#import "UIViewController+IDNPrompt.h"

@interface FeedItemsController ()

@property(nonatomic,strong) NSArray* feedItems;

@end

@implementation FeedItemsController

- (void)viewDidLoad {
	[super viewDidLoad];

	[self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];

}

- (void)setFeedInfo:(IDNFeedInfo *)feedInfo
{
	[self view]; //强制loadView

	_feedInfo = feedInfo;

	[self.navigationController prompting:@"正在获取文章列表"];

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

		// 获取文章列表
		NSArray* items = [IDNFeedParser feedItemsWithUrl:feedInfo.url];

		if(items==nil) //失败
			[self.navigationController prompt:@"获取文章列表失败" duration:2];
		else //成功
		{
			[self.navigationController stopPrompt];

			// 解析完成后在主线程更新显示
			dispatch_async(dispatch_get_main_queue(), ^{
				self.feedItems = items;
			});
		}
	});
}
- (void)setFeedItems:(NSArray *)feedItems
{
	_feedItems = feedItems;
	[self.tableView reloadData];
}

#pragma mark table view

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return self.feedItems.count;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell" forIndexPath:indexPath];

	IDNFeedItem* item = self.feedItems[indexPath.row];
	cell.textLabel.text = item.title;

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	IDNFeedItem* item = self.feedItems[indexPath.row];

	WebViewController* web = [WebViewController new];
	web.url = item.link;
	web.title = item.title;
	[self.navigationController pushViewController:web animated:YES];
}

@end
