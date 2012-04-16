//
//  LuaState.m
//  Invocator
//
//  Created by Toru Hisai on 12/04/13.
//  Copyright (c) 2012年 Kronecker's Delta Studio. All rights reserved.
//

#import <objc/objc-runtime.h>

#import "LuaState.h"

#import "lualib.h"
#import "lauxlib.h"

int luafunc_hoge (lua_State *L);

int luafunc_newstack(lua_State *L);
int luafunc_push(lua_State *L);
int luafunc_pop(lua_State *L);
int luafunc_operate(lua_State *L);
int luafunc_getclass(lua_State *L);

@implementation LuaState
- (id)init {
    self = [super init];
    if (self) {
        L = luaL_newstate();
        luaL_openlibs(L);
        lua_register(L, "hoge", luafunc_hoge);
        lua_register(L, "newstack", luafunc_newstack);
        lua_register(L, "push", luafunc_push);
        lua_register(L, "pop", luafunc_pop);
        lua_register(L, "operate", luafunc_operate);
        lua_register(L, "getclass", luafunc_getclass);
        
        NSString *path = [NSString stringWithFormat:@"%@/bootstrap.lua", [[NSBundle mainBundle] bundlePath]];
        int err = luaL_dofile(L, [path cStringUsingEncoding:NSUTF8StringEncoding]);
        if (err) {
            NSLog(@"Lua Error: %s", lua_tostring(L, -1));
            lua_pop(L, 1);
        }
    }
    return self;
}

+ (LuaState*)instance
{
    static LuaState *stat = nil;
    if (!stat) {
        stat = [LuaState alloc];
        [stat init];
    }
    return stat;
}

- (void)operate:(NSString*)opname onStack:(NSMutableArray*)stack
{
    NSString *method = [NSString stringWithFormat:@"op_%s:", lua_tostring(L, -1)];
    
    SEL sel = sel_getUid([method cStringUsingEncoding:NSUTF8StringEncoding]);
    [self performSelector:sel withObject:stack];
}

