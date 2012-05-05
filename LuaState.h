//
//  LuaState.h
//  Lua-Objective-C Bridge
//
//  Created by Toru Hisai on 12/04/13.
//  Copyright (c) 2012年 Kronecker's Delta Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif
#import "lua.h"
#ifdef __cplusplus
}
#endif

@interface LuaBridge : NSObject
{
    lua_State *L;
}

@property (readonly) lua_State *L;

+ (LuaBridge*)instance;
- (void)dostring:(NSString*)stmt;
- (void)operate:(NSString*)opname onStack:(NSMutableArray*)stack;
- (void)op_call:(NSMutableArray*)stack;
@end
