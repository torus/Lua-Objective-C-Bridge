//
//  LuaBridgeInternal.h
//  Img2Ch
//
//  Created by Toru Hisai on 12/08/20.
//  Copyright (c) 2012年 Kronecker's Delta Studio. All rights reserved.
//

#ifndef Img2Ch_LuaBridgeInternal_h
#define Img2Ch_LuaBridgeInternal_h

int luafunc_hoge (lua_State *L);

int luafunc_newstack(lua_State *L);
int luafunc_push(lua_State *L);
int luafunc_pop(lua_State *L);
int luafunc_clear(lua_State *L);
int luafunc_operate(lua_State *L);
int luafunc_getclass(lua_State *L);
int luafunc_extract(lua_State *L);


#endif
