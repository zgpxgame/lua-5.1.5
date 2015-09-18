--[[--------------------------------------------------------------------

  lparser.lua
  Lua 5 parser in Lua
  This file is part of Yueliang.

  Copyright (c) 2008 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- Notes:
-- * this is a Lua 5.0.x parser skeleton, for llex_mk3.lua lexer
-- * written as a module factory with recognizable lparser.c roots
-- * builds some data, performs logging for educational purposes
-- * target is to have relatively efficient and clear code
-- * needs one parameter, a lexer module that implements:
--     luaX:lex() - returns appropriate [token, semantic info] pairs
--     luaX.ln - current line number
--     luaX:errorline(s, [line]) - dies with error message
--
-- Usage example:
--   lex_init = require("llex_mk3.lua")
--   parser_init = require("lparser_mk3.lua")
--   local luaX = lex_init(chunk, "=string")
--   local luaY = parser_init(luaX)
--   local fs = luaY:parser()
--
-- Development notes:
-- * see test_parser-5.0.lua for grammar elements based on lparser.c
-- * lparser has a few extra items to help parsing/syntax checking
--   (a) line number (error reporting), lookahead token storage
--   (b) per-prototype states needs a storage list
--   (c) 'break' needs a per-block flag in a stack
--   (d) 'kind' (v.k) testing needed in expr_stat() and assignment()
--       for disambiguation, thus v.k manipulation is retained
--   (e) one line # var (lastln) for ambiguous (split line) function
--       call checking
--   (f) most line number function call args retained for future use
--   (g) Lua 4 compatibility code completely removed
--   (h) no variable management code! singlevar() always returns VLOCAL
-- * parsing starts from the end of this file in luaY:parser()
--
----------------------------------------------------------------------]]

return
function(luaX)
--[[--------------------------------------------------------------------
-- structures and data initialization
----------------------------------------------------------------------]]

  local line                    -- start line # for error messages
  local lastln                  -- last line # for ambiguous syntax chk
  local tok, seminfo            -- token, semantic info pair
  local peek_tok, peek_sem      -- ditto, for lookahead
  local fs                      -- function state
  local top_fs = {}             -- top-level function state
  local luaY = {}
  --------------------------------------------------------------------
  local block_follow = {}       -- lookahead check in chunk(), returnstat()
  for v in string.gfind("else elseif end until <eof>", "%S+") do
    block_follow[v] = true
  end
  --------------------------------------------------------------------
  local stat_call = {}          -- lookup for calls in stat()
  for v in string.gfind("if while do for repeat function local return break", "%S+") do
    stat_call[v] = v.."_stat"
  end
  --------------------------------------------------------------------
  local binopr_left = {}        -- binary operators, left priority
  local binopr_right = {}       -- binary operators, right priority
  for op, lt, rt in string.gfind([[
{+ 6 6}{- 6 6}{* 7 7}{/ 7 7}{^ 10 9}{.. 5 4}
{~= 3 3}{== 3 3}{< 3 3}{<= 3 3}{> 3 3}{>= 3 3}
{and 2 2}{or 1 1}
]], "{(%S+)%s(%d+)%s(%d+)}") do
    binopr_left[op] = lt + 0
    binopr_right[op] = rt + 0
  end
  local unopr = { ["not"] = true, ["-"] = true, }  -- unary operators

--[[--------------------------------------------------------------------
-- logging: this logging function is for educational purposes
-- * logged data can be retrieved from the returned data structure
-- * or, replace self:log() instances with your custom code...
----------------------------------------------------------------------]]

  function luaY:log(msg)
    local log = top_fs.log
    if not log then log = {}; top_fs.log = log end
    table.insert(top_fs.log, msg)
  end

