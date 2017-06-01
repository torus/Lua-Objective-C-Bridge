//
//  LuaObjCBridgeTests.m
//  LuaObjCBridgeTests
//
//  Created by Hisai Toru on 2017/05/28.
//  Copyright © 2017年 Kronecker's Delta Studio. All rights reserved.
//

#import <XCTest/XCTest.h>

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

- (void)testFunctionCall {
    const char *code = "return objc.context:create():wrap(objc.class.LuaObjCTest)('alloc')('init')('sum:withAnotherValue:', 1, 2)";
    int fail = luaL_dostring(self.L, code);
    XCTAssertFalse(fail);
    
    if (fail) {
        const char *err = lua_tostring(self.L, -1);
        NSLog(@"error: %d, %s", fail, err);
    }

    lua_Integer result = lua_tointeger(self.L, -1);
    XCTAssertEqual(result, 3);
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
