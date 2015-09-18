--[[--------------------------------------------------------------------

  llex.lua
  Lua 5 lexical analyzer in Lua
  This file is part of Yueliang.

  Copyright (c) 2005-2006 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- Notes:
-- * intended to 'imitate' llex.c code; performance is not a concern
-- * tokens are strings; code structure largely retained
-- * deleted stuff (compared to llex.c) are noted, comments retained
-- * Added:
--   luaX:chunkid (from lobject.c)
-- * To use the lexer:
--   (1) luaX:init() to initialize the lexer
--   (2) luaX:setinput() to set the input stream to lex, get LS
--   (3) call luaX:lex() to get tokens, until "TK_EOS":
--       LS.t.token = luaX:lex(LS, LS.t)
-- * since EOZ is returned as a string, be careful when regexp testing
----------------------------------------------------------------------]]

luaX = {}

-- FIRST_RESERVED is not required as tokens are manipulated as strings
-- TOKEN_LEN deleted; maximum length of a reserved word

------------------------------------------------------------------------
-- "ORDER RESERVED" deleted; enumeration in one place: luaX.RESERVED
------------------------------------------------------------------------

-- terminal symbols denoted by reserved words: TK_AND to TK_WHILE
-- other terminal symbols: TK_NAME to TK_EOS
luaX.RESERVED = [[
TK_AND and
TK_BREAK break
TK_DO do
TK_ELSE else
TK_ELSEIF elseif
TK_END end
TK_FALSE false
TK_FOR for
TK_FUNCTION function
TK_IF if
TK_IN in
TK_LOCAL local
TK_NIL nil
TK_NOT not
TK_OR or
TK_REPEAT repeat
TK_RETURN return
TK_THEN then
TK_TRUE true
TK_UNTIL until
TK_WHILE while
TK_NAME *name
TK_CONCAT ..
TK_DOTS ...
TK_EQ ==
TK_GE >=
TK_LE <=
TK_NE ~=
TK_NUMBER *number
TK_STRING *string
TK_EOS <eof>]]

-- NUM_RESERVED is not required; number of reserved words

--[[--------------------------------------------------------------------
-- Instead of passing seminfo, the Token struct (e.g. LS.t) is passed
-- so that lexer functions can use its table element, LS.t.seminfo
--
-- Token (struct of LS.t and LS.lookahead):
--   token  -- token symbol
--   seminfo  -- semantics information
--
-- LexState (struct of LS; LS is initialized by luaX:setinput):
--   current  -- current character
--   linenumber  -- input line counter
--   lastline  -- line of last token 'consumed'
--   t  -- current token (table: struct Token)
--   lookahead  -- look ahead token (table: struct Token)
--   fs  -- 'FuncState' is private to the parser
--   L -- LuaState
--   z  -- input stream
--   buff  -- buffer for tokens
--   source  -- current source name
--   nestlevel  -- level of nested non-terminals
----------------------------------------------------------------------]]

-- token2string is now a hash; see luaX:init

------------------------------------------------------------------------
-- initialize lexer
------------------------------------------------------------------------
function luaX:init()
  self.token2string = {}
  self.string2token = {}
  for v in string.gfind(self.RESERVED, "[^\n]+") do
    local _, _, tok, str = string.find(v, "(%S+)%s+(%S+)")
    self.token2string[tok] = str
    self.string2token[str] = tok
  end
end

luaX.MAXSRC = 80

------------------------------------------------------------------------
-- returns a suitably-formatted chunk name or id
-- * from lobject.c, used in llex.c and ldebug.c
-- * the result, out, is returned (was first argument)
------------------------------------------------------------------------
function luaX:chunkid(source, bufflen)
  local out
  local first = string.sub(source, 1, 1)
  if first == "=" then
    out = string.sub(source, 2, bufflen)  -- remove first char
  else  -- out = "source", or "...source"
    if first == "@" then
      source = string.sub(source, 2)  -- skip the '@'
      bufflen = bufflen - string.len(" `...' ")
      local l = string.len(source)
      out = ""
      if l > bufflen then
        source = string.sub(source, 1 + l - bufflen)  -- get last part of file name
        out = out.."..."
      end
      out = out..source
    else  -- out = [string "string"]
      local len = string.find(source, "\n", 1, 1)  -- stop at first newline
      len = len and (len - 1) or string.len(source)
      bufflen = bufflen - string.len(" [string \"...\"] ")
      if len > bufflen then len = bufflen end
      out = "[string \""
      if len < string.len(source) then  -- must truncate?
        out = out..string.sub(source, 1, len).."..."
      else
        out = out..source
      end
      out = out.."\"]"
    end
  end
  return out