--[[--------------------------------------------------------------------
-- support functions
----------------------------------------------------------------------]]

  --------------------------------------------------------------------
  -- reads in next token
  --------------------------------------------------------------------
  function luaY:next()
    lastln = luaX.ln
    if peek_tok then  -- is there a look-ahead token? if yes, use it
      tok, seminfo = peek_tok, peek_sem
      peek_tok = nil
    else
      tok, seminfo = luaX:lex()  -- read next token
    end
  end
  --------------------------------------------------------------------
  -- peek at next token (single lookahead for table constructor)
  --------------------------------------------------------------------
  function luaY:lookahead()
    peek_tok, peek_sem = luaX:lex()
    return peek_tok
  end

  ------------------------------------------------------------------------
  -- throws a syntax error
  ------------------------------------------------------------------------
  function luaY:syntaxerror(msg)
    local tok = tok
    if tok ~= "<number>" and tok ~= "<string>" then
      if tok == "<name>" then tok = seminfo end
      tok = "'"..tok.."'"
    end
    luaX:errorline(msg.." near "..tok)
  end
  --------------------------------------------------------------------
  -- throws a syntax error if token expected is not there
  --------------------------------------------------------------------
  function luaY:error_expected(token)
    self:syntaxerror("'"..token.."' expected")
  end

  --------------------------------------------------------------------
  -- verifies token conditions are met or else throw error
  --------------------------------------------------------------------
  function luaY:check_match(what, who, where)
    if not self:testnext(what) then
      if where == luaX.ln then
        self:error_expected(what)
      else
        self:syntaxerror("'"..what.."' expected (to close '"..who.."' at line "..where..")")
      end
    end
  end
  --------------------------------------------------------------------
  -- tests for a token, returns outcome
  -- * return value changed to boolean
  --------------------------------------------------------------------
  function luaY:testnext(c)
    if tok == c then self:next(); return true end
  end
  --------------------------------------------------------------------
  -- throws error if condition not matched
  --------------------------------------------------------------------
  function luaY:check_condition(c, msg)
    if not c then self:syntaxerror(msg) end
  end
  --------------------------------------------------------------------
  -- check for existence of a token, throws error if not found
  --------------------------------------------------------------------
  function luaY:check(c)
    if not self:testnext(c) then self:error_expected(c) end
  end

  --------------------------------------------------------------------
  -- expect that token is a name, return the name
  --------------------------------------------------------------------
  function luaY:str_checkname()
    self:check_condition(tok == "<name>", "<name> expected")
    local ts = seminfo
    self:next()
    self:log("    str_checkname: '"..ts.."'")
    return ts
  end
  --------------------------------------------------------------------
  -- adds given string s in string pool, sets e as VK
  --------------------------------------------------------------------
  function luaY:codestring(e, s)
    e.k = "VK"
    self:log("    codestring: "..string.format("%q", s))
  end
  --------------------------------------------------------------------
  -- consume a name token, adds it to string pool
  --------------------------------------------------------------------
  function luaY:checkname(e)
    self:log("    checkname:")
    self:codestring(e, self:str_checkname())
  end

--[[--------------------------------------------------------------------
-- state management functions with open/close pairs
----------------------------------------------------------------------]]

  --------------------------------------------------------------------
  -- enters a code unit, initializes elements
  --------------------------------------------------------------------
  function luaY:enterblock(isbreakable)
    local bl = {}  -- per-block state
    bl.isbreakable = isbreakable
    bl.prev = fs.bl
    fs.bl = bl
    self:log(">> enterblock(isbreakable="..tostring(isbreakable)..")")
  end
  --------------------------------------------------------------------
  -- leaves a code unit, close any upvalues
  --------------------------------------------------------------------
  function luaY:leaveblock()
    local bl = fs.bl
    fs.bl = bl.prev
    self:log("<< leaveblock")
  end
  --------------------------------------------------------------------
  -- opening of a function
  --------------------------------------------------------------------
  function luaY:open_func()
    local new_fs  -- per-function state
    if not fs then  -- top_fs is created early
      new_fs = top_fs
    else
      new_fs = {}
    end
    new_fs.prev = fs  -- linked list of function states
    new_fs.bl = nil
    fs = new_fs
    self:log(">> open_func")
  end
  --------------------------------------------------------------------
  -- closing of a function
  --------------------------------------------------------------------
  function luaY:close_func()
    fs = fs.prev
    self:log("<< close_func")
  end

