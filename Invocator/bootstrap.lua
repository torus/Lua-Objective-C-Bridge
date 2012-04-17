objc.hoge()
local stack = objc.newstack()
local cls = objc.getclass "NSNumber"
objc.push(stack, 12345)
objc.push(stack, cls)
objc.push(stack, "numberWithInt:")
objc.operate(stack, "call")

local res = objc.pop(stack)
print("res =", res)
