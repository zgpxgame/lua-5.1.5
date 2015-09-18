--[[--------------------------------------------------------------------

  lparser.lua
  Lua 5 parser in Lua
  This file is part of Yueliang.

  Copyright (c) 2005-2006 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- Notes:
-- * LUA_COMPATUPSYNTAX option changed into a comment block
-- * Added:
--   some constants, see below
--   luaY:newproto (from lfunc.c) -- called by lparser, lundump, luac
--   luaY:int2fb (from lobject.c) -- called by lparser, ltests
--   luaY:log2 (from lobject.c) -- called by lparser, ltests, ltable
--   luaY:growvector (from lmem.h) -- skeleton only, limit checking
-- * Unimplemented:
--   luaG_checkcode() in lua_assert is not currently implemented
----------------------------------------------------------------------]]

--requires luaP, luaX, luaK
luaY = {}

------------------------------------------------------------------------
-- constants used by parser
-- * MAX_INT duplicated in luaX.MAX_INT
------------------------------------------------------------------------
luaY.MAX_INT = 2147483645  -- INT_MAX-2 for 32-bit systems (llimits.h)
luaY.MAXVARS = 200  -- (llimits.h)
luaY.MAXUPVALUES = 32  -- (llimits.h)
luaY.MAXPARAMS = 100  -- (llimits.h)
luaY.LUA_MAXPARSERLEVEL = 200  -- (llimits.h)
luaY.LUA_MULTRET = -1  -- (lua.h)
luaY.MAXSTACK = 250  -- (llimits.h, used in lcode.lua)

------------------------------------------------------------------------
-- Expression descriptor
------------------------------------------------------------------------

--[[--------------------------------------------------------------------
-- * expkind changed to string constants; luaY:assignment was the only
--   function to use a relational operator with this enumeration
-- VVOID       -- no value
-- VNIL        -- no value
-- VTRUE       -- no value
-- VFALSE      -- no value
-- VK          -- info = index of constant in 'k'
-- VLOCAL      -- info = local register
-- VUPVAL,     -- info = index of upvalue in 'upvalues'
-- VGLOBAL     -- info = index of table; aux = index of global name in 'k'
-- VINDEXED    -- info = table register; aux = index register (or 'k')
-- VJMP        -- info = instruction pc
-- VRELOCABLE  -- info = instruction pc
-- VNONRELOC   -- info = result register
-- VCALL       -- info = result register
----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- struct expdesc:
--   k  -- (enum: expkind)
--   info, aux
--   t  -- patch list of 'exit when true'
--   f  -- patch list of 'exit when false'
----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- state needed to generate code for a given function
-- struct FuncState:
--   f  -- current function header (table: Proto)
--   h  -- table to find (and reuse) elements in 'k' (table: Table)
--   prev  -- enclosing function (table: FuncState)
--   ls  -- lexical state (table: LexState)
--   L  -- copy of the Lua state (table: lua_State)
--   bl  -- chain of current blocks (table: BlockCnt)
--   pc  -- next position to code (equivalent to 'ncode')
--   lasttarget   -- 'pc' of last 'jump target'
--   jpc  -- list of pending jumps to 'pc'
--   freereg  -- first free register
--   nk  -- number of elements in 'k'
--   np  -- number of elements in 'p'
--   nlocvars  -- number of elements in 'locvars'
--   nactvar  -- number of active local variables
--   upvalues[MAXUPVALUES]  -- upvalues (table: expdesc)
--   actvar[MAXVARS]  -- declared-variable stack
----------------------------------------------------------------------]]

------------------------------------------------------------------------
-- converts an integer to a "floating point byte", represented as
-- (mmmmmxxx), where the real value is (xxx) * 2^(mmmmm)
------------------------------------------------------------------------

function luaY:int2fb(x)
  local m = 0  -- mantissa
  while x >= 8 do
    x = math.floor((x + 1) / 2)
    m = m + 1
  end
  return m * 8 + x
end

------------------------------------------------------------------------
-- calculates log value for encoding the hash portion's size
-- * there are 2 implementations: the shorter one uses math.frexp
--   while the other one is based on the original code, so pick one...
-- * since LUA_NUMBER is assumed to be a double elsewhere, the
--   shorter version works fine
------------------------------------------------------------------------
--[[
function luaY:log2(x)
  -- this is based on the original lua0_log2 in lobject.c
  local log_8 = {  -- index starts from 1
    0,
    1,1,
    2,2,2,2,
    3,3,3,3,3,3,3,3,
    4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,
    5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
    6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
    6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
    7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
    7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
    7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
    7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
  }
  if x >= 65536 then
    if x >= 16777216 then
      return log_8[math.mod(math.floor(x / 16777216), 256)] + 24
    else
      return log_8[math.mod(math.floor(x / 65536), 256)] + 16
    end
  else
    if x >= 256 then
      return log_8[math.mod(math.floor(x / 256), 256)] + 8
    elseif x > 0 then
      return log_8[math.mod(x, 256)]
    end
    return -1  -- special 'log' for 0
  end
end
--]]
-- [[
function luaY:log2(x)
  -- math result is always one more than lua0_log2()
  local mn, ex = math.frexp(x)
  return ex - 1
end
--]]

------------------------------------------------------------------------
-- this is a stripped-down luaM_growvector (from lmem.h) which is a
-- macro based on luaM_growaux (in lmem.c); all this function does is
-- reproduce the size limit checking logic of the original function
-- so that error behaviour is identical; all arguments preserved for
-- convenience, even those which are unused
-- * set the t field to nil, since this originally does a sizeof(t)
-- * size (originally a pointer) is never updated, their final values
--   are set by luaY:close_func(), so overall things should still work
------------------------------------------------------------------------
function luaY:growvector(L, v, nelems, size, t, limit, e)
  local MINSIZEARRAY = 4  -- defined in lmem.c
  -- still have at least MINSIZEARRAY free places
  if nelems >= limit - MINSIZEARRAY then
    luaX:syntaxerror(ls, e)
  end
end

-- getlocvar(fs, i) has been placed with functions for locals, changed
-- into a function

------------------------------------------------------------------------
-- tracks and limits parsing depth, assert check at end of parsing
------------------------------------------------------------------------
function luaY:enterlevel(ls)
  ls.nestlevel = ls.nestlevel + 1
  if ls.nestlevel > self.LUA_MAXPARSERLEVEL then
    luaX:syntaxerror(ls, "too many syntax levels")
  end
end

------------------------------------------------------------------------
-- tracks parsing depth, a pair with luaY:enterlevel()
------------------------------------------------------------------------
function luaY:leavelevel(ls)
  ls.nestlevel = ls.nestlevel - 1
end

------------------------------------------------------------------------
-- nodes for block list (list of active blocks)
------------------------------------------------------------------------
--[[--------------------------------------------------------------------
-- struct BlockCnt:
--   previous  -- chain (table: struct BlockCnt)
--   breaklist  -- list of jumps out of this loop
--   nactvar  -- # active local variables outside the breakable structure
--   upval  -- true if some variable in the block is an upvalue (boolean)
--   isbreakable  -- true if 'block' is a loop (boolean)
----------------------------------------------------------------------]]

------------------------------------------------------------------------
-- prototypes for recursive non-terminal functions
------------------------------------------------------------------------
-- prototypes deleted; not required in Lua

------------------------------------------------------------------------
-- reads in next token
-- * luaX:lex fills in ls.t.seminfo too, lookahead is handled
------------------------------------------------------------------------
function luaY:next(ls)
  ls.lastline = ls.linenumber
  if ls.lookahead.token ~= "TK_EOS" then  -- is there a look-ahead token?
    ls.t.token = ls.lookahead.token  -- use this one
    ls.t.seminfo = ls.lookahead.seminfo
    ls.lookahead.token = "TK_EOS"  -- and discharge it
  else
    ls.t.token = luaX:lex(ls, ls.t)  -- read next token
  end
