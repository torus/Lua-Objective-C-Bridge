//
//  LuaObjCBridgeTests.m
//  LuaObjCBridgeTests
//
//  Created by Hisai Toru on 2017/05/28.
//  Copyright © 2017年 Kronecker's Delta Studio. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <objc/runtime.h>

#import "lua.h"
#import "lualib.h"
#import "lauxlib.h"
#import "LuaBridge.h"

@interface LuaObjCBridgeTests : XCTestCase

@property lua_State *L;

@end

@implementation LuaObjCBridgeTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.

    self.L = [[LuaBridge instance] L];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testLExists {
    XCTAssert(self.L);
}

int varargtest_int(int n, ...) {
    int dest = 0;
    
    va_list vl;
    va_start(vl, n);
    for (int i = 0; i < n; i ++) {
        int v = va_arg(vl, int);
        dest += v;
    }
    va_end(vl);
    return dest;
}

- (void)testVarargsInt {
    int ret = varargtest_int(3, 10, 100, 1000);
    XCTAssertEqual(ret, 1110);
}

int vaargtest_ptr(int n, ...) {
    va_list vl;
    va_start(vl, n);
    
    void *ptr = va_arg(vl, void*);
    void *ptr2 = va_arg(vl, void*);
    
    va_end(vl);
    
    int dest = ((char*) ptr2) - ((char*) ptr);
    return dest;
}

- (void)testVarargsPointer {
    const char *str = "konnichiwa";
    int ret = vaargtest_ptr(1, (void*)str, (void*)(str + 5));
    XCTAssertEqual(ret, 5);
}

#ifdef __LP64__
id varargtest_id(id self, SEL _cmd, void *arg1, void *arg2) {
    int n = (int)arg1;
    NSLog(@"n: %x", n);

    void *ptr = arg2;
    id x = (__bridge id)ptr;
    NSLog(@"str: %p, %@", ptr, x);
    
    return x;
}
#else
id varargtest_id(id self, SEL _cmd, ...) {
    va_list vl;
    va_start(vl, _cmd);
    
    const unsigned char *p = (const unsigned char*)vl;
    for (int i = -32; i < 32; i += 8) {
        NSLog(@"%03d: %02x%02x%02x%02x%02x%02x%02x%02x", i, p[i], p[i + 1], p[i + 2], p[i + 3], p[i + 4], p[i + 5], p[i + 6], p[i + 7]);
    }

    int n = va_arg(vl, int);
    NSLog(@"n: %x", n);
    void *ptr = va_arg(vl, void*);
    id x = (__bridge id)ptr;
    NSLog(@"str: %p, %@", ptr, x);
    
    return x;
}
#endif

- (void)testVargargsId {
    NSString *str = @"ahoaho";
    id ret = varargtest_id(str, @selector(testVargargsId), (void*)0xdeadbeef, (__bridge void*)str);
    NSLog(@"%@", ret);
}

- (void)execLuaCode: (const char*)code {
    int fail = luaL_dostring(self.L, code);
    XCTAssertFalse(fail);

    if (fail) {
        const char *err = lua_tostring(self.L, -1);
        NSLog(@"error: %d, %s", fail, err);
    }
}

- (void)testInvocation {
    NSString *str = @"hoge";
    SEL sel = @selector(stringByAppendingString:);
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature: [str methodSignatureForSelector:sel]];
    
    NSString *str2 = @"fuga";
    inv.target = str;
    inv.selector = sel;
    
    [inv setArgument:&str2 atIndex:2];
    [inv invoke];

    NSUInteger len = [[inv methodSignature] methodReturnLength];
    void *buffer = malloc(len);
    [inv getReturnValue:buffer];

    void *ptr = *(void**)buffer;
    NSString *result = (__bridge NSString*)ptr;

    XCTAssert([result isEqualToString:@"hogefuga"]);
}

