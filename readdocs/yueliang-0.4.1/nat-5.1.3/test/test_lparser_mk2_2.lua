--[[--------------------------------------------------------------------

  test_lparser_mk2_2.lua
  Test for lparser_mk2.lua, using the test case file
  This file is part of Yueliang.

  Copyright (c) 2006-2008 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- Notes:
-- * unlike the equivalent in the orig-5.1.3/ directory, this version
--   tests only parsing, lparser_mk3 cannot generate binary chunks
-- * the test cases are in the test_lua directory (test_parser-5.1.lua)
----------------------------------------------------------------------]]

-- * true if you want an output of all failure cases in native Lua,
--   for checking whether test cases fail where you intend them to
local DEBUG_FAILS = false

------------------------------------------------------------------------
-- test the whole kaboodle
------------------------------------------------------------------------

package.path = "../?.lua;"..package.path
local llex = require "llex_mk2"
local lparser = require "lparser_mk2"

------------------------------------------------------------------------
-- load test cases
------------------------------------------------------------------------

dofile("../../test_lua/test_parser-5.1.lua")

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
-- test using Yueliang front end
------------------------------------------------------------------------

local last_head = "TESTS: no heading yet"
for i = 1, total do
  local test_case, expected, head = test[i], expect[i], heading[i]
  -- show progress
  if head then last_head = head end
  ------------------------------------------------------------------
  -- perform test
  llex.init(test_case, "=test_sample")
  lparser.init(llex)

  local status, func = pcall(lparser.parser)
  -- look at outcome
  ------------------------------------------------------------------
  if status then-- actual PASS
    if expected == "FAIL" then
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
      os.exit()
    else
      io.stdout:write("-")
    end
  ------------------------------------------------------------------
  end--status
  io.stdout:write("\rTesting ["..i.."]...")
end--for
print(" done.")

print("Test cases run on Yueliang, no anomalies.")

-- end
