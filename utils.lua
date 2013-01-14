--
-- Objective-C Classes
--

local Class = {}
setmetatable(Class, {__index = function(tbl, key)
                                  local cls = objc.getclass(key)
                                  tbl[key] = cls
                                  return cls
                               end})
objc.class = Class

--
-- Context
--

local Context = {}

function Context:create ()
   local s = {stack = objc.newstack()}
   setmetatable(s, {__index = self})
   return s
end

function Context:sendMesg (target, selector, ...)
   local stack = self.stack
   local n = select("#", ...)
   for i = 1, n do
      local arg = select(-i, ...)
      objc.push(stack, arg)
   end
   objc.push(stack, target, selector)
   objc.operate(stack, "call")
   return objc.pop(stack)
end

function Context:wrap(obj)
   local o = {}
   setmetatable(o, {__call = function (func, ...)
                                -- print("obj called!", func, obj)
                                local ret = self:sendMesg(obj, ...)
                                if type(ret) == "userdata" then
                                   return self:wrap(ret)
                                else
                                   return ret
                                end
                             end,
                    __unm = function (op)
                               return obj
                            end})
   return o
end

objc.context = Context
