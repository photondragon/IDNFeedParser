### *IDNFeedParser* 一个使用非常方便的Rss解析库

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
	// 下载rss原始Data
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
