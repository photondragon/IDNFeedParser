//
//  WebViewController.m
//  IDNFeedParser
//
//  Created by photondragon on 15/6/26.
//  Copyright (c) 2015年 iosdev.net. All rights reserved.
//

#import "WebViewController.h"
#import "UIViewController+IDNPrompt.h"

@interface WebViewController ()
<UIWebViewDelegate>

@property(nonatomic,strong) UIWebView* webView;

@end

@implementation WebViewController

- (void)loadView
{
	_webView = [[UIWebView alloc] init];
	_webView.delegate = self;
	self.view = _webView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)setUrl:(NSString *)url
{
	_url = url;

	[self view];

	if(url)
	{
		NSURL* nsurl = [NSURL URLWithString:url];
		NSURLRequest* request = [NSURLRequest requestWithURL:nsurl];
		[self.webView loadRequest:request];
	}
	else
		[self.webView loadRequest:nil];
}

#pragma mark UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	return YES;
}
- (void)webViewDidStartLoad:(UIWebView *)webView
{
	[self prompting:@"正在加载"];
}
- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	[self stopPrompt];
}
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	[self prompt:[NSString stringWithFormat:@"加载失败\n%@", error.localizedDescription] duration:2];
}

@end
