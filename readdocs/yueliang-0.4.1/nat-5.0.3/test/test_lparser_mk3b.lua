--[[--------------------------------------------------------------------

  test_lparser_mk3b.lua
  Test for lparser_mk3b.lua
  This file is part of Yueliang.

  Copyright (c) 2008 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

------------------------------------------------------------------------
-- test the whole kaboodle
------------------------------------------------------------------------

local lex_init = require("../llex_mk3")
local parser_init = require("../lparser_mk3b")

------------------------------------------------------------------------
-- dump contents of log table
------------------------------------------------------------------------

local function dump_log(fs)
  local log = fs.log
  for i = 1, table.getn(log) do
    print(log[i])
  end
end

------------------------------------------------------------------------
-- automatic dumper of output log data
------------------------------------------------------------------------

local test_case = {
-- 1
[[
  print(a)
]],
-- 2
[[
  local a
  print(a)
]],
-- 3
[[
  do
    local a
    print(a)
  end
  print(a)
]],
-- 4
[[
  local a,b,c
  do
    local b
    print(b)
  end
  print(b)
]],
-- 5
[[
  local function foo() end
  bar = foo
]],
-- 6
[[
  do
    local function foo() end
    bar = foo
  end
  baz = foo
]],
-- 7
[[
  local foo
  local function bar()
    baz = nil
    foo = bar()
  end
  foo = bar
]],
-- 8
[[
  local foo
  local function bar()
    local function baz()
      local foo, bar
      foo = bar
      foo = baz
    end
    foo = bar
    foo = baz
  end
  foo = bar
  foo = baz
]],
-- 9
[[
  function foo:bar()
    print(self)
  end
]],
-- 10
[[
  function foo(...)
    print(arg)
  end
]],
-- 11
[[
  local c,d
  function foo(a,b,c)
    print(a,c,d,e)
  end
]],
-- 11
[[
  function foo(a,b)
    local bar = function(c,d)
      print(a,b,c,d)
    end
  end
]],
-- 12
[[
  for i = 1,10 do
    print(i)
  end
  for i = 1,10,-2 do
    print(i)
  end
]],
-- 13
[[
  for foo in bar() do
    print(foo)
  end
  for foo,bar,baz in spring() do
    print(foo,bar,baz)
  end
]],
}

-- helps to skip old stuff during development of snippets
local do_beg, do_end = 1, table.getn(test_case)

-- loop for all example snippets
for i = do_beg, do_end do
  local fname = "parser_log/sample_b_"..string.format("%02d", i)..".lua"
  local src = test_case[i]
  local OUTF = io.open(fname, "wb")
  if not OUTF then error("failed to write to file '"..fname.."'") end
  -- write out actual source for comparison
  OUTF:write(
    "-- START OF SOURCE --\n"..
    src..
    "-- END OF SOURCE --\n"..
    "\n"
  )
  -- attempt to parse
  local luaX = lex_init(src, "=string")
  local luaY = parser_init(luaX)
  local fs = luaY:parser()
  -- grab logged messages and write
  local log = fs.log
  local indent = 0
  for i = 1, table.getn(log) do
    local ln = log[i]
    -- handle indentation
    local tag = string.sub(ln, 1, 2)
    if tag == ">>" or tag == "<<" then
      ln = string.sub(ln, 4)
    end
    if tag == ">>" then
      indent = indent + 1
    end
    OUTF:write(string.rep("  ", indent)..ln.."\n")
    if tag == "<<" then
      indent = indent - 1
    end
  end
  -- we're done
  OUTF:close()
end