- (void)testMethodCall {
    Class cls = objc_getClass("LuaObjCTest");
    SEL sel = @selector(varargtest:obj:);
    class_addMethod(cls, sel, (IMP)varargtest_id, "@@:i@");
    
    id target = [[cls alloc] init];
    
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature: [target methodSignatureForSelector:sel]];
    
    inv.target = target;
    inv.selector = sel;

    int arg1 = 0xc001cafe;
    [inv setArgument:&arg1 atIndex:2];
    
    NSString *arg2 = @"arg2 string";
    [inv setArgument:&arg2 atIndex:3];
    
    [inv invoke];
    
    NSUInteger len = [[inv methodSignature] methodReturnLength];
    void *buffer = malloc(len);
    [inv getReturnValue:buffer];
    
    void *ptr = *(void**)buffer;
    NSString *result = (__bridge NSString*)ptr;
    
    XCTAssert([result isEqualToString:@"arg2 string"]);
}

- (void)testNumber {
    const char *code = "return 0.125";
    [self execLuaCode:code];

    lua_Number result = lua_tonumber(self.L, -1);
    XCTAssertEqual(result, 0.125);
}

- (void)testVersion {
    const char *code = "return _VERSION";
    [self execLuaCode:code];

    const char *result = lua_tostring(self.L, -1);
    XCTAssert(!strcmp(result, "Lua 5.3"));
}

- (void)testInteger {
    const char *code = "return objc.context:create():wrap(objc.class.LuaObjCTest)"
    "('alloc')('init')('sum:withAnotherValue:', 1, 2)";
    [self execLuaCode:code];

    lua_Integer result = lua_tointeger(self.L, -1);
    XCTAssertEqual(result, 3);
}

- (void)testDouble {
    const char *code = "return objc.context:create():wrap(objc.class.LuaObjCTest)"
    "('alloc')('init')('sumDouble:withAnotherValue:', 1.0, 2.0)";
    [self execLuaCode:code];

    lua_Number result = lua_tonumber(self.L, -1);
    XCTAssertEqual(result, 3.0);
}

- (void)testString {
    const char *code = "assert (objc.context:create():wrap(objc.class.LuaObjCTest)"
    "('alloc')('init')('hello:', 'Lua') == 'Hello Lua!')";
    [self execLuaCode:code];
}

- (void)testClassDefinition {
    const char *code =
    ("local st = objc.newstack();"
     "objc.push(st, 'MyLuaClass');"
     "objc.push(st, objc.class.NSObject);"
     "objc.operate(st, 'addClass')");
    [self execLuaCode:code];
    
    id cls = objc_getClass("MyLuaClass");
    XCTAssertNotNil(cls);
}

id methodImp(id self, SEL _cmd) {
    const char *name = sel_getName(_cmd);
    NSLog(@"called: %@, %s", self, name);
    return @"aho";
}

- (void)testAddMethod {
    Class cls = objc_getClass("LuaObjCTest");
    SEL sel = sel_getUid("testMethod");
    BOOL result = class_addMethod(cls, sel, (IMP)methodImp, "@@:");
    XCTAssert(result);
    
    id obj = [[cls alloc] init];
    id res = [obj performSelector:sel];
    XCTAssertEqual(res, @"aho");
}

- (void)testAddProtocol {
    const char *code =
    ("local ctx = objc.context:create();"
     "local st = ctx.stack;"
     "local result = nil;"
     "objc.push(st, objc.class.LuaObjCTest);"
     "objc.push(st, objc.getprotocol('UITableViewDelegate'));"
     "objc.operate(st, 'addProtocol');");

     [self execLuaCode:code];

    Class cls = objc_getClass("LuaObjCTest");
    XCTAssertTrue(class_conformsToProtocol(cls, objc_getProtocol("UITableViewDelegate")));
}

