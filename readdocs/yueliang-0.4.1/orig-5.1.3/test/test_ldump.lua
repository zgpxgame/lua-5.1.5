--[[--------------------------------------------------------------------

  test_ldump.lua
  Test for ldump.lua
  This file is part of Yueliang.

  Copyright (c) 2006 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

------------------------------------------------------------------------
-- test dump chunkwriter style
------------------------------------------------------------------------

dofile("../lopcodes.lua")
dofile("../ldump.lua")

-- Original typedef:
--int (*lua_Chunkwriter) (lua_State *L, const void* p, size_t sz, void* ud);

local MyWriter, MyBuff = luaU:make_setS()
if not MyWriter then
  error("failed to initialize using make_setS")
end
MyWriter("hello, ", MyBuff)
MyWriter("world!", MyBuff)
print(MyBuff.data)

local MyWriter, MyBuff = luaU:make_setF("try.txt")
if not MyWriter then
  error("failed to initialize using make_setF")
end
MyWriter("hello, ", MyBuff)
MyWriter("world!", MyBuff)
MyWriter(nil, MyBuff)

------------------------------------------------------------------------
-- test output of a function prototype
-- * data can be copied from a ChunkSpy listing output
------------------------------------------------------------------------
--   local a = 47
--   local b = "hello, world!"
--   print(a, b)
------------------------------------------------------------------------

local F = {}
F.source = "sample.lua"
F.lineDefined = 0
F.lastlinedefined = 0
F.nups = 0
F.numparams = 0
F.is_vararg = 2
F.maxstacksize = 5
F.sizecode = 7
F.code = {}
F.code[0] = { OP =  1, A = 0, Bx = 0 }
F.code[1] = { OP =  1, A = 1, Bx = 1 }
F.code[2] = { OP =  5, A = 2, Bx = 2 }
F.code[3] = { OP =  0, A = 3, B = 0, C = 0 }
F.code[4] = { OP =  0, A = 4, B = 1, C = 0 }
F.code[5] = { OP = 28, A = 2, B = 3, C = 1 }
F.code[6] = { OP = 30, A = 0, B = 1, C = 0 }
F.sizek = 3
F.k = {}
F.k[0] = { value = 47 }
F.k[1] = { value = "hello, world!" }
F.k[2] = { value = "print" }
F.sizep = 0
F.p = {}
F.sizelineinfo = 7
F.lineinfo = {}
F.lineinfo[0] = 1
F.lineinfo[1] = 2
F.lineinfo[2] = 3
F.lineinfo[3] = 3
F.lineinfo[4] = 3
F.lineinfo[5] = 3
F.lineinfo[6] = 3
F.sizelocvars = 2
F.locvars = {}
F.locvars[0] = { varname = "a", startpc = 1, endpc = 6 }
F.locvars[1] = { varname = "b", startpc = 2, endpc = 6 }
F.sizeupvalues = 0
F.upvalues = {}

local L = {}
--[[
local Writer, Buff = luaU:make_setS()
luaU:dump(L, F, Writer, Buff)
for i = 1, string.len(Buff.data) do
  io.stdout:write(string.byte(string.sub(Buff.data, i, i)).." ")
end
--]]
local Writer, Buff = luaU:make_setF("try.out")
luaU:dump(L, F, Writer, Buff)
