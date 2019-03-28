
local f,t = function() return function() end end, {
  nil,
  [false]  = 'Lua 5.1',
  [true]   = 'Lua 5.2',
  [1/'-0'] = 'Lua 5.3',
  [1]      = 'LuaJIT'
}

local version = t[1] or t[1/0] or t[f()==f()]
print(version)

--[[
t[1] 判断了jit
t[1/0]判断了5.3
t[f()==f()]判断了5.2还是5.1

5.2开始支持没有upvalue闭包的函数会优化成不重复生成
luaJIT对表达式初始化也有优化 所以第一个判断才能有效
--]]
