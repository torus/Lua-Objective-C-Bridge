//
//  PointerObject.h
//  Lua-Objective-C Bridge
//
//  Created by Toru Hisai on 12/04/24.
//  Copyright (c) 2012年 Kronecker's Delta Studio. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PointerObject : NSObject
{
    void *ptr;
}

@property (readonly) void *ptr;
+ (PointerObject*)pointerWithVoidPtr:(void*)p;

@end
