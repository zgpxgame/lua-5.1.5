--[[--------------------------------------------------------------------

  sample_expr.lua
  Stand-alone expression parsing demonstrator.
  This file is part of Yueliang.

  Copyright (c) 2005 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- Notes:
-- * this is an interactive demonstrator for implementing expression
--   parsing in ChunkBake, a Lua assembler
-- * evaluation is immediate, and a result is immediately generated
----------------------------------------------------------------------]]

require("../lzio.lua")
require("../llex.lua")
luaX:init()

------------------------------------------------------------------------
-- expression parser
------------------------------------------------------------------------

expr = {}

expr.unop = {
  ["TK_NOT"] = true,
  ["-"] = true,
}
expr.binop = {
  ["^"] = 10,
  ["*"] = 7,
  ["/"] = 7,
  ["+"] = 6,
  ["-"] = 6,
  ["TK_CONCAT"] = 5,
  ["TK_NE"] = 3,
  ["TK_EQ"] = 3,
  ["<"] = 3,
  ["TK_LE"] = 3,
  [">"] = 3,
  ["TK_GE"] = 3,
  ["TK_AND"] = 2,
  ["TK_OR"] = 1,
}
expr.binop_r = {
  ["^"] = 9,
  ["*"] = 7,
  ["/"] = 7,
  ["+"] = 6,
  ["-"] = 6,
  ["TK_CONCAT"] = 4,
  ["TK_NE"] = 3,
  ["TK_EQ"] = 3,
  ["<"] = 3,
  ["TK_LE"] = 3,
  [">"] = 3,
  ["TK_GE"] = 3,
  ["TK_AND"] = 2,
  ["TK_OR"] = 1,
}

function expr:parse(str)
  self.LS = {}
  self.L = {}
  self.z = luaZ:init(luaZ:make_getS(str), nil, "=string")
  luaX:setinput(self.L, self.LS, self.z, self.z.name)
  self:token()
  local v = self:expr()
  if self.tok ~= "TK_EOS" then
    io.stderr:write("parse error: some tokens unparsed\n")
  end
  return v
end

function expr:token()
  self.tok = luaX:lex(self.LS, self.LS.t)
  self.seminfo = self.LS.t.seminfo
  return self.tok
end

function expr:simpleexpr()
  local tok = self.tok
  if tok == "TK_NIL" then
    self:token()
    return nil
  elseif tok == "TK_TRUE" then
    self:token()
    return true
  elseif tok == "TK_FALSE" then
    self:token()
    return false
  elseif tok == "TK_NUMBER" or tok == "TK_STRING" then
    self:token()
    return self.seminfo
  elseif tok == "(" then
    self:token()
    local v = self:expr()
    if self.tok ~= ")" then
      io.stderr:write("parse error: expecting ')' to delimit\n")
    else
      self:token()
      return v
    end
  end
  self:token()
  io.stderr:write("parse error: "..tok.." encountered, substituting nil\n")
  return nil
end

function expr:subexpr(prev_op)
  local v, op
  if self.unop[self.tok] then
    op = self.tok
    self:token()
    v = self:subexpr(8)
    if op == "TK_NOT" then
      v = not v
    else-- op == "-" then
      v = -v
    end
  else
    v = self:simpleexpr()
  end
  op = self.tok
  if self.binop[op] then
    while self.binop[op] and self.binop[op] > prev_op do
      self:token()
      local v2, next_op = self:subexpr(self.binop_r[op])
      if op == "^" then
        v = v ^ v2
      elseif op == "*" then
        v = v * v2
      elseif op == "/" then
        v = v / v2
      elseif op == "+" then
        v = v + v2
      elseif op == "-" then
        v = v - v2
      elseif op == "TK_CONCAT" then
        v = v .. v2
      elseif op == "TK_NE" then
        v = v ~= v2
      elseif op == "TK_EQ" then
        v = v == v2
      elseif op == "<" then
        v = v < v2
      elseif op == "TK_LE" then
        v = v <= v2
      elseif op == ">" then
        v = v > v2
      elseif op == "TK_GE" then
        v = v >= v2
      elseif op == "TK_AND" then
        v = v and v2
      else-- op == "TK_OR" then
        v = v or v2
      end
      op = next_op
    end
  end
  return v, op
end

function expr:expr()
  return self:subexpr(-1)
end

------------------------------------------------------------------------
-- interactive test code
------------------------------------------------------------------------

io.stdout:write([[
Lua-style expression parsing demonstrator.
Type 'exit' or 'quit' at the prompt to terminate session.
]])
local done = false
while not done do
  io.stdout:write(":>")
  io.stdout:flush()
  local l = io.stdin:read("*l")
  if l == nil or (l == "exit" or l == "quit" and not prevline) then
    done = true
  else
    local v = tostring(expr:parse(l))
    io.stdout:write(v, "\n")
  end
end--while
--end