end

--[[--------------------------------------------------------------------
-- Support functions for lexer
-- * all lexer errors eventually reaches errorline:
     checklimit -> syntaxerror -> error -> errorline
                      lexerror -> error -> errorline
----------------------------------------------------------------------]]

------------------------------------------------------------------------
-- limit check, syntax error if fails (also called by parser)
------------------------------------------------------------------------
function luaX:checklimit(ls, val, limit, msg)
  if val > limit then
    msg = string.format("too many %s (limit=%d)", msg, limit)
    self:syntaxerror(ls, msg)
  end
end

------------------------------------------------------------------------
-- formats error message and throws error (also called by parser)
------------------------------------------------------------------------
function luaX:errorline(ls, s, token, line)
  local buff = self:chunkid(ls.source, self.MAXSRC)
  error(string.format("%s:%d: %s near `%s'", buff, line, s, token))
end

------------------------------------------------------------------------
-- throws an error, adds line number
------------------------------------------------------------------------
function luaX:error(ls, s, token)
  self:errorline(ls, s, token, ls.linenumber)
end

------------------------------------------------------------------------
-- throws a syntax error (mainly called by parser)
-- * ls.t.token has to be set by the function calling luaX:lex
--   (see next() and lookahead() in lparser.c)
------------------------------------------------------------------------
function luaX:syntaxerror(ls, msg)
  local lasttoken
  local tok = ls.t.token
  if tok == "TK_NAME" then
    lasttoken = ls.t.seminfo
  elseif tok == "TK_STRING" or tok == "TK_NUMBER" then
    lasttoken = ls.buff
  else
    lasttoken = self:token2str(ls.t.token)
  end
  self:error(ls, msg, lasttoken)
end

------------------------------------------------------------------------
-- look up token and return keyword if found (also called by parser)
------------------------------------------------------------------------
function luaX:token2str(ls, token)
  if string.sub(token, 1, 3) ~= "TK_" then
    return token
  else
    --lua_assert(string.len(token) == 1)
    return self.token2string[token]
  end
end

------------------------------------------------------------------------
-- throws a lexer error
------------------------------------------------------------------------
function luaX:lexerror(ls, s, token)
  if token == "TK_EOS" then
    self:error(ls, s, self:token2str(ls, token))
  else
    self:error(ls, s, ls.buff)
  end
end

------------------------------------------------------------------------
-- move on to next line
------------------------------------------------------------------------
function luaX:inclinenumber(LS)
  self:next(LS)  -- skip '\n'
  LS.linenumber = LS.linenumber + 1
  self:checklimit(LS, LS.linenumber, self.MAX_INT, "lines in a chunk")
end

luaX.MAX_INT = 2147483645  -- INT_MAX-2 for 32-bit systems (llimits.h)

------------------------------------------------------------------------
-- initializes an input stream for lexing
-- * if LS (the lexer state) is passed as a table, then it is filled in,
--   otherwise it has to be retrieved as a return value
------------------------------------------------------------------------
function luaX:setinput(L, LS, z, source)
  if not LS then LS = {} end  -- create struct
  if not LS.lookahead then LS.lookahead = {} end
  if not LS.t then LS.t = {} end
  LS.L = L
  LS.lookahead.token = "TK_EOS"  -- no look-ahead token
  LS.z = z
  LS.fs = nil
  LS.linenumber = 1
  LS.lastline = 1
  LS.source = source
  self:next(LS)  -- read first char
  if LS.current == "#" then
    repeat  -- skip first line
      self:next(LS)
    until LS.current == "\n" or LS.current == "EOZ"
  end
  return LS
end

--[[--------------------------------------------------------------------
-- LEXICAL ANALYZER
----------------------------------------------------------------------]]

