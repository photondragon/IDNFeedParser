//
//  IDNFeedParser.h
//  IDNFramework
//
//  Created by photondragon on 15/6/24.
//  Copyright (c) 2015年 iosdev.net.
//

/*
 ### *IDNFeedParser* 一个使用非常方便的Rss解析器

 在[MWFeedParser](https://github.com/mwaterfall/MWFeedParser)的基础上修改。之所以要重新封装，是因为MWFeedParser的接口有点复杂，使用起来不太方便。

 重新封装后的IDNFeedParser，**只需要一两行代码就可以完成RSS解析**，不用再写那么多delegate方法了。

 主要做了以下改动：

 1. 简化接口，去掉异步操作和delegate，只留下同步操作；
 1. 把下载与解析分开（解耦），方便对RSS数据进行缓存。
 1. FeedInfo增加了image图像信息

 这个库使用起来非常简单，只要把IDNFeedParser目录下的源文件拷贝到你的项目中，然后`#import "IDNFeedParser.h"`就可以使用了

 简单用法：

	// 获取RSS源信息
	IDNFeedInfo* info = [IDNFeedParser feedInfoWithUrl:@"http://www.zhihu.com/rss"];
	// 获取文章列表
	NSArray* items = [IDNFeedParser feedItemsWithUrl:@"http://www.zhihu.com/rss"];

 下载和解析分离的用法：

	NSString* rssUrl = @"http://www.zhihu.com/rss";
	// 获rss原始Data
	NSData* rssData = [IDNFeedParser dataFromUrl:rssUrl];

	// 解析RSS源信息
	IDNFeedInfo* info = [IDNFeedParser feedInfoWithData:rssData fromUrl:rssUrl];

	// 获取文章列表
	NSArray* items = [IDNFeedParser feedItemsWithData:rssData fromUrl:rssUrl];

 如果要在后台线程解析RSS，用GCD可以很方便地实现：

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

		// 获取文章列表
		NSArray* items = [IDNFeedParser feedItemsWithUrl:feedInfo.url];

		if(items==nil) //失败
			NSLog(@"获取文章列表失败");
		else //成功
		{
			// 解析完成后在主线程更新显示
			dispatch_async(dispatch_get_main_queue(), ^{
				[self showFeedItems:items];
			});
		}
	});

	#### 为什么接口只提供同步方法，不提供异步方法和delegate?

	因为同步方法非常灵活，可以很方便地结合GCG或者NSOperation使用以实现异步操作；
	而且很多开发者都有自己的多线程组件，如果用delegate方式返回数据，反而很难用。
	最重要的是好处还是接口一目了然，**简单易用**！
 */

//  Copyright (c) 2010 Michael Waterfall
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  1. The above copyright notice and this permission notice shall be included
//     in all copies or substantial portions of the Software.
//
//  2. This Software cannot be used to archive or collect data such as (but not
//     limited to) that of events, news, experiences and activities, for the
//     purpose of any concept relating to diary/journal keeping.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import <Foundation/Foundation.h>

@class IDNFeedInfo,IDNFeedItem;

//RSS解析器
@interface IDNFeedParser : NSObject

/// 获取RSS源信息。出错返回nil
+ (IDNFeedInfo*)feedInfoWithUrl:(NSString*)url;
/// 获取RSS文章列表。出错返回nil
+ (NSArray*)feedItemsWithUrl:(NSString*)url; // 返回IDNFeedItem对象的数组

/**
 从指定URL下载RSS数据，如果不是UTF8编码，会转换为UTF8编码的数据。
 内部调用了+[IDNFeedParser utf8DataFromData:textEncodingName:]
 */
+ (NSData*)dataFromUrl:(NSString*)url;
/// 获取RSS源信息。出错返回nil
+ (IDNFeedInfo*)feedInfoWithData:(NSData *)data fromUrl:(NSString*)url;
/// 获取RSS文章列表。出错返回nil
+ (NSArray*)feedItemsWithData:(NSData*)data fromUrl:(NSString*)url; // 返回IDNFeedItem对象的数组

/**
 辅助方法
 将网络上下载的原始RSS数据转为utf8编码的数据
 @param data 待转换的RSS xml数据
 @param textEncodingName data的字符编码，来自NSURLResponse.textEncodingName属性
 */
+ (NSData*)utf8DataFromData:(NSData*)data textEncodingName:(NSString*)textEncodingName;

@end

/// RSS源信息
@interface IDNFeedInfo : NSObject
<NSCoding>

@property(nonatomic,copy) NSString* title;
@property(nonatomic,copy) NSString* link;
@property(nonatomic,copy) NSString* summary;
@property(nonatomic,copy) NSString* url;
@property(nonatomic,copy) NSString* image;

@end

/// RSS文章信息
@interface IDNFeedItem : NSObject
<NSCoding>

@property (nonatomic, copy) NSString* identifier;
@property (nonatomic, copy) NSString* title;
@property (nonatomic, copy) NSString* link;
@property (nonatomic, copy) NSString* image;
@property (nonatomic, copy) NSDate* date;
@property (nonatomic, copy) NSDate* updated;
@property (nonatomic, copy) NSString* summary;
@property (nonatomic, copy) NSString* content;
@property (nonatomic, copy) NSString* author;
@property (nonatomic, copy) NSArray* enclosures;

@end