end

------------------------------------------------------------------------
-- peek at next token (single lookahead only)
------------------------------------------------------------------------
function luaY:lookahead(ls)
  lua_assert(ls.lookahead.token == "TK_EOS")
  ls.lookahead.token = luaX:lex(ls, ls.lookahead)
end

------------------------------------------------------------------------
-- throws a syntax error if token expected is not there
------------------------------------------------------------------------
function luaY:error_expected(ls, token)
  luaX:syntaxerror(ls,
    string.format("`%s' expected", luaX:token2str(ls, token)))
end

------------------------------------------------------------------------
-- tests for a token, returns outcome
-- * return value changed to boolean
------------------------------------------------------------------------
function luaY:testnext(ls, c)
  if ls.t.token == c then
    self:next(ls)
    return true
  else
    return false
  end
end

------------------------------------------------------------------------
-- check for existence of a token, throws error if not found
------------------------------------------------------------------------
function luaY:check(ls, c)
  if not self:testnext(ls, c) then
    self:error_expected(ls, c)
  end
end

------------------------------------------------------------------------
-- throws error if condition not matched
------------------------------------------------------------------------
function luaY:check_condition(ls, c, msg)
  if not c then luaX:syntaxerror(ls, msg) end
end

------------------------------------------------------------------------
-- verifies token conditions are met or else throw error
------------------------------------------------------------------------
function luaY:check_match(ls, what, who, where)
  if not self:testnext(ls, what) then
    if where == ls.linenumber then
      self:error_expected(ls, what)
    else
      luaX:syntaxerror(ls, string.format(
        "`%s' expected (to close `%s' at line %d)",
        luaX:token2str(ls, what), luaX:token2str(ls, who), where))
    end
  end
end

------------------------------------------------------------------------
-- expect that token is a name, return the name
------------------------------------------------------------------------
function luaY:str_checkname(ls)
  self:check_condition(ls, ls.t.token == "TK_NAME", "<name> expected")
  local ts = ls.t.seminfo
  self:next(ls)
  return ts
end

------------------------------------------------------------------------
-- initialize a struct expdesc, expression description data structure
------------------------------------------------------------------------
function luaY:init_exp(e, k, i)
  e.f, e.t = luaK.NO_JUMP, luaK.NO_JUMP
  e.k = k
  e.info = i
end

------------------------------------------------------------------------
-- adds given string s in string pool, sets e as VK
------------------------------------------------------------------------
function luaY:codestring(ls, e, s)
  self:init_exp(e, "VK", luaK:stringK(ls.fs, s))
end

------------------------------------------------------------------------
-- consume a name token, adds it to string pool, sets e as VK
------------------------------------------------------------------------
function luaY:checkname(ls, e)
  self:codestring(ls, e, self:str_checkname(ls))
end

------------------------------------------------------------------------
-- returns local variable entry struct for a function
------------------------------------------------------------------------
function luaY:getlocvar(fs, i)
  return fs.f.locvars[ fs.actvar[i] ]
end

------------------------------------------------------------------------
-- creates struct entry for a local variable
-- * used by new_localvar() only
------------------------------------------------------------------------
function luaY:registerlocalvar(ls, varname)
  local fs = ls.fs
  local f = fs.f
  self:growvector(ls.L, f.locvars, fs.nlocvars, f.sizelocvars,
                  nil, self.MAX_INT, "")
  f.locvars[fs.nlocvars] = {} -- LocVar
  f.locvars[fs.nlocvars].varname = varname
  local nlocvars = fs.nlocvars
  fs.nlocvars = fs.nlocvars + 1
  return nlocvars
end

------------------------------------------------------------------------
-- register a local variable, set in active variable list
-- * used in new_localvarstr(), parlist(), fornum(), forlist(),
--   localfunc(), localstat()
------------------------------------------------------------------------
function luaY:new_localvar(ls, name, n)
  local fs = ls.fs
  luaX:checklimit(ls, fs.nactvar + n + 1, self.MAXVARS, "local variables")
  fs.actvar[fs.nactvar + n] = self:registerlocalvar(ls, name)
end

------------------------------------------------------------------------
-- adds nvars number of new local variables, set debug information
-- * used in create_local(), code_params(), forbody(), localfunc(),
--   localstat()
------------------------------------------------------------------------
function luaY:adjustlocalvars(ls, nvars)
  local fs = ls.fs
  fs.nactvar = fs.nactvar + nvars
  for i = 1, nvars do
    self:getlocvar(fs, fs.nactvar - i).startpc = fs.pc
  end
end

------------------------------------------------------------------------
-- removes a number of locals, set debug information
-- * used in leaveblock(), close_func()
------------------------------------------------------------------------
function luaY:removevars(ls, tolevel)
  local fs = ls.fs
  while fs.nactvar > tolevel do
    fs.nactvar = fs.nactvar - 1
    self:getlocvar(fs, fs.nactvar).endpc = fs.pc
  end
end

------------------------------------------------------------------------
-- creates a new local variable given a name and an offset from nactvar
-- * used in fornum(), forlist() for loop variables; in create_local()
------------------------------------------------------------------------
function luaY:new_localvarstr(ls, name, n)
  self:new_localvar(ls, name, n)
end

------------------------------------------------------------------------
-- creates a single local variable and activates it
-- * used only in code_params() for "arg", body() for "self"
------------------------------------------------------------------------
function luaY:create_local(ls, name)
  self:new_localvarstr(ls, name, 0)
  self:adjustlocalvars(ls, 1)
end

------------------------------------------------------------------------
-- returns an existing upvalue index based on the given name, or
-- creates a new upvalue struct entry and returns the new index
-- * used only in singlevaraux()
------------------------------------------------------------------------
function luaY:indexupvalue(fs, name, v)
  local f = fs.f
  for i = 0, f.nups - 1 do
    if fs.upvalues[i].k == v.k and fs.upvalues[i].info == v.info then
      lua_assert(fs.f.upvalues[i] == name)
      return i
    end
  end
  -- new one
  luaX:checklimit(fs.ls, f.nups + 1, self.MAXUPVALUES, "upvalues")
  self:growvector(fs.L, fs.f.upvalues, f.nups, fs.f.sizeupvalues,
                  nil, self.MAX_INT, "")
  fs.f.upvalues[f.nups] = name
  -- this is a partial copy; only k & info fields used
  fs.upvalues[f.nups] = { k = v.k, info = v.info }
  local nups = f.nups
  f.nups = f.nups + 1
  return nups
end

------------------------------------------------------------------------
-- search the local variable namespace of the given fs for a match
-- * used only in singlevaraux()
------------------------------------------------------------------------
function luaY:searchvar(fs, n)
  for i = fs.nactvar - 1, 0, -1 do
    if n == self:getlocvar(fs, i).varname then
      return i
    end
  end
  return -1  -- not found
end

------------------------------------------------------------------------
-- * mark upvalue flags in function states up to a given level
-- * used only in singlevaraux()
------------------------------------------------------------------------
function luaY:markupval(fs, level)
  local bl = fs.bl
  while bl and bl.nactvar > level do bl = bl.previous end
  if bl then bl.upval = true end
end

