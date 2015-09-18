--[[--------------------------------------------------------------------

  bench_llex.lua
  Benchmark test for llex.lua
  This file is part of Yueliang.

  Copyright (c) 2006 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

require("../lzio")
require("../llex")
luaX:init()

------------------------------------------------------------------------
-- load in a standard set of sample files
-- * file set is 5.0.3 front end set sans luac.lua
------------------------------------------------------------------------

local fileset, totalsize = {}, 0
for fn in string.gfind([[
../lcode.lua
../ldump.lua
../llex.lua
../lopcodes.lua
../lparser.lua
../lzio.lua
]], "%S+") do
  table.insert(fileset, fn)
end

for i = 1, table.getn(fileset) do
  local fn = fileset[i]
  local inf = io.open(fn, "rb")
  if not inf then
    error("failed to open "..fn.." for reading")
  end
  local data = inf:read("*a")
  local data_sz = string.len(data)
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
  for i = 1, table.getn(fileset) do
    ------------------------------------------------------------
    local chunk = fileset[i]
    local z = luaZ:init(luaZ:make_getS(chunk), nil, "=string")
    luaX:setinput(L, LS, z, z.name)
    while true do
      LS.t.token = luaX:lex(LS, LS.t)
      local tok, seminfo = LS.t.token, LS.t.seminfo
      if tok == "TK_EOS" then break end
    end
    ------------------------------------------------------------
    lexedsize = lexedsize + string.len(chunk)
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
