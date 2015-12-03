--[[--------------------------------------------------------------------

  lparser.lua
  Lua 5.1 parser in Lua
  This file is part of Yueliang.

  Copyright (c) 2008 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- Notes:
-- * this is a Lua 5.1.x parser skeleton, for the llex_mk2.lua lexer
-- * builds some data, performs logging for educational purposes
-- * target is to have relatively efficient and clear code
-- * NO parsing limitations, since it is only a parser skeleton. Some
--   limits set in the default sources (in luaconf.h) are:
--     LUAI_MAXVARS = 200
--     LUAI_MAXUPVALUES = 60
--     LUAI_MAXCCALLS = 200
-- * NO support for 'arg' vararg functions (LUA_COMPAT_VARARG)
-- * init(llex) needs one parameter, a lexer module that implements:
--     llex.lex() - returns appropriate [token, semantic info] pairs
--     llex.ln - current line number
--     llex.errorline(s, [line]) - dies with error message
--
-- Usage example:
--   local llex = require("llex_mk2")
--   local lparser = require("lparser_mk2")
--   llex.init(source_code, source_code_name)
--   lparser.init(llex)
--   local fs = lparser.parser()
--
-- Development notes:
-- * see test_parser-5.1.lua for grammar elements based on lparser.c
-- * next() (renamed to nextt) and lookahead() has been moved from llex;
--   it's more convenient to keep tok, seminfo as local variables here
-- * syntaxerror() is from llex, easier to keep here since little token
--   translation needed in preparation of error message
-- * lparser has a few extra items to help parsing/syntax checking
--   (a) line number (error reporting), lookahead token storage
-- * (b) per-prototype states needs a storage list
-- * (c) 'break' needs a per-block flag in a stack
-- * (d) 'kind' (v.k) testing needed in expr_stat() and assignment()
--       for disambiguation, thus v.k manipulation is retained
-- * (e) one line # var (lastln) for ambiguous (split line) function
--       call checking
-- * (f) LUA_COMPAT_VARARG compatibility code completely removed
-- * (g) minimal variable management code to differentiate each type
-- * parsing starts from the end of this file in parser()
----------------------------------------------------------------------]]

local base = _G
local string = require "string"
module "lparser"
local _G = base.getfenv()

--[[--------------------------------------------------------------------
-- variable and data structure initialization
----------------------------------------------------------------------]]

----------------------------------------------------------------------
-- initialization: main variables
----------------------------------------------------------------------

local llex, llex_lex            -- references lexer module, function
local line                      -- start line # for error messages
local lastln                    -- last line # for ambiguous syntax chk
local tok, seminfo              -- token, semantic info pair
local peek_tok, peek_sem        -- ditto, for lookahead
local fs                        -- current function state
local top_fs                    -- top-level function state

-- forward references for local functions
local explist1, expr, block, exp1, body

----------------------------------------------------------------------
-- initialization: data structures
----------------------------------------------------------------------

local gmatch = string.gmatch

local block_follow = {}         -- lookahead check in chunk(), returnstat()
for v in gmatch("else elseif end until <eof>", "%S+") do
  block_follow[v] = true
end

local stat_call = {}            -- lookup for calls in stat()
for v in gmatch("if while do for repeat function local return break", "%S+") do
  stat_call[v] = v.."_stat"
end

local binopr_left = {}          -- binary operators, left priority
local binopr_right = {}         -- binary operators, right priority
for op, lt, rt in gmatch([[
{+ 6 6}{- 6 6}{* 7 7}{/ 7 7}{% 7 7}
{^ 10 9}{.. 5 4}
{~= 3 3}{== 3 3}
{< 3 3}{<= 3 3}{> 3 3}{>= 3 3}
{and 2 2}{or 1 1}
]], "{(%S+)%s(%d+)%s(%d+)}") do
  binopr_left[op] = lt + 0
  binopr_right[op] = rt + 0
end

local unopr = { ["not"] = true, ["-"] = true,
                ["#"] = true, } -- unary operators
local UNARY_PRIORITY = 8        -- priority for unary operators

--[[--------------------------------------------------------------------
-- logging: this logging function is for educational purposes
-- * logged data can be retrieved from the returned data structure
----------------------------------------------------------------------]]