- (void)testMethodDefinition {
    const char *code =
    ("local ctx = objc.context:create();"
     "local st = ctx.stack;"
     "local result = nil;"
     "objc.push(st, objc.class.LuaObjCTest);"
     "objc.push(st, 'newMethod:withArg:');"
     "objc.push(st, '@@:l@');"
     "objc.push(st, function(self, cmd, num, str) print('called', self, cmd, str, num); result = str .. num; return 'ok'; end);"
     "objc.operate(st, 'addMethod');");

    [self execLuaCode:code];

    Class cls = objc_getClass("LuaObjCTest");
    SEL sel = sel_getUid("newMethod:withArg:");
    XCTAssert(sel);

    id target = [[cls alloc] init];
    NSLog(@"target: %@, selector: %p", target, sel);
    
    NSMethodSignature *sig = [target methodSignatureForSelector:sel];
    XCTAssert(sig);

    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.selector = sel;
    inv.target = target;

    long numarg = 0x0ff1ce;
    [inv setArgument:&numarg atIndex:2];

    NSString *str = @"ahoaho";
    NSLog(@"str: %p", str);
    [inv setArgument:&str atIndex:3];

    long *outp = malloc(sizeof(long));
    [inv getArgument:outp atIndex:2];
    void **outstr = malloc(sizeof(void*));
    [inv getArgument:outstr atIndex:3];
    NSLog(@"arg2: %ld, arg3: %p", *outp, *outstr);
    [inv invoke];

    NSUInteger len = [[inv methodSignature] methodReturnLength];
    void *buffer = malloc(len);
    [inv getReturnValue:buffer];

    id ret = *(const id*)buffer;

    XCTAssert([ret isEqualToString:@"ok"]);
}

- (void)testMethodReturningInt {
    const char *code =
    ("local ctx = objc.context:create();"
     "local st = ctx.stack;"
     "objc.push(st, objc.class.LuaObjCTest);"
     "objc.push(st, 'methodInt');"
     "objc.push(st, 'i@:');"
     "objc.push(st, function(self, cmd) return 9876 end);"
     "objc.operate(st, 'addMethod');");
    
    [self execLuaCode:code];

    Class cls = objc_getClass("LuaObjCTest");
    SEL sel = sel_getUid("methodInt");
    
    id obj = [[cls alloc] init];
    int res = [obj performSelector:sel];
    XCTAssertEqual(res, 9876);
}

- (void)testMethodReturningFloat {
    const char *code =
    ("local ctx = objc.context:create();"
     "local st = ctx.stack;"
     "objc.push(st, objc.class.LuaObjCTest);"
     "objc.push(st, 'methodFloat');"
     "objc.push(st, 'f@:');"
     "objc.push(st, function(self, cmd) return -9.876 end);"
     "objc.operate(st, 'addMethod');");
    
    [self execLuaCode:code];
    
    Class cls = objc_getClass("LuaObjCTest");
    SEL sel = sel_getUid("methodFloat");
    id target = [[cls alloc] init];
    
    NSMethodSignature *sig = [target methodSignatureForSelector:sel];
    XCTAssert(sig);
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setSelector:sel];
    [inv setTarget:target];
    [inv invoke];
    
    NSUInteger len = [[inv methodSignature] methodReturnLength];
    void *buffer = malloc(len);
    [inv getReturnValue:buffer];
    
    float ret = *(float*)buffer;
    
    XCTAssertEqualWithAccuracy(ret, -9.876, 0.001);
}

long methodImpReturningLong(id self, SEL _cmd) {
    const char *name = sel_getName(_cmd);
    NSLog(@"called: %@, %s", self, name);
    return 1234567890;
}

- (void)testAddMethodReturningLong {
    Class cls = objc_getClass("LuaObjCTest");
    SEL sel = sel_getUid("testMethodReturningLong");
    BOOL result = class_addMethod(cls, sel, (IMP)methodImpReturningLong, "l@:");
    XCTAssert(result);
    
    id obj = [[cls alloc] init];
    long res = [obj performSelector:sel];
    XCTAssertEqual(res, 1234567890);
}

- (void)testPerformSelector {
    const char *code =
    ("local ctx = objc.context:create();"
     "local sel = objc.getselector('hello:');"
     "ctx:wrap(objc.class.LuaObjCTest)('new')('performSelectorOnMainThread:withObject:waitUntilDone:', sel, 'selector', 1)"
     );
    
    [self execLuaCode:code];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