--[[--------------------------------------------------------------------
-- variable (global|local|upvalue) handling
-- * does nothing for now, always returns "VLOCAL"
----------------------------------------------------------------------]]

  --------------------------------------------------------------------
  -- consume a name token, creates a variable (global|local|upvalue)
  -- * used in prefixexp(), funcname()
  --------------------------------------------------------------------
  function luaY:singlevar(v)
    local varname = self:str_checkname()
    v.k = "VLOCAL"
    self:log("    singlevar: name='"..varname.."'")
  end

--[[--------------------------------------------------------------------
-- other parsing functions
-- * for table constructor, parameter list, argument list
----------------------------------------------------------------------]]

  --------------------------------------------------------------------
  -- parse a function name suffix, for function call specifications
  -- * used in primaryexp(), funcname()
  --------------------------------------------------------------------
  function luaY:field(v)
    -- field -> ['.' | ':'] NAME
    local key = {}
    self:log("  field: operator="..tok)
    self:next()  -- skip the dot or colon
    self:checkname(key)
    v.k = "VINDEXED"
  end
  --------------------------------------------------------------------
  -- parse a table indexing suffix, for constructors, expressions
  -- * used in recfield(), primaryexp()
  --------------------------------------------------------------------
  function luaY:index(v)
    -- index -> '[' expr ']'
    self:log(">> index: begin '['")
    self:next()  -- skip the '['
    self:expr(v)
    self:check("]")
    self:log("<< index: end ']'")
  end
  --------------------------------------------------------------------
  -- parse a table record (hash) field
  -- * used in constructor()
  --------------------------------------------------------------------
  function luaY:recfield(cc)
    -- recfield -> (NAME | '['exp1']') = exp1
    local key, val = {}, {}
    if tok == "<name>" then
      self:log("recfield: name")
      self:checkname(key)
    else-- tok == '['
      self:log("recfield: [ exp1 ]")
      self:index(key)
    end
    self:check("=")
    self:expr(val)
  end
  --------------------------------------------------------------------
  -- emit a set list instruction if enough elements (LFIELDS_PER_FLUSH)
  -- * note: retained in this skeleton because it modifies cc.v.k
  -- * used in constructor()
  --------------------------------------------------------------------
  function luaY:closelistfield(cc)
    if cc.v.k == "VVOID" then return end  -- there is no list item
    cc.v.k = "VVOID"
  end
  --------------------------------------------------------------------
  -- parse a table list (array) field
  -- * used in constructor()
  --------------------------------------------------------------------
  function luaY:listfield(cc)
    self:log("listfield: expr")
    self:expr(cc.v)
  end
  --------------------------------------------------------------------
  -- parse a table constructor
  -- * used in funcargs(), simpleexp()
  --------------------------------------------------------------------
  function luaY:constructor(t)
    -- constructor -> '{' [ field { fieldsep field } [ fieldsep ] ] '}'
    -- field -> recfield | listfield
    -- fieldsep -> ',' | ';'
    self:log(">> constructor: begin")
    local line = luaX.ln
    local cc = {}
    cc.v = {}
    cc.t = t
    t.k = "VRELOCABLE"
    cc.v.k = "VVOID"
    self:check("{")
    repeat
      self:testnext(";")  -- compatibility only
      if tok == "}" then break end
      -- closelistfield(cc) here
      local c = tok
      if c == "<name>" then  -- may be listfields or recfields
        if self:lookahead() ~= "=" then  -- look ahead: expression?
          self:listfield(cc)
        else
          self:recfield(cc)
        end
      elseif c == "[" then  -- constructor_item -> recfield
        self:recfield(cc)
      else  -- constructor_part -> listfield
        self:listfield(cc)
      end
    until not self:testnext(",") and not self:testnext(";")
    self:check_match("}", "{", line)
    -- lastlistfield(cc) here
    self:log("<< constructor: end")
  end
  --------------------------------------------------------------------
  -- parse the arguments (parameters) of a function declaration
  -- * used in body()
  --------------------------------------------------------------------
  function luaY:parlist()
    -- parlist -> [ param { ',' param } ]
    self:log(">> parlist: begin")
    local dots = false
    if tok ~= ")" then  -- is 'parlist' not empty?
      repeat
        local c = tok
        if c == "..." then
          self:log("parlist: ... (dots)")
          dots = true
          self:next()
        elseif c == "<name>" then
          local str = self:str_checkname()
        else
          self:syntaxerror("<name> or '...' expected")
        end
      until dots or not self:testnext(",")
    end
    self:log("<< parlist: end")
  end
  --------------------------------------------------------------------
  -- parse the parameters of a function call
  -- * contrast with parlist(), used in function declarations
  -- * used in primaryexp()
  --------------------------------------------------------------------
  function luaY:funcargs(f)
    local args = {}
    local line = luaX.ln
    local c = tok
    if c == "(" then  -- funcargs -> '(' [ explist1 ] ')'
      self:log(">> funcargs: begin '('")
      if line ~= lastln then
        self:syntaxerror("ambiguous syntax (function call x new statement)")
      end
      self:next()
      if tok == ")" then  -- arg list is empty?
        args.k = "VVOID"
      else
        self:explist1(args)
      end
      self:check_match(")", "(", line)
    elseif c == "{" then  -- funcargs -> constructor
      self:log(">> funcargs: begin '{'")
      self:constructor(args)
    elseif c == "<string>" then  -- funcargs -> STRING
      self:log(">> funcargs: begin <string>")
      self:codestring(args, seminfo)
      self:next()  -- must use 'seminfo' before 'next'
    else
      self:syntaxerror("function arguments expected")
      return
    end--if c
    f.k = "VCALL"
    self:log("<< funcargs: end -- expr is a VCALL")
  end

