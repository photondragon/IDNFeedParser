//
//  IDNFeedParser.h
//  IDNFramework
//
//  Created by photondragon on 15/6/24.
//  Copyright (c) 2015年 iosdev.net.
//

/*
 在MWFeedParser的基础上修改。https://github.com/mwaterfall/MWFeedParser
 简化接口，去掉异步操作，只留下同步操作；
 把下载与解析分开（解耦），方便对RSS xml数据进行缓存。
 FeedInfo增加了image图像信息
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

/// 获取RSS源信息
+ (IDNFeedInfo*)feedInfoWithUrl:(NSString*)url;
/// 获取RSS文章列表
+ (NSArray*)feedItemsWithUrl:(NSString*)url; // 返回IDNFeedItem对象的数组

/**
 从指定URL下载RSS数据，如果不是UTF8编码，会转换为UTF8编码的数据。
 内部调用了+[IDNFeedParser utf8DataFromData:textEncodingName:]
 */
+ (NSData*)dataFromUrl:(NSString*)url;
/// 获取RSS源信息
+ (IDNFeedInfo*)feedInfoWithData:(NSData *)data fromUrl:(NSString*)url;
/// 获取RSS文章列表
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

@property(nonatomic,copy) NSString *title;
@property(nonatomic,copy) NSString *link;
@property(nonatomic,copy) NSString *summary;
@property(nonatomic,copy) NSString *url;
@property(nonatomic,copy) NSString* image;

@end

/// RSS文章信息
@interface IDNFeedItem : NSObject
<NSCoding>

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *link;
@property (nonatomic, copy) NSDate *date;
@property (nonatomic, copy) NSDate *updated;
@property (nonatomic, copy) NSString *summary;
@property (nonatomic, copy) NSString *content;
@property (nonatomic, copy) NSString *author;
@property (nonatomic, copy) NSArray *enclosures;

@end

