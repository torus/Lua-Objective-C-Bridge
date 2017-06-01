//
//  LuaObjCTest.m
//  LuaObjCBridge
//
//  Created by Hisai Toru on 2017/05/29.
//  Copyright © 2017年 Kronecker's Delta Studio. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LuaObjCTest : NSObject

@property (readwrite) NSString *str;

@end


@implementation LuaObjCTest

- (int)sum: (int) a withAnotherValue: (int) b {
    return a + b;
}

@end