--[[--------------------------------------------------------------------
-- mostly expression functions
----------------------------------------------------------------------]]

  --------------------------------------------------------------------
  -- parses an expression in parentheses or a single variable
  -- * used in primaryexp()
  --------------------------------------------------------------------
  function luaY:prefixexp(v)
    -- prefixexp -> NAME | '(' expr ')'
    local c = tok
    if c == "(" then
      self:log(">> prefixexp: begin ( expr ) ")
      local line = self.ln
      self:next()
      self:expr(v)
      self:check_match(")", "(", line)
      self:log("<< prefixexp: end ( expr ) ")
    elseif c == "<name>" then
      self:log("prefixexp: <name>")
      self:singlevar(v)
    else
      self:syntaxerror("unexpected symbol")
    end--if c
  end
  --------------------------------------------------------------------
  -- parses a prefixexp (an expression in parentheses or a single
  -- variable) or a function call specification
  -- * used in simpleexp(), assignment(), expr_stat()
  --------------------------------------------------------------------
  function luaY:primaryexp(v)
    -- primaryexp ->
    --    prefixexp { '.' NAME | '[' exp ']' | ':' NAME funcargs | funcargs }
    self:prefixexp(v)
    while true do
      local c = tok
      if c == "." then  -- field
        self:log("primaryexp: '.' field")
        self:field(v)
      elseif c == "[" then  -- '[' exp1 ']'
        self:log("primaryexp: [ exp1 ]")
        local key = {}
        self:index(key)
      elseif c == ":" then  -- ':' NAME funcargs
        self:log("primaryexp: :<name> funcargs")
        local key = {}
        self:next()
        self:checkname(key)
        self:funcargs(v)
      elseif c == "(" or c == "<string>" or c == "{" then  -- funcargs
        self:log("primaryexp: "..c.." funcargs")
        self:funcargs(v)
      else
        return
      end--if c
    end--while
  end
  --------------------------------------------------------------------
  -- parses general expression types, constants handled here
  -- * used in subexpr()
  --------------------------------------------------------------------
  function luaY:simpleexp(v)
    -- simpleexp -> NUMBER | STRING | NIL | TRUE | FALSE | constructor
    --           | FUNCTION body | primaryexp
    local c = tok
    if c == "<number>" then
      self:log("simpleexp: <number>="..seminfo)
      v.k = "VK"
      self:next()  -- must use 'seminfo' before 'next'
    elseif c == "<string>" then
      self:log("simpleexp: <string>="..seminfo)
      self:codestring(v, seminfo)
      self:next()  -- must use 'seminfo' before 'next'
    elseif c == "nil" then
      self:log("simpleexp: nil")
      v.k = "VNIL"
      self:next()
    elseif c == "true" then
      self:log("simpleexp: true")
      v.k = "VTRUE"
      self:next()
    elseif c == "false" then
      self:log("simpleexp: false")
      v.k = "VFALSE"
      self:next()
    elseif c == "{" then  -- constructor
      self:log("simpleexp: constructor")
      self:constructor(v)
    elseif c == "function" then
      self:log("simpleexp: function")
      self:next()
      self:body(v, false, luaX.ln)
    else
      self:primaryexp(v)
    end--if c
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
  function luaY:subexpr(v, limit)
    -- subexpr -> (simpleexp | unop subexpr) { binop subexpr }
    --   * where 'binop' is any binary operator with a priority
    --     higher than 'limit'
    local op = tok
    local uop = unopr[op]
    if uop then
      self:log("  subexpr: uop='"..op.."'")
      self:next()
      self:subexpr(v, 8) -- UNARY_PRIORITY
    else
      self:simpleexp(v)
    end
    -- expand while operators have priorities higher than 'limit'
    op = tok
    local binop = binopr_left[op]
    while binop and binop > limit do
      local v2 = {}
      self:log(">> subexpr: binop='"..op.."'")
      self:next()
      -- read sub-expression with higher priority
      local nextop = self:subexpr(v2, binopr_right[op])
      self:log("<< subexpr: -- evaluate")
      op = nextop
      binop = binopr_left[op]
    end
    return op  -- return first untreated operator
  end
  --------------------------------------------------------------------
  -- Expression parsing starts here. Function subexpr is entered with the
  -- left operator (which is non-existent) priority of -1, which is lower
  -- than all actual operators. Expr information is returned in parm v.
  -- * used in cond(), explist1(), index(), recfield(), listfield(),
  --   prefixexp(), while_stat(), exp1()
  --------------------------------------------------------------------
  function luaY:expr(v)
    -- expr -> subexpr
    self:log("expr:")
    self:subexpr(v, -1)
  end

