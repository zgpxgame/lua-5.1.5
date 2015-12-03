--[[--------------------------------------------------------------------

  bench_llex.lua
  Benchmark test for llex.lua
  This file is part of Yueliang.

  Copyright (c) 2006 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

dofile("../lzio.lua")
dofile("../llex.lua")
luaX:init()

------------------------------------------------------------------------
-- load in a standard set of sample files
-- * file set is 5.0.3 front end set sans luac.lua
------------------------------------------------------------------------

local fileset, totalsize = {}, 0
for fn in string.gmatch([[
../../orig-5.0.3/lcode.lua
../../orig-5.0.3/ldump.lua
../../orig-5.0.3/llex.lua
../../orig-5.0.3/lopcodes.lua
../../orig-5.0.3/lparser.lua
../../orig-5.0.3/lzio.lua
]], "%S+") do
  fileset[#fileset+1] = fn
end

for i = 1, #fileset do
  local fn = fileset[i]
  local inf = io.open(fn, "rb")
  if not inf then
    error("failed to open "..fn.." for reading")
  end
  local data = inf:read("*a")
  local data_sz = #data
  inf:close()
  if not data or data_sz == 0 then
    error("failed to read data from "..fn.." or file is zero-length")
  end
  totalsize = totalsize + data_sz
  fileset[i] = data
end

------------------------------------------------------------------------
-- benchmark tester
------------------------------------------------------------------------

local DURATION = 5      -- how long the benchmark should run

local L = {} -- LuaState
local LS = {} -- LexState

local time = os.time
local lexedsize = 0
local tnow, elapsed = time(), 0

while time() == tnow do end    -- wait for second to click over
tnow = time()

while true do
  for i = 1, #fileset do
    ------------------------------------------------------------
    local chunk = fileset[i]
    local z = luaZ:init(luaZ:make_getS(chunk), nil)
    luaX:setinput(L, LS, z, "=string")
    while true do
      LS.t.token = luaX:llex(LS, LS.t)
      local tok, seminfo = LS.t.token, LS.t.seminfo
      if tok == "TK_EOS" then break end
    end
    ------------------------------------------------------------
    lexedsize = lexedsize + #chunk
    if time() > tnow then
      tnow = time()
      elapsed = elapsed + 1
      if elapsed >= DURATION then
        -- report performance of lexer
        lexedsize = lexedsize / 1024
        local speed = lexedsize / DURATION
        print("Lexer performance:")
        print("Size of data lexed (KB): "..string.format("%.1f", lexedsize))
        print("Speed of lexer (KB/s): "..string.format("%.1f", speed))
        -- repeat until user breaks program
        elapsed = 0
      end
    end
    ------------------------------------------------------------
  end--for
end--while

-- end of script
