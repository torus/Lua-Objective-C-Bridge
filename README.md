Lua-Objective-C Bridge
======================

Synopsis
--------

    local ctx = objc.context:create()
    local img = ctx:wrap(objc.class.UIImage)("imageNamed:", "spaceship.png")
    local ship = ctx:wrap(objc.class.UIImageView)("alloc")("initWithImage:", -img)

The Lua code above is equivalent to following Objective-C code:

    UIImage *img = [UIImage imageNamed:@"spaceship.png"];
    UIImageView *ship = [[UIImageView alloc] initWithImage:img];

More Example:
https://github.com/torus/ios-lua-lander/blob/master/LuaLander/LuaLander/bootstrap.lua


Objective-C API
---------------

First, import Lua and the bridge header files:

    #import "lua.h"
    #import "lualib.h"
    #import "lauxlib.h"
    #import "LuaBridge.h"

Then,

    lua_State *L = [[LuaBridge instance] L];

gets the lua_State object to call Lua functions.


High-Level Lua API
------------------

    local ctx = objc.context:create()

Creates a new context.

    local wrapped_object = ctx:wrap(...)

Returns wrapped Objective-C object. Then, you can send a message to the object like:

    wrapped_object("setOpaque:", false)

You need to unwrap the object to pass to a method using `-` (unary minus) like:

    local webview = ctx:wrap(objc.class.UIWebView)("alloc")("initWithFrame:", -rect)

Any Objective-C class object can be obtained via `objc.class` table. For example

    objc.class.UIWebView

Returns the UIWebView class object.



Extending the Bridge
--------------------

LuaBridge uses a stack to share objects between Lua and Objective-C.
And some operators are defined to handle stuff in the stack.

You can add user-defined operators to the LuaBridge class folloing this signature:

    - (void)op_your_operator:(NSMutableArray*)stack


Low-Level Lua API
-----------------

### newstack

    stack = objc.newstack()

Returns a new stack to pass and receive paramters between Lua and Objective-C.

### push

    objc.push(stack, arg, ...)

Pushes one or more arguments to the stack.

### pop

    val = objc.pop(stack)

Pops the last (top) value from the stack.

### operate

    objc.operate(stack, "operator_name")

Calls given operator with the content of the stack.

### getclass

    cls = objc.getclass(class_name)

Returns the class object for given class name.

Data Type Conversion
---------------

<table>
<tr><th>Lua</th><th>Objective-C</th></tr>
<tr><td>nil</td><td>NSNull (nil)</td></tr>
<tr><td>string</td><td>NSString</td></tr>
<tr><td>number, boolean</td><td>NSNumber</td></tr>
<tr><td>userdata</td><td>other NSObject-derived type</td></tr>
<tr><td>lightuserdata</td><td>void *</td></tr>
<tr><td>table, function, thread</td><td>LuaObjectReference</td></tr>
</table>

Pre-defined Operators
---------------------

### call

    objc.push(stack, ..., arg2, arg1, target, selector)
    objc.operate(stack, "call")
    local ret = objc.pop(stack)

"call" operator sends a method specified by selector to the target, then pushes the returned object.
Please note that the argments must be pushed in reverse order.
This is equivalent to following Objective-C expression:

    ret = [target selector arg1 arg2 ...]


Adding Operators
----------------

Create a category on the LuaBrige class and implement your operators in folloing signature:

    - (void)op_your_operator:(NSMutableArray*)stack

Then from Lua script call the operator like this:

    objc.operate(stack, "your_operator")

Note that in Objective-C, the method name should be "op_*your_operator*:".