--[[--------------------------------------------------------------------
-- third level parsing functions
----------------------------------------------------------------------]]

  --------------------------------------------------------------------
  -- parse a variable assignment sequence
  -- * recursively called
  -- * used in expr_stat()
  --------------------------------------------------------------------
  function luaY:assignment(v)
    local e = {}
    local c = v.v.k
    self:check_condition(c == "VLOCAL" or c == "VUPVAL" or c == "VGLOBAL"
                         or c == "VINDEXED", "syntax error")
    if self:testnext(",") then  -- assignment -> ',' primaryexp assignment
      local nv = {}  -- expdesc
      nv.v = {}
      self:log("assignment: ',' -- next LHS element")
      self:primaryexp(nv.v)
      -- lparser.c deals with some register usage conflict here
      self:assignment(nv)
    else  -- assignment -> '=' explist1
      self:check("=")
      self:log("assignment: '=' -- RHS elements follows")
      self:explist1(e)
      return  -- avoid default
    end
    e.k = "VNONRELOC"
  end
  --------------------------------------------------------------------
  -- parse a for loop body for both versions of the for loop
  -- * used in fornum(), forlist()
  --------------------------------------------------------------------
  function luaY:forbody(line, isnum)
    self:check("do")
    self:enterblock(true)  -- loop block
    self:block()
    self:leaveblock()
  end
  --------------------------------------------------------------------
  -- parse a numerical for loop, calls forbody()
  -- * used in for_stat()
  --------------------------------------------------------------------
  function luaY:fornum(line)
    -- fornum -> NAME = exp1, exp1 [, exp1] DO body
    self:log(">> fornum: begin")
    self:check("=")
    self:log("fornum: index start")
    self:exp1()  -- initial value
    self:check(",")
    self:log("fornum: index stop")
    self:exp1()  -- limit
    if self:testnext(",") then
      self:log("fornum: index step")
      self:exp1()  -- optional step
    else
      -- default step = 1
    end
    self:log("fornum: body")
    self:forbody(line, true)
    self:log("<< fornum: end")
  end
  --------------------------------------------------------------------
  -- parse a generic for loop, calls forbody()
  -- * used in for_stat()
  --------------------------------------------------------------------
  function luaY:forlist()
    -- forlist -> NAME {, NAME} IN explist1 DO body
    self:log(">> forlist: begin")
    local e = {}
    while self:testnext(",") do
      self:str_checkname()
    end
    self:check("in")
    local line = line
    self:log("forlist: explist1")
    self:explist1(e)
    self:log("forlist: body")
    self:forbody(line, false)
    self:log("<< forlist: end")
  end
  --------------------------------------------------------------------
  -- parse a function name specification
  -- * used in func_stat()
  --------------------------------------------------------------------
  function luaY:funcname(v)
    -- funcname -> NAME {field} [':' NAME]
    self:log(">> funcname: begin")
    local needself = false
    self:singlevar(v)
    while tok == "." do
      self:log("funcname: -- '.' field")
      self:field(v)
    end
    if tok == ":" then
      self:log("funcname: -- ':' field")
      needself = true
      self:field(v)
    end
    self:log("<< funcname: end")
    return needself
  end
  --------------------------------------------------------------------
  -- parse the single expressions needed in numerical for loops
  -- * used in fornum()
  --------------------------------------------------------------------
  function luaY:exp1()
    -- exp1 -> expr
    local e = {}
    self:log(">> exp1: begin")
    self:expr(e)
    self:log("<< exp1: end")
  end
  --------------------------------------------------------------------
  -- parse condition in a repeat statement or an if control structure
  -- * used in repeat_stat(), test_then_block()
  --------------------------------------------------------------------
  function luaY:cond(v)
    -- cond -> expr
    self:log(">> cond: begin")
    self:expr(v)  -- read condition
    self:log("<< cond: end")
  end
  --------------------------------------------------------------------
  -- parse part of an if control structure, including the condition
  -- * used in if_stat()
  --------------------------------------------------------------------
  function luaY:test_then_block(v)
    -- test_then_block -> [IF | ELSEIF] cond THEN block
    self:next()  -- skip IF or ELSEIF
    self:log("test_then_block: test condition")
    self:cond(v)
    self:check("then")
    self:log("test_then_block: then block")
    self:block()  -- 'then' part
  end
  --------------------------------------------------------------------
  -- parse a local function statement
  -- * used in local_stat()
  --------------------------------------------------------------------
  function luaY:localfunc()
    -- localfunc -> NAME body
    local v, b = {}
    self:log("localfunc: begin")
    local str = self:str_checkname()
    v.k = "VLOCAL"
    self:log("localfunc: body")
    self:body(b, false, luaX.ln)
    self:log("localfunc: end")
  end
  --------------------------------------------------------------------
  -- parse a local variable declaration statement
  -- * used in local_stat()
  --------------------------------------------------------------------
  function luaY:localstat()
    -- localstat -> NAME {',' NAME} ['=' explist1]
    self:log(">> localstat: begin")
    local e = {}
    repeat
      local str = self:str_checkname()
    until not self:testnext(",")
    if self:testnext("=") then
      self:log("localstat: -- assignment")
      self:explist1(e)
    else
      e.k = "VVOID"
    end
    self:log("<< localstat: end")
  end
  --------------------------------------------------------------------
  -- parse a list of comma-separated expressions
  -- * used in return_stat(), localstat(), funcargs(), assignment(),
  --   forlist()
  --------------------------------------------------------------------
  function luaY:explist1(e)
    -- explist1 -> expr { ',' expr }
    self:log(">> explist1: begin")
    self:expr(e)
    while self:testnext(",") do
      self:log("explist1: ',' -- continuation")
      self:expr(e)
    end
    self:log("<< explist1: end")
  end
  --------------------------------------------------------------------
  -- parse function declaration body
  -- * used in simpleexp(), localfunc(), func_stat()
  --------------------------------------------------------------------
  function luaY:body(e, needself, line)
    -- body ->  '(' parlist ')' chunk END
    self:open_func()
    self:log("body: begin")
    self:check("(")
    if needself then
      -- handle 'self' processing here
    end
    self:log("body: parlist")
    self:parlist()
    self:check(")")
    self:log("body: chunk")
    self:chunk()
    self:check_match("end", "function", line)
    self:log("body: end")
    self:close_func()
  end
  --------------------------------------------------------------------
  -- parse a code block or unit
  -- * used in do_stat(), while_stat(), repeat_stat(), forbody(),
  --   test_then_block(), if_stat()
  --------------------------------------------------------------------
  function luaY:block()
    -- block -> chunk
    self:log("block: begin")
    self:enterblock(false)
    self:chunk()
    self:leaveblock()
    self:log("block: end")
  end