-- NOTE the following buffer handling stuff are no longer required:
-- use buffer to store names, literal strings and numbers
-- EXTRABUFF deleted; extra space to allocate when growing buffer
-- MAXNOCHECK deleted; maximum number of chars that can be read without checking buffer size
-- checkbuffer(LS, len)	deleted

------------------------------------------------------------------------
-- gets the next character and returns it
------------------------------------------------------------------------
function luaX:next(LS)
  local c = luaZ:zgetc(LS.z)
  LS.current = c
  return c
end

------------------------------------------------------------------------
-- saves the given character into the token buffer
------------------------------------------------------------------------
function luaX:save(LS, c)
  LS.buff = LS.buff..c
end

------------------------------------------------------------------------
-- save current character into token buffer, grabs next character
------------------------------------------------------------------------
function luaX:save_and_next(LS)
  self:save(LS, LS.current)
  return self:next(LS)
end

------------------------------------------------------------------------
-- reads a name
-- * originally returns the string length
------------------------------------------------------------------------
function luaX:readname(LS)
  LS.buff = ""
  repeat
    self:save_and_next(LS)
  until LS.current == "EOZ" or not string.find(LS.current, "[_%w]")
  return LS.buff
end

------------------------------------------------------------------------
-- reads a number (LUA_NUMBER)
------------------------------------------------------------------------
function luaX:read_numeral(LS, comma, Token)
  LS.buff = ""
  if comma then self:save(LS, '.') end
  while string.find(LS.current, "%d") do
    self:save_and_next(LS)
  end
  if LS.current == "." then
    self:save_and_next(LS)
    if LS.current == "." then
      self:save_and_next(LS)
      self:lexerror(LS,
        "ambiguous syntax (decimal point x string concatenation)",
        "TK_NUMBER")
    end
  end
  while string.find(LS.current, "%d") do
    self:save_and_next(LS)
  end
  if LS.current == "e" or LS.current == "E" then
    self:save_and_next(LS)  -- read 'E'
    if LS.current == "+" or LS.current == "-" then
      self:save_and_next(LS)  -- optional exponent sign
    end
    while string.find(LS.current, "%d") do
      self:save_and_next(LS)
    end
  end
  local seminfo = tonumber(LS.buff)
  if not seminfo then
    self:lexerror(LS, "malformed number", "TK_NUMBER")
  end
  Token.seminfo = seminfo
end

------------------------------------------------------------------------
-- reads a long string or long comment
------------------------------------------------------------------------
function luaX:read_long_string(LS, Token)
  local cont = 0
  LS.buff = ""
  self:save(LS, "[")  -- save first '['
  self:save_and_next(LS)  -- pass the second '['
  if LS.current == "\n" then  -- string starts with a newline?
    self:inclinenumber(LS)  -- skip it
  end
  while true do
    local c = LS.current
    if c == "EOZ" then
      self:lexerror(LS, Token and "unfinished long string" or
                    "unfinished long comment", "TK_EOS")
    elseif c == "[" then
      self:save_and_next(LS)
      if LS.current == "[" then
        cont = cont + 1
        self:save_and_next(LS)
      end
    elseif c == "]" then
      self:save_and_next(LS)
      if LS.current == "]" then
        if cont == 0 then break end
        cont = cont - 1
        self:save_and_next(LS)
      end
    elseif c == "\n" then
      self:save(LS, "\n")
      self:inclinenumber(LS)
      if not Token then LS.buff = "" end -- reset buffer to avoid wasting space
    else
      self:save_and_next(LS)
    end--if c
  end--while
  self:save_and_next(LS)  -- skip the second ']'
  if Token then
    Token.seminfo = string.sub(LS.buff, 3, -3)
  end
end

