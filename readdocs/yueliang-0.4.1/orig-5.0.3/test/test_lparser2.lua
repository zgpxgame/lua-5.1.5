--[[--------------------------------------------------------------------

  test_lparser2.lua
  Test for lparser.lua, using the test case file
  This file is part of Yueliang.

  Copyright (c) 2006 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- Notes:
-- * the test cases are in the test_lua directory (test_parser-5.0.lua)
----------------------------------------------------------------------]]

-- * true if you want an output of all failure cases in native Lua,
--   for checking whether test cases fail where you intend them to
local DEBUG_FAILS = false

------------------------------------------------------------------------
-- test the whole kaboodle
------------------------------------------------------------------------

require("../lzio")
require("../llex")
require("../lopcodes")
require("../ldump")
require("../lcode")
require("../lparser")

function lua_assert(test)
  if not test then error("assertion failed!") end
end

luaX:init()

------------------------------------------------------------------------
-- load test cases
------------------------------------------------------------------------

require("../../test_lua/test_parser-5.0")

local test, expect, heading = {}, {}, {}
local total, total_pass, total_fail = 0, 0, 0

for ln in string.gfind(tests_source, "([^\n]*)\n") do
  if string.find(ln, "^%s*%-%-") then
    -- comment, ignore
  else
    local m, _, head = string.find(ln, "^%s*(TESTS:%s*.*)$")
    if m then
      heading[total + 1] = head         -- informational heading
    else
      total = total + 1
      local n, _, flag = string.find(ln, "%s*%-%-%s*FAIL%s*$")
      if n then                         -- FAIL test case
        ln = string.sub(ln, 1, n - 1)   -- remove comment
        expect[total] = "FAIL"
        total_fail = total_fail + 1
      else                              -- PASS test case
        expect[total] = "PASS"
        total_pass = total_pass + 1
      end--n
      test[total] = ln
    end--m
  end--ln
end--for

print("Tests loaded: "..total.." (total), "
                      ..total_pass.." (passes), "
                      ..total_fail.." (fails)")

------------------------------------------------------------------------
-- verify test cases using native Lua
------------------------------------------------------------------------

local last_head = "TESTS: no heading yet"
for i = 1, total do
  local test_case, expected, head = test[i], expect[i], heading[i]
  -- show progress
  if head then
    last_head = head
    if DEBUG_FAILS then print("\n"..head.."\n") end
  end
  ------------------------------------------------------------------
  -- perform test
  local f, err = loadstring(test_case)
  -- look at outcome
  ------------------------------------------------------------------
  if f then-- actual PASS
    if expected == "FAIL" then
      print("\nVerified as PASS but expected to FAIL"..
            "\n-------------------------------------")
      print("Lastest heading: "..last_head)
      print("TEST: "..test_case)
      os.exit()
    end
  ------------------------------------------------------------------
  else-- actual FAIL
    if expected == "PASS" then
      print("\nVerified as FAIL but expected to PASS"..
            "\n-------------------------------------")
      print("Lastest heading: "..last_head)
      print("TEST: "..test_case)
      print("ERROR: "..err)
      os.exit()
    end
    if DEBUG_FAILS then
      print("TEST: "..test_case)
      print("ERROR: "..err.."\n")
    end
  ------------------------------------------------------------------
  end--f
end--for

print("Test cases verified using native Lua, no anomalies.")

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
-- test using Yueliang front end
------------------------------------------------------------------------

local last_head = "TESTS: no heading yet"
for i = 1, total do
  local test_case, expected, head = test[i], expect[i], heading[i]
  -- show progress
  if head then last_head = head end
  ------------------------------------------------------------------
  -- perform test
  local LuaState = {}
  local zio = luaZ:init(luaZ:make_getS(test_case), nil, "test")
  local status, func = pcall(luaY.parser, luaY, LuaState, zio, nil)
  -- look at outcome
  ------------------------------------------------------------------
  if status then-- actual PASS
    if expected == "PASS" then
      -- actual PASS and expected PASS, so check binary chunks
      local writer, buff = luaU:make_setS()
      luaU:dump(LuaState, func, writer, buff)
      local bc1 = buff.data  -- Yueliang's output
      local f = loadstring(test_case, "test")
      local bc2 = string.dump(f)  -- Lua's output
      local die
      -- compare outputs
      if string.len(bc1) ~= string.len(bc2) then
        Dump(bc1, "bc1.out")
        Dump(bc2, "bc2.out")
        die = "binary chunk sizes different"
      elseif bc1 ~= bc2 then
        Dump(bc1, "bc1.out")
        Dump(bc2, "bc2.out")
        die = "binary chunks different"
      else
        -- everything checks out!
      end
      if die then
        print("\nTested PASS and expected to PASS, but chunks different"..
              "\n------------------------------------------------------")
        print("Reason: "..die)
        print("Lastest heading: "..last_head)
        print("TEST: "..test_case)
        os.exit()
      end
    else-- expected FAIL
      print("\nTested as PASS but expected to FAIL"..
            "\n-----------------------------------")
      print("Lastest heading: "..last_head)
      print("TEST: "..test_case)
      os.exit()
    end
  ------------------------------------------------------------------
  else-- actual FAIL
    if expected == "PASS" then
      print("\nTested as FAIL but expected to PASS"..
            "\n-----------------------------------")
      print("Lastest heading: "..last_head)
      print("TEST: "..test_case)
      print("ERROR: "..err)
      os.exit()
    end
  ------------------------------------------------------------------
  end--status
  io.stdout:write("\rTesting ["..i.."]...")
end--for
print(" done.")

print("Test cases run on Yueliang, no anomalies.")

-- end