local function log(msg)
  local log = top_fs.log
  if not log then                       -- initialize message table
    log = {}; top_fs.log = log
  end
  log[#log + 1] = msg
end

--[[--------------------------------------------------------------------
-- support functions
----------------------------------------------------------------------]]

----------------------------------------------------------------------
-- handles incoming token, semantic information pairs; these two
-- functions are from llex, they are put here because keeping the
-- tok, seminfo variables here as locals is more convenient
-- * NOTE: 'nextt' is named 'next' originally
----------------------------------------------------------------------

-- reads in next token
local function nextt()
  lastln = llex.ln
  if peek_tok then  -- is there a look-ahead token? if yes, use it
    tok, seminfo = peek_tok, peek_sem
    peek_tok = nil
  else
    tok, seminfo = llex_lex()  -- read next token
  end
end

-- peek at next token (single lookahead for table constructor)
local function lookahead()
  peek_tok, peek_sem = llex_lex()
  return peek_tok
end

----------------------------------------------------------------------
-- throws a syntax error, or if token expected is not there
----------------------------------------------------------------------

local function syntaxerror(msg)
  local tok = tok
  if tok ~= "<number>" and tok ~= "<string>" then
    if tok == "<name>" then tok = seminfo end
    tok = "'"..tok.."'"
  end
  llex.errorline(msg.." near "..tok)
end

local function error_expected(token)
  syntaxerror("'"..token.."' expected")
end

----------------------------------------------------------------------
-- tests for a token, returns outcome
-- * return value changed to boolean
----------------------------------------------------------------------

local function testnext(c)
  if tok == c then nextt(); return true end
end

----------------------------------------------------------------------
-- check for existence of a token, throws error if not found
----------------------------------------------------------------------

local function check(c)
  if tok ~= c then error_expected(c) end
end

----------------------------------------------------------------------
-- verify existence of a token, then skip it
----------------------------------------------------------------------

local function checknext(c)
  check(c); nextt()
end

----------------------------------------------------------------------
-- throws error if condition not matched
----------------------------------------------------------------------

local function check_condition(c, msg)
  if not c then syntaxerror(msg) end
end

----------------------------------------------------------------------
-- verifies token conditions are met or else throw error
----------------------------------------------------------------------

local function check_match(what, who, where)
  if not testnext(what) then
    if where == llex.ln then
      error_expected(what)
    else
      syntaxerror("'"..what.."' expected (to close '"..who.."' at line "..where..")")
    end
  end
end

----------------------------------------------------------------------
-- expect that token is a name, return the name
----------------------------------------------------------------------

local function str_checkname()
  check("<name>")
  local ts = seminfo
  nextt()
  log("    str_checkname: '"..ts.."'")
  return ts
end

----------------------------------------------------------------------
-- adds given string s in string pool, sets e as VK
----------------------------------------------------------------------

local function codestring(e, s)
  e.k = "VK"
  log("    codestring: "..string.format("%q", s))
end

----------------------------------------------------------------------
-- consume a name token, adds it to string pool
----------------------------------------------------------------------

local function checkname(e)
  log("    checkname:")
  codestring(e, str_checkname())
end

--[[--------------------------------------------------------------------
-- state management functions with open/close pairs
----------------------------------------------------------------------]]

----------------------------------------------------------------------
-- enters a code unit, initializes elements
----------------------------------------------------------------------

local function enterblock(isbreakable)
  local bl = {}  -- per-block state
  bl.isbreakable = isbreakable
  bl.prev = fs.bl
  bl.locallist = {}
  fs.bl = bl
  log(">> enterblock(isbreakable="..base.tostring(isbreakable)..")")
end

----------------------------------------------------------------------
-- leaves a code unit, close any upvalues
----------------------------------------------------------------------

local function leaveblock()
  local bl = fs.bl
  fs.bl = bl.prev
  log("<< leaveblock")
end

----------------------------------------------------------------------
-- opening of a function
-- * top_fs is only for anchoring the top fs, so that parser() can
--   return it to the caller function along with useful output
-- * used in parser() and body()
----------------------------------------------------------------------

local function open_func()
  local new_fs  -- per-function state
  if not fs then  -- top_fs is created early
    new_fs = top_fs
  else
    new_fs = {}
  end
  new_fs.prev = fs  -- linked list of function states
  new_fs.bl = nil
  new_fs.locallist = {}
  fs = new_fs
  log(">> open_func")
end

----------------------------------------------------------------------
-- closing of a function
-- * used in parser() and body()
----------------------------------------------------------------------

local function close_func()
  fs = fs.prev
  log("<< close_func")
end

--[[--------------------------------------------------------------------
-- variable (global|local|upvalue) handling
-- * a pure parser does not really need this, but if we want to produce
--   useful output, might as well write minimal code to manage this...
-- * entry point is singlevar() for variable lookups
-- * three entry points for local variable creation, in order to keep
--   to original C calls, but the extra arguments such as positioning
--   are removed as we are not allocating registers -- we are only
--   doing simple classification
-- * lookup tables (bl.locallist) are maintained awkwardly in the basic
--   block data structures, PLUS the function data structure (this is
--   an inelegant hack, since bl is nil for the top level of a function)
----------------------------------------------------------------------]]

----------------------------------------------------------------------
-- register a local variable, set in active variable list
-- * code for a simple lookup only
-- * used in new_localvarliteral(), parlist(), fornum(), forlist(),
--   localfunc(), localstat()
----------------------------------------------------------------------

local function new_localvar(name)
  local bl = fs.bl
  local locallist
  if bl then
    locallist = bl.locallist
  else
    locallist = fs.locallist
  end
  locallist[name] = true
  log("    new_localvar: '"..name.."'")
end

----------------------------------------------------------------------
-- creates a new local variable given a name
-- * used in fornum(), forlist(), parlist(), body()
----------------------------------------------------------------------

local function new_localvarliteral(name)
  new_localvar(name)
end

----------------------------------------------------------------------
-- search the local variable namespace of the given fs for a match
-- * a simple lookup only, no active variable list kept, so no useful
--   index value can be returned by this function
-- * used only in singlevaraux()
----------------------------------------------------------------------

local function searchvar(fs, n)
  local bl = fs.bl
  if bl then
    locallist = bl.locallist
    while locallist do
      if locallist[n] then return 1 end  -- found
      bl = bl.prev
      locallist = bl and bl.locallist
    end
  end
  locallist = fs.locallist
  if locallist[n] then return 1 end  -- found
  return -1  -- not found
end

----------------------------------------------------------------------
-- handle locals, globals and upvalues and related processing
-- * search mechanism is recursive, calls itself to search parents
-- * used only in singlevar()
----------------------------------------------------------------------

local function singlevaraux(fs, n, var, base)
  if fs == nil then  -- no more levels?
    var.k = "VGLOBAL"  -- default is global variable
    return "VGLOBAL"
  else
    local v = searchvar(fs, n)  -- look up at current level
    if v >= 0 then
      var.k = "VLOCAL"
      --  codegen may need to deal with upvalue here
      return "VLOCAL"
    else  -- not found at current level; try upper one
      if singlevaraux(fs.prev, n, var, 0) == "VGLOBAL" then
        return "VGLOBAL"
      end
      -- else was LOCAL or UPVAL, handle here
      var.k = "VUPVAL"  -- upvalue in this level
      return "VUPVAL"
    end--if v
  end--if fs
end

----------------------------------------------------------------------
-- consume a name token, creates a variable (global|local|upvalue)
-- * used in prefixexp(), funcname()
----------------------------------------------------------------------

local function singlevar(v)
  local varname = str_checkname()
  singlevaraux(fs, varname, v, 1)
  log("    singlevar(kind): '"..v.k.."'")
end

--[[--------------------------------------------------------------------
-- other parsing functions
-- * for table constructor, parameter list, argument list
----------------------------------------------------------------------]]

----------------------------------------------------------------------
-- parse a function name suffix, for function call specifications
-- * used in primaryexp(), funcname()
----------------------------------------------------------------------

local function field(v)
  -- field -> ['.' | ':'] NAME
  local key = {}
  log("  field: operator="..tok)
  nextt()  -- skip the dot or colon
  checkname(key)
  v.k = "VINDEXED"
end

----------------------------------------------------------------------
-- parse a table indexing suffix, for constructors, expressions
-- * used in recfield(), primaryexp()
----------------------------------------------------------------------

local function yindex(v)
  -- index -> '[' expr ']'
  log(">> index: begin '['")
  nextt()  -- skip the '['
  expr(v)
  checknext("]")
  log("<< index: end ']'")
end

----------------------------------------------------------------------
-- parse a table record (hash) field
-- * used in constructor()
----------------------------------------------------------------------

local function recfield(cc)
  -- recfield -> (NAME | '['exp1']') = exp1
  local key, val = {}, {}
  if tok == "<name>" then
    log("recfield: name")
    checkname(key)
  else-- tok == '['
    log("recfield: [ exp1 ]")
    yindex(key)
  end
  checknext("=")
  expr(val)
end

----------------------------------------------------------------------
-- emit a set list instruction if enough elements (LFIELDS_PER_FLUSH)
-- * note: retained in this skeleton because it modifies cc.v.k
-- * used in constructor()
----------------------------------------------------------------------

local function closelistfield(cc)
  if cc.v.k == "VVOID" then return end  -- there is no list item
  cc.v.k = "VVOID"
end

----------------------------------------------------------------------
-- parse a table list (array) field
-- * used in constructor()
----------------------------------------------------------------------

local function listfield(cc)
  log("listfield: expr")
  expr(cc.v)
end

----------------------------------------------------------------------
-- parse a table constructor
-- * used in funcargs(), simpleexp()
----------------------------------------------------------------------

local function constructor(t)
  -- constructor -> '{' [ field { fieldsep field } [ fieldsep ] ] '}'
  -- field -> recfield | listfield
  -- fieldsep -> ',' | ';'
  log(">> constructor: begin")
  local line = llex.ln
  local cc = {}
  cc.v = {}
  cc.t = t
  t.k = "VRELOCABLE"
  cc.v.k = "VVOID"
  checknext("{")
  repeat
    if tok == "}" then break end
    -- closelistfield(cc) here
    local c = tok
    if c == "<name>" then  -- may be listfields or recfields
      if lookahead() ~= "=" then  -- look ahead: expression?
        listfield(cc)
      else
        recfield(cc)
      end
    elseif c == "[" then  -- constructor_item -> recfield
      recfield(cc)
    else  -- constructor_part -> listfield
      listfield(cc)
    end
  until not testnext(",") and not testnext(";")
  check_match("}", "{", line)
  -- lastlistfield(cc) here
  log("<< constructor: end")
end

----------------------------------------------------------------------
-- parse the arguments (parameters) of a function declaration
-- * used in body()
----------------------------------------------------------------------

local function parlist()
  -- parlist -> [ param { ',' param } ]
  log(">> parlist: begin")
  if tok ~= ")" then  -- is 'parlist' not empty?
    repeat
      local c = tok
      if c == "<name>" then  -- param -> NAME
        new_localvar(str_checkname())
      elseif c == "..." then
        log("parlist: ... (dots)")
        nextt()
        fs.is_vararg = true
      else
        syntaxerror("<name> or '...' expected")
      end
    until fs.is_vararg or not testnext(",")
  end--if
  log("<< parlist: end")
end

----------------------------------------------------------------------
-- parse the parameters of a function call
-- * contrast with parlist(), used in function declarations
-- * used in primaryexp()
----------------------------------------------------------------------

local function funcargs(f)
  local args = {}
  local line = llex.ln
  local c = tok
  if c == "(" then  -- funcargs -> '(' [ explist1 ] ')'
    log(">> funcargs: begin '('")
    if line ~= lastln then
      syntaxerror("ambiguous syntax (function call x new statement)")
    end
    nextt()
    if tok == ")" then  -- arg list is empty?
      args.k = "VVOID"
    else
      explist1(args)
    end
    check_match(")", "(", line)
  elseif c == "{" then  -- funcargs -> constructor
    log(">> funcargs: begin '{'")
    constructor(args)
  elseif c == "<string>" then  -- funcargs -> STRING
    log(">> funcargs: begin <string>")
    codestring(args, seminfo)
    nextt()  -- must use 'seminfo' before 'next'
  else
    syntaxerror("function arguments expected")
    return
  end--if c
  f.k = "VCALL"
  log("<< funcargs: end -- expr is a VCALL")
end

--[[--------------------------------------------------------------------
-- mostly expression functions
----------------------------------------------------------------------]]

----------------------------------------------------------------------
-- parses an expression in parentheses or a single variable
-- * used in primaryexp()
----------------------------------------------------------------------

local function prefixexp(v)
  -- prefixexp -> NAME | '(' expr ')'
  local c = tok
  if c == "(" then
    log(">> prefixexp: begin ( expr ) ")
    local line = llex.ln
    nextt()
    expr(v)
    check_match(")", "(", line)
    log("<< prefixexp: end ( expr ) ")
  elseif c == "<name>" then
    log("prefixexp: <name>")
    singlevar(v)
  else
    syntaxerror("unexpected symbol")
  end--if c
end

----------------------------------------------------------------------
-- parses a prefixexp (an expression in parentheses or a single
-- variable) or a function call specification
-- * used in simpleexp(), assignment(), expr_stat()
----------------------------------------------------------------------

local function primaryexp(v)
  -- primaryexp ->
  --    prefixexp { '.' NAME | '[' exp ']' | ':' NAME funcargs | funcargs }
  prefixexp(v)
  while true do
    local c = tok
    if c == "." then  -- field
      log("primaryexp: '.' field")
      field(v)
    elseif c == "[" then  -- '[' exp1 ']'
      log("primaryexp: [ exp1 ]")
      local key = {}
      yindex(key)
    elseif c == ":" then  -- ':' NAME funcargs
      log("primaryexp: :<name> funcargs")
      local key = {}
      nextt()
      checkname(key)
      funcargs(v)
    elseif c == "(" or c == "<string>" or c == "{" then  -- funcargs
      log("primaryexp: "..c.." funcargs")
      funcargs(v)
    else
      return
    end--if c
  end--while
end

----------------------------------------------------------------------
-- parses general expression types, constants handled here
-- * used in subexpr()
----------------------------------------------------------------------

local function simpleexp(v)
  -- simpleexp -> NUMBER | STRING | NIL | TRUE | FALSE | ... |
  --              constructor | FUNCTION body | primaryexp
  local c = tok
  if c == "<number>" then
    log("simpleexp: <number>="..seminfo)
    v.k = "VKNUM"
  elseif c == "<string>" then
    log("simpleexp: <string>="..seminfo)
    codestring(v, seminfo)
  elseif c == "nil" then
    log("simpleexp: nil")
    v.k = "VNIL"
  elseif c == "true" then
    log("simpleexp: true")
    v.k = "VTRUE"
  elseif c == "false" then
    log("simpleexp: false")
    v.k = "VFALSE"
  elseif c == "..." then  -- vararg
    check_condition(fs.is_vararg == true,
                    "cannot use '...' outside a vararg function");
    log("simpleexp: ...")
    v.k = "VVARARG"
  elseif c == "{" then  -- constructor
    log("simpleexp: constructor")
    constructor(v)
    return
  elseif c == "function" then
    log("simpleexp: function")
    nextt()
    body(v, false, llex.ln)
    return
  else
    primaryexp(v)
    return
  end--if c
  nextt()
end

------------------------------------------------------------------------
-- Parse subexpressions. Includes handling of unary operators and binary
-- operators. A subexpr is given the rhs priority level of the operator
-- immediately left of it, if any (limit is -1 if none,) and if a binop
-- is found, limit is compared with the lhs priority level of the binop
-- in order to determine which executes first.
-- * recursively called
-- * used in expr()
------------------------------------------------------------------------

local function subexpr(v, limit)
  -- subexpr -> (simpleexp | unop subexpr) { binop subexpr }
  --   * where 'binop' is any binary operator with a priority
  --     higher than 'limit'
  local op = tok
  local uop = unopr[op]
  if uop then
    log("  subexpr: uop='"..op.."'")
    nextt()
    subexpr(v, UNARY_PRIORITY)
  else
    simpleexp(v)
  end
  -- expand while operators have priorities higher than 'limit'
  op = tok
  local binop = binopr_left[op]
  while binop and binop > limit do
    local v2 = {}
    log(">> subexpr: binop='"..op.."'")
    nextt()
    -- read sub-expression with higher priority
    local nextop = subexpr(v2, binopr_right[op])
    log("<< subexpr: -- evaluate")
    op = nextop
    binop = binopr_left[op]
  end
  return op  -- return first untreated operator
end

----------------------------------------------------------------------
-- Expression parsing starts here. Function subexpr is entered with the
-- left operator (which is non-existent) priority of -1, which is lower
-- than all actual operators. Expr information is returned in parm v.
-- * used in cond(), explist1(), index(), recfield(), listfield(),
--   prefixexp(), while_stat(), exp1()
----------------------------------------------------------------------

-- this is a forward-referenced local
function expr(v)
  -- expr -> subexpr
  log("expr:")
  subexpr(v, 0)
end

--[[--------------------------------------------------------------------
-- third level parsing functions
----------------------------------------------------------------------]]

------------------------------------------------------------------------
-- parse a variable assignment sequence
-- * recursively called
-- * used in expr_stat()
------------------------------------------------------------------------

local function assignment(v)
  local e = {}
  local c = v.v.k
  check_condition(c == "VLOCAL" or c == "VUPVAL" or c == "VGLOBAL"
                  or c == "VINDEXED", "syntax error")
  if testnext(",") then  -- assignment -> ',' primaryexp assignment
    local nv = {}  -- expdesc
    nv.v = {}
    log("assignment: ',' -- next LHS element")
    primaryexp(nv.v)
    -- lparser.c deals with some register usage conflict here
    assignment(nv)
  else  -- assignment -> '=' explist1
    checknext("=")
    log("assignment: '=' -- RHS elements follows")
    explist1(e)
    return  -- avoid default
  end
  e.k = "VNONRELOC"
end

----------------------------------------------------------------------
-- parse a for loop body for both versions of the for loop
-- * used in fornum(), forlist()
----------------------------------------------------------------------

local function forbody(isnum)
  -- forbody -> DO block
  checknext("do")
  enterblock(false)  -- scope for declared variables
  block()
  leaveblock()  -- end of scope for declared variables
end

----------------------------------------------------------------------
-- parse a numerical for loop, calls forbody()
-- * used in for_stat()
----------------------------------------------------------------------

local function fornum(varname)
  -- fornum -> NAME = exp1, exp1 [, exp1] DO body
  local line = line
  new_localvarliteral("(for index)")
  new_localvarliteral("(for limit)")
  new_localvarliteral("(for step)")
  new_localvar(varname)
  log(">> fornum: begin")
  checknext("=")
  log("fornum: index start")
  exp1()  -- initial value
  checknext(",")
  log("fornum: index stop")
  exp1()  -- limit
  if testnext(",") then
    log("fornum: index step")
    exp1()  -- optional step
  else
    -- default step = 1
  end
  log("fornum: body")
  forbody(true)
  log("<< fornum: end")
end

----------------------------------------------------------------------
-- parse a generic for loop, calls forbody()
-- * used in for_stat()
----------------------------------------------------------------------

local function forlist(indexname)
  -- forlist -> NAME {, NAME} IN explist1 DO body
  log(">> forlist: begin")
  local e = {}
  -- create control variables
  new_localvarliteral("(for generator)")
  new_localvarliteral("(for state)")
  new_localvarliteral("(for control)")
  -- create declared variables
  new_localvar(indexname)
  while testnext(",") do
    new_localvar(str_checkname())
  end
  checknext("in")
  local line = line
  log("forlist: explist1")
  explist1(e)
  log("forlist: body")
  forbody(false)
  log("<< forlist: end")
end

----------------------------------------------------------------------
-- parse a function name specification
-- * used in func_stat()
----------------------------------------------------------------------

local function funcname(v)
  -- funcname -> NAME {field} [':' NAME]
  log(">> funcname: begin")
  local needself = false
  singlevar(v)
  while tok == "." do
    log("funcname: -- '.' field")
    field(v)
  end
  if tok == ":" then
    log("funcname: -- ':' field")
    needself = true
    field(v)
  end
  log("<< funcname: end")
  return needself
end

----------------------------------------------------------------------
-- parse the single expressions needed in numerical for loops
-- * used in fornum()
----------------------------------------------------------------------

-- this is a forward-referenced local
function exp1()
  -- exp1 -> expr
  local e = {}
  log(">> exp1: begin")
  expr(e)
  log("<< exp1: end")
end

----------------------------------------------------------------------
-- parse condition in a repeat statement or an if control structure
-- * used in repeat_stat(), test_then_block()
----------------------------------------------------------------------

local function cond()
  -- cond -> expr
  log(">> cond: begin")
  local v = {}
  expr(v)  -- read condition
  log("<< cond: end")
end

----------------------------------------------------------------------
-- parse part of an if control structure, including the condition
-- * used in if_stat()
----------------------------------------------------------------------

local function test_then_block()
  -- test_then_block -> [IF | ELSEIF] cond THEN block
  nextt()  -- skip IF or ELSEIF
  log("test_then_block: test condition")
  cond()
  checknext("then")
  log("test_then_block: then block")
  block()  -- 'then' part
end

----------------------------------------------------------------------
-- parse a local function statement
-- * used in local_stat()
----------------------------------------------------------------------

local function localfunc()
  -- localfunc -> NAME body
  local v, b = {}
  log("localfunc: begin")
  new_localvar(str_checkname())
  v.k = "VLOCAL"
  log("localfunc: body")
  body(b, false, llex.ln)
  log("localfunc: end")
end

----------------------------------------------------------------------
-- parse a local variable declaration statement
-- * used in local_stat()
----------------------------------------------------------------------

local function localstat()
  -- localstat -> NAME {',' NAME} ['=' explist1]
  log(">> localstat: begin")
  local e = {}
  repeat
    new_localvar(str_checkname())
  until not testnext(",")
  if testnext("=") then
    log("localstat: -- assignment")
    explist1(e)
  else
    e.k = "VVOID"
  end
  log("<< localstat: end")
end

----------------------------------------------------------------------
-- parse a list of comma-separated expressions
-- * used in return_stat(), localstat(), funcargs(), assignment(),
--   forlist()
----------------------------------------------------------------------

-- this is a forward-referenced local
function explist1(e)
  -- explist1 -> expr { ',' expr }
  log(">> explist1: begin")
  expr(e)
  while testnext(",") do
    log("explist1: ',' -- continuation")
    expr(e)
  end
  log("<< explist1: end")
end

----------------------------------------------------------------------
-- parse function declaration body
-- * used in simpleexp(), localfunc(), func_stat()
----------------------------------------------------------------------

-- this is a forward-referenced local
function body(e, needself, line)
  -- body ->  '(' parlist ')' chunk END
  open_func()
  log("body: begin")
  checknext("(")
  if needself then
    new_localvarliteral("self")
  end
  log("body: parlist")
  parlist()
  checknext(")")
  log("body: chunk")
  chunk()
  check_match("end", "function", line)
  log("body: end")
  close_func()
end

----------------------------------------------------------------------
-- parse a code block or unit
-- * used in do_stat(), while_stat(), forbody(), test_then_block(),
--   if_stat()
----------------------------------------------------------------------

-- this is a forward-referenced local
function block()
  -- block -> chunk
  log("block: begin")
  enterblock(false)
  chunk()
  leaveblock()
  log("block: end")
end

--[[--------------------------------------------------------------------
-- second level parsing functions, all with '_stat' suffix
-- * since they are called via a table lookup, they cannot be local
--   functions (a lookup table of local functions might be smaller...)
-- * stat() -> *_stat()
----------------------------------------------------------------------]]

----------------------------------------------------------------------
-- initial parsing for a for loop, calls fornum() or forlist()
-- * removed 'line' parameter (used to set debug information only)
-- * used in stat()
----------------------------------------------------------------------

function for_stat()
  -- stat -> for_stat -> FOR (fornum | forlist) END
  local line = line
  log("for_stat: begin")
  enterblock(true)  -- scope for loop and control variables
  nextt()  -- skip 'for'
  local varname = str_checkname()  -- first variable name
  local c = tok
  if c == "=" then
    log("for_stat: numerical loop")
    fornum(varname)
  elseif c == "," or c == "in" then
    log("for_stat: list-based loop")
    forlist(varname)
  else
    syntaxerror("'=' or 'in' expected")
  end
  check_match("end", "for", line)
  leaveblock()  -- loop scope (`break' jumps to this point)
  log("for_stat: end")
end

----------------------------------------------------------------------
-- parse a while-do control structure, body processed by block()
-- * used in stat()
----------------------------------------------------------------------

function while_stat()
  -- stat -> while_stat -> WHILE cond DO block END
  local line = line
  nextt()  -- skip WHILE
  log("while_stat: begin/condition")
  cond()  -- parse condition
  enterblock(true)
  checknext("do")
  log("while_stat: block")
  block()
  check_match("end", "while", line)
  leaveblock()
  log("while_stat: end")
end

----------------------------------------------------------------------
-- parse a repeat-until control structure, body parsed by chunk()
-- * originally, repeatstat() calls breakstat() too if there is an
--   upvalue in the scope block; nothing is actually lexed, it is
--   actually the common code in breakstat() for closing of upvalues
-- * used in stat()
----------------------------------------------------------------------

function repeat_stat()
  -- stat -> repeat_stat -> REPEAT block UNTIL cond
  local line = line
  log("repeat_stat: begin")
  enterblock(true)  -- loop block
  enterblock(false)  -- scope block
  nextt()  -- skip REPEAT
  chunk()
  check_match("until", "repeat", line)
  log("repeat_stat: condition")
  cond()
  -- close upvalues at scope level below
  leaveblock()  -- finish scope
  leaveblock()  -- finish loop
  log("repeat_stat: end")
end

----------------------------------------------------------------------
-- parse an if control structure
-- * used in stat()
----------------------------------------------------------------------

function if_stat()
  -- stat -> if_stat -> IF cond THEN block
  --                    {ELSEIF cond THEN block} [ELSE block] END
  local line = line
  local v = {}
  log("if_stat: if...then")
  test_then_block()  -- IF cond THEN block
  while tok == "elseif" do
    log("if_stat: elseif...then")
    test_then_block()  -- ELSEIF cond THEN block
  end
  if tok == "else" then
    log("if_stat: else...")
    nextt()  -- skip ELSE
    block()  -- 'else' part
  end
  check_match("end", "if", line)
  log("if_stat: end")
end

----------------------------------------------------------------------
-- parse a return statement
-- * used in stat()
----------------------------------------------------------------------

function return_stat()
  -- stat -> return_stat -> RETURN explist
  local e = {}
  nextt()  -- skip RETURN
  local c = tok
  if block_follow[c] or c == ";" then
    -- return no values
    log("return_stat: no return values")
  else
    log("return_stat: begin")
    explist1(e)  -- optional return values
    log("return_stat: end")
  end
end

----------------------------------------------------------------------
-- parse a break statement
-- * used in stat()
----------------------------------------------------------------------

function break_stat()
  -- stat -> break_stat -> BREAK
  local bl = fs.bl
  nextt()  -- skip BREAK
  while bl and not bl.isbreakable do -- find a breakable block
    bl = bl.prev
  end
  if not bl then
    syntaxerror("no loop to break")
  end
  log("break_stat: -- break out of loop")
end

----------------------------------------------------------------------
-- parse a function call with no returns or an assignment statement
-- * the struct with .prev is used for name searching in lparse.c,
--   so it is retained for now; present in assignment() also
-- * used in stat()
----------------------------------------------------------------------

function expr_stat()
  -- stat -> expr_stat -> func | assignment
  local v = {}
  v.v = {}
  primaryexp(v.v)
  if v.v.k == "VCALL" then  -- stat -> func
    -- call statement uses no results
    log("expr_stat: function call k='"..v.v.k.."'")
  else  -- stat -> assignment
    log("expr_stat: assignment k='"..v.v.k.."'")
    v.prev = nil
    assignment(v)
  end
end

----------------------------------------------------------------------
-- parse a function statement
-- * used in stat()
----------------------------------------------------------------------

function function_stat()
  -- stat -> function_stat -> FUNCTION funcname body
  local line = line
  local v, b = {}, {}
  log("function_stat: begin")
  nextt()  -- skip FUNCTION
  local needself = funcname(v)
  log("function_stat: body needself='"..base.tostring(needself).."'")
  body(b, needself, line)
  log("function_stat: end")
end

----------------------------------------------------------------------
-- parse a simple block enclosed by a DO..END pair
-- * used in stat()
----------------------------------------------------------------------

function do_stat()
  -- stat -> do_stat -> DO block END
  local line = line
  nextt()  -- skip DO
  log("do_stat: begin")
  block()
  log("do_stat: end")
  check_match("end", "do", line)
end

----------------------------------------------------------------------
-- parse a statement starting with LOCAL
-- * used in stat()
----------------------------------------------------------------------

function local_stat()
  -- stat -> local_stat -> LOCAL FUNCTION localfunc
  --                    -> LOCAL localstat
  nextt()  -- skip LOCAL
  if testnext("function") then  -- local function?
    log("local_stat: local function")
    localfunc()
  else
    log("local_stat: local statement")
    localstat()
  end
end

--[[--------------------------------------------------------------------
-- main functions, top level parsing functions
-- * accessible functions are: init(lexer), parser()
-- * [entry] -> parser() -> chunk() -> stat()
----------------------------------------------------------------------]]

----------------------------------------------------------------------
-- initial parsing for statements, calls '_stat' suffixed functions
-- * used in chunk()
----------------------------------------------------------------------

local function stat()
  -- stat -> if_stat while_stat do_stat for_stat repeat_stat
  --         function_stat local_stat return_stat break_stat
  --         expr_stat
  line = llex.ln  -- may be needed for error messages
  local c = tok
  local fn = stat_call[c]
  -- handles: if while do for repeat function local return break
  if fn then
    log("-- STATEMENT: begin '"..c.."' line="..line)
    _G[fn]()
    log("-- STATEMENT: end '"..c.."'")
    -- return or break must be last statement
    if c == "return" or c == "break" then return true end
  else
    log("-- STATEMENT: begin 'expr' line="..line)
    expr_stat()
    log("-- STATEMENT: end 'expr'")
  end
  log("")
  return false
end

----------------------------------------------------------------------
-- parse a chunk, which consists of a bunch of statements
-- * used in parser(), body(), block(), repeat_stat()
----------------------------------------------------------------------

function chunk()
  -- chunk -> { stat [';'] }
  log("chunk:")
  local islast = false
  while not islast and not block_follow[tok] do
    islast = stat()
    testnext(";")
  end
end

----------------------------------------------------------------------
-- performs parsing, returns parsed data structure
----------------------------------------------------------------------

function parser()
  log("-- TOP: begin")
  open_func()
  fs.is_vararg = true  -- main func. is always vararg
  log("")
  nextt()  -- read first token
  chunk()
  check("<eof>")
  close_func()
  log("-- TOP: end")
  return top_fs
end

----------------------------------------------------------------------
-- initialization function
----------------------------------------------------------------------

function init(lexer)
  llex = lexer                  -- set lexer (assume user-initialized)
  llex_lex = llex.llex
  top_fs = {}                   -- reset top level function state
end

return _G