- (void)op_call:(NSMutableArray*)stack
{
    NSString *message = (NSString*)[[stack lastObject] retain];
    [stack removeLastObject];
    id target = [[stack lastObject] retain];
    [stack removeLastObject];
    
    SEL sel = sel_getUid([message cStringUsingEncoding:NSUTF8StringEncoding]);
    NSMethodSignature *sig = [target methodSignatureForSelector:sel];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    NSUInteger numarg = [sig numberOfArguments];
    NSLog(@"Number of arguments = %d", numarg);
    
    for (int i = 2; i < numarg; i++) {
        const char *t = [sig getArgumentTypeAtIndex:i];
        NSLog(@"arg %d: %s", i, t);
        id arg = [stack lastObject];
        [stack removeLastObject];
        
        switch (t[0]) {
            case 'c': // A char
            {
                char x = [(NSNumber*)arg charValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'i': // An int
            {
                int x = [(NSNumber*)arg intValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 's': // A short
            {
                short x = [(NSNumber*)arg shortValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'l': // A long l is treated as a 32-bit quantity on 64-bit programs.
            {
                long x = [(NSNumber*)arg longValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'q': // A long long
            {
                long long x = [(NSNumber*)arg longLongValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'C': // An unsigned char
            {
                unsigned char x = [(NSNumber*)arg unsignedCharValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'I': // An unsigned int
            {
                unsigned int x = [(NSNumber*)arg unsignedIntValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'S': // An unsigned short
            {
                unsigned short x = [(NSNumber*)arg unsignedShortValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'L': // An unsigned long
            {
                unsigned long x = [(NSNumber*)arg unsignedLongValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'Q': // An unsigned long long
            {
                unsigned long long x = [(NSNumber*)arg unsignedLongLongValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'f': // A float
            {
                float x = [(NSNumber*)arg floatValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'd': // A double
            {
                double x = [(NSNumber*)arg doubleValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'B': // A C++ bool or a C99 _Bool
            {
                int x = [(NSNumber*)arg boolValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
                
            case '*': // A character string (char *)
            {
                const char *x = [(NSString*)arg cStringUsingEncoding:NSUTF8StringEncoding];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case '@': // An object (whether statically typed or typed id)
                [inv setArgument:&arg atIndex:i];
                break;

            case 'v': // A void
            case '#': // A class object (Class)
            case ':': // A method selector (SEL)
            default:
                NSLog(@"%s: Not implemented", t);
                break;
        }
    }
    
    [inv setTarget:target];
    [inv setSelector:sel];
    [inv invoke];
    
    NSUInteger len = [[inv methodSignature] methodReturnLength];
    const char *rettype = [sig methodReturnType];
    NSLog(@"ret type = %s", rettype);
    void *buffer = malloc(len);
    [inv getReturnValue:buffer];
    NSLog(@"ret = %c", *(unichar*)buffer);
#define CNVBUF(type) type x = *(type*)buffer
    
    switch (rettype[0]) {
        case 'c': // A char
        {
            CNVBUF(char);
            [stack addObject:[NSNumber numberWithChar:x]];
        }
            break;
        case 'i': // An int
        {
            CNVBUF(int);
            [stack addObject:[NSNumber numberWithInt:x]];
        }
            break;
        case 's': // A short
        {
            CNVBUF(short);
            [stack addObject:[NSNumber numberWithShort:x]];
        }
            break;
        case 'l': // A long l is treated as a 32-bit quantity on 64-bit programs.
        {
            CNVBUF(long);
            [stack addObject:[NSNumber numberWithLong:x]];
        }
            break;
        case 'q': // A long long
        {
            CNVBUF(long long);
            [stack addObject:[NSNumber numberWithLong:x]];
        }
            break;
        case 'C': // An unsigned char
        {
            CNVBUF(unsigned char);
            [stack addObject:[NSNumber numberWithUnsignedChar:x]];
        }
            break;
        case 'I': // An unsigned int
        {
            CNVBUF(unsigned int);
            [stack addObject:[NSNumber numberWithUnsignedInt:x]];
        }
            break;
        case 'S': // An unsigned short
        {
            CNVBUF(unsigned short);
            [stack addObject:[NSNumber numberWithUnsignedShort:x]];
        }
            break;
        case 'L': // An unsigned long
        {
            CNVBUF(unsigned long);
            [stack addObject:[NSNumber numberWithUnsignedLong:x]];
        }
            break;
        case 'Q': // An unsigned long long
        {
            CNVBUF(unsigned long long);
            [stack addObject:[NSNumber numberWithUnsignedLongLong:x]];
        }
            break;
        case 'f': // A float
        {
            CNVBUF(float);
            [stack addObject:[NSNumber numberWithFloat:x]];
        }
            break;
        case 'd': // A double
        {
            CNVBUF(double);
            [stack addObject:[NSNumber numberWithDouble:x]];
        }
            break;
        case 'B': // A C++ bool or a C99 _Bool
        {
            CNVBUF(int);
            [stack addObject:[NSNumber numberWithBool:x]];
        }
            break;
            
        case '*': // A character string (char *)
        {
            NSString *x = [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
            [stack addObject:x];
        }
            break;
        case '@': // An object (whether statically typed or typed id)
        {
            id x = *(id*)buffer;
            [stack addObject:x];
        }
            break;
            
        case 'v': // A void
        case '#': // A class object (Class)
        case ':': // A method selector (SEL)
        default:
            NSLog(@"%s: Not implemented", rettype);
            break;
    }
#undef CNVBUF
    
    free(buffer);
}

@end

int luafunc_newstack(lua_State *L)
{
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    
    lua_pushlightuserdata(L, arr);
    
    return 1;
}
int luafunc_getclass(lua_State *L)
{
    const char *classname = lua_tostring(L, -1);
    id cls = objc_getClass(classname);
    lua_pushlightuserdata(L, cls);
    return 1;
}
int luafunc_push(lua_State *L)
{
    int top = lua_gettop(L);
    
    NSMutableArray *arr = (NSMutableArray*)lua_topointer(L, 1);
    for (int i = 2; i <= top; i ++) {
        switch (lua_type(L, i)) {
            case LUA_TNIL:
                [arr addObject:[NSNull null]];
                break;
            case LUA_TNUMBER:
                [arr addObject:[NSNumber numberWithDouble:lua_tonumber(L, i)]];
                break;
            case LUA_TBOOLEAN:
                [arr addObject:[NSNumber numberWithBool:lua_toboolean(L, i)]];
                break;
            case LUA_TSTRING:
                [arr addObject:[NSString stringWithCString:lua_tostring(L, i) encoding:NSUTF8StringEncoding]];
                break;
            case LUA_TLIGHTUSERDATA:
                [arr addObject:(id)lua_topointer(L, i)];
                break;
                
            case LUA_TTABLE:
            case LUA_TFUNCTION:
            case LUA_TUSERDATA:
            case LUA_TTHREAD:
            case LUA_TNONE:
            default:
                lua_pushstring(L, "Value type not supported.");
                lua_error(L);
                break;
        }
    }

    return 0;
}

int luafunc_operate(lua_State *L)
{
    NSMutableArray *arr = (NSMutableArray*)lua_topointer(L, 1);
    NSString *opname = [NSString stringWithCString:lua_tostring(L, 2) encoding:NSUTF8StringEncoding];
    
    [[LuaState instance] operate:opname onStack:arr];
    return 0;
}

int luafunc_pop(lua_State *L)
{
    NSMutableArray *arr = (NSMutableArray*)lua_topointer(L, 1);
    id obj = [arr lastObject];
    [arr removeLastObject];
    
    if ([obj isKindOfClass:[NSString class]]) {
        lua_pushstring(L, [obj cStringUsingEncoding:NSUTF8StringEncoding]);
    } else if ([obj isKindOfClass:[NSNumber class]]) {
        lua_pushnumber(L, [obj doubleValue]);
    } else if ([obj isKindOfClass:[NSNull class]]) {
        lua_pushnil(L);
    } else {
        lua_pushlightuserdata(L, [obj retain]);
    }
    return 1;
}

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