------------------------------------------------------------------------
-- handle locals, globals and upvalues and related processing
-- * search mechanism is recursive, calls itself to search parents
-- * used only in singlevar()
------------------------------------------------------------------------
function luaY:singlevaraux(fs, n, var, base)
  if fs == nil then  -- no more levels?
    self:init_exp(var, "VGLOBAL", luaP.NO_REG)  -- default is global variable
  else
    local v = self:searchvar(fs, n)  -- look up at current level
    if v >= 0 then
      self:init_exp(var, "VLOCAL", v)
      if base == 0 then
        self:markupval(fs, v)  -- local will be used as an upval
      end
    else  -- not found at current level; try upper one
      self:singlevaraux(fs.prev, n, var, 0)
      if var.k == "VGLOBAL" then
        if base ~= 0 then
          var.info = luaK:stringK(fs, n)  -- info points to global name
        end
      else  -- LOCAL or UPVAL
        var.info = self:indexupvalue(fs, n, var)
        var.k = "VUPVAL"  -- upvalue in this level
      end
    end--if v
  end--if fs
end

------------------------------------------------------------------------
-- consume a name token, creates a variable (global|local|upvalue)
-- * used in prefixexp(), funcname()
------------------------------------------------------------------------
function luaY:singlevar(ls, var, base)
  local varname = self:str_checkname(ls)
  self:singlevaraux(ls.fs, varname, var, base)
  return varname
end

------------------------------------------------------------------------
-- adjust RHS to match LHS in an assignment
-- * used in assignment(), forlist(), localstat()
------------------------------------------------------------------------
function luaY:adjust_assign(ls, nvars, nexps, e)
  local fs = ls.fs
  local extra = nvars - nexps
  if e.k == "VCALL" then
    extra = extra + 1  -- includes call itself
    if extra <= 0 then extra = 0
    else luaK:reserveregs(fs, extra - 1) end
    luaK:setcallreturns(fs, e, extra)  -- call provides the difference
  else
    if e.k ~= "VVOID" then luaK:exp2nextreg(fs, e) end  -- close last expression
    if extra > 0 then
      local reg = fs.freereg
      luaK:reserveregs(fs, extra)
      luaK:_nil(fs, reg, extra)
    end
  end
end

------------------------------------------------------------------------
-- perform initialization for a parameter list, adds arg if needed
-- * used only in parlist()
------------------------------------------------------------------------
function luaY:code_params(ls, nparams, dots)
  local fs = ls.fs
  self:adjustlocalvars(ls, nparams)
  luaX:checklimit(ls, fs.nactvar, self.MAXPARAMS, "parameters")
  fs.f.numparams = fs.nactvar
  fs.f.is_vararg = dots and 1 or 0
  if dots then
    self:create_local(ls, "arg")
  end
  luaK:reserveregs(fs, fs.nactvar)  -- reserve register for parameters
end

------------------------------------------------------------------------
-- enters a code unit, initializes elements
------------------------------------------------------------------------
function luaY:enterblock(fs, bl, isbreakable)
  bl.breaklist = luaK.NO_JUMP
  bl.isbreakable = isbreakable
  bl.nactvar = fs.nactvar
  bl.upval = false
  bl.previous = fs.bl
  fs.bl = bl
  lua_assert(fs.freereg == fs.nactvar)
end

------------------------------------------------------------------------
-- leaves a code unit, close any upvalues
------------------------------------------------------------------------
function luaY:leaveblock(fs)
  local bl = fs.bl
  fs.bl = bl.previous
  self:removevars(fs.ls, bl.nactvar)
  if bl.upval then
    luaK:codeABC(fs, "OP_CLOSE", bl.nactvar, 0, 0)
  end
  lua_assert(bl.nactvar == fs.nactvar)
  fs.freereg = fs.nactvar  -- free registers
  luaK:patchtohere(fs, bl.breaklist)
end

------------------------------------------------------------------------
-- implement the instantiation of a function prototype, append list of
-- upvalues after the instantiation instruction
-- * used only in body()
------------------------------------------------------------------------
function luaY:pushclosure(ls, func, v)
  local fs = ls.fs
  local f = fs.f
  self:growvector(ls.L, f.p, fs.np, f.sizep, nil,
                  luaP.MAXARG_Bx, "constant table overflow")
  f.p[fs.np] = func.f
  fs.np = fs.np + 1
  self:init_exp(v, "VRELOCABLE", luaK:codeABx(fs, "OP_CLOSURE", 0, fs.np - 1))
  for i = 0, func.f.nups - 1 do
    local o = (func.upvalues[i].k == "VLOCAL") and "OP_MOVE" or "OP_GETUPVAL"
    luaK:codeABC(fs, o, 0, func.upvalues[i].info, 0)
  end
end

------------------------------------------------------------------------
-- initialize a new function prototype structure
------------------------------------------------------------------------
function luaY:newproto(L)
  local f = {} -- Proto
  -- luaC_link deleted
  f.k = {}
  f.sizek = 0
  f.p = {}
  f.sizep = 0
  f.code = {}
  f.sizecode = 0
  f.sizelineinfo = 0
  f.sizeupvalues = 0
  f.nups = 0
  f.upvalues = {}
  f.numparams = 0
  f.is_vararg = 0
  f.maxstacksize = 0
  f.lineinfo = {}
  f.sizelocvars = 0
  f.locvars = {}
  f.lineDefined = 0
  f.source = nil
  return f
end

------------------------------------------------------------------------
-- opening of a function
------------------------------------------------------------------------
function luaY:open_func(ls, fs)
  local f = self:newproto(ls.L)
  fs.f = f
  fs.prev = ls.fs  -- linked list of funcstates
  fs.ls = ls
  fs.L = ls.L
  ls.fs = fs
  fs.pc = 0
  fs.lasttarget = 0
  fs.jpc = luaK.NO_JUMP
  fs.freereg = 0
  fs.nk = 0
  fs.h = {}  -- constant table; was luaH_new call
  fs.np = 0
  fs.nlocvars = 0
  fs.nactvar = 0
  fs.bl = nil
  f.source = ls.source
  f.maxstacksize = 2  -- registers 0/1 are always valid
end

------------------------------------------------------------------------
-- closing of a function
------------------------------------------------------------------------
function luaY:close_func(ls)
  local L = ls.L
  local fs = ls.fs
  local f = fs.f
  self:removevars(ls, 0)
  luaK:codeABC(fs, "OP_RETURN", 0, 1, 0)  -- final return
  -- luaM_reallocvector deleted for f->code, f->lineinfo, f->k, f->p,
  -- f->locvars, f->upvalues; not required for Lua table arrays
  f.sizecode = fs.pc
  f.sizelineinfo = fs.pc
  f.sizek = fs.nk
  f.sizep = fs.np
  f.sizelocvars = fs.nlocvars
  f.sizeupvalues = f.nups
  --lua_assert(luaG_checkcode(f))  -- currently not implemented
  lua_assert(fs.bl == nil)
  ls.fs = fs.prev
end

------------------------------------------------------------------------
-- parser initialization function
-- * note additional sub-tables needed for LexState, FuncState
------------------------------------------------------------------------
function luaY:parser(L, z, buff)
  local lexstate = {}  -- LexState
        lexstate.t = {}
        lexstate.lookahead = {}
  local funcstate = {}  -- FuncState
        funcstate.upvalues = {}
        funcstate.actvar = {}
  lexstate.buff = buff
  lexstate.nestlevel = 0
  luaX:setinput(L, lexstate, z, z.name)
  self:open_func(lexstate, funcstate)
  self:next(lexstate)  -- read first token
  self:chunk(lexstate)
  self:check_condition(lexstate, lexstate.t.token == "TK_EOS", "<eof> expected")
  self:close_func(lexstate)
  lua_assert(funcstate.prev == nil)
  lua_assert(funcstate.f.nups == 0)
  lua_assert(lexstate.nestlevel == 0)
  return funcstate.f
end

--[[--------------------------------------------------------------------
-- GRAMMAR RULES
----------------------------------------------------------------------]]

