Lua-Objective-C Bridge
======================

Objective-C API
---------------

    lua_State *L = [[LuaBridge instance] L];

Gets lua_State object.

    - (void)op_your_operator:(NSMutableArray*)stack

Define your operator.


Lua API
-------

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
