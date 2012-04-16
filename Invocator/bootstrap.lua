hoge()
local stack = newstack()
local cls = getclass "NSNumber"
push(stack, 12345)
push(stack, cls)
push(stack, "numberWithInt:")
operate(stack, "call")
