objc.hoge()
local stack = objc.newstack()
local cls = objc.getclass "NSNumber"
objc.push(stack, 12345)
objc.push(stack, cls)
objc.push(stack, "numberWithInt:")
objc.operate(stack, "call")

local res = objc.pop(stack)
print("res =", res)



-- // create and initialize a Label
-- CCLabelTTF *label = [CCLabelTTF labelWithString:@"Hello World" fontName:@"Marker Felt" fontSize:64];

-- // ask director the the window size
-- CGSize size = [[CCDirector sharedDirector] winSize];

-- // position the label on the center of the screen
-- label.position =  ccp( size.width /2 , size.height/2 );

-- // add the label as a child to this Layer
-- [self addChild: label];

local CCLabelTTF = objc.getclass "CCLabelTTF"
-- push arguments by reverse order
objc.push(stack, 64, "Marker Felt", "Hello Lua")
objc.push(stack, CCLabelTTF)
objc.push(stack, "labelWithString:fontName:fontSize:")
objc.operate(stack, "call")
local label = objc.pop(stack)
objc.push(stack, 100, 100)
objc.push(label)
objc.operate(stack, "sprite_setpos")
