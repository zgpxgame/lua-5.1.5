--[[--------------------------------------------------------------------

  test_number.lua
  Test for Lua-based number conversion functions in ldump.lua
  This file is part of Yueliang.

  Copyright (c) 2006 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- Notes:
-- * luaU:from_int(value) does not have overflow checks, but this
--   can presumably be put in for debugging purposes.
-- * TODO: double conversion does not support denormals or NaNs
-- * apparently 0/0 == 0/0 is false (Lua 5.0.2 on Win32/Mingw), so
--   can't use to check for NaNs
----------------------------------------------------------------------]]

dofile("../ldump.lua")

------------------------------------------------------------------------
-- convert hex string representation to a byte string
-- * must have an even number of hex digits
------------------------------------------------------------------------
local function from_hexstring(s)
  local bs = ""
  for i = 1, string.len(s), 2 do
    local asc = tonumber(string.sub(s, i, i + 1), 16)
    bs = bs..string.char(asc)
  end
  return bs
end

------------------------------------------------------------------------
-- convert a byte string to a hex string representation
-- * big-endian, easier to grok
------------------------------------------------------------------------
local function to_hexstring(s)
  local hs = ""
  for i = string.len(s), 1, -1 do
    local c = string.byte(string.sub(s, i, i))
    hs = hs..string.format("%02X", c)
  end
  return hs
end

------------------------------------------------------------------------
-- tests for 32-bit signed/unsigned integer
------------------------------------------------------------------------
local function test_int(value, expected)
  local actual = to_hexstring(luaU:from_int(value))
  if not expected or expected == "" then
    print(value..": "..actual)
  elseif actual ~= expected then
    print(value..": FAILED!\n"..
          "Converted: "..actual.."\n"..
          "Expected:  "..expected)
    return true
  end
  return false
end

local table_int = {
  ["0"]           = "00000000",
  ["1"]           = "00000001",
  ["256"]         = "00000100",
  ["-256"]        = "FFFFFF00",
  ["-1"]          = "FFFFFFFF",
  ["2147483647"]  = "7FFFFFFF", -- LONG_MAX
  ["-2147483648"] = "80000000", -- LONG_MIN
  ["4294967295"]  = "FFFFFFFF", -- ULONG_MAX
  --[""] = "",
}

local success = true
print("Testing luaU:from_int():")
for i, v in pairs(table_int) do
  local test_value = tonumber(i)
  local expected = v
  if test_int(test_value, expected) then
    success = false
  end
end
if success then
  print("All test numbers passed okay.\n")
else
  print("There were one or more failures.\n")
end

------------------------------------------------------------------------
-- tests for IEEE 754 64-bit double
------------------------------------------------------------------------

local function test_double(value, expected)
  local actual = to_hexstring(luaU:from_double(value))
  if not expected or expected == "" then
    print(value..": "..actual)
  elseif actual ~= expected then
    print(value..": FAILED!\n"..
          "Converted: "..actual.."\n"..
          "Expected:  "..expected)
    return true
  end
  return false
end

-- special values, see testing loop for actual lookup
Infinity = 1/0
Infinity_neg = -1/0

-- can't seem to do a comparison test with NaN, so leave them
-- (need to check the IEEE standard on this...)
NaN = 0/0
NaN_neg = -0/0
--["NaN"] = "", -- 7FF8000000000000 (djgpp)
--["NaN_neg"] = "", -- FFF8000000000000 (djgpp)

local table_double = {
  -- 0 for exponent, 0 for mantissa
  ["0"] = "0000000000000000",
  -- 3FF is bias of 1023, so (-1)^0 * (1+0) * 2^0
  ["1"] = "3FF0000000000000",
  -- BFF has sign bit on, so (-1)^1 * (1+0) * 2^0
  ["-1"] = "BFF0000000000000",
  -- 3FC is bias of 1020, so (-1)^0 * (1+0) * 2^-3
  ["0.125"] = "3FC0000000000000",
  ["0.250"] = "3FD0000000000000",
  ["0.500"] = "3FE0000000000000",
  -- 40F is bias of 1039, so (-1)^0 * (1+0) * 2^16
  ["65536"] = "40F0000000000000",
  -- 7FF is bias of 2047, 0 for mantissa
  ["Infinity"] = "7FF0000000000000",
  -- FFF has sign bit on, 0 for mantissa
  ["Infinity_neg"] = "FFF0000000000000",
  -- DBL_MIN, exponent=001 (   1), mantissa=0000000000000
  ["2.2250738585072014e-308"] = "0010000000000000",
  -- DBL_MAX, exponent=7FE (2046), mantissa=FFFFFFFFFFFFF
  ["1.7976931348623157e+308"] = "7FEFFFFFFFFFFFFF",
--[[
  -- * the following is for float numbers only *
  -- FLT_MIN, exponent=01 (  1), mantissa=000000
  -- altervative value for FLT_MIN: 1.17549435e-38F
  ["1.1754943508222875081e-38"] = "00800000",
  -- FLT_MAX, exponent=FE (254), mantissa=7FFFFF
  -- altervative value for FLT_MAX: 3.402823466e+38F
  ["3.4028234663852885982e+38"] = "7F7FFFFF",
--]]
  --[""] = "",
}

local success = true
print("Testing luaU:from_double():")
for i, v in pairs(table_double) do
  local test_value
  if not string.find(i, "%d") then
    test_value = _G[i]
  else
    test_value = tonumber(i)
  end
  local expected = v
  if test_double(test_value, expected) then
    success = false
  end
end
if success then
  print("All test numbers passed okay.\n")
else
  print("There were one or more failures.\n")
end
