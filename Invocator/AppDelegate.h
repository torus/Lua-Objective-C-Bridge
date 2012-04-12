//
//  AppDelegate.h
//  Invocator
//
//  Created by Toru Hisai on 12/04/12.
//  Copyright Kronecker's Delta Studio 2012年. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RootViewController;

@interface AppDelegate : NSObject <UIApplicationDelegate> {
	UIWindow			*window;
	RootViewController	*viewController;
}

@property (nonatomic, retain) UIWindow *window;

@end