--[[--------------------------------------------------------------------
-- second level parsing functions, all with '_stat' suffix
-- * stat() -> *_stat()
----------------------------------------------------------------------]]

  --------------------------------------------------------------------
  -- initial parsing for a for loop, calls fornum() or forlist()
  -- * used in stat()
  --------------------------------------------------------------------
  function luaY:for_stat()
    -- stat -> for_stat -> fornum | forlist
    local line = line
    self:log("for_stat: begin")
    self:enterblock(false)  -- block to control variable scope
    self:next()  -- skip 'for'
    local str = self:str_checkname()  -- first variable name
    local c = tok
    if c == "=" then
      self:log("for_stat: numerical loop")
      self:fornum(line)
    elseif c == "," or c == "in" then
      self:log("for_stat: list-based loop")
      self:forlist()
    else
      self:syntaxerror("'=' or 'in' expected")
    end
    self:check_match("end", "for", line)
    self:leaveblock()
    self:log("for_stat: end")
  end
  --------------------------------------------------------------------
  -- parse a while-do control structure, body processed by block()
  -- * used in stat()
  --------------------------------------------------------------------
  function luaY:while_stat()
    -- stat -> while_stat -> WHILE cond DO block END
    local line = line
    local v = {}
    self:next()  -- skip WHILE
    self:log("while_stat: begin/condition")
    self:expr(v)  -- parse condition
    self:enterblock(true)
    self:check("do")
    self:log("while_stat: block")
    self:block()
    self:check_match("end", "while", line)
    self:leaveblock()
    self:log("while_stat: end")
  end
  --------------------------------------------------------------------
  -- parse a repeat-until control structure, body parsed by block()
  -- * used in stat()
  --------------------------------------------------------------------
  function luaY:repeat_stat()
    -- stat -> repeat_stat -> REPEAT block UNTIL cond
    local line = line
    local v = {}
    self:log("repeat_stat: begin")
    self:enterblock(true)
    self:next()
    self:block()
    self:check_match("until", "repeat", line)
    self:log("repeat_stat: condition")
    self:cond(v)
    self:leaveblock()
    self:log("repeat_stat: end")
  end
  --------------------------------------------------------------------
  -- parse an if control structure
  -- * used in stat()
  --------------------------------------------------------------------
  function luaY:if_stat()
    -- stat -> if_stat -> IF cond THEN block
    --                    {ELSEIF cond THEN block} [ELSE block] END
    local line = line
    local v = {}
    self:log("if_stat: if...then")
    self:test_then_block(v)  -- IF cond THEN block
    while tok == "elseif" do
      self:log("if_stat: elseif...then")
      self:test_then_block(v)  -- ELSEIF cond THEN block
    end
    if tok == "else" then
      self:log("if_stat: else...")
      self:next()  -- skip ELSE
      self:block()  -- 'else' part
    end
    self:check_match("end", "if", line)
    self:log("if_stat: end")
  end
  --------------------------------------------------------------------
  -- parse a return statement
  -- * used in stat()
  --------------------------------------------------------------------
  function luaY:return_stat()
    -- stat -> return_stat -> RETURN explist
    local e = {}
    self:next()  -- skip RETURN
    local c = tok
    if block_follow[c] or c == ";" then
      -- return no values
      self:log("return_stat: no return values")
    else
      self:log("return_stat: begin")
      self:explist1(e)  -- optional return values
      self:log("return_stat: end")
    end
  end
  --------------------------------------------------------------------
  -- parse a break statement
  -- * used in stat()
  --------------------------------------------------------------------
  function luaY:break_stat()
    -- stat -> break_stat -> BREAK
    local bl = fs.bl
    self:next()  -- skip BREAK
    while bl and not bl.isbreakable do -- find a breakable block
      bl = bl.prev
    end
    if not bl then
      self:syntaxerror("no loop to break")
    end
    self:log("break_stat: -- break out of loop")
  end
  --------------------------------------------------------------------
  -- parse a function call with no returns or an assignment statement
  -- * the struct with .prev is used for name searching in lparse.c,
  --   so it is retained for now; present in assignment() also
  -- * used in stat()
  --------------------------------------------------------------------
  function luaY:expr_stat()
    -- stat -> expr_stat -> func | assignment
    local v = {}
    v.v = {}
    self:primaryexp(v.v)
    if v.v.k == "VCALL" then  -- stat -> func
      -- call statement uses no results
      self:log("expr_stat: function call k='"..v.v.k.."'")
    else  -- stat -> assignment
      self:log("expr_stat: assignment k='"..v.v.k.."'")
      v.prev = nil
      self:assignment(v)
    end
  end
  --------------------------------------------------------------------
  -- parse a function statement
  -- * used in stat()
  --------------------------------------------------------------------
  function luaY:function_stat()
    -- stat -> function_stat -> FUNCTION funcname body
    local line = line
    local v, b = {}, {}
    self:log("function_stat: begin")
    self:next()  -- skip FUNCTION
    local needself = self:funcname(v)
    self:log("function_stat: body needself='"..tostring(needself).."'")
    self:body(b, needself, line)
    self:log("function_stat: end")
  end
  --------------------------------------------------------------------
  -- parse a simple block enclosed by a DO..END pair
  -- * used in stat()
  --------------------------------------------------------------------
  function luaY:do_stat()
    -- stat -> do_stat -> DO block END
    self:next()  -- skip DO
    self:log("do_stat: begin")
    self:block()
    self:log("do_stat: end")
    self:check_match("end", "do", line)
  end
  --------------------------------------------------------------------
  -- parse a statement starting with LOCAL
  -- * used in stat()
  --------------------------------------------------------------------
  function luaY:local_stat()
    -- stat -> local_stat -> LOCAL FUNCTION localfunc
    --                    -> LOCAL localstat
    self:next()  -- skip LOCAL
    if self:testnext("function") then  -- local function?
      self:log("local_stat: local function")
      self:localfunc()
    else
      self:log("local_stat: local statement")
      self:localstat()
    end
  end