------------------------------------------------------------------------
-- parse a function name suffix, for function call specifications
-- * used in primaryexp(), funcname()
------------------------------------------------------------------------
function luaY:field(ls, v)
  -- field -> ['.' | ':'] NAME
  local fs = ls.fs
  local key = {}  -- expdesc
  luaK:exp2anyreg(fs, v)
  self:next(ls)  -- skip the dot or colon
  self:checkname(ls, key)
  luaK:indexed(fs, v, key)
end

------------------------------------------------------------------------
-- parse a table indexing suffix, for constructors, expressions
-- * used in recfield(), primaryexp()
------------------------------------------------------------------------
function luaY:index(ls, v)
  -- index -> '[' expr ']'
  self:next(ls)  -- skip the '['
  self:expr(ls, v)
  luaK:exp2val(ls.fs, v)
  self:check(ls, "]")
end

--[[--------------------------------------------------------------------
-- Rules for Constructors
----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- struct ConsControl:
--   v  -- last list item read (table: struct expdesc)
--   t  -- table descriptor (table: struct expdesc)
--   nh  -- total number of 'record' elements
--   na  -- total number of array elements
--   tostore  -- number of array elements pending to be stored
----------------------------------------------------------------------]]

------------------------------------------------------------------------
-- parse a table record (hash) field
-- * used in constructor()
------------------------------------------------------------------------
function luaY:recfield(ls, cc)
  -- recfield -> (NAME | '['exp1']') = exp1
  local fs = ls.fs
  local reg = ls.fs.freereg
  local key, val = {}, {}  -- expdesc
  if ls.t.token == "TK_NAME" then
    luaX:checklimit(ls, cc.nh, self.MAX_INT, "items in a constructor")
    cc.nh = cc.nh + 1
    self:checkname(ls, key)
  else  -- ls->t.token == '['
    self:index(ls, key)
  end
  self:check(ls, "=")
  luaK:exp2RK(fs, key)
  self:expr(ls, val)
  luaK:codeABC(fs, "OP_SETTABLE", cc.t.info, luaK:exp2RK(fs, key),
                                             luaK:exp2RK(fs, val))
  fs.freereg = reg  -- free registers
end

------------------------------------------------------------------------
-- emit a set list instruction if enough elements (LFIELDS_PER_FLUSH)
-- * used in constructor()
------------------------------------------------------------------------
function luaY:closelistfield(fs, cc)
  if cc.v.k == "VVOID" then return end  -- there is no list item
  luaK:exp2nextreg(fs, cc.v)
  cc.v.k = "VVOID"
  if cc.tostore == luaP.LFIELDS_PER_FLUSH then
    luaK:codeABx(fs, "OP_SETLIST", cc.t.info, cc.na - 1)  -- flush
    cc.tostore = 0  -- no more items pending
    fs.freereg = cc.t.info + 1  -- free registers
  end
end

------------------------------------------------------------------------
-- emit a set list instruction at the end of parsing list constructor
-- * used in constructor()
------------------------------------------------------------------------
function luaY:lastlistfield(fs, cc)
  if cc.tostore == 0 then return end
  if cc.v.k == "VCALL" then
    luaK:setcallreturns(fs, cc.v, self.LUA_MULTRET)
    luaK:codeABx(fs, "OP_SETLISTO", cc.t.info, cc.na - 1)
  else
    if cc.v.k ~= "VVOID" then
      luaK:exp2nextreg(fs, cc.v)
    end
    luaK:codeABx(fs, "OP_SETLIST", cc.t.info, cc.na - 1)
  end
  fs.freereg = cc.t.info + 1  -- free registers
end

------------------------------------------------------------------------
-- parse a table list (array) field
-- * used in constructor()
------------------------------------------------------------------------
function luaY:listfield(ls, cc)
  self:expr(ls, cc.v)
  luaX:checklimit(ls, cc.na, luaP.MAXARG_Bx, "items in a constructor")
  cc.na = cc.na + 1
  cc.tostore = cc.tostore + 1
end

------------------------------------------------------------------------
-- parse a table constructor
-- * used in funcargs(), simpleexp()
------------------------------------------------------------------------
function luaY:constructor(ls, t)
  -- constructor -> '{' [ field { fieldsep field } [ fieldsep ] ] '}'
  -- field -> recfield | listfield
  -- fieldsep -> ',' | ';'
  local fs = ls.fs
  local line = ls.linenumber
  local pc = luaK:codeABC(fs, "OP_NEWTABLE", 0, 0, 0)
  local cc = {}  -- ConsControl
        cc.v = {}
  cc.na, cc.nh, cc.tostore = 0, 0, 0
  cc.t = t
  self:init_exp(t, "VRELOCABLE", pc)
  self:init_exp(cc.v, "VVOID", 0)  -- no value (yet)
  luaK:exp2nextreg(ls.fs, t)  -- fix it at stack top (for gc)
  self:check(ls, "{")
  repeat
    lua_assert(cc.v.k == "VVOID" or cc.tostore > 0)
    self:testnext(ls, ";")  -- compatibility only
    if ls.t.token == "}" then break end
    self:closelistfield(fs, cc)
    local c = ls.t.token
    if c == "TK_NAME" then  -- may be listfields or recfields
      self:lookahead(ls)
      if ls.lookahead.token ~= "=" then  -- expression?
        self:listfield(ls, cc)
      else
        self:recfield(ls, cc)
      end
    elseif c == "[" then  -- constructor_item -> recfield
      self:recfield(ls, cc)
    else  -- constructor_part -> listfield
      self:listfield(ls, cc)
    end
  until not self:testnext(ls, ",") and not self:testnext(ls, ";")
  self:check_match(ls, "}", "{", line)
  self:lastlistfield(fs, cc)
  luaP:SETARG_B(fs.f.code[pc], self:int2fb(cc.na)) -- set initial array size
  luaP:SETARG_C(fs.f.code[pc], self:log2(cc.nh) + 1)  -- set initial table size
end

------------------------------------------------------------------------
-- parse the arguments (parameters) of a function declaration
-- * used in body()
------------------------------------------------------------------------
function luaY:parlist(ls)
  -- parlist -> [ param { ',' param } ]
  local nparams = 0
  local dots = false
  if ls.t.token ~= ")" then  -- is 'parlist' not empty?
    repeat
      local c = ls.t.token
      if c == "TK_DOTS" then
        dots = true
        self:next(ls)
      elseif c == "TK_NAME" then
        self:new_localvar(ls, self:str_checkname(ls), nparams)
        nparams = nparams + 1
      else
        luaX:syntaxerror(ls, "<name> or `...' expected")
      end
    until dots or not self:testnext(ls, ",")
  end
  self:code_params(ls, nparams, dots)
end

------------------------------------------------------------------------
-- parse function declaration body
-- * used in simpleexp(), localfunc(), funcstat()
------------------------------------------------------------------------
function luaY:body(ls, e, needself, line)
  -- body ->  '(' parlist ')' chunk END
  local new_fs = {}  -- FuncState
        new_fs.upvalues = {}
        new_fs.actvar = {}
  self:open_func(ls, new_fs)
  new_fs.f.lineDefined = line
  self:check(ls, "(")
  if needself then
    self:create_local(ls, "self")
  end
  self:parlist(ls)
  self:check(ls, ")")
  self:chunk(ls)
  self:check_match(ls, "TK_END", "TK_FUNCTION", line)
  self:close_func(ls)
  self:pushclosure(ls, new_fs, e)
end

------------------------------------------------------------------------
-- parse a list of comma-separated expressions
-- * used is multiple locations
------------------------------------------------------------------------
function luaY:explist1(ls, v)
  -- explist1 -> expr { ',' expr }
  local n = 1  -- at least one expression
  self:expr(ls, v)
  while self:testnext(ls, ",") do
    luaK:exp2nextreg(ls.fs, v)
    self:expr(ls, v)
    n = n + 1
  end
  return n
