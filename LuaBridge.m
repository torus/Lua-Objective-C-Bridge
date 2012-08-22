//
//  LuaState.m
//  Lua-Objective-C Bridge
//
//  Created by Toru Hisai on 12/04/13.
//  Copyright (c) 2012年 Kronecker's Delta Studio. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <objc/runtime.h>

#import "LuaBridge.h"
//#import "PointerObject.h"

#import "lualib.h"
#import "lauxlib.h"

#import "LuaBridgeInternal.h"
//int luafunc_hoge (lua_State *L);
//
//int luafunc_newstack(lua_State *L);
//int luafunc_push(lua_State *L);
//int luafunc_pop(lua_State *L);
//int luafunc_clear(lua_State *L);
//int luafunc_operate(lua_State *L);
//int luafunc_getclass(lua_State *L);
static void push_object(lua_State *L, id obj);

static int gc_metatable_ref;

int finalize_object(lua_State *L)
{
    void *p = lua_touserdata(L, 1);
    void **ptr = (void**)p;
    id obj = (id)*ptr;
    
//    NSLog(@"%s: releasing %@ retainCount = %d", __PRETTY_FUNCTION__, obj, [obj retainCount]);

    [obj release];

    return 0;
}

@implementation LuaBridge
@synthesize L;

- (id)init {
    self = [super init];
    if (self) {
        L = luaL_newstate();
        luaL_openlibs(L);
        lua_newtable(L);

#define ADDMETHOD(name) \
    (lua_pushstring(L, #name), \
     lua_pushcfunction(L, luafunc_ ## name), \
     lua_settable(L, -3))
        
        ADDMETHOD(hoge);
        ADDMETHOD(newstack);
        ADDMETHOD(push);
        ADDMETHOD(pop);
        ADDMETHOD(clear);
        ADDMETHOD(operate);
        ADDMETHOD(getclass);

        lua_setglobal(L, "objc");
#undef ADDMETHOD        
    }
    return self;
}

+ (LuaBridge*)instance
{
    static LuaBridge *stat = nil;
    if (!stat) {
        stat = [LuaBridge alloc];
        [stat init];
        
        lua_State *L = stat.L;
        
        lua_newtable(L);
        lua_pushstring(L, "__gc");
        lua_pushcfunction(L, finalize_object);
        lua_settable(L, -3);
        gc_metatable_ref = luaL_ref(L, LUA_REGISTRYINDEX);
        
        NSLog(@"%s: metatable_ref = %d", __PRETTY_FUNCTION__, gc_metatable_ref);
        
    }
    return stat;
}

- (void)dostring:(NSString*)stmt
{
    if (luaL_dostring(L, [stmt cStringUsingEncoding:NSUTF8StringEncoding])) {
        NSLog(@"Lua Error: %s", lua_tostring(L, -1));
        lua_pop(L, 1);
    }
}

static NSUncaughtExceptionHandler * orig_exception_handler = NULL;
static NSString *exception_handler_opname = NULL;
static NSMutableArray *exception_handler_stack = NULL;

static void lua_exception_handler(NSException *exception)
{
    NSLog(@"Lua exception: opname = %@: stack = %@", exception_handler_opname, exception_handler_stack);
    if (orig_exception_handler) {
        orig_exception_handler(exception);
    }
}

- (void)operate:(NSString*)opname onStack:(NSMutableArray*)stack
{
    orig_exception_handler = NSGetUncaughtExceptionHandler();
    exception_handler_stack = [stack retain];
    exception_handler_opname = [opname retain];

    NSSetUncaughtExceptionHandler(lua_exception_handler);
    
    NSString *method = [NSString stringWithFormat:@"op_%@:", opname];
    
    SEL sel = sel_getUid([method cStringUsingEncoding:NSUTF8StringEncoding]);
    [self performSelector:sel withObject:stack];
    
    NSSetUncaughtExceptionHandler(orig_exception_handler);
    orig_exception_handler = NULL;
    exception_handler_stack = NULL;
    exception_handler_opname = NULL;
    [stack release];
    [opname release];
}

- (void)op_call:(NSMutableArray*)stack
{
    NSString *message = [(NSString*)[[stack lastObject] retain] autorelease];
    [stack removeLastObject];
    id target = [[[stack lastObject] retain] autorelease];
    [stack removeLastObject];
    
    SEL sel = sel_getUid([message cStringUsingEncoding:NSUTF8StringEncoding]);
    NSMethodSignature *sig = [target methodSignatureForSelector:sel];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv retainArguments];
    NSUInteger numarg = [sig numberOfArguments];
//    NSLog(@"Number of arguments = %d", numarg);
    
    for (int i = 2; i < numarg; i++) {
        const char *t = [sig getArgumentTypeAtIndex:i];
//        NSLog(@"arg %d: %s", i, t);
        id arg = [[[stack lastObject] retain] autorelease];
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

            case '^': // pointer
                if ([arg isKindOfClass:[NSValue class]]) {
                    void *ptr = [(NSValue*)arg pointerValue];
                    [inv setArgument:&ptr atIndex:i];
                } else {
                    //[inv setArgument:&arg atIndex:i];
                    [NSError errorWithDomain:@"Passing wild pointer" code:1 userInfo:nil];
                }
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
    
    const char *rettype = [sig methodReturnType];
//    NSLog(@"[%@ %@] ret type = %s", target, message, rettype);
    void *buffer = NULL;
    if (rettype[0] != 'v') { // don't get return value from void function
        NSUInteger len = [[inv methodSignature] methodReturnLength];
        buffer = malloc(len);
        [inv getReturnValue:buffer];
//        NSLog(@"ret = %c", *(unichar*)buffer);
    }
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
            if (x) {
                [stack addObject:x];
            } else {
                [stack addObject:[NSNull null]];
            }
        }
            break;
            
        case '^':
        {
            void *x = *(void**)buffer;
//            [stack addObject:[PointerObject pointerWithVoidPtr:x]];
            [stack addObject:[NSValue valueWithPointer:x]];
        }
            break;
        case 'v': // A void
            [stack addObject:[NSNull null]];
            break;
        case '#': // A class object (Class)
        case ':': // A method selector (SEL)
        default:
            NSLog(@"%s: Not implemented", rettype);
            [stack addObject:[NSNull null]];
            break;
    }
#undef CNVBUF
    
    free(buffer);
}

