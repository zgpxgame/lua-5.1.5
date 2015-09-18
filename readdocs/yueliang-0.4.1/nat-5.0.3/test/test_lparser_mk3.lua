--[[--------------------------------------------------------------------

  test_lparser_mk3.lua
  Test for lparser_mk3.lua
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
local parser_init = require("../lparser_mk3")

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
-- try 1
------------------------------------------------------------------------

local luaX = lex_init("local a = 1", "=string")
local luaY = parser_init(luaX)

-- nothing is returned, so hope there is an error if problem occurs
local fs = luaY:parser()
--dump_log(fs)

------------------------------------------------------------------------
-- try 2
------------------------------------------------------------------------

-- llex_mk3.lua cannot load files by itself
local INF = io.open("sample.lua", "rb")
if not INF then error("failed to load test file") end
local sample = INF:read("*a")
INF:close()

luaX = lex_init(sample, "@sample.lua")
luaY = parser_init(luaX)

-- nothing is returned, so hope there is an error if problem occurs
local fs = luaY:parser()
--dump_log(fs)

------------------------------------------------------------------------
-- automatic dumper of output log data
------------------------------------------------------------------------

local test_case = {
-- 1
[[
]],
-- 2
[[
-- foobar
]],
-- 3
[[
do
end
]],
-- 4
[[
do end
do end
]],
-- 5
[[
foo()
foo{}
foo""
foo:bar()
foo=false
foo.bar=true
foo[true]=nil
foo,bar=1,"a"
]],
-- 6
[[
foo=true
foo=false
foo=nil
foo=1.23e45
foo=-1
foo=(0)
foo=1+2
foo=1+2*3-4/5
]],
-- 7
[[
if foo then foo=1 end
if foo then foo=1 else foo=0 end
if foo then foo=1 elseif not foo then foo=0 end
]],
-- 8
[[
do return end
do return 123 end
do return "foo","bar" end
]],
-- 9
[[
while true do foo=not foo end
while foo~=42 do foo=foo-1 end
while true do break end
]],
-- 10
[[
repeat foo=foo.."bar" until false
repeat foo=foo/2 until foo<1
repeat break until false
]],
-- 11
[[
for i=1,10 do foo=i end
for i=1,10,2 do break end
for i in foo do bar=0 end
for i,j in foo,bar do baz=0 end
]],
-- 12
[[
local foo
local foo,bar,baz
local foo,bar="foo","bar"
]],
-- 13
[[
local function foo() return end
local function foo(a) return end
local function foo(x,y,z) return end
local function foo(x,...) return end
]],
-- 14
[[
function foo() return end
function foo(a) return end
function foo(x,y,z) return end
function foo(x,...) return end
]],
-- 15
[[
function foo.bar(p) return end
function foo.bar.baz(p) return end
function foo:bar(p) return end
function foo.bar.baz(p) return end
]],
-- 16
[[
foo = function() return end
foo = function(x,y) return end
foo = function(...) return end
]],
-- 17
[[
foo = {}
foo = { 1,2,3; "foo"; }
foo = { bar=77, baz=88, }
foo = { ["bar"]=77, ["baz"]=88, }
]],
}

-- helps to skip old stuff during development of snippets
local do_beg, do_end = 1, table.getn(test_case)

-- loop for all example snippets
for i = do_beg, do_end do
  local fname = "parser_log/sample_"..string.format("%02d", i)..".lua"
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