end

------------------------------------------------------------------------
-- parse the parameters of a function call
-- * contrast with parlist(), used in function declarations
-- * used in primaryexp()
------------------------------------------------------------------------
function luaY:funcargs(ls, f)
  local fs = ls.fs
  local args = {}  -- expdesc
  local nparams
  local line = ls.linenumber
  local c = ls.t.token
  if c == "(" then  -- funcargs -> '(' [ explist1 ] ')'
    if line ~= ls.lastline then
      luaX:syntaxerror(ls, "ambiguous syntax (function call x new statement)")
    end
    self:next(ls)
    if ls.t.token == ")" then  -- arg list is empty?
      args.k = "VVOID"
    else
      self:explist1(ls, args)
      luaK:setcallreturns(fs, args, self.LUA_MULTRET)
    end
    self:check_match(ls, ")", "(", line)
  elseif c == "{" then  -- funcargs -> constructor
    self:constructor(ls, args)
  elseif c == "TK_STRING" then  -- funcargs -> STRING
    self:codestring(ls, args, ls.t.seminfo)
    self:next(ls)  -- must use 'seminfo' before 'next'
  else
    luaX:syntaxerror(ls, "function arguments expected")
    return
  end
  lua_assert(f.k == "VNONRELOC")
  local base = f.info  -- base register for call
  if args.k == "VCALL" then
    nparams = self.LUA_MULTRET  -- open call
  else
    if args.k ~= "VVOID" then
      luaK:exp2nextreg(fs, args)  -- close last argument
    end
    nparams = fs.freereg - (base + 1)
  end
  self:init_exp(f, "VCALL", luaK:codeABC(fs, "OP_CALL", base, nparams + 1, 2))
  luaK:fixline(fs, line)
  fs.freereg = base + 1  -- call remove function and arguments and leaves
                         -- (unless changed) one result
end

--[[--------------------------------------------------------------------
-- Expression parsing
----------------------------------------------------------------------]]

------------------------------------------------------------------------
-- parses an expression in parentheses or a single variable
-- * used in primaryexp()
------------------------------------------------------------------------
function luaY:prefixexp(ls, v)
  -- prefixexp -> NAME | '(' expr ')'
  local c = ls.t.token
  if c == "(" then
    local line = ls.linenumber
    self:next(ls)
    self:expr(ls, v)
    self:check_match(ls, ")", "(", line)
    luaK:dischargevars(ls.fs, v)
  elseif c == "TK_NAME" then
    self:singlevar(ls, v, 1)
  -- LUA_COMPATUPSYNTAX
--[[
  elseif c == "%" then  -- for compatibility only
    local line = ls.linenumber
    self:next(ls)  -- skip '%'
    local varname = self:singlevar(ls, v, 1)
    if v.k ~= "VUPVAL" then
      luaX:errorline(ls, "global upvalues are obsolete", varname, line)
    end
--]]
  else
    luaX:syntaxerror(ls, "unexpected symbol")
  end--if c
  return
end

------------------------------------------------------------------------
-- parses a prefixexp (an expression in parentheses or a single variable)
-- or a function call specification
-- * used in simpleexp(), assignment(), exprstat()
------------------------------------------------------------------------
function luaY:primaryexp(ls, v)
  -- primaryexp ->
  --    prefixexp { '.' NAME | '[' exp ']' | ':' NAME funcargs | funcargs }
  local fs = ls.fs
  self:prefixexp(ls, v)
  while true do
    local c = ls.t.token
    if c == "." then  -- field
      self:field(ls, v)
    elseif c == "[" then  -- '[' exp1 ']'
      local key = {}  -- expdesc
      luaK:exp2anyreg(fs, v)
      self:index(ls, key)
      luaK:indexed(fs, v, key)
    elseif c == ":" then  -- ':' NAME funcargs
      local key = {}  -- expdesc
      self:next(ls)
      self:checkname(ls, key)
      luaK:_self(fs, v, key)
      self:funcargs(ls, v)
    elseif c == "(" or c == "TK_STRING" or c == "{" then  -- funcargs
      luaK:exp2nextreg(fs, v)
      self:funcargs(ls, v)
    else
      return
    end--if c
  end--while
end

------------------------------------------------------------------------
-- parses general expression types, constants handled here
-- * used in subexpr()
------------------------------------------------------------------------
function luaY:simpleexp(ls, v)
  -- simpleexp -> NUMBER | STRING | NIL | TRUE | FALSE | constructor
  --           | FUNCTION body | primaryexp
  local c = ls.t.token
  if c == "TK_NUMBER" then
    self:init_exp(v, "VK", luaK:numberK(ls.fs, ls.t.seminfo))
    self:next(ls)  -- must use 'seminfo' before 'next'
  elseif c == "TK_STRING" then
    self:codestring(ls, v, ls.t.seminfo)
    self:next(ls)  -- must use 'seminfo' before 'next'
  elseif c == "TK_NIL" then
    self:init_exp(v, "VNIL", 0)
    self:next(ls)
  elseif c == "TK_TRUE" then
    self:init_exp(v, "VTRUE", 0)
    self:next(ls)
  elseif c == "TK_FALSE" then
    self:init_exp(v, "VFALSE", 0)
    self:next(ls)
  elseif c == "{" then  -- constructor
    self:constructor(ls, v)
  elseif c == "TK_FUNCTION" then
    self:next(ls)
    self:body(ls, v, false, ls.linenumber)
  else
    self:primaryexp(ls, v)
  end--if c
end

------------------------------------------------------------------------
-- Translates unary operators tokens if found, otherwise returns
-- OPR_NOUNOPR. getunopr() and getbinopr() are used in subexpr().
-- * used in subexpr()
------------------------------------------------------------------------
function luaY:getunopr(op)
  if op == "TK_NOT" then
    return "OPR_NOT"
  elseif op == "-" then
    return "OPR_MINUS"
  else
    return "OPR_NOUNOPR"
  end
end

------------------------------------------------------------------------
-- Translates binary operator tokens if found, otherwise returns
-- OPR_NOBINOPR. Code generation uses OPR_* style tokens.
-- * used in subexpr()
------------------------------------------------------------------------
luaY.getbinopr_table = {
  ["+"] = "OPR_ADD",
  ["-"] = "OPR_SUB",
  ["*"] = "OPR_MULT",
  ["/"] = "OPR_DIV",
  ["^"] = "OPR_POW",
  ["TK_CONCAT"] = "OPR_CONCAT",
  ["TK_NE"] = "OPR_NE",
  ["TK_EQ"] = "OPR_EQ",
  ["<"] = "OPR_LT",
  ["TK_LE"] = "OPR_LE",
  [">"] = "OPR_GT",
  ["TK_GE"] = "OPR_GE",
  ["TK_AND"] = "OPR_AND",
  ["TK_OR"] = "OPR_OR",
}
function luaY:getbinopr(op)
  local opr = self.getbinopr_table[op]
  if opr then return opr else return "OPR_NOBINOPR" end
end

------------------------------------------------------------------------
-- the following priority table consists of pairs of left/right values
-- for binary operators (was a static const struct); grep for ORDER OPR
------------------------------------------------------------------------
luaY.priority = {
  {6, 6}, {6, 6}, {7, 7}, {7, 7},  -- arithmetic
  {10, 9}, {5, 4},                 -- power and concat (right associative)
  {3, 3}, {3, 3},                  -- equality
  {3, 3}, {3, 3}, {3, 3}, {3, 3},  -- order
  {2, 2}, {1, 1}                   -- logical (and/or)
}

luaY.UNARY_PRIORITY = 8  -- priority for unary operators

