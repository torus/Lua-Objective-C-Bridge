//
//  PointerObject.m
//  Lua-Objective-C Bridge
//
//  Created by Toru Hisai on 12/04/24.
//  Copyright (c) 2012年 Kronecker's Delta Studio. All rights reserved.
//

#import "PointerObject.h"

@implementation PointerObject
@synthesize ptr;

+ (PointerObject*)pointerWithVoidPtr:(void*)p
{
    PointerObject *ptr = [[[PointerObject alloc] init] autorelease];
    ptr->ptr = p;
    
    return ptr;
}

@end
