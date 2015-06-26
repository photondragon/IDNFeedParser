//
//  UIViewController+IDNPrompt.m
//  IDNFramework
//
//  Created by photondragon on 15/5/17.
//  Copyright (c) 2015年 iosdev.net. All rights reserved.
//

#import "UIViewController+IDNPrompt.h"
//#import "IDNActivityIndicator.h"

//#define ActivityIndicator IDNActivityIndicator
//#define ActivityIndicatorColor [UIColor colorWithRed:21/255.0 green:138/255.0 blue:228/255.0 alpha:1]
#define ActivityIndicator UIActivityIndicatorView
#define ActivityIndicatorColor nil

#define PromptFrameWidth 110
#define PromptFrameHeight 90
#define LoadingIndicatorLength 30

@interface UIViewControllerPromptView : UIView
@property(nonatomic,weak) UIView* frameView;
@property(nonatomic,weak) UILabel* labelPrompt;
@property(nonatomic,strong) ActivityIndicator* loadingIndicator;
- (void)showLoadingIndicator;//显示旋转菊花
@end
@implementation UIViewControllerPromptView

- (instancetype)init
{
	self = [super init];
	if (self) {
		//框
		UIView* frameView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, PromptFrameWidth, PromptFrameHeight)];//这里设置frame是为了后面设置labelPrompt.autoresizingMask方便
		frameView.translatesAutoresizingMaskIntoConstraints = NO;
		frameView.layer.cornerRadius = 6;
		frameView.layer.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5].CGColor;
		[self addSubview:frameView];
		self.frameView = frameView;

		//居中显示框
		[frameView addConstraint:[NSLayoutConstraint constraintWithItem:frameView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:PromptFrameWidth]];
		[frameView addConstraint:[NSLayoutConstraint constraintWithItem:frameView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:PromptFrameHeight]];
		[self addConstraint:[NSLayoutConstraint constraintWithItem:frameView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0]];
		[self addConstraint:[NSLayoutConstraint constraintWithItem:frameView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:-32]];


		UILabel* labelPrompt = [[UILabel alloc] initWithFrame:CGRectMake(8, 4, PromptFrameWidth-16, PromptFrameHeight-8)];
		labelPrompt.numberOfLines = 4;
		labelPrompt.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		labelPrompt.font = [UIFont boldSystemFontOfSize:14];
		labelPrompt.textColor = [UIColor whiteColor];//colorWithRed:0.2 green:0.2 blue:0.2 alpha:1];
		labelPrompt.textAlignment = NSTextAlignmentCenter;
		[frameView addSubview:labelPrompt];
		self.labelPrompt = labelPrompt;
	}
	return self;
}

- (ActivityIndicator*)loadingIndicator
{
	if(_loadingIndicator==nil)
	{
		_loadingIndicator = [[ActivityIndicator alloc] initWithFrame:CGRectMake(PromptFrameWidth/2.0-15, 16, LoadingIndicatorLength, LoadingIndicatorLength)];
		_loadingIndicator.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		_loadingIndicator.color = ActivityIndicatorColor;
	}
	return _loadingIndicator;
}
- (void)showLoadingIndicator
{
	self.labelPrompt.frame = CGRectMake(8, 8+LoadingIndicatorLength+4, PromptFrameWidth-16, PromptFrameHeight-LoadingIndicatorLength-8-4-4);
	[self.frameView addSubview:self.loadingIndicator];
	//	[self.loadingIndicator startAnimating];
}
- (void)willMoveToWindow:(UIWindow *)newWindow
{
	if(_loadingIndicator && _loadingIndicator.superview)
	{
		if(newWindow==nil)
			[self.loadingIndicator stopAnimating];
		else
			[self.loadingIndicator startAnimating];
	}
}
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event{
}
@end

@implementation UIViewController(Prompt)

+ (NSMutableDictionary*)dictionaryOfPromptInfos
{
	static NSMutableDictionary* dic = nil;
	if(dic==nil)
	{
		dic	= [NSMutableDictionary dictionary];
	}
	return dic;
}

