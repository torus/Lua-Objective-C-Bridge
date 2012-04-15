//
//  LuaState.m
//  Invocator
//
//  Created by Toru Hisai on 12/04/13.
//  Copyright (c) 2012年 Kronecker's Delta Studio. All rights reserved.
//

#import "LuaState.h"

#import "lualib.h"
#import "lauxlib.h"

int luafunc_hoge (lua_State *L);

@implementation LuaState
- (id)init {
    self = [super init];
    if (self) {
        L = luaL_newstate();
        luaL_openlibs(L);
        lua_register(L, "hoge", luafunc_hoge);
        
        int err = luaL_dostring(L, "print('abcde' .. hoge())");
        if (err) {
            NSLog(@"Lua Error: %s", lua_tostring(L, -1));
            lua_pop(L, 1);
        }
    }
    return self;
}
@end

int luafunc_hoge (lua_State *L)
{
    NSString *str = @"Hoge Fuga";
    SEL sel = sel_getUid("characterAtIndex:");
    NSMethodSignature *sig = [str methodSignatureForSelector:sel];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    NSUInteger numarg = [sig numberOfArguments];
    NSLog(@"Number of arguments = %d", numarg);
    
    for (int i = 0; i < numarg; i++) {
        const char *t = [sig getArgumentTypeAtIndex:i];
        NSLog(@"arg %d: %s", i, t);
    }
    
    [inv setTarget:str];
    [inv setSelector:sel];
    NSUInteger arg1 = 5;
    [inv setArgument:&arg1 atIndex:2];
    [inv invoke];
    
    NSUInteger len = [[inv methodSignature] methodReturnLength];
    const char *rettype = [sig methodReturnType];
    NSLog(@"ret type = %s", rettype);
    void *buffer = malloc(len);
    [inv getReturnValue:buffer];
    NSLog(@"ret = %c", *(unichar*)buffer);
    
    lua_pushinteger(L, *(unichar*)buffer);

    return 1;
}