------------------------------------------------------------------------
-- subexpr -> (simpleexp | unop subexpr) { binop subexpr }
-- where 'binop' is any binary operator with a priority higher than 'limit'
------------------------------------------------------------------------

------------------------------------------------------------------------
-- * for priority lookups with self.priority[], 1=left and 2=right
--
-- Parse subexpressions. Includes handling of unary operators and binary
-- operators. A subexpr is given the rhs priority level of the operator
-- immediately left of it, if any (limit is -1 if none,) and if a binop
-- is found, limit is compared with the lhs priority level of the binop
-- in order to determine which executes first.
--
-- * recursively called
-- * used in expr()
------------------------------------------------------------------------
function luaY:subexpr(ls, v, limit)
  self:enterlevel(ls)
  local uop = self:getunopr(ls.t.token)
  if uop ~= "OPR_NOUNOPR" then
    self:next(ls)
    self:subexpr(ls, v, self.UNARY_PRIORITY)
    luaK:prefix(ls.fs, uop, v)
  else
    self:simpleexp(ls, v)
  end
  -- expand while operators have priorities higher than 'limit'
  local op = self:getbinopr(ls.t.token)
  while op ~= "OPR_NOBINOPR" and self.priority[luaK.BinOpr[op] + 1][1] > limit do
    local v2 = {}  -- expdesc
    self:next(ls)
    luaK:infix(ls.fs, op, v)
    -- read sub-expression with higher priority
    local nextop = self:subexpr(ls, v2, self.priority[luaK.BinOpr[op] + 1][2])
    luaK:posfix(ls.fs, op, v, v2)
    op = nextop
  end
  self:leavelevel(ls)
  return op  -- return first untreated operator
end

------------------------------------------------------------------------
-- Expression parsing starts here. Function subexpr is entered with the
-- left operator (which is non-existent) priority of -1, which is lower
-- than all actual operators. Expr information is returned in parm v.
-- * used in multiple locations
------------------------------------------------------------------------
function luaY:expr(ls, v)
  self:subexpr(ls, v, -1)
end

--[[--------------------------------------------------------------------
-- Rules for Statements
----------------------------------------------------------------------]]

------------------------------------------------------------------------
-- checks next token, used as a look-ahead
-- * returns boolean instead of 0|1
-- * used in retstat(), chunk()
------------------------------------------------------------------------
function luaY:block_follow(token)
  if token == "TK_ELSE" or token == "TK_ELSEIF" or token == "TK_END"
     or token == "TK_UNTIL" or token == "TK_EOS" then
    return true
  else
    return false
  end
end

------------------------------------------------------------------------
-- parse a code block or unit
-- * used in multiple functions
------------------------------------------------------------------------
function luaY:block(ls)
  -- block -> chunk
  local fs = ls.fs
  local bl = {}  -- BlockCnt
  self:enterblock(fs, bl, false)
  self:chunk(ls)
  lua_assert(bl.breaklist == luaK.NO_JUMP)
  self:leaveblock(fs)
end

------------------------------------------------------------------------
-- structure to chain all variables in the left-hand side of an
-- assignment
------------------------------------------------------------------------
--[[--------------------------------------------------------------------
-- struct LHS_assign:
--   prev  -- (table: struct LHS_assign)
--   v  -- variable (global, local, upvalue, or indexed) (table: expdesc)
----------------------------------------------------------------------]]

------------------------------------------------------------------------
-- check whether, in an assignment to a local variable, the local variable
-- is needed in a previous assignment (to a table). If so, save original
-- local value in a safe place and use this safe copy in the previous
-- assignment.
-- * used in assignment()
------------------------------------------------------------------------
function luaY:check_conflict(ls, lh, v)
  local fs = ls.fs
  local extra = fs.freereg  -- eventual position to save local variable
  local conflict = false
  while lh do
    if lh.v.k == "VINDEXED" then
      if lh.v.info == v.info then  -- conflict?
        conflict = true
        lh.v.info = extra  -- previous assignment will use safe copy
      end
      if lh.v.aux == v.info then  -- conflict?
        conflict = true
        lh.v.aux = extra  -- previous assignment will use safe copy
      end
    end
    lh = lh.prev
  end
  if conflict then
    luaK:codeABC(fs, "OP_MOVE", fs.freereg, v.info, 0)  -- make copy
    luaK:reserveregs(fs, 1)
  end
end

------------------------------------------------------------------------
-- parse a variable assignment sequence
-- * recursively called
-- * used in exprstat()
------------------------------------------------------------------------
function luaY:assignment(ls, lh, nvars)
  local e = {}  -- expdesc
  -- test was: VLOCAL <= lh->v.k && lh->v.k <= VINDEXED
  local c = lh.v.k
  self:check_condition(ls, c == "VLOCAL" or c == "VUPVAL" or c == "VGLOBAL"
                       or c == "VINDEXED", "syntax error")
  if self:testnext(ls, ",") then  -- assignment -> ',' primaryexp assignment
    local nv = {}  -- LHS_assign
          nv.v = {}
    nv.prev = lh
    self:primaryexp(ls, nv.v)
    if nv.v.k == "VLOCAL" then
      self:check_conflict(ls, lh, nv.v)
    end
    self:assignment(ls, nv, nvars + 1)
  else  -- assignment -> '=' explist1
    self:check(ls, "=")
    local nexps = self:explist1(ls, e)
    if nexps ~= nvars then
      self:adjust_assign(ls, nvars, nexps, e)
      if nexps > nvars then
        ls.fs.freereg = ls.fs.freereg - (nexps - nvars)  -- remove extra values
      end
    else
      luaK:setcallreturns(ls.fs, e, 1)  -- close last expression
      luaK:storevar(ls.fs, lh.v, e)
      return  -- avoid default
    end
  end
  self:init_exp(e, "VNONRELOC", ls.fs.freereg - 1)  -- default assignment
  luaK:storevar(ls.fs, lh.v, e)
end

------------------------------------------------------------------------
-- parse condition in a repeat statement or an if control structure
-- * used in repeatstat(), test_then_block()
------------------------------------------------------------------------
function luaY:cond(ls, v)
  -- cond -> exp
  self:expr(ls, v)  -- read condition
  if v.k == "VNIL" then v.k = "VFALSE" end  -- 'falses' are all equal here
  luaK:goiftrue(ls.fs, v)
  luaK:patchtohere(ls.fs, v.t)
end

------------------------------------------------------------------------
-- The while statement optimizes its code by coding the condition
-- after its body (and thus avoiding one jump in the loop).
------------------------------------------------------------------------

------------------------------------------------------------------------
-- maximum size of expressions for optimizing 'while' code
------------------------------------------------------------------------
if not luaY.MAXEXPWHILE then
  luaY.MAXEXPWHILE = 100
end

------------------------------------------------------------------------
-- the call 'luaK_goiffalse' may grow the size of an expression by
-- at most this:
------------------------------------------------------------------------
luaY.EXTRAEXP = 5