------------------------------------------------------------------------
-- reads a string
------------------------------------------------------------------------
function luaX:read_string(LS, del, Token)
  LS.buff = ""
  self:save_and_next(LS)
  while LS.current ~= del do
    local c = LS.current
    if c == "EOZ" then
      self:lexerror(LS, "unfinished string", "TK_EOS")
    elseif c == "\n" then
      self:lexerror(LS, "unfinished string", "TK_STRING")
    elseif c == "\\" then
      c = self:next(LS)  -- do not save the '\'
      if c ~= "EOZ" then -- will raise an error next loop
        -- escapes handling greatly simplified here:
        local i = string.find("abfnrtv\n", c, 1, 1)
        if i then
          self:save(LS, string.sub("\a\b\f\n\r\t\v\n", i, i))
          if i == 8 then self:inclinenumber(LS) else self:next(LS) end
        elseif not string.find(c, "%d") then
          self:save_and_next(LS)  -- handles \\, \", \', and \?
        else  -- \xxx
          c, i = 0, 0
          repeat
            c = 10 * c + LS.current
            self:next(LS)
            i = i + 1
          until i >= 3 or not string.find(LS.current, "%d")
          if c > 255 then  -- UCHAR_MAX
            self:lexerror(LS, "escape sequence too large", "TK_STRING")
          end
          self:save(LS, string.char(c))
        end
      end
    else
      self:save_and_next(LS)
    end--if c
  end--while
  self:save_and_next(LS)  -- skip delimiter
  Token.seminfo = string.sub(LS.buff, 2, -2)
end

------------------------------------------------------------------------
-- main lexer function
------------------------------------------------------------------------
function luaX:lex(LS, Token)
  while true do
    local c = LS.current
    ----------------------------------------------------------------
    if c == "\n" then
      self:inclinenumber(LS)
    ----------------------------------------------------------------
    elseif c == "-" then
      c = self:next(LS)
      if c ~= "-" then return "-" end
      -- else is a comment
      c = self:next(LS)
      if c == "[" and self:next(LS) == "[" then
        self:read_long_string(LS)  -- long comment
      else  -- short comment
        c = LS.current
        while c ~= "\n" and c ~= "EOZ" do
          c = self:next(LS)
        end
      end
    ----------------------------------------------------------------
    elseif c == "[" then
      c = self:next(LS)
      if c ~= "[" then return "["
      else
        self:read_long_string(LS, Token)
        return "TK_STRING"
      end
    ----------------------------------------------------------------
    elseif c == "=" then
      c = self:next(LS)
      if c ~= "=" then return "="
      else self:next(LS); return "TK_EQ" end
    ----------------------------------------------------------------
    elseif c == "<" then
      c = self:next(LS)
      if c ~= "=" then return "<"
      else self:next(LS); return "TK_LE" end
    ----------------------------------------------------------------
    elseif c == ">" then
      c = self:next(LS)
      if c ~= "=" then return ">"
      else self:next(LS); return "TK_GE" end
    ----------------------------------------------------------------
    elseif c == "~" then
      c = self:next(LS)
      if c ~= "=" then return "~"
      else self:next(LS); return "TK_NE" end
    ----------------------------------------------------------------
    elseif c == "\"" or c == "'" then
      self:read_string(LS, c, Token)
      return "TK_STRING"
    ----------------------------------------------------------------
    elseif c == "." then
      c = self:next(LS)
      if c == "." then
        c = self:next(LS)
        if c == "." then
          self:next(LS)
          return "TK_DOTS"  -- ...
        else
          return "TK_CONCAT"  -- ..
        end
      elseif not string.find(c, "%d") then
        return '.'
      else
        self:read_numeral(LS, true, Token)
        return "TK_NUMBER"
      end
    ----------------------------------------------------------------
    elseif c == "EOZ" then
      return "TK_EOS"
    ----------------------------------------------------------------
    else  -- default
      if string.find(c, "%s") then
        self:next(LS)
      elseif string.find(c, "%d") then
        self:read_numeral(LS, false, Token)
        return "TK_NUMBER"
      elseif string.find(c, "[_%a]") then
        -- identifier or reserved word
        local l = self:readname(LS)
        local tok = self.string2token[l]
        if tok then return tok end  -- reserved word?
        Token.seminfo = l
        return "TK_NAME"
      else
        if string.find(c, "%c") then
          self:error(LS, "invalid control char",
                     string.format("char(%d)", string.byte(c)))
        end
        self:next(LS)
        return c  -- single-char tokens (+ - / ...)
      end
    ----------------------------------------------------------------
    end--if c
  end--while
end
