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

Pre-defined Operators
---------------------

### call

    objc.push(stack, target, selector, arg, ...)
    objc.operate(stack, "call")
    local ret = objc.pop(stack)

"call" operator sends a method specified by selector to the target, then pushes the returned object.
This is equivalent to following Objective-C expression:

    ret = [target selector arg ...]


Adding Operators
----------------

Create a category on the LuaBrige class and implement your operators in folloing signature:

    - (void)op_your_operator:(NSMutableArray*)stack

Then from Lua script call the operator like this:

    objc.operate(stack, "your_operator")

Note that in Objective-C, the method name should be "op_*your_operator*:".