- (void)pushObject:(id)obj
{
    push_object(L, obj);
}

@end

static void push_object(lua_State *L, id obj)
{
    if (obj == nil) {
        lua_pushnil(L);
    } else if ([obj isKindOfClass:[NSString class]]) {
        lua_pushstring(L, [obj cStringUsingEncoding:NSUTF8StringEncoding]);
    } else if ([obj isKindOfClass:[NSNumber class]]) {
        lua_pushnumber(L, [obj doubleValue]);
    } else if ([obj isKindOfClass:[NSNull class]]) {
        lua_pushnil(L);
//    } else if ([obj isKindOfClass:[PointerObject class]]) {
//        lua_pushlightuserdata(L, [(PointerObject*)obj ptr]);
    } else {
        [obj retain];
        
        void *ud = lua_newuserdata(L, sizeof(void*));
        void **udptr = (void**)ud;
        *udptr = obj;
        lua_rawgeti(L, LUA_REGISTRYINDEX, gc_metatable_ref);
        lua_setmetatable(L, -2);
    }
}

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
            case LUA_TUSERDATA:
            {
                void *p = lua_touserdata(L, i);
                void **ptr = (void**)p;
                [arr addObject:(id)*ptr];
            }
                break;                
            case LUA_TTABLE:
            case LUA_TFUNCTION:
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
    
    [[LuaBridge instance] operate:opname onStack:arr];
    return 0;
}

int luafunc_pop(lua_State *L)
{
    NSMutableArray *arr = (NSMutableArray*)lua_topointer(L, 1);
    id obj = [[[arr lastObject] retain] autorelease];
    [arr removeLastObject];
    
    push_object(L, obj);
    
    return 1;
}

int luafunc_clear(lua_State *L)
{
    NSMutableArray *arr = (NSMutableArray*)lua_topointer(L, 1);
    [arr removeAllObjects];

    return 0;
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
