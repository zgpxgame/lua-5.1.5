--[[--------------------------------------------------------------------

  test_lzio.lua
  Test for lzio.lua
  This file is part of Yueliang.

  Copyright (c) 2006 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

-- manual test for lzio.lua lua-style chunk reader

dofile("../lzio.lua")

local z
function dump(z)
  while true do
    local c = luaZ:zgetc(z)
    io.stdout:write("("..c..")")
    if c == "EOZ" then break end
  end
  io.stdout:write("\n")
end

-- luaZ:make_getS or luaZ:make_getF creates a chunk reader
-- luaZ:init makes a zio stream

-- [[
z = luaZ:init(luaZ:make_getS("hello, world!"), nil, "=string")
dump(z)
z = luaZ:init(luaZ:make_getS(", world!"), "hello", "=string")
dump(z)
z = luaZ:init(luaZ:make_getS("line1\nline2\n"), "", "=string")
dump(z)
z = luaZ:init(luaZ:make_getF("test_lzio.lua"), nil, "=string")
dump(z)
--]]
