//
//  LuaState.m
//  Lua-Objective-C Bridge
//
//  Created by Toru Hisai on 12/04/13.
//  Copyright (c) 2012年 Kronecker's Delta Studio. All rights reserved.
//

#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX
#endif

#import <objc/runtime.h>

#import "LuaBridge.h"

#import "lualib.h"
#import "lauxlib.h"

#import "LuaBridgeInternal.h"

static int gc_metatable_ref;
static id luavalue_to_object(lua_State *L, int index);

#define HANDLENUMBERTYPES(F, index)            \
F('c', char, numberWithChar, charValue, index); \
F('i', int, numberWithInt, intValue, index); \
F('s', short, numberWithShort, shortValue, index); \
F('l', long, numberWithLong, longValue, index); \
F('q', long long, numberWithLongLong, longLongValue, index); \
F('C', unsigned char, numberWithUnsignedChar, unsignedCharValue, index); \
F('I', unsigned int, numberWithUnsignedInt, unsignedIntValue, index); \
F('S', unsigned short, numberWithUnsignedShort, unsignedShortValue, index); \
F('L', unsigned long, numberWithUnsignedLong, unsignedLongValue, index); \
F('Q', unsigned long long, numberWithUnsignedLongLong, unsignedLongLongValue, index); \
F('f', float, numberWithFloat, floatValue, index); \
F('d', double, numberWithDouble, doubleValue, index); \
F('B', _Bool, numberWithBool, boolValue, index)

int finalize_object(lua_State *L)
{
    void *p = lua_touserdata(L, 1);
    void **ptr = (void**)p;
    CFBridgingRelease(*ptr);

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
        
        ADDMETHOD(newstack);
        ADDMETHOD(push);
        ADDMETHOD(pop);
        ADDMETHOD(clear);
        ADDMETHOD(operate);
        ADDMETHOD(getclass);
        ADDMETHOD(getprotocol);
        ADDMETHOD(getselector);
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
        stat = [[LuaBridge alloc] init];
        
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

#define OPCALLNUMBERTYPE(ch, type, nummethod, valmethod, _) \
case ch: \
        { \
            type x = [(NSNumber*)arg valmethod]; \
            [inv setArgument:&x atIndex:i]; \
        } \
        break

        switch (t[0]) {
          HANDLENUMBERTYPES(OPCALLNUMBERTYPE, 0);

            case '*': // A character string (char *)
            {
                const char *x = [(NSString*)arg cStringUsingEncoding:NSUTF8StringEncoding];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case '@': // An object (whether statically typed or typed id)
            {
                if ([arg isKindOfClass:[NSNull class]]) {
                    id n = nil;
                    [inv setArgument:&n atIndex:i];
                } else {
                    [inv setArgument:&arg atIndex:i];
                }
            }
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
#if TARGET_OS_IOS
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
#elif TARGET_OS_OSX
                if ([t_str hasPrefix:@"{CGRect"]) {
                    CGRect rect = [(NSValue*)arg rectValue];
                    [inv setArgument:&rect atIndex:i];
                } else if ([t_str hasPrefix:@"{CGSize"]) {
                    CGSize size = [(NSValue*)arg sizeValue];
                    [inv setArgument:&size atIndex:i];
                } else if ([t_str hasPrefix:@"{CGPoint"]) {
                    CGPoint point = [(NSValue*)arg pointValue];
                    [inv setArgument:&point atIndex:i];
                }
#endif
            }
                break;

            case 'v': // A void
            case '#': // A class object (Class)
                break;
            case ':': // A method selector (SEL)
            {
                SEL sel = (SEL)[(NSValue*)arg pointerValue];
                [inv setArgument:&sel atIndex:i];
                break;
            }
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
#define PUSHNUMBERTYPE(ch, type, nummethod, valmethod, index) \
case ch: \
    { \
        CNVBUF(type); \
        [stack addObject:[NSNumber nummethod:x]]; \
    } \
    break
    
    switch (types[0]) {
      HANDLENUMBERTYPES(PUSHNUMBERTYPE, 0);
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
#if TARGET_OS_IOS
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
#elif TARGET_OS_OSX
            if ([t hasPrefix:@"{CGRect"]) {
                CGRect *rect = (CGRect*)buffer;
                [stack addObject:[NSValue valueWithRect:*rect]];
            } else if ([t hasPrefix:@"{CGSize"]) {
                CGSize *size = (CGSize*)buffer;
                [stack addObject:[NSValue valueWithSize:*size]];
            } else if ([t hasPrefix:@"{CGPoint"]) {
                CGPoint *size = (CGPoint*)buffer;
                [stack addObject:[NSValue valueWithPoint:*size]];
            }
#endif
        }
            break;
            
        case '#': // A class object (Class)
        case ':': // A method selector (SEL)
        default:
            NSLog(@"%s: Not implemented", types);
            [stack addObject:[NSNull null]];
            break;
    }
}

