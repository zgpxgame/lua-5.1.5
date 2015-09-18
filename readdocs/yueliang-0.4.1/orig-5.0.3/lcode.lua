--[[--------------------------------------------------------------------

  lcode.lua
  Lua 5 code generator in Lua
  This file is part of Yueliang.

  Copyright (c) 2005-2006 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- Notes:
-- * one function manipulate a pointer argument with a simple data type
--   (can't be emulated by a table, ambiguous), now returns that value:
--   luaK:concat(fs, l1, l2)
-- * some function parameters changed to boolean, additional code
--   translates boolean back to 1/0 for instruction fields
-- * Added:
--   luaK:ttisnumber(o) (from lobject.h)
--   luaK:nvalue(o) (from lobject.h)
--   luaK:setnilvalue(o) (from lobject.h)
--   luaK:setsvalue(o, x) (from lobject.h)
--   luaK:setnvalue(o, x) (from lobject.h)
--   luaK:sethvalue(o, x) (from lobject.h)
----------------------------------------------------------------------]]

-- requires luaP, luaX, luaY
luaK = {}

------------------------------------------------------------------------
-- Marks the end of a patch list. It is an invalid value both as an absolute
-- address, and as a list link (would link an element to itself).
------------------------------------------------------------------------
luaK.NO_JUMP = -1

------------------------------------------------------------------------
-- grep "ORDER OPR" if you change these enums
------------------------------------------------------------------------
luaK.BinOpr = {
  OPR_ADD = 0, OPR_SUB = 1, OPR_MULT = 2, OPR_DIV = 3, OPR_POW = 4,
  OPR_CONCAT = 5,
  OPR_NE = 6, OPR_EQ = 7,
  OPR_LT = 8, OPR_LE = 9, OPR_GT = 10, OPR_GE = 11,
  OPR_AND = 12, OPR_OR = 13,
  OPR_NOBINOPR = 14,
}

------------------------------------------------------------------------
-- emulation of TObject macros (these are from lobject.h)
-- * TObject is a table since lcode passes references around
-- * tt member field removed, using Lua's type() instead
------------------------------------------------------------------------
function luaK:ttisnumber(o)
  if o then return type(o.value) == "number" else return false end
end
function luaK:nvalue(o) return o.value end
function luaK:setnilvalue(o) o.value = nil end
function luaK:setsvalue(o, x) o.value = x end
luaK.setnvalue = luaK.setsvalue
luaK.sethvalue = luaK.setsvalue

------------------------------------------------------------------------
-- * binopistest appears to be unused
-- * UnOpr is used by luaK:prefix's op argument
------------------------------------------------------------------------
function luaK:binopistest(op)
  return self.BinOpr[op] >= self.BinOpr["OPR_NE"]
end

luaK.UnOpr = {
  OPR_MINUS = 0, OPR_NOT = 1, OPR_NOUNOPR = 2
}

------------------------------------------------------------------------
-- returns the instruction object for given e (expdesc)
------------------------------------------------------------------------
function luaK:getcode(fs, e)
  return fs.f.code[e.info]
end

------------------------------------------------------------------------
-- codes an instruction with a signed Bx (sBx) field
------------------------------------------------------------------------
function luaK:codeAsBx(fs, o, A, sBx)
  return self:codeABx(fs, o, A, sBx + luaP.MAXARG_sBx)
end

------------------------------------------------------------------------
-- there is a jump if patch lists are not identical
-- * used in luaK:exp2reg(), luaK:exp2anyreg(), luaK:exp2val()
------------------------------------------------------------------------
function luaK:hasjumps(e)
  return e.t ~= e.f
end

------------------------------------------------------------------------
-- codes loading of nil, optimization done if consecutive locations
-- * used only in discharge2reg()
------------------------------------------------------------------------
function luaK:_nil(fs, from, n)
  if fs.pc > fs.lasttarget then  -- no jumps to current position?
    local previous = fs.f.code[fs.pc - 1]
    if luaP:GET_OPCODE(previous) == "OP_LOADNIL" then
      local pfrom = luaP:GETARG_A(previous)
      local pto = luaP:GETARG_B(previous)
      if pfrom <= from and from <= pto + 1 then  -- can connect both?
        if from + n - 1 > pto then
          luaP:SETARG_B(previous, from + n - 1)
        end
        return
      end
    end
  end
  self:codeABC(fs, "OP_LOADNIL", from, from + n - 1, 0)  -- else no optimization
end

------------------------------------------------------------------------
--
-- * used in multiple locations
------------------------------------------------------------------------
function luaK:jump(fs)
  local jpc = fs.jpc  -- save list of jumps to here
  fs.jpc = self.NO_JUMP
  local j = self:codeAsBx(fs, "OP_JMP", 0, self.NO_JUMP)
  return self:concat(fs, j, jpc)  -- keep them on hold
end

------------------------------------------------------------------------
--
-- * used in luaK:jumponcond(), luaK:codebinop()
------------------------------------------------------------------------
function luaK:condjump(fs, op, A, B, C)
  self:codeABC(fs, op, A, B, C)
  return self:jump(fs)
end

------------------------------------------------------------------------
--
-- * used in luaK:patchlistaux(), luaK:concat()
------------------------------------------------------------------------
function luaK:fixjump(fs, pc, dest)
  local jmp = fs.f.code[pc]
  local offset = dest - (pc + 1)
  lua_assert(dest ~= self.NO_JUMP)
  if math.abs(offset) > luaP.MAXARG_sBx then
    luaX:syntaxerror(fs.ls, "control structure too long")
  end
  luaP:SETARG_sBx(jmp, offset)
end

------------------------------------------------------------------------
-- returns current 'pc' and marks it as a jump target (to avoid wrong
-- optimizations with consecutive instructions not in the same basic block).
-- * used in multiple locations
-- * fs.lasttarget tested only by luaK:_nil() when optimizing OP_LOADNIL
------------------------------------------------------------------------
function luaK:getlabel(fs)
  fs.lasttarget = fs.pc
  return fs.pc
end

------------------------------------------------------------------------
--
-- * used in luaK:need_value(), luaK:patchlistaux(), luaK:concat()
------------------------------------------------------------------------
function luaK:getjump(fs, pc)
  local offset = luaP:GETARG_sBx(fs.f.code[pc])
  if offset == self.NO_JUMP then  -- point to itself represents end of list
    return self.NO_JUMP  -- end of list
  else
    return (pc + 1) + offset  -- turn offset into absolute position
  end
end

------------------------------------------------------------------------
--
-- * used in luaK:need_value(), luaK:patchlistaux(), luaK:invertjump()
------------------------------------------------------------------------
function luaK:getjumpcontrol(fs, pc)
  local pi = fs.f.code[pc]
  local ppi = fs.f.code[pc - 1]
  if pc >= 1 and luaP:testOpMode(luaP:GET_OPCODE(ppi), "OpModeT") then
    return ppi
  else
    return pi
  end
end

------------------------------------------------------------------------
-- check whether list has any jump that do not produce a value
-- (or produce an inverted value)
-- * used only in luaK:exp2reg()
------------------------------------------------------------------------
function luaK:need_value(fs, list, cond)
  while list ~= self.NO_JUMP do
    local i = self:getjumpcontrol(fs, list)
    if luaP:GET_OPCODE(i) ~= "OP_TEST" or
       luaP:GETARG_A(i) ~= luaP.NO_REG or
       luaP:GETARG_C(i) ~= cond then
      return true
    end
    list = self:getjump(fs, list)
  end
  return false  -- not found
end

------------------------------------------------------------------------
--
-- * used only in luaK:patchlistaux()
------------------------------------------------------------------------
function luaK:patchtestreg(i, reg)
  if reg == luaP.NO_REG then reg = luaP:GETARG_B(i) end
  luaP:SETARG_A(i, reg)
end

------------------------------------------------------------------------
--
-- * used only in luaK:codenot()
------------------------------------------------------------------------

function luaK:removevalues(fs, list)
  while list ~= self.NO_JUMP do
    local i = self:getjumpcontrol(fs, list)
    if luaP:GET_OPCODE(i) == "OP_TEST" then
      self:patchtestreg(i, luaP.NO_REG)
    end
    list = self:getjump(fs, list)
  end
end

------------------------------------------------------------------------
--
-- * used in luaK:dischargejpc(), luaK:patchlist(), luaK:exp2reg()
------------------------------------------------------------------------
function luaK:patchlistaux(fs, list, vtarget, reg, dtarget)
  while list ~= self.NO_JUMP do
    local _next = self:getjump(fs, list)
    local i = self:getjumpcontrol(fs, list)
    if luaP:GET_OPCODE(i) == "OP_TEST" and luaP:GETARG_A(i) == luaP.NO_REG then
      self:patchtestreg(i, reg)
      self:fixjump(fs, list, vtarget)
    else
      self:fixjump(fs, list, dtarget)  -- jump to default target
    end
    list = _next
  end
end

------------------------------------------------------------------------
--
-- * used only in luaK:code()
------------------------------------------------------------------------
function luaK:dischargejpc(fs)
  self:patchlistaux(fs, fs.jpc, fs.pc, luaP.NO_REG, fs.pc)
  fs.jpc = self.NO_JUMP
end

------------------------------------------------------------------------
--
-- * used in (lparser) luaY:whilestat(), luaY:repeatstat(), luaY:forbody()
------------------------------------------------------------------------
function luaK:patchlist(fs, list, target)
  if target == fs.pc then
    self:patchtohere(fs, list)
  else
    lua_assert(target < fs.pc)
    self:patchlistaux(fs, list, target, luaP.NO_REG, target)
  end
end

------------------------------------------------------------------------
--
-- * used in multiple locations
------------------------------------------------------------------------
function luaK:patchtohere(fs, list)
  self:getlabel(fs)
  fs.jpc = self:concat(fs, fs.jpc, list)
end

------------------------------------------------------------------------
-- * l1 was a pointer, now l1 is returned and callee assigns the value
-- * used in multiple locations
------------------------------------------------------------------------
function luaK:concat(fs, l1, l2)
  if l2 == self.NO_JUMP then return l1  -- unchanged
  elseif l1 == self.NO_JUMP then
    return l2  -- changed
  else
    local list = l1
    local _next = self:getjump(fs, list)
    while _next ~= self.NO_JUMP do  -- find last element
      list = _next
      _next = self:getjump(fs, list)
    end
    self:fixjump(fs, list, l2)
  end
  return l1  -- unchanged
end

------------------------------------------------------------------------
--
-- * used in luaK:reserveregs(), (lparser) luaY:forlist()
------------------------------------------------------------------------
function luaK:checkstack(fs, n)
  local newstack = fs.freereg + n
  if newstack > fs.f.maxstacksize then
    if newstack >= luaY.MAXSTACK then
      luaX:syntaxerror(fs.ls, "function or expression too complex")
    end
    fs.f.maxstacksize = newstack
  end
end

------------------------------------------------------------------------
--
-- * used in multiple locations
------------------------------------------------------------------------
function luaK:reserveregs(fs, n)
  self:checkstack(fs, n)
  fs.freereg = fs.freereg + n
end

------------------------------------------------------------------------
--
-- * used in luaK:freeexp(), luaK:dischargevars()
------------------------------------------------------------------------
function luaK:freereg(fs, reg)
  if reg >= fs.nactvar and reg < luaY.MAXSTACK then
    fs.freereg = fs.freereg - 1
    lua_assert(reg == fs.freereg)
  end
end

------------------------------------------------------------------------
--
-- * used in multiple locations
------------------------------------------------------------------------
function luaK:freeexp(fs, e)
  if e.k == "VNONRELOC" then
    self:freereg(fs, e.info)
  end
end

------------------------------------------------------------------------
-- * luaH_get, luaH_set deleted; direct table access used instead
-- * luaO_rawequalObj deleted in first assert
-- * setobj2n deleted in assignment of v to f.k table
-- * used in luaK:stringK(), luaK:numberK(), luaK:nil_constant()
------------------------------------------------------------------------
function luaK:addk(fs, k, v)
  local idx = fs.h[k.value]
  if self:ttisnumber(idx) then
    --TODO this assert currently FAILS, probably something wrong...
    --lua_assert(fs.f.k[self:nvalue(idx)] == v)
    return self:nvalue(idx)
  else  -- constant not found; create a new entry
    local f = fs.f
    luaY:growvector(fs.L, f.k, fs.nk, f.sizek, nil,
                    luaP.MAXARG_Bx, "constant table overflow")
    f.k[fs.nk] = v  -- setobj2n deleted
    fs.h[k.value] = {}
    self:setnvalue(fs.h[k.value], fs.nk)
    local nk = fs.nk
    fs.nk = fs.nk + 1
    return nk
  end
end

------------------------------------------------------------------------
-- creates and sets a string object
-- * used in (lparser) luaY:codestring(), luaY:singlevaraux()
------------------------------------------------------------------------
function luaK:stringK(fs, s)
  local o = {}  -- TObject
  self:setsvalue(o, s)
  return self:addk(fs, o, o)
end

------------------------------------------------------------------------
-- creates and sets a number object
-- * used in luaK:prefix() for negative (or negation of) numbers
-- * used in (lparser) luaY:simpleexp(), luaY:fornum()
------------------------------------------------------------------------
function luaK:numberK(fs, r)
  local o = {}  -- TObject
  self:setnvalue(o, r)
  return self:addk(fs, o, o)
end

------------------------------------------------------------------------
--
-- * used only in luaK:exp2RK()
------------------------------------------------------------------------
function luaK:nil_constant(fs)
  local k, v = {}, {}  -- TObject
  self:setnilvalue(v)
  self:sethvalue(k, fs.h)  -- cannot use nil as key; instead use table itself
  return self:addk(fs, k, v)
end

------------------------------------------------------------------------
--
-- * used in luaK:dischargevars()
-- * used in (lparser) luaY:adjust_assign(), luaY:lastlistfield(),
--   luaY:funcargs(), luaY:assignment(), luaY:exprstat(), luaY:retstat()
------------------------------------------------------------------------
function luaK:setcallreturns(fs, e, nresults)
  if e.k == "VCALL" then  -- expression is an open function call?
    luaP:SETARG_C(self:getcode(fs, e), nresults + 1)
    if nresults == 1 then  -- 'regular' expression?
      e.k = "VNONRELOC"
      e.info = luaP:GETARG_A(self:getcode(fs, e))
    end
  end
end

------------------------------------------------------------------------
--
-- * used in multiple locations
------------------------------------------------------------------------
function luaK:dischargevars(fs, e)
  local k = e.k
  if k == "VLOCAL" then
    e.k = "VNONRELOC"
  elseif k == "VUPVAL" then
    e.info = self:codeABC(fs, "OP_GETUPVAL", 0, e.info, 0)
    e.k = "VRELOCABLE"
  elseif k == "VGLOBAL" then
    e.info = self:codeABx(fs, "OP_GETGLOBAL", 0, e.info)
    e.k = "VRELOCABLE"
  elseif k == "VINDEXED" then
    self:freereg(fs, e.aux)
    self:freereg(fs, e.info)
    e.info = self:codeABC(fs, "OP_GETTABLE", 0, e.info, e.aux)
    e.k = "VRELOCABLE"
  elseif k == "VCALL" then
    self:setcallreturns(fs, e, 1)
  else
    -- there is one value available (somewhere)
  end
end

------------------------------------------------------------------------
--
-- * used only in luaK:exp2reg()
------------------------------------------------------------------------
function luaK:code_label(fs, A, b, jump)
  self:getlabel(fs)  -- those instructions may be jump targets
  return self:codeABC(fs, "OP_LOADBOOL", A, b, jump)
end

------------------------------------------------------------------------
--
-- * used in luaK:discharge2anyreg(), luaK:exp2reg()
------------------------------------------------------------------------
function luaK:discharge2reg(fs, e, reg)
  self:dischargevars(fs, e)
  local k = e.k
  if k == "VNIL" then
    self:_nil(fs, reg, 1)
  elseif k == "VFALSE" or k == "VTRUE" then
    self:codeABC(fs, "OP_LOADBOOL", reg, (e.k == "VTRUE") and 1 or 0, 0)
  elseif k == "VK" then
    self:codeABx(fs, "OP_LOADK", reg, e.info)
  elseif k == "VRELOCABLE" then
    local pc = self:getcode(fs, e)
    luaP:SETARG_A(pc, reg)
  elseif k == "VNONRELOC" then
    if reg ~= e.info then
      self:codeABC(fs, "OP_MOVE", reg, e.info, 0)
    end
  else
    lua_assert(e.k == "VVOID" or e.k == "VJMP")
    return  -- nothing to do...
  end
  e.info = reg
  e.k = "VNONRELOC"
end

------------------------------------------------------------------------
--
-- * used in luaK:jumponcond(), luaK:codenot()
------------------------------------------------------------------------
function luaK:discharge2anyreg(fs, e)
  if e.k ~= "VNONRELOC" then
    self:reserveregs(fs, 1)
    self:discharge2reg(fs, e, fs.freereg - 1)
  end
end

------------------------------------------------------------------------
--
-- * used in luaK:exp2nextreg(), luaK:exp2anyreg(), luaK:storevar()
------------------------------------------------------------------------
function luaK:exp2reg(fs, e, reg)
  self:discharge2reg(fs, e, reg)
  if e.k == "VJMP" then
    e.t = self:concat(fs, e.t, e.info)  -- put this jump in 't' list
  end
  if self:hasjumps(e) then
    local final  -- position after whole expression
    local p_f = self.NO_JUMP  -- position of an eventual LOAD false
    local p_t = self.NO_JUMP  -- position of an eventual LOAD true
    if self:need_value(fs, e.t, 1) or self:need_value(fs, e.f, 0) then
      local fj = self.NO_JUMP  -- first jump (over LOAD ops.)
      if e.k ~= "VJMP" then
        fj = self:jump(fs)
      end
      p_f = self:code_label(fs, reg, 0, 1)
      p_t = self:code_label(fs, reg, 1, 0)
      self:patchtohere(fs, fj)
    end
    final = self:getlabel(fs)
    self:patchlistaux(fs, e.f, final, reg, p_f)
    self:patchlistaux(fs, e.t, final, reg, p_t)
  end
  e.f, e.t = self.NO_JUMP, self.NO_JUMP
  e.info = reg
  e.k = "VNONRELOC"
end

------------------------------------------------------------------------
--
-- * used in multiple locations
------------------------------------------------------------------------
function luaK:exp2nextreg(fs, e)
  self:dischargevars(fs, e)
  self:freeexp(fs, e)
  self:reserveregs(fs, 1)
  self:exp2reg(fs, e, fs.freereg - 1)
end

------------------------------------------------------------------------
--
-- * used in multiple locations
------------------------------------------------------------------------
function luaK:exp2anyreg(fs, e)
  self:dischargevars(fs, e)
  if e.k == "VNONRELOC" then
    if not self:hasjumps(e) then  -- exp is already in a register
      return e.info
    end
    if e.info >= fs.nactvar then  -- reg. is not a local?
      self:exp2reg(fs, e, e.info)  -- put value on it
      return e.info
    end
  end
  self:exp2nextreg(fs, e)  -- default
  return e.info
end

------------------------------------------------------------------------
--
-- * used in luaK:exp2RK(), luaK:prefix(), luaK:posfix()
-- * used in (lparser) luaY:index()
------------------------------------------------------------------------
function luaK:exp2val(fs, e)
  if self:hasjumps(e) then
    self:exp2anyreg(fs, e)
  else
    self:dischargevars(fs, e)
  end
end

------------------------------------------------------------------------
--
-- * used in multiple locations
------------------------------------------------------------------------
function luaK:exp2RK(fs, e)
  self:exp2val(fs, e)
  local k = e.k
  if k == "VNIL" then
    if fs.nk + luaY.MAXSTACK <= luaP.MAXARG_C then  -- constant fit in argC?
      e.info = self:nil_constant(fs)
      e.k = "VK"
      return e.info + luaY.MAXSTACK
    end
  elseif k == "VK" then
    if e.info + luaY.MAXSTACK <= luaP.MAXARG_C then  -- constant fit in argC?
      return e.info + luaY.MAXSTACK
    end
  end
  -- not a constant in the right range: put it in a register
  return self:exp2anyreg(fs, e)
end

------------------------------------------------------------------------
--
-- * used in (lparser) luaY:assignment(), luaY:localfunc(), luaY:funcstat()
------------------------------------------------------------------------
function luaK:storevar(fs, var, exp)
  local k = var.k
  if k == "VLOCAL" then
    self:freeexp(fs, exp)
    self:exp2reg(fs, exp, var.info)
    return
  elseif k == "VUPVAL" then
    local e = self:exp2anyreg(fs, exp)
    self:codeABC(fs, "OP_SETUPVAL", e, var.info, 0)
  elseif k == "VGLOBAL" then
    local e = self:exp2anyreg(fs, exp)
    self:codeABx(fs, "OP_SETGLOBAL", e, var.info)
  elseif k == "VINDEXED" then
    local e = self:exp2RK(fs, exp)
    self:codeABC(fs, "OP_SETTABLE", var.info, var.aux, e)
  else
    lua_assert(0)  -- invalid var kind to store
  end
  self:freeexp(fs, exp)
end

------------------------------------------------------------------------
--
-- * used only in (lparser) luaY:primaryexp()
------------------------------------------------------------------------
function luaK:_self(fs, e, key)
  self:exp2anyreg(fs, e)
  self:freeexp(fs, e)
  local func = fs.freereg
  self:reserveregs(fs, 2)
  self:codeABC(fs, "OP_SELF", func, e.info, self:exp2RK(fs, key))
  self:freeexp(fs, key)
  e.info = func
  e.k = "VNONRELOC"
end

------------------------------------------------------------------------
--
-- * used in luaK:goiftrue(), luaK:codenot()
------------------------------------------------------------------------
function luaK:invertjump(fs, e)
  local pc = self:getjumpcontrol(fs, e.info)
  lua_assert(luaP:testOpMode(luaP:GET_OPCODE(pc), "OpModeT") and
             luaP:GET_OPCODE(pc) ~= "OP_TEST")
  luaP:SETARG_A(pc, (luaP:GETARG_A(pc) == 0) and 1 or 0)
end

------------------------------------------------------------------------
--
-- * used in luaK:goiftrue(), luaK:goiffalse()
------------------------------------------------------------------------
function luaK:jumponcond(fs, e, cond)
  if e.k == "VRELOCABLE" then
    local ie = self:getcode(fs, e)
    if luaP:GET_OPCODE(ie) == "OP_NOT" then
      fs.pc = fs.pc - 1  -- remove previous OP_NOT
      return self:condjump(fs, "OP_TEST", luaP:GETARG_B(ie), luaP:GETARG_B(ie),
                           cond and 0 or 1)
    end
    -- else go through
  end
  self:discharge2anyreg(fs, e)
  self:freeexp(fs, e)
  return self:condjump(fs, "OP_TEST", luaP.NO_REG, e.info, cond and 1 or 0)
end

------------------------------------------------------------------------
--
-- * used in luaK:infix(), (lparser) luaY:cond()
------------------------------------------------------------------------
function luaK:goiftrue(fs, e)
  local pc  -- pc of last jump
  self:dischargevars(fs, e)
  local k = e.k
  if k == "VK" or k == "VTRUE" then
    pc = self.NO_JUMP  -- always true; do nothing
  elseif k == "VFALSE" then
    pc = self:jump(fs)  -- always jump
  elseif k == "VJMP" then
    self:invertjump(fs, e)
    pc = e.info
  else
    pc = self:jumponcond(fs, e, false)
  end
  e.f = self:concat(fs, e.f, pc)  -- insert last jump in 'f' list
end

------------------------------------------------------------------------
--
-- * used in luaK:infix(), (lparser) luaY:whilestat()
------------------------------------------------------------------------
function luaK:goiffalse(fs, e)
  local pc  -- pc of last jump
  self:dischargevars(fs, e)
  local k = e.k
  if k == "VNIL" or k == "VFALSE"then
    pc = self.NO_JUMP  -- always false; do nothing
  elseif k == "VTRUE" then
    pc = self:jump(fs)  -- always jump
  elseif k == "VJMP" then
    pc = e.info
  else
    pc = self:jumponcond(fs, e, true)
  end
  e.t = self:concat(fs, e.t, pc)  -- insert last jump in 't' list
end

------------------------------------------------------------------------
--
-- * used only in luaK:prefix()
------------------------------------------------------------------------
function luaK:codenot(fs, e)
  self:dischargevars(fs, e)
  local k = e.k
  if k == "VNIL" or k == "VFALSE" then
    e.k = "VTRUE"
  elseif k == "VK" or k == "VTRUE" then
    e.k = "VFALSE"
  elseif k == "VJMP" then
    self:invertjump(fs, e)
  elseif k == "VRELOCABLE" or k == "VNONRELOC" then
    self:discharge2anyreg(fs, e)
    self:freeexp(fs, e)
    e.info = self:codeABC(fs, "OP_NOT", 0, e.info, 0)
    e.k = "VRELOCABLE"
  else
    lua_assert(0)  -- cannot happen
  end
  -- interchange true and false lists
  e.f, e.t = e.t, e.f
  self:removevalues(fs, e.f)
  self:removevalues(fs, e.t)
end

------------------------------------------------------------------------
--
-- * used in (lparser) luaY:field(), luaY:primaryexp()
------------------------------------------------------------------------
function luaK:indexed(fs, t, k)
  t.aux = self:exp2RK(fs, k)
  t.k = "VINDEXED"
end

------------------------------------------------------------------------
--
-- * used only in (lparser) luaY:subexpr()
------------------------------------------------------------------------
function luaK:prefix(fs, op, e)
  if op == "OPR_MINUS" then
    self:exp2val(fs, e)
    if e.k == "VK" and self:ttisnumber(fs.f.k[e.info]) then
      e.info = self:numberK(fs, -self:nvalue(fs.f.k[e.info]))
    else
      self:exp2anyreg(fs, e)
      self:freeexp(fs, e)
      e.info = self:codeABC(fs, "OP_UNM", 0, e.info, 0)
      e.k = "VRELOCABLE"
    end
  else  -- op == NOT
    self:codenot(fs, e)
  end
end

------------------------------------------------------------------------
--
-- * used only in (lparser) luaY:subexpr()
------------------------------------------------------------------------
function luaK:infix(fs, op, v)
  if op == "OPR_AND" then
    self:goiftrue(fs, v)
    self:patchtohere(fs, v.t)
    v.t = self.NO_JUMP
  elseif op == "OPR_OR" then
    self:goiffalse(fs, v)
    self:patchtohere(fs, v.f)
    v.f = self.NO_JUMP
  elseif op == "OPR_CONCAT" then
    self:exp2nextreg(fs, v)  -- operand must be on the 'stack'
  else
    self:exp2RK(fs, v)
  end
end

------------------------------------------------------------------------
--
-- grep "ORDER OPR" if you change these enums
-- * used only in luaK:posfix()
------------------------------------------------------------------------
luaK.arith_opc = {  -- done as a table lookup instead of a calc
  OPR_ADD = "OP_ADD",
  OPR_SUB = "OP_SUB",
  OPR_MULT = "OP_MUL",
  OPR_DIV = "OP_DIV",
  OPR_POW = "OP_POW",
}
luaK.test_opc = {  -- was ops[] in the codebinop function
  OPR_NE = "OP_EQ",
  OPR_EQ = "OP_EQ",
  OPR_LT = "OP_LT",
  OPR_LE = "OP_LE",
  OPR_GT = "OP_LT",
  OPR_GE = "OP_LE",
}
function luaK:codebinop(fs, res, op, o1, o2)
  if self.BinOpr[op] <= self.BinOpr["OPR_POW"] then  -- arithmetic operator?
    local opc = self.arith_opc[op]  -- ORDER OP
    res.info = self:codeABC(fs, opc, 0, o1, o2)
    res.k = "VRELOCABLE"
  else  -- test operator
    local cond = true
    if self.BinOpr[op] >= self.BinOpr["OPR_GT"] then  -- '>' or '>='?
      -- exchange args and replace by '<' or '<='
      o1, o2 = o2, o1  -- o1 <==> o2
    elseif op == "OPR_NE" then
      cond = false
    end
    res.info = self:condjump(fs, self.test_opc[op], cond and 1 or 0, o1, o2)
    res.k = "VJMP"
  end
end

------------------------------------------------------------------------
--
-- * used only in (lparser) luaY:subexpr()
------------------------------------------------------------------------
function luaK:posfix(fs, op, e1, e2)
  if op == "OPR_AND" then
    lua_assert(e1.t == self.NO_JUMP)  -- list must be closed
    self:dischargevars(fs, e2)
    e1.f = self:concat(fs, e1.f, e2.f)
    e1.k = e2.k; e1.info = e2.info; e1.aux = e2.aux; e1.t = e2.t
  elseif op == "OPR_OR" then
    lua_assert(e1.f == self.NO_JUMP)  -- list must be closed
    self:dischargevars(fs, e2)
    e1.t = self:concat(fs, e1.t, e2.t)
    e1.k = e2.k; e1.info = e2.info; e1.aux = e2.aux; e1.f = e2.f
  elseif op == "OPR_CONCAT" then
    self:exp2val(fs, e2)
    if e2.k == "VRELOCABLE"
       and luaP:GET_OPCODE(self:getcode(fs, e2)) == "OP_CONCAT" then
      lua_assert(e1.info == luaP:GETARG_B(self:getcode(fs, e2)) - 1)
      self:freeexp(fs, e1)
      luaP:SETARG_B(self:getcode(fs, e2), e1.info)
      e1.k = e2.k; e1.info = e2.info
    else
      self:exp2nextreg(fs, e2)
      self:freeexp(fs, e2)
      self:freeexp(fs, e1)
      e1.info = self:codeABC(fs, "OP_CONCAT", 0, e1.info, e2.info)
      e1.k = "VRELOCABLE"
    end
  else
    local o1 = self:exp2RK(fs, e1)
    local o2 = self:exp2RK(fs, e2)
    self:freeexp(fs, e2)
    self:freeexp(fs, e1)
    self:codebinop(fs, e1, op, o1, o2)
  end
end

------------------------------------------------------------------------
-- adjusts debug information for last instruction written, in order to
-- change the line where item comes into existence
-- * used in (lparser) luaY:funcargs(), luaY:forbody(), luaY:funcstat()
------------------------------------------------------------------------
function luaK:fixline(fs, line)
  fs.f.lineinfo[fs.pc - 1] = line
end

------------------------------------------------------------------------
-- general function to write an instruction into the instruction buffer,
-- sets debug information too
-- * used in luaK:codeABC(), luaK:codeABx()
-- * called directly by (lparser) luaY:whilestat()
------------------------------------------------------------------------
function luaK:code(fs, i, line)
  local f = fs.f
  self:dischargejpc(fs)  -- 'pc' will change
  -- put new instruction in code array
  luaY:growvector(fs.L, f.code, fs.pc, f.sizecode, nil,
                  luaY.MAX_INT, "code size overflow")
  f.code[fs.pc] = i
  -- save corresponding line information
  luaY:growvector(fs.L, f.lineinfo, fs.pc, f.sizelineinfo, nil,
                  luaY.MAX_INT, "code size overflow")
  f.lineinfo[fs.pc] = line
  local pc = fs.pc
  fs.pc = fs.pc + 1
  return pc
end

------------------------------------------------------------------------
-- writes an instruction of type ABC
-- * calls luaK:code()
------------------------------------------------------------------------
function luaK:codeABC(fs, o, a, b, c)
  lua_assert(luaP:getOpMode(o) == "iABC")
  return self:code(fs, luaP:CREATE_ABC(o, a, b, c), fs.ls.lastline)
end

------------------------------------------------------------------------
-- writes an instruction of type ABx
-- * calls luaK:code(), called by luaK:codeAsBx()
------------------------------------------------------------------------
function luaK:codeABx(fs, o, a, bc)
  lua_assert(luaP:getOpMode(o) == "iABx" or luaP:getOpMode(o) == "iAsBx")
  return self:code(fs, luaP:CREATE_ABx(o, a, bc), fs.ls.lastline)
end