------------------------------------------------------------------------
-- parse a while-do control structure, body processed by block()
-- * with dynamic array sizes, MAXEXPWHILE + EXTRAEXP limits imposed by
--   the function's implementation can be removed
-- * used in statements()
------------------------------------------------------------------------
function luaY:whilestat(ls, line)
  -- whilestat -> WHILE cond DO block END
  -- array size of [MAXEXPWHILE + EXTRAEXP] no longer required
  local codeexp = {}  -- Instruction
  local fs = ls.fs
  local v = {}  -- expdesc
  local bl = {}  -- BlockCnt
  self:next(ls)  -- skip WHILE
  local whileinit = luaK:jump(fs)  -- jump to condition (which will be moved)
  local expinit = luaK:getlabel(fs)
  self:expr(ls, v)  -- parse condition
  if v.k == "VK" then v.k = "VTRUE" end  -- 'trues' are all equal here
  local lineexp = ls.linenumber
  luaK:goiffalse(fs, v)
  v.f = luaK:concat(fs, v.f, fs.jpc)
  fs.jpc = luaK.NO_JUMP
  local sizeexp = fs.pc - expinit  -- size of expression code
  if sizeexp > self.MAXEXPWHILE then
    luaX:syntaxerror(ls, "`while' condition too complex")
  end
  for i = 0, sizeexp - 1 do  -- save 'exp' code
    codeexp[i] = fs.f.code[expinit + i]
  end
  fs.pc = expinit  -- remove 'exp' code
  self:enterblock(fs, bl, true)
  self:check(ls, "TK_DO")
  local blockinit = luaK:getlabel(fs)
  self:block(ls)
  luaK:patchtohere(fs, whileinit)  -- initial jump jumps to here
  -- move 'exp' back to code
  if v.t ~= luaK.NO_JUMP then v.t = v.t + fs.pc - expinit end
  if v.f ~= luaK.NO_JUMP then v.f = v.f + fs.pc - expinit end
  for i = 0, sizeexp - 1 do
    luaK:code(fs, codeexp[i], lineexp)
  end
  self:check_match(ls, "TK_END", "TK_WHILE", line)
  self:leaveblock(fs)
  luaK:patchlist(fs, v.t, blockinit)  -- true conditions go back to loop
  luaK:patchtohere(fs, v.f)  -- false conditions finish the loop
end

------------------------------------------------------------------------
-- parse a repeat-until control structure, body parsed by block()
-- * used in statements()
------------------------------------------------------------------------
function luaY:repeatstat(ls, line)
  -- repeatstat -> REPEAT block UNTIL cond
  local fs = ls.fs
  local repeat_init = luaK:getlabel(fs)
  local v = {}  -- expdesc
  local bl = {}  -- BlockCnt
  self:enterblock(fs, bl, true)
  self:next(ls)
  self:block(ls)
  self:check_match(ls, "TK_UNTIL", "TK_REPEAT", line)
  self:cond(ls, v)
  luaK:patchlist(fs, v.f, repeat_init)
  self:leaveblock(fs)
end

------------------------------------------------------------------------
-- parse the single expressions needed in numerical for loops
-- * used in fornum()
------------------------------------------------------------------------
function luaY:exp1(ls)
  local e = {}  -- expdesc
  self:expr(ls, e)
  local k = e.k
  luaK:exp2nextreg(ls.fs, e)
  return k
end

------------------------------------------------------------------------
-- parse a for loop body for both versions of the for loop
-- * used in fornum(), forlist()
------------------------------------------------------------------------
function luaY:forbody(ls, base, line, nvars, isnum)
  local bl = {}  -- BlockCnt
  local fs = ls.fs
  self:adjustlocalvars(ls, nvars)  -- scope for all variables
  self:check(ls, "TK_DO")
  self:enterblock(fs, bl, true)  -- loop block
  local prep = luaK:getlabel(fs)
  self:block(ls)
  luaK:patchtohere(fs, prep - 1)
  local endfor = isnum and luaK:codeAsBx(fs, "OP_FORLOOP", base, luaK.NO_JUMP)
                 or luaK:codeABC(fs, "OP_TFORLOOP", base, 0, nvars - 3)
  luaK:fixline(fs, line)  -- pretend that 'OP_FOR' starts the loop
  luaK:patchlist(fs, isnum and endfor or luaK:jump(fs), prep)
  self:leaveblock(fs)
end

------------------------------------------------------------------------
-- parse a numerical for loop, calls forbody()
-- * used in forstat()
------------------------------------------------------------------------
function luaY:fornum(ls, varname, line)
  -- fornum -> NAME = exp1,exp1[,exp1] DO body
  local fs = ls.fs
  local base = fs.freereg
  self:new_localvar(ls, varname, 0)
  self:new_localvarstr(ls, "(for limit)", 1)
  self:new_localvarstr(ls, "(for step)", 2)
  self:check(ls, "=")
  self:exp1(ls)  -- initial value
  self:check(ls, ",")
  self:exp1(ls)  -- limit
  if self:testnext(ls, ",") then
    self:exp1(ls)  -- optional step
  else  -- default step = 1
    luaK:codeABx(fs, "OP_LOADK", fs.freereg, luaK:numberK(fs, 1))
    luaK:reserveregs(fs, 1)
  end
  luaK:codeABC(fs, "OP_SUB", fs.freereg - 3, fs.freereg - 3, fs.freereg - 1)
  luaK:jump(fs)
  self:forbody(ls, base, line, 3, true)
end

------------------------------------------------------------------------
-- parse a generic for loop, calls forbody()
-- * used in forstat()
------------------------------------------------------------------------
function luaY:forlist(ls, indexname)
  -- forlist -> NAME {,NAME} IN explist1 DO body
  local fs = ls.fs
  local e = {}  -- expdesc
  local nvars = 0
  local base = fs.freereg
  self:new_localvarstr(ls, "(for generator)", nvars)
  nvars = nvars + 1
  self:new_localvarstr(ls, "(for state)", nvars)
  nvars = nvars + 1
  self:new_localvar(ls, indexname, nvars)
  nvars = nvars + 1
  while self:testnext(ls, ",") do
    self:new_localvar(ls, self:str_checkname(ls), nvars)
    nvars = nvars + 1
  end
  self:check(ls, "TK_IN")
  local line = ls.linenumber
  self:adjust_assign(ls, nvars, self:explist1(ls, e), e)
  luaK:checkstack(fs, 3)  -- extra space to call generator
  luaK:codeAsBx(fs, "OP_TFORPREP", base, luaK.NO_JUMP)
  self:forbody(ls, base, line, nvars, false)
end

------------------------------------------------------------------------
-- initial parsing for a for loop, calls fornum() or forlist()
-- * used in statements()
------------------------------------------------------------------------
function luaY:forstat(ls, line)
  -- forstat -> fornum | forlist
  local fs = ls.fs
  local bl = {}  -- BlockCnt
  self:enterblock(fs, bl, false)  -- block to control variable scope
  self:next(ls)  -- skip 'for'
  local varname = self:str_checkname(ls)  -- first variable name
  local c = ls.t.token
  if c == "=" then
    self:fornum(ls, varname, line)
  elseif c == "," or c == "TK_IN" then
    self:forlist(ls, varname)
  else
    luaX:syntaxerror(ls, "`=' or `in' expected")
  end
  self:check_match(ls, "TK_END", "TK_FOR", line)
  self:leaveblock(fs)
end

------------------------------------------------------------------------
-- parse part of an if control structure, including the condition
-- * used in ifstat()
------------------------------------------------------------------------
function luaY:test_then_block(ls, v)
  -- test_then_block -> [IF | ELSEIF] cond THEN block
  self:next(ls)  -- skip IF or ELSEIF
  self:cond(ls, v)
  self:check(ls, "TK_THEN")
  self:block(ls)  -- 'then' part
end

------------------------------------------------------------------------
-- parse an if control structure
-- * used in statements()
------------------------------------------------------------------------
function luaY:ifstat(ls, line)
  -- ifstat -> IF cond THEN block {ELSEIF cond THEN block} [ELSE block] END
  local fs = ls.fs
  local v = {}  -- expdesc
  local escapelist = luaK.NO_JUMP
  self:test_then_block(ls, v)  -- IF cond THEN block
  while ls.t.token == "TK_ELSEIF" do
    escapelist = luaK:concat(fs, escapelist, luaK:jump(fs))
    luaK:patchtohere(fs, v.f)
    self:test_then_block(ls, v)  -- ELSEIF cond THEN block
  end
  if ls.t.token == "TK_ELSE" then
    escapelist = luaK:concat(fs, escapelist, luaK:jump(fs))
    luaK:patchtohere(fs, v.f)
    self:next(ls)  -- skip ELSE (after patch, for correct line info)
    self:block(ls)  -- 'else' part
  else
    escapelist = luaK:concat(fs, escapelist, v.f)
  end
  luaK:patchtohere(fs, escapelist)
  self:check_match(ls, "TK_END", "TK_IF", line)