--[[--------------------------------------------------------------------
-- main function, top level parsing functions
-- * [entry] -> parser() -> chunk() -> stat()
----------------------------------------------------------------------]]

  --------------------------------------------------------------------
  -- initial parsing for statements, calls '_stat' suffixed functions
  -- * used in chunk()
  --------------------------------------------------------------------
  function luaY:stat()
    line = luaX.ln
    local c = tok
    local fn = stat_call[c]
    -- handles: if while do for repeat function local return break
    if fn then
      self:log("-- STATEMENT: begin '"..c.."' line="..line)
      self[fn](self)
      self:log("-- STATEMENT: end '"..c.."'")
      -- return or break must be last statement
      if c == "return" or c == "break" then return true end
    else
      self:log("-- STATEMENT: begin 'expr' line="..line)
      self:expr_stat()
      self:log("-- STATEMENT: end 'expr'")
    end
    self:log("")
    return false
  end
  --------------------------------------------------------------------
  -- parse a chunk, which consists of a bunch of statements
  -- * used in parser(), body(), block()
  --------------------------------------------------------------------
  function luaY:chunk()
    -- chunk -> { stat [';'] }
    self:log("chunk:")
    local islast = false
    while not islast and not block_follow[tok] do
      islast = self:stat()
      self:testnext(";")
    end
  end
  --------------------------------------------------------------------
  -- performs parsing, returns parsed data structure
  --------------------------------------------------------------------
  function luaY:parser()
    self:log("-- TOP: begin")
    self:open_func()
    self:log("")
    self:next()  -- read first token
    self:chunk()
    self:check_condition(tok == "<eof>", "<eof> expected")
    self:close_func()
    self:log("-- TOP: end")
    return top_fs
  end
  --------------------------------------------------------------------
  return luaY -- return actual module to user, done
end
