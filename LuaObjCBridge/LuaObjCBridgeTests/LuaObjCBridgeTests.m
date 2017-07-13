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

- (void)execLuaCode: (const char*)code {
    int fail = luaL_dostring(self.L, code);
    XCTAssertFalse(fail);

    if (fail) {
        const char *err = lua_tostring(self.L, -1);
        NSLog(@"error: %d, %s", fail, err);
    }
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

- (void)testMethodDefinition {
    const char *code =
    ("local ctx = objc.context:create();"
     "local st = ctx.stack;"
     "local result = nil;"
     "objc.push(st, objc.class.LuaObjCTest);"
     "objc.push(st, 'newMethod:withArg:');"
     "objc.push(st, '@@:@i');"
     "objc.push(st, function(self, cmd, str, num) result = str .. num; print('called', self, cmd, str, num); return 'ok'; end);"
     "objc.operate(st, 'addMethod');"

/*    "local ret = ctx:wrap(objc.class.LuaObjCTest)('alloc')('init')('newMethod:withArg:', 'aho', 123);"
    "print('result', result, ret);"*/);

    [self execLuaCode:code];

    Class cls = objc_getClass("LuaObjCTest");
    SEL sel = sel_getUid("newMethod:withArg:");
    XCTAssert(sel);

    id target = [[cls alloc] init];
    NSLog(@"target: %@, selector: %p", target, sel);
    
    NSMethodSignature *sig = [target methodSignatureForSelector:sel];
    XCTAssert(sig);
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setSelector:sel];
    [inv setTarget:target];
    [inv setArgument:&target atIndex:0];
    [inv setArgument:&sel atIndex:1];
    NSString *str = @"ahoaho";
    [inv setArgument:&str atIndex:2];
    int numarg = 1234;
    [inv setArgument:&numarg atIndex:3];
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