- (NSMutableDictionary*)promptInfo
{
	NSValue* controllerKey = [NSValue valueWithNonretainedObject:self];
	NSMutableDictionary* dicPromptInfos = [UIViewController dictionaryOfPromptInfos];
	NSMutableDictionary* dicPromptInfo = dicPromptInfos[controllerKey];
	return dicPromptInfo;
}

- (BOOL)prompting
{
	if([self promptInfo])
		return TRUE;
	return FALSE;
}

- (void)prompt:(NSString*)text duration:(NSTimeInterval)duration
{
	[self prompt:text duration:duration blockTouches:NO finishedHandle:nil];
}
- (void)prompt:(NSString*)text duration:(NSTimeInterval)duration blockTouches:(BOOL)blockTouches finishedHandle:(void(^)())finishedHandler
{
	if(duration<=0)
		duration = 2.0;

	[self promptWithText:text delay:0 duration:duration blockTouches:blockTouches showLoading:NO finishedHandle:finishedHandler];
}

- (void)prompting:(NSString*)text
{
	[self promptWithText:text delay:0.3 duration:0 blockTouches:YES showLoading:YES finishedHandle:nil];
}

// duration==0表示不自动消失。showLoading是否显示旋转菊花。
- (void)promptWithText:(NSString*)text delay:(NSTimeInterval)delay duration:(NSTimeInterval)duration blockTouches:(BOOL)blockTouches showLoading:(BOOL)showLoading finishedHandle:(void(^)())finishedHandler
{
	[self stopPrompt];

	if(delay<0)
		delay = 0;
	if(duration<0)
		duration = 2.0;

	UIViewControllerPromptView* view = [[UIViewControllerPromptView alloc] init];
	view.userInteractionEnabled = blockTouches;//屏蔽下层Touches
	if(showLoading)
		[view showLoadingIndicator];
	view.labelPrompt.text = text;
	view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

	NSMutableDictionary* dicPromptInfo = [NSMutableDictionary dictionaryWithDictionary:@{@"view":view,
																						 @"delay":@(delay),
																						 @"duration":@(duration),
																						 }];
	if(text)
		dicPromptInfo[@"text"] = text;
	if(finishedHandler)
		dicPromptInfo[@"finishedHandler"] = finishedHandler;
	NSMutableDictionary* dicPromptInfos = [UIViewController dictionaryOfPromptInfos];
	dicPromptInfos[[NSValue valueWithNonretainedObject:self]] = dicPromptInfo;

	[self performSelector:@selector(addPromptView) withObject:nil afterDelay:delay];
}

- (void)addPromptView
{
	NSValue* controllerKey = [NSValue valueWithNonretainedObject:self];
	NSMutableDictionary* dicPromptInfos = [UIViewController dictionaryOfPromptInfos];
	NSMutableDictionary* dicPromptInfo = dicPromptInfos[controllerKey];
	if(dicPromptInfo==nil)
		return;
	UIView* view = dicPromptInfo[@"view"];
	CGRect frame = self.view.frame;
	frame.origin = CGPointZero;
	view.frame = frame;
	[self.view addSubview:view];

	NSTimeInterval duration = [dicPromptInfo[@"duration"] doubleValue];
	if(duration>0)
		[self performSelector:@selector(removePromptView) withObject:nil afterDelay:duration];
}

- (void)stopPrompt
{
	[self.class cancelPreviousPerformRequestsWithTarget:self selector:@selector(addPromptView) object:nil];
	[self.class cancelPreviousPerformRequestsWithTarget:self selector:@selector(removePromptView) object:nil];

	[self performSelectorOnMainThread:@selector(removePromptView) withObject:nil waitUntilDone:YES];//立即执行
}

- (void)removePromptView
{
	NSValue* controllerKey = [NSValue valueWithNonretainedObject:self];
	NSMutableDictionary* dicPromptInfos = [UIViewController dictionaryOfPromptInfos];
	NSMutableDictionary* dicPromptInfo = dicPromptInfos[controllerKey];
	if(dicPromptInfo==nil)
		return;
	UIView* view = dicPromptInfo[@"view"];
	[view removeFromSuperview];
	[dicPromptInfos removeObjectForKey:controllerKey];
	void (^finishedHandler)();
	finishedHandler = dicPromptInfo[@"finishedHandler"];
	if(finishedHandler)
		finishedHandler();
}

@end