- (NSNumber *)popNumber:(NSMutableArray*)stack
{
    NSNumber *num = [stack lastObject];
    [stack removeLastObject];
    
    return num;
}

#if TARGET_OS_IOS
- (void)op_cgrectmake:(NSMutableArray*)stack
{
    double x = [[self popNumber:stack] doubleValue];
    double y = [[self popNumber:stack] doubleValue];
    double w = [[self popNumber:stack] doubleValue];
    double h = [[self popNumber:stack] doubleValue];
    
    CGRect rect = CGRectMake(x, y, w, h);
    [stack addObject:[NSValue valueWithCGRect:rect]];
}
#endif

- (void)op_addClass:(NSMutableArray*)stack
{
    Class superClass = [stack lastObject];
    [stack removeLastObject];
    NSString *name = [stack lastObject];
    [stack removeLastObject];
    Class cls = objc_allocateClassPair(superClass, [name UTF8String], 0);
    objc_registerClassPair(cls);

    [stack addObject:cls];
}

- (void)op_addLuaBridgedClass:(NSMutableArray*)stack
{
    NSString *name = [stack lastObject];
    [stack removeLastObject];
    Class cls = objc_allocateClassPair([LuaBridgedClass class], [name UTF8String], 0);
    objc_registerClassPair(cls);
    
    [stack addObject:cls];
}

#define IMPARGNUMBERTYPE(ch, type, nummethod, valmethod, i)   \
case ch: \
    { \
        void *z = arg ## i; \
        /*NSLog(@"IMPARGNUMBERTYPE: %d, %p", i, z);*/ \
        type x = *((type*)(&z)); \
        luabridge_push_object(L, [NSNumber nummethod:x]); \
    } \
    break

#define HANDLE_METHOD_ARGUMENT(i)                                       \
do {                                                                    \
        const char *t = [sig getArgumentTypeAtIndex:i + 1];                 \
        /*NSLog(@"arg %d: %s", i, t); */                                    \
        switch (t[0]) {                                                 \
          HANDLENUMBERTYPES(IMPARGNUMBERTYPE, i);                         \
                                                                        \
        case '*': /* A character string (char *) */                     \
            {                                                           \
                const char *x = (const char *) arg ## i;                \
                luabridge_push_object(L, [NSString stringWithUTF8String:x]); \
            }                                                           \
                break;                                                  \
                                                                        \
        case '@': /* An object (whether statically typed or typed id) */ \
            {                                                           \
                id x = (__bridge id) arg ## i;                          \
                luabridge_push_object(L, x);                            \
            }                                                           \
                break;                                                  \
                                                                        \
        case '^': /* pointer */                                         \
            {                                                           \
                void *x = arg ## i;                                     \
                NSValue *val = [NSValue valueWithPointer:x];            \
                luabridge_push_object(L, val);                          \
            }                                                           \
                break;                                                  \
                                                                        \
        case '{': /* {name=type...} A structure */                      \
        case 'v': /* A void */                                          \
        case '#': /* A class object (Class) */                          \
        case ':': /* A method selector (SEL) */                         \
            default:                                                    \
                NSLog(@"%s: Not implemented", t);                       \
                break;                                                  \
        }                                                               \
} while (0)

