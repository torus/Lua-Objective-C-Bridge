//
//  LuaState.h
//  Invocator
//
//  Created by Toru Hisai on 12/04/13.
//  Copyright (c) 2012年 Kronecker's Delta Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "lua.h"

@interface LuaState : NSObject
{
    lua_State *L;
}

+ (LuaState*)instance;
- (void)operate:(NSString*)opname onStack:(NSMutableArray*)stack;
- (void)op_call:(NSMutableArray*)stack;
@end
