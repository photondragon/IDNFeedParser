### 一个Rss解析器

在MWFeedParser的基础上修改。https://github.com/mwaterfall/MWFeedParser

主要做了以下改动：

1. 简化接口，去掉异步操作和delegate，只留下同步操作；
1. 把下载与解析分开（解耦），方便对RSS数据进行缓存。
1. FeedInfo增加了image图像信息

之所以去掉异步方式和delegate，就是为了保持接口的简洁。开发者也可以很方便地使用GCG或者NSOperation来实现异步加载和解析，或者使用自己的多线程组件实现异步加载。

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