end

------------------------------------------------------------------------
-- parse a local function statement
-- * used in statements()
------------------------------------------------------------------------
function luaY:localfunc(ls)
  local v, b = {}, {}  -- expdesc
  local fs = ls.fs
  self:new_localvar(ls, self:str_checkname(ls), 0)
  self:init_exp(v, "VLOCAL", fs.freereg)
  luaK:reserveregs(fs, 1)
  self:adjustlocalvars(ls, 1)
  self:body(ls, b, false, ls.linenumber)
  luaK:storevar(fs, v, b)
  -- debug information will only see the variable after this point!
  self:getlocvar(fs, fs.nactvar - 1).startpc = fs.pc
end

------------------------------------------------------------------------
-- parse a local variable declaration statement
-- * used in statements()
------------------------------------------------------------------------
function luaY:localstat(ls)
  -- stat -> LOCAL NAME {',' NAME} ['=' explist1]
  local nvars = 0
  local nexps
  local e = {}  -- expdesc
  repeat
    self:new_localvar(ls, self:str_checkname(ls), nvars)
    nvars = nvars + 1
  until not self:testnext(ls, ",")
  if self:testnext(ls, "=") then
    nexps = self:explist1(ls, e)
  else
    e.k = "VVOID"
    nexps = 0
  end
  self:adjust_assign(ls, nvars, nexps, e)
  self:adjustlocalvars(ls, nvars)
end

------------------------------------------------------------------------
-- parse a function name specification
-- * used in funcstat()
------------------------------------------------------------------------
function luaY:funcname(ls, v)
  -- funcname -> NAME {field} [':' NAME]
  local needself = false
  self:singlevar(ls, v, 1)
  while ls.t.token == "." do
    self:field(ls, v)
  end
  if ls.t.token == ":" then
    needself = true
    self:field(ls, v)
  end
  return needself
end

------------------------------------------------------------------------
-- parse a function statement
-- * used in statements()
------------------------------------------------------------------------
function luaY:funcstat(ls, line)
  -- funcstat -> FUNCTION funcname body
  local v, b = {}, {}  -- expdesc
  self:next(ls)  -- skip FUNCTION
  local needself = self:funcname(ls, v)
  self:body(ls, b, needself, line)
  luaK:storevar(ls.fs, v, b)
  luaK:fixline(ls.fs, line)  -- definition 'happens' in the first line
end

------------------------------------------------------------------------
-- parse a function call with no returns or an assignment statement
-- * used in statements()
------------------------------------------------------------------------
function luaY:exprstat(ls)
  -- stat -> func | assignment
  local fs = ls.fs
  local v = {}  -- LHS_assign
        v.v = {}
  self:primaryexp(ls, v.v)
  if v.v.k == "VCALL" then  -- stat -> func
    luaK:setcallreturns(fs, v.v, 0)  -- call statement uses no results
  else  -- stat -> assignment
    v.prev = nil
    self:assignment(ls, v, 1)
  end
end

------------------------------------------------------------------------
-- parse a return statement
-- * used in statements()
------------------------------------------------------------------------
function luaY:retstat(ls)
  -- stat -> RETURN explist
  local fs = ls.fs
  local e = {}  -- expdesc
  local first, nret  -- registers with returned values
  self:next(ls)  -- skip RETURN
  if self:block_follow(ls.t.token) or ls.t.token == ";" then
    first, nret = 0, 0  -- return no values
  else
    nret = self:explist1(ls, e)  -- optional return values
    if e.k == "VCALL" then
      luaK:setcallreturns(fs, e, self.LUA_MULTRET)
      if nret == 1 then  -- tail call?
        luaP:SET_OPCODE(luaK:getcode(fs, e), "OP_TAILCALL")
        lua_assert(luaP:GETARG_A(luaK:getcode(fs, e)) == fs.nactvar)
      end
      first = fs.nactvar
      nret = self.LUA_MULTRET  -- return all values
    else
      if nret == 1 then  -- only one single value?
        first = luaK:exp2anyreg(fs, e)
      else
        luaK:exp2nextreg(fs, e)  -- values must go to the 'stack'
        first = fs.nactvar  -- return all 'active' values
        lua_assert(nret == fs.freereg - first)
      end
    end--if
  end--if
  luaK:codeABC(fs, "OP_RETURN", first, nret + 1, 0)
end

------------------------------------------------------------------------
-- parse a break statement
-- * used in statements()
------------------------------------------------------------------------
function luaY:breakstat(ls)
  -- stat -> BREAK
  local fs = ls.fs
  local bl = fs.bl
  local upval = false
  self:next(ls)  -- skip BREAK
  while bl and not bl.isbreakable do
    if bl.upval then upval = true end
    bl = bl.previous
  end
  if not bl then
    luaX:syntaxerror(ls, "no loop to break")
  end
  if upval then
    luaK:codeABC(fs, "OP_CLOSE", bl.nactvar, 0, 0)
  end
  bl.breaklist = luaK:concat(fs, bl.breaklist, luaK:jump(fs))
end

------------------------------------------------------------------------
-- initial parsing for statements, calls a lot of functions
-- * returns boolean instead of 0|1
-- * used in chunk()
------------------------------------------------------------------------
function luaY:statement(ls)
  local line = ls.linenumber  -- may be needed for error messages
  local c = ls.t.token
  if c == "TK_IF" then  -- stat -> ifstat
    self:ifstat(ls, line)
    return false
  elseif c == "TK_WHILE" then  -- stat -> whilestat
    self:whilestat(ls, line)
    return false
  elseif c == "TK_DO" then  -- stat -> DO block END
    self:next(ls)  -- skip DO
    self:block(ls)
    self:check_match(ls, "TK_END", "TK_DO", line)
    return false
  elseif c == "TK_FOR" then  -- stat -> forstat
    self:forstat(ls, line)
    return false
  elseif c == "TK_REPEAT" then  -- stat -> repeatstat
    self:repeatstat(ls, line)
    return false
  elseif c == "TK_FUNCTION" then  -- stat -> funcstat
    self:funcstat(ls, line)
    return false
  elseif c == "TK_LOCAL" then  -- stat -> localstat
    self:next(ls)  -- skip LOCAL
    if self:testnext(ls, "TK_FUNCTION") then  -- local function?
      self:localfunc(ls)
    else
      self:localstat(ls)
    end
    return false
  elseif c == "TK_RETURN" then  -- stat -> retstat
    self:retstat(ls)
    return true  -- must be last statement
  elseif c == "TK_BREAK" then  -- stat -> breakstat
    self:breakstat(ls)
    return true  -- must be last statement
  else
    self:exprstat(ls)
    return false  -- to avoid warnings
  end--if c
end

------------------------------------------------------------------------
-- parse a chunk, which consists of a bunch of statements
-- * used in parser(), body(), block()
------------------------------------------------------------------------
function luaY:chunk(ls)
  -- chunk -> { stat [';'] }
  local islast = false
  self:enterlevel(ls)
  while not islast and not self:block_follow(ls.t.token) do
    islast = self:statement(ls)
    self:testnext(ls, ";")
    lua_assert(ls.fs.freereg >= ls.fs.nactvar)
    ls.fs.freereg = ls.fs.nactvar  -- free registers
  end
  self:leavelevel(ls)
end