#define IMPDEFINITION_FIRSTHALF()                                       \
    /*NSLog(@"_cmd = %s", sel_getName(_cmd)); */                        \
                                                                        \
    NSMethodSignature *sig = [self methodSignatureForSelector:_cmd];    \
    int num = (int)[sig numberOfArguments];                             \
                                                                        \
    lua_State *L = [[LuaBridge instance] L];                            \
                                                                        \
    LuaBridge *brdg = [LuaBridge instance];                             \
    Class cls = [self class];                                           \
    LuaObjectReference *func = [brdg.methodTable valueForKey:[NSString stringWithFormat:@"%s.%s", class_getName(cls), sel_getName(_cmd)]]; \
                                                                        \
    luabridge_push_object(L, func);                                     \
                                                                        \
    luabridge_push_object(L, self);                                     \
    lua_pushstring(L, sel_getName(_cmd));                               \
                                                                        \
    if (num > 2) {HANDLE_METHOD_ARGUMENT(1);}                           \
    if (num > 3) {HANDLE_METHOD_ARGUMENT(2);}                                          \
    if (num > 4) {HANDLE_METHOD_ARGUMENT(3);}                                          \
    if (num > 5) {HANDLE_METHOD_ARGUMENT(4);}

id luaFuncIMP_id(id self, SEL _cmd, void *arg1, void *arg2, void *arg3, void *arg4)
{
  IMPDEFINITION_FIRSTHALF()
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

#define DEFINE_LUAFUNCIMP(rettype, disptype, luafunc)                   \
rettype luaFuncIMP_ ## disptype(id self, SEL _cmd, void *arg1, void *arg2, void *arg3, void *arg4) \
{                                                                       \
  IMPDEFINITION_FIRSTHALF()                                            \
                                                                        \
    rettype ret = (rettype)0;                                           \
    int err = lua_pcall(L, num, 1, 0);                                  \
    if (err) {                                                          \
        const char *mesg = lua_tostring(L, -1);                         \
        NSLog(@"Lua Error (%d): %s", err, mesg);                        \
    } else {                                                            \
        ret = (rettype)luafunc(L, -1);                                  \
    }                                                                   \
                                                                        \
    return ret;                                                         \
}

DEFINE_LUAFUNCIMP(char, char, lua_tointeger)
DEFINE_LUAFUNCIMP(int, int, lua_tointeger)
DEFINE_LUAFUNCIMP(short, short, lua_tointeger)
DEFINE_LUAFUNCIMP(long, long, lua_tointeger)
DEFINE_LUAFUNCIMP(long long, longLong, lua_tointeger)
DEFINE_LUAFUNCIMP(unsigned char, unsignedChar, lua_tointeger)
DEFINE_LUAFUNCIMP(unsigned int, unsignedInt, lua_tointeger)
DEFINE_LUAFUNCIMP(unsigned short, unsignedShort, lua_tointeger)
DEFINE_LUAFUNCIMP(unsigned long, unsignedLong, lua_tointeger)
DEFINE_LUAFUNCIMP(unsigned long long, unsignedLongLong, lua_tointeger)
DEFINE_LUAFUNCIMP(float, float, lua_tonumber)
DEFINE_LUAFUNCIMP(double, double, lua_tonumber)
DEFINE_LUAFUNCIMP(_Bool, Bool, lua_tointeger)
DEFINE_LUAFUNCIMP(const char *, cstr, lua_tostring)

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
    const char *sigstr = [sig UTF8String];

    IMP imp;
    switch (sigstr[0]) {
        case 'c': imp = (IMP)luaFuncIMP_char; break;
        case 'i': imp = (IMP)luaFuncIMP_int; break;
        case 's': imp = (IMP)luaFuncIMP_short; break;
        case 'l': imp = (IMP)luaFuncIMP_long; break;
        case 'q': imp = (IMP)luaFuncIMP_longLong; break;
        case 'C': imp = (IMP)luaFuncIMP_unsignedChar; break;
        case 'I': imp = (IMP)luaFuncIMP_unsignedInt; break;
        case 'S': imp = (IMP)luaFuncIMP_unsignedShort; break;
        case 'L': imp = (IMP)luaFuncIMP_unsignedLong; break;
        case 'Q': imp = (IMP)luaFuncIMP_unsignedLongLong; break;
        case 'f': imp = (IMP)luaFuncIMP_float; break;
        case 'd': imp = (IMP)luaFuncIMP_double; break;
        case 'B': imp = (IMP)luaFuncIMP_Bool; break;
        case 'v': imp = (IMP)luaFuncIMP_int; break; // return value ignored
        case '*': imp = (IMP)luaFuncIMP_cstr; break;
        case '@': imp = (IMP)luaFuncIMP_id; break;
        default:
            imp = (IMP)luaFuncIMP_int;
            break;
    }

    class_addMethod(cls, sel_registerName([name UTF8String]), (IMP)imp, sigstr);
}

