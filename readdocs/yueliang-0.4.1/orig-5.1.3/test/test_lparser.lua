--[[--------------------------------------------------------------------

  test_lparser.lua
  Test for lparser.lua
  This file is part of Yueliang.

  Copyright (c) 2005-2006 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

------------------------------------------------------------------------
-- test the whole kaboodle
------------------------------------------------------------------------

dofile("../lzio.lua")
dofile("../llex.lua")
dofile("../lopcodes.lua")
dofile("../ldump.lua")
dofile("../lcode.lua")
dofile("../lparser.lua")

function lua_assert(test)
  if not test then error("assertion failed!") end
end

luaX:init()

------------------------------------------------------------------------
-- try 1
------------------------------------------------------------------------
local zio = luaZ:init(luaZ:make_getS("local a = 1"), nil)
local LuaState = {}
local Func = luaY:parser(LuaState, zio, nil, "=string")

--[[
for i, v in Func do
  if type(v) == "string" or type(v) == "number" then
    print(i, v)
  elseif type(v) == "table" then
    print(i, "TABLE")
  end
end
--]]

local Writer, Buff = luaU:make_setF("parse1.out")
luaU:dump(LuaState, Func, Writer, Buff)

------------------------------------------------------------------------
-- try 2
------------------------------------------------------------------------

zio = luaZ:init(luaZ:make_getF("sample.lua"), nil)
Func = luaY:parser(LuaState, zio, nil, "@sample.lua")
Writer, Buff = luaU:make_setF("parse2.out")
luaU:dump(LuaState, Func, Writer, Buff)
