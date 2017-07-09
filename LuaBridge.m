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

#import "lualib.h"
#import "lauxlib.h"

#import "LuaBridgeInternal.h"

static int gc_metatable_ref;
static id luavalue_to_object(lua_State *L, int index);

int finalize_object(lua_State *L)
{
    void *p = lua_touserdata(L, 1);
    void **ptr = (void**)p;
    id obj = (__bridge_transfer id)*ptr;
//    NSLog(@"%s: releasing %@", __PRETTY_FUNCTION__, obj);
//    CFBridgingRelease(*ptr);

//    NSLog(@"%s: releasing %@ retainCount = %d", __PRETTY_FUNCTION__, obj, [obj retainCount]);

    return 0;
}

@implementation LuaBridge
@synthesize L;
@synthesize methodTable;

- (id)init {
    self = [super init];
    if (self) {
        L = luaL_newstate();
        luaL_openlibs(L);
        lua_newtable(L);
        
        methodTable = [NSMutableDictionary new];

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
        ADDMETHOD(extract);

        lua_setglobal(L, "objc");
#undef ADDMETHOD
        
        NSString *path = [[NSBundle mainBundle] pathForResource:@"utils" ofType:@"lua"];
        if (!path) {
            NSLog(@"Error: utils.lua not found");
        } else if (luaL_dofile(L, [path UTF8String])) {
            const char *err = lua_tostring(L, -1);
            NSLog(@"error while loading utils: %s", err);
        }
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
    exception_handler_stack = stack;
    exception_handler_opname = opname;

    NSSetUncaughtExceptionHandler(lua_exception_handler);
    
    NSString *method = [NSString stringWithFormat:@"op_%@:", opname];
    
    SEL sel = sel_getUid([method cStringUsingEncoding:NSUTF8StringEncoding]);
    [self performSelector:sel withObject:stack];
    
    NSSetUncaughtExceptionHandler(orig_exception_handler);
    orig_exception_handler = NULL;
    exception_handler_stack = NULL;
    exception_handler_opname = NULL;

}

- (void)op_call:(NSMutableArray*)stack
{
    NSString *message = (NSString*)[stack lastObject];
    [stack removeLastObject];
    id target = [stack lastObject] ;
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

            case '^': // pointer
                if ([arg isKindOfClass:[NSValue class]]) {
                    void *ptr = [(NSValue*)arg pointerValue];
                    [inv setArgument:&ptr atIndex:i];
                } else {
                    //[inv setArgument:&arg atIndex:i];
                    [NSError errorWithDomain:@"Passing wild pointer" code:1 userInfo:nil];
                }
                break;
                
            case '{': // {name=type...} A structure
            {
                NSString *t_str = [NSString stringWithUTF8String:t];
                if ([t_str hasPrefix:@"{CGRect"]) {
                    CGRect rect = [(NSValue*)arg CGRectValue];
                    [inv setArgument:&rect atIndex:i];
                } else if ([t_str hasPrefix:@"{CGSize"]) {
                    CGSize size = [(NSValue*)arg CGSizeValue];
                    [inv setArgument:&size atIndex:i];
                } else if ([t_str hasPrefix:@"{CGPoint"]) {
                    CGPoint point = [(NSValue*)arg CGPointValue];
                    [inv setArgument:&point atIndex:i];
                } else if ([t_str hasPrefix:@"{CGAffineTransform"]) {
                    CGAffineTransform tran = [(NSValue*)arg CGAffineTransformValue];
                    [inv setArgument:&tran atIndex:i];
                }
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
    [[self class] pushValue:buffer withTypes:rettype toStack:stack];
    free(buffer);
}

+ (void)pushValue:(void*)buffer withTypes:(const char*)types toStack:(NSMutableArray*)stack
{
#define CNVBUF(type) type x = *(type*)buffer
    
    switch (types[0]) {
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
            id x = (__bridge id)*((void **)buffer);
            //            NSLog(@"stack %@", stack);
            if (x) {
                //                NSLog(@"x %@", x);
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
            
        case '{': // {name=type...} A structure
        {
            NSString *t = [NSString stringWithUTF8String:types];
            
            if ([t hasPrefix:@"{CGRect"]) {
                CGRect *rect = (CGRect*)buffer;
                [stack addObject:[NSValue valueWithCGRect:*rect]];
            } else if ([t hasPrefix:@"{CGSize"]) {
                CGSize *size = (CGSize*)buffer;
                [stack addObject:[NSValue valueWithCGSize:*size]];
            } else if ([t hasPrefix:@"{CGPoint"]) {
                CGPoint *size = (CGPoint*)buffer;
                [stack addObject:[NSValue valueWithCGPoint:*size]];
            } else if ([t hasPrefix:@"{CGAffineTransform"]) {
                CGAffineTransform *tran = (CGAffineTransform*)buffer;
                [stack addObject:[NSValue valueWithCGAffineTransform:*tran]];
            }
        }
            break;
            
        case '#': // A class object (Class)
        case ':': // A method selector (SEL)
        default:
            NSLog(@"%s: Not implemented", types);
            [stack addObject:[NSNull null]];
            break;
    }
#undef CNVBUF
}

- (NSNumber *)popNumber:(NSMutableArray*)stack
{
    NSNumber *num = [stack lastObject];
    [stack removeLastObject];
    
    return num;
}

- (void)op_cgrectmake:(NSMutableArray*)stack
{
    double x = [[self popNumber:stack] doubleValue];
    double y = [[self popNumber:stack] doubleValue];
    double w = [[self popNumber:stack] doubleValue];
    double h = [[self popNumber:stack] doubleValue];
    
    CGRect rect = CGRectMake(x, y, w, h);
    [stack addObject:[NSValue valueWithCGRect:rect]];
}

- (void)op_addClass:(NSMutableArray*)stack
{
    NSString *name = [stack lastObject];
    [stack removeLastObject];
    Class cls = objc_allocateClassPair([NSObject class], [name UTF8String], 0);
    objc_registerClassPair(cls);
    [stack addObject:cls];
}

id luaFuncIMP(id self, SEL _cmd, ...)
{
    NSLog(@"_cmd = %s", sel_getName(_cmd));
    //
    NSMethodSignature *sig = [self methodSignatureForSelector:_cmd];
    NSUInteger num = [sig numberOfArguments];
    va_list vl;
    va_start(vl, _cmd);
    
    lua_State *L = [[LuaBridge instance] L];

    LuaBridge *brdg = [LuaBridge instance];
    Class cls = [self class];
    LuaObjectReference *func = [brdg.methodTable valueForKey:[NSString stringWithFormat:@"%s.%s", class_getName(cls), sel_getName(_cmd)]];
    
    luabridge_push_object(L, func);

    luabridge_push_object(L, self);
    lua_pushstring(L, sel_getName(_cmd));

    for (int i = 2; i < num; i ++) {
        const char *t = [sig getArgumentTypeAtIndex:i];
        NSLog(@"arg %d: %s", i, t);
        switch (t[0]) {
            case 'c': // A char
            {
                char x = va_arg(vl, char);
                luabridge_push_object(L, [NSNumber numberWithChar:x]);
            }
                break;
            case 'i': // An int
            {
                int x = va_arg(vl, int);
                luabridge_push_object(L, [NSNumber numberWithInt:x]);
            }
                break;
            case 's': // A short
            {
                short x = va_arg(vl, short);
                luabridge_push_object(L, [NSNumber numberWithShort:x]);
            }
                break;
            case 'l': // A long l is treated as a 32-bit quantity on 64-bit programs.
            {
                long x = va_arg(vl, long);
                luabridge_push_object(L, [NSNumber numberWithLong:x]);
            }
                break;
            case 'q': // A long long
            {
                long long x = va_arg(vl, long long);
                luabridge_push_object(L, [NSNumber numberWithLongLong:x]);
            }
                break;
            case 'C': // An unsigned char
            {
                unsigned char x = va_arg(vl, unsigned char);
                luabridge_push_object(L, [NSNumber numberWithUnsignedChar:x]);
            }
                break;
            case 'I': // An unsigned int
            {
                unsigned int x = va_arg(vl, unsigned int);
                luabridge_push_object(L, [NSNumber numberWithUnsignedInt:x]);
            }
                break;
            case 'S': // An unsigned short
            {
                unsigned short x = va_arg(vl, unsigned short);
                luabridge_push_object(L, [NSNumber numberWithUnsignedShort:x]);
            }
                break;
            case 'L': // An unsigned long
            {
                unsigned long x = va_arg(vl, unsigned long);
                luabridge_push_object(L, [NSNumber numberWithUnsignedLong:x]);
            }
                break;
            case 'Q': // An unsigned long long
            {
                unsigned long long x = va_arg(vl, unsigned long long);
                luabridge_push_object(L, [NSNumber numberWithUnsignedLongLong:x]);
            }
                break;
            case 'f': // A float
            {
                float x = va_arg(vl, float);
                luabridge_push_object(L, [NSNumber numberWithFloat:x]);
            }
                break;
            case 'd': // A double
            {
                double x = va_arg(vl, double);
                luabridge_push_object(L, [NSNumber numberWithDouble:x]);
            }
                break;
            case 'B': // A C++ bool or a C99 _Bool
            {
                _Bool x = va_arg(vl, _Bool);
                luabridge_push_object(L, [NSNumber numberWithBool:x]);
            }
                break;
                
            case '*': // A character string (char *)
            {
                const char *x = va_arg(vl, const char *);
                luabridge_push_object(L, [NSString stringWithUTF8String:x]);
            }
                break;

            case '@': // An object (whether statically typed or typed id)
            {
                id x = va_arg(vl, id);
                luabridge_push_object(L, x);
            }
                break;
                
            case '^': // pointer
            {
                void *x = va_arg(vl, void *);
                NSValue *val = [NSValue valueWithPointer:x];
                luabridge_push_object(L, val);
            }
                break;
                
            case '{': // {name=type...} A structure
            case 'v': // A void
            case '#': // A class object (Class)
            case ':': // A method selector (SEL)
            default:
                NSLog(@"%s: Not implemented", t);
                break;
        }
    }
    va_end(vl);

    id ret = nil;
    int err = lua_pcall(L, num, 1, 0);
    if (err) {
        const char *mesg = lua_tostring(L, -1);
        NSLog(@"Lua Error (%d): %s", err, mesg);
    } else {
        ret = luavalue_to_object(L, -1);
    }

    return ret;
}

- (void)op_addMethod:(NSMutableArray*)stack
{
    LuaObjectReference *func = [stack lastObject];
    [stack removeLastObject];
    NSString *sig = [stack lastObject];
    [stack removeLastObject];
    NSString *name = [stack lastObject];
    [stack removeLastObject];
    Class cls = [stack lastObject];
    [stack removeLastObject];
    
    [methodTable setValue:func forKey:[NSString stringWithFormat:@"%s.%@", class_getName(cls), name]];
    class_addMethod(cls, sel_registerName([name UTF8String]), (IMP)luaFuncIMP, [sig UTF8String]);
    // class, method name, signature, func
}

- (void)pushObject:(id)obj
{
    luabridge_push_object(L, obj);
}

@end

@implementation LuaObjectReference
@synthesize ref, L;
- (void)dealloc
{
    luaL_unref(self.L, LUA_REGISTRYINDEX, self.ref);
}
@end

void luabridge_push_object(lua_State *L, id obj)
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
    } else if ([obj isKindOfClass:[LuaObjectReference class]]) {
        int ref = ((LuaObjectReference*)obj). ref;
        lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
    } else {
      
        
        void *ud = lua_newuserdata(L, sizeof(void*));
        void **udptr = (void**)ud;
        *udptr = (__bridge_retained void *)(obj);
        lua_rawgeti(L, LUA_REGISTRYINDEX, gc_metatable_ref);
        lua_setmetatable(L, -2);
    }
}

int luafunc_newstack(lua_State *L)
{
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    
    lua_pushlightuserdata(L, (__bridge_retained void *)(arr));
    
    return 1;
}
int luafunc_getclass(lua_State *L)
{
    const char *classname = lua_tostring(L, -1);
    id cls = objc_getClass(classname);
    lua_pushlightuserdata(L, (__bridge void *)(cls));
    return 1;
}

static id luavalue_to_object(lua_State *L, int index)
{
    id dest = nil;

    int t = lua_type(L, index);
    switch (t) {
        case LUA_TNIL:
            dest = [NSNull null];
            break;
        case LUA_TNUMBER:
            dest = [NSNumber numberWithDouble:lua_tonumber(L, index)];
            break;
        case LUA_TBOOLEAN:
            dest = [NSNumber numberWithBool:lua_toboolean(L, index)];
            break;
        case LUA_TSTRING:
            dest = [NSString stringWithCString:lua_tostring(L, index) encoding:NSUTF8StringEncoding];
            break;
        case LUA_TLIGHTUSERDATA:
            dest = (__bridge id)lua_topointer(L, index);
            break;
        case LUA_TUSERDATA:
        {
            void *p = lua_touserdata(L, index);
            void **ptr = (void**)p;
            dest = (__bridge id)*ptr;
        }
            break;
        case LUA_TTABLE:
        case LUA_TFUNCTION:
        case LUA_TTHREAD:
        {
            LuaObjectReference *ref = [LuaObjectReference new];
            ref.ref = luaL_ref(L, LUA_REGISTRYINDEX);
            ref.L = L;
            dest = ref;
        }
            break;
        case LUA_TNONE:
        default:
        {
            NSString *errmsg = [NSString stringWithFormat:@"Value type not supported. type = %d", t];
            lua_pushstring(L, [errmsg UTF8String]);
            lua_error(L);
        }
            break;
    }
    return dest;
}

int luafunc_push(lua_State *L)
{
    int top = lua_gettop(L);
    
    NSMutableArray *arr = (__bridge NSMutableArray*)lua_topointer(L, 1);
    for (int i = 2; i <= top; i ++) {
        [arr addObject:luavalue_to_object(L, i)];
    }

    return 0;
}

int luafunc_operate(lua_State *L)
{
    NSMutableArray *arr = (__bridge NSMutableArray*)lua_topointer(L, 1);
    NSString *opname = [NSString stringWithCString:lua_tostring(L, 2) encoding:NSUTF8StringEncoding];
    
    [[LuaBridge instance] operate:opname onStack:arr];
    return 0;
}

int luafunc_pop(lua_State *L)
{
    NSMutableArray *arr = (__bridge NSMutableArray*)lua_topointer(L, 1);
    id obj = [arr lastObject];
    [arr removeLastObject];
    
    luabridge_push_object(L, obj);
    
    return 1;
}

int luafunc_clear(lua_State *L)
{
    NSMutableArray *arr = (__bridge NSMutableArray*)lua_topointer(L, 1);
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

int luafunc_extract (lua_State *L)
{
    NSMutableArray *arr = (__bridge NSMutableArray*)lua_topointer(L, 1);
    NSString *type = [NSString stringWithUTF8String:lua_tostring(L, 2)];
    NSValue *val = [arr lastObject];
    [arr removeLastObject];
    
    int retnum = 0;
        
    if ([type compare:@"CGSize"] == NSOrderedSame) {
        CGSize size = [val CGSizeValue];
        lua_pushnumber(L, size.width);
        lua_pushnumber(L, size.height);
        retnum = 2;
    } else if ([type compare:@"CGPoint"] == NSOrderedSame) {
        CGPoint p = [val CGPointValue];
        lua_pushnumber(L, p.x);
        lua_pushnumber(L, p.y);
        retnum = 2;
    } else if ([type compare:@"CGRect"] == NSOrderedSame) {
        CGRect r = [val CGRectValue];
        lua_pushnumber(L, r.origin.x);
        lua_pushnumber(L, r.origin.y);
        lua_pushnumber(L, r.size.width);
        lua_pushnumber(L, r.size.height);
        retnum = 4;
    } else if ([type compare:@"CGAffineTransform"] == NSOrderedSame) {
        CGAffineTransform t = [val CGAffineTransformValue];
        lua_pushnumber(L, t.a);
        lua_pushnumber(L, t.b);
        lua_pushnumber(L, t.c);
        lua_pushnumber(L, t.d);
        lua_pushnumber(L, t.tx);
        lua_pushnumber(L, t.ty);
        retnum = 6;
    }

    return retnum;
}