- (void)op_addProtocol:(NSMutableArray*)stack
{
    Protocol *proto = [stack lastObject];
    [stack removeLastObject];
    Class cls = [stack lastObject];
    [stack removeLastObject];
    
    class_addProtocol(cls, proto);
}

- (void)op_setLuaTable:(NSMutableArray*)stack
{
    LuaObjectReference *luaobj = [stack lastObject];
    [stack removeLastObject];

    LuaBridgedClass *obj = [stack lastObject];
    [stack removeLastObject];

    [obj setLuaObj:luaobj];
}

- (void)op_getLuaTable:(NSMutableArray*)stack
{
    LuaBridgedClass *obj = [stack lastObject];
    [stack removeLastObject];

    id luaobj = [obj luaObj];
    [[self class] pushValue:&luaobj withTypes:"@" toStack:stack];
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

@implementation LuaBridgedClass
@synthesize luaObj;
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

int luafunc_getprotocol(lua_State *L)
{
    const char *classname = lua_tostring(L, -1);
    id cls = objc_getProtocol(classname);
    lua_pushlightuserdata(L, (__bridge void *)(cls));
    return 1;
}

int luafunc_getselector(lua_State *L)
{
    const char *selname = lua_tostring(L, -1);
    SEL sel = sel_registerName(selname);
    NSValue *selval = [NSValue valueWithPointer:sel];
    lua_pushlightuserdata(L, (__bridge void *)(selval));
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

int luafunc_extract (lua_State *L)
{
    NSMutableArray *arr = (__bridge NSMutableArray*)lua_topointer(L, 1);
    NSString *type = [NSString stringWithUTF8String:lua_tostring(L, 2)];
    NSValue *val = [arr lastObject];
    [arr removeLastObject];
    
    int retnum = 0;

#if TARGET_OS_IOS
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
#elif TARGET_OS_OSX
    if ([type compare:@"CGSize"] == NSOrderedSame) {
        CGSize size = [val sizeValue];
        lua_pushnumber(L, size.width);
        lua_pushnumber(L, size.height);
        retnum = 2;
    } else if ([type compare:@"CGPoint"] == NSOrderedSame) {
        CGPoint p = [val pointValue];
        lua_pushnumber(L, p.x);
        lua_pushnumber(L, p.y);
        retnum = 2;
    } else if ([type compare:@"CGRect"] == NSOrderedSame) {
        CGRect r = [val rectValue];
        lua_pushnumber(L, r.origin.x);
        lua_pushnumber(L, r.origin.y);
        lua_pushnumber(L, r.size.width);
        lua_pushnumber(L, r.size.height);
        retnum = 4;
    }
#endif
    return retnum;
}
