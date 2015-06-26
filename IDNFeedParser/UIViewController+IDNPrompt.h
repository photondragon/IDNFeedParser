//
//  UIViewController+IDNPrompt.h
//  IDNFramework
//
//  Created by photondragon on 15/5/17.
//  Copyright (c) 2015年 iosdev.net. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 在controller.view上居中显示提示内容，比如“正在加载”、“操作成功”之类的。
 */
@interface UIViewController(IDNPrompt)

@property(nonatomic,readonly) BOOL prompting;//是否正在显示提示框

// 在controller.view中加入提示框，显示文本提示，位于原有内容之上，原内容可点击。在duration秒后提示框自动消失。如果duration<=0，duration=2.0
- (void)prompt:(NSString*)text duration:(NSTimeInterval)duration;

// blockTouches==TRUE表示不允许用户点击提示框下面的内容。当提示框自动消失时，会调用finishedHandler
- (void)prompt:(NSString*)text duration:(NSTimeInterval)duration blockTouches:(BOOL)blockTouches finishedHandle:(void(^)())finishedHandler;

// 在controller.view中加入提示框（默认会有0.3s的延迟），显示旋转菊花加文本提示，原有内容不可点击。提示框不会自动消失，需要手动取消显示。
- (void)prompting:(NSString*)text;

// 取消显示提示框
- (void)stopPrompt;

@end