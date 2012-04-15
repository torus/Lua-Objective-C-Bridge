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
@end
