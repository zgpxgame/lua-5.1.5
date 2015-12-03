--[[--------------------------------------------------------------------

  test_lzio.lua
  Test for lzio.lua
  This file is part of Yueliang.

  Copyright (c) 2005-2006 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

-- manual test for lzio.lua lua-style chunk reader

local zio_init = require("../lzio_mk2")

local z
function dump(z)
  while true do
    local c = z:getc()
    io.stdout:write("("..c..")")
    if c == "EOZ" then break end
  end
  io.stdout:write("\n")
end

-- z = zio_init("@<filename>") for a file
-- z = zio_init("<string>") for a string

-- [[
z = zio_init("hello, world!")
dump(z)
z = zio_init("line1\nline2\n")
dump(z)
z = zio_init("@test_lzio_mk2.lua")
dump(z)
--]]

-- test read beyond end of file
-- bug reported by Adam429
--[[
z = zio_init("@test_lzio_mk2.lua")
while true do
  local c = z:getc()
  io.stdout:write("("..c..")")
  if c == "EOZ" then break end
end
print(z:getc())
print(z:getc())
io.stdout:write("\n")
--]]
