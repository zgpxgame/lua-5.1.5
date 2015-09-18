--[[--------------------------------------------------------------------

  test_scripts-5.0.lua
  Compile and compare Lua files
  This file is part of Yueliang.

  Copyright (c) 2005-2007 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- NOTE
-- * use the argument ALL to pull in additional personal Lua scripts
--   for testing, e.g. lua test_scripts.lua ALL
----------------------------------------------------------------------]]

------------------------------------------------------------------------
-- reads in a list of files to crunch from a text file
------------------------------------------------------------------------

local function loadlist(fname, flist)
  local inf = io.open(fname, "r")
  if not inf then error("cannot open "..fname.." for reading") end
  while true do
    local d = inf:read("*l")
    if not d then break end
    if string.find(d, "^%s*$") or string.find(d, "^#") then
      -- comments and empty lines are ignored
    else
      table.insert(flist, d)
    end
  end
  inf:close()
end

------------------------------------------------------------------------
-- read in list of files to test
------------------------------------------------------------------------

local files = {}

loadlist("files-lua-5.0.txt", files)
loadlist("files-yueliang-5.0.txt", files)

-- pull in personal scripts to test if user specifies "ALL"
if arg[1] == "ALL" then
  loadlist("files-other-5.0.txt", files)
end

-- if you want to specify files in this script itself (not recommended)
-- you can add them using the following
--[[
for v in string.gfind([[
]], "[^%s]+") do
  table.insert(files, v)
end
--]]

total = 0  -- sum of sizes
fsize = 0  -- current file size

------------------------------------------------------------------------
-- initialize
------------------------------------------------------------------------

require("../orig-5.0.3/lzio")
require("../orig-5.0.3/llex")
require("../orig-5.0.3/lopcodes")
require("../orig-5.0.3/ldump")
require("../orig-5.0.3/lcode")
require("../orig-5.0.3/lparser")

function lua_assert(test)
  if not test then error("assertion failed!") end
end

luaX:init()

io.stdout:write("\n\n")

------------------------------------------------------------------------
-- * basic comparison for now; do it properly later
------------------------------------------------------------------------

local LuaState = {}

------------------------------------------------------------------------
-- dump binary chunks to a file if something goes wrong
------------------------------------------------------------------------
local function Dump(data, filename)
  h = io.open(filename, "wb")
  if not h then error("failed to open "..filename.." for writing") end
  h:write(data)
  h:close()
end

------------------------------------------------------------------------
-- create custom chunk reader (sums up file sizes)
------------------------------------------------------------------------
function make_getF(filename)
  local h = io.open(filename, "r")
  if not h then return nil end
  fsize = h:seek("end")
  h:seek("set")
  total = total + fsize
  return function() -- chunk reader anonymous function here
    if not h then return nil end
    local buff = h:read(512)
    if not buff then h:close() end
    return buff
  end
end

------------------------------------------------------------------------
-- attempt to compile Lua source files
------------------------------------------------------------------------
for i, filename in ipairs(files) do
  -- compile a source file
  local zio = luaZ:init(make_getF(filename), nil, "@"..filename)
  if not zio then
    error("could not initialize zio stream for "..filename)
  end
  io.stdout:write(filename.."("..fsize.."): ")
  local Func = luaY:parser(LuaState, zio, nil)
  local Writer, Buff = luaU:make_setS()
  luaU:dump(LuaState, Func, Writer, Buff)
  local bc1 = Buff.data  -- Yueliang's output

  local f = loadfile(filename)
  local bc2 = string.dump(f)  -- Lua's output

  -- compare outputs
  if string.len(bc1) ~= string.len(bc2) then
    Dump(bc1, "bc1.out")
    Dump(bc2, "bc2.out")
    error("binary chunk sizes different")
  elseif bc1 ~= bc2 then
    Dump(bc1, "bc1.out")
    Dump(bc2, "bc2.out")
    error("binary chunks different")
  else
    io.stdout:write("CORRECT\n")
  end
  local x, y = gcinfo()
  -- memory usage isn't really a problem for the straight port
  -- string handling in Lua that follows the original C closely is more
  -- of a problem, but this will be fixed elsewhere, not in this tree
  --io.stdout:write("gcinfo: "..x.." "..y.."\n")
end

-- summaries here
io.stdout:write("\nTotal file sizes: "..total.."\n")

-- end
