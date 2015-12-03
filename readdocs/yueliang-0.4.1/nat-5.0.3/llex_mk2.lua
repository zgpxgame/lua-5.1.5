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
-- * parser to implement luaX_syntaxerror, call errorline with 2 parms
----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- local lex_init = require("llex.lua")
-- local llex = lex_init(z, source)
-- llex:chunkid()
-- * returns formatted name of chunk id
-- llex:errorline(s, token, line)
-- * throws an error with a formatted message
-- llex:lex()
-- * returns next lexical element (token, seminfo)
----------------------------------------------------------------------]]

return
function(z, source)
--[[--------------------------------------------------------------------
-- lexer initialization
----------------------------------------------------------------------]]
  --------------------------------------------------------------------
  -- initialize variables
  --------------------------------------------------------------------
  local string = string
  local EOF = "<eof>"
  local z = z
  local luaX = {source = source, lineno = 1,}
  local curr, buff
  --------------------------------------------------------------------
  -- initialize keyword list
  --------------------------------------------------------------------
  local kw = {}
  for v in string.gfind([[
and break do else elseif end false for function if in
local nil not or repeat return then true until while]], "%S+") do
    kw[v] = true
  end
--[[--------------------------------------------------------------------
-- support functions
----------------------------------------------------------------------]]
  --------------------------------------------------------------------
  -- returns a chunk name or id
  --------------------------------------------------------------------
  function luaX:chunkid()
    local sub = string.sub
    local first = sub(source, 1, 1)
    if first == "=" or first == "@" then
      return sub(source, 2)  -- remove first char
    end
    return "[string]"
  end
  --------------------------------------------------------------------
  -- formats error message and throws error
  --------------------------------------------------------------------
  function luaX:errorline(s, token, line)
    if not line then line = self.lineno end
    error(string.format("%s:%d: %s near '%s'", self:chunkid(), line, s, token))
  end
  --------------------------------------------------------------------
  -- throws a lexer error
  --------------------------------------------------------------------
  local function lexerror(s, token)
    if not token then token = buff end
    luaX:errorline(s, token)
  end
  --------------------------------------------------------------------
  -- gets the next character and returns it
  --------------------------------------------------------------------
  local function nextc()
    local c = z:getc()
    curr = c
    return c
  end
  --------------------------------------------------------------------
  -- save current character into token buffer, grabs next character
  -- * save(c) merged into this and elsewhere to save space
  --------------------------------------------------------------------
  local function save_next()
    buff = buff..curr
    return nextc()
  end
  --------------------------------------------------------------------
  -- move on to next line
  --------------------------------------------------------------------
  local function nextline()
    local luaX = luaX
    nextc()  -- skip '\n'
    luaX.lineno = luaX.lineno + 1
  end
--[[--------------------------------------------------------------------
-- reads a number (LUA_NUMBER)
----------------------------------------------------------------------]]
  local function read_numeral(comma)
    buff = ""
    local find = string.find
    if comma then buff = "." end
    ------------------------------------------------------------------
    while find(curr, "%d") do save_next() end
    if curr == "." then
      if save_next() == "." then
        save_next()
        lexerror("ambiguous syntax (dots follows digits)")
      end
    end
    ------------------------------------------------------------------
    while find(curr, "%d") do save_next() end
    if find(curr, "^[eE]$") then
      save_next()  -- read 'E' and optional exponent sign
      if find(curr, "^[+-]$") then save_next() end
      while find(curr, "%d") do save_next() end
    end
    c = tonumber(buff)
    if c then return c end
    lexerror("malformed number")
  end
--[[--------------------------------------------------------------------
-- reads a long string or long comment
----------------------------------------------------------------------]]
  local function read_long(is_str)
    local cont = 0
    buff = ""
    nextc()  -- pass the '[['
    if curr == "\n" then  -- string starts with a newline?
      nextline()  -- skip it
    end
    while true do
      local c = curr
      ----------------------------------------------------------------
      if c == "EOZ" then
        lexerror(is_str and "unfinished long string" or
                 "unfinished long comment", EOF)
      ----------------------------------------------------------------
      elseif c == "[" then
        if save_next() == "[" then
          cont = cont + 1; save_next()
        end
      ----------------------------------------------------------------
      elseif c == "]" then
        if save_next() == "]" then
          if cont == 0 then break end
          cont = cont - 1; save_next()
        end
      ----------------------------------------------------------------
      elseif c == "\n" then
        buff = buff.."\n"; nextline()
        if not is_str then buff = "" end -- avoid wasting space
      ----------------------------------------------------------------
      else
        save_next()
      ----------------------------------------------------------------
      end--if c
    end--while
    nextc()  -- skip second ']'
    return string.sub(buff, 1, -2)
  end
--[[--------------------------------------------------------------------
-- reads a string
----------------------------------------------------------------------]]
  local function read_string(del)
    local find = string.find
    buff = ""
    save_next()  -- save delimiter
    while curr ~= del do
      local c = curr
      ----------------------------------------------------------------
      -- end-of-file, newline
      ----------------------------------------------------------------
      if c == "EOZ" then
        lexerror("unfinished string", EOF)
      elseif c == "\n" then
        lexerror("unfinished string")
      ----------------------------------------------------------------
      -- escapes
      ----------------------------------------------------------------
      elseif c == "\\" then
        c = nextc()  -- do not save the '\'
        if c ~= "EOZ" then -- will raise an error next loop iteration
          local d = find("\nabfnrtv", c, 1, 1)
          if d then
            buff = buff..string.sub("\n\a\b\f\n\r\t\v", d, d)
            if d == 1 then nextline() else nextc() end
          elseif find(c, "%D") then
            save_next()  -- handles \\, \", \', and \?
          else  -- \xxx
            c, d = 0, 0
            repeat
              c = 10 * c + curr; d = d + 1; nextc()
            until d >= 3 or find(curr, "%D")
            if c > 255 then  -- UCHAR_MAX
              lexerror("escape sequence too large")
            end
            buff = buff..string.char(c)
          end
        end
      ----------------------------------------------------------------
      -- a regular character
      ----------------------------------------------------------------
      else
        save_next()
      ----------------------------------------------------------------
      end--if c
    end--while
    nextc()  -- skip delimiter
    return string.sub(buff, 2)
  end
--[[--------------------------------------------------------------------
-- main lexer function
----------------------------------------------------------------------]]
  function luaX:lex()
    local find = string.find
    while true do
      local c = curr
      ----------------------------------------------------------------
      -- operators, numbers
      ----------------------------------------------------------------
      local d = find("=<>~\"'-[.\n", c, 1, 1)
      if d then
        ------------------------------------------------------------
        if d <= 4 then       -- "=<>~" (relational operators)
          if nextc() ~= "=" then return c end
          nextc(); return c.."="
        ------------------------------------------------------------
        elseif d <= 6 then   -- "\"" or "'" (string)
          return "<string>", read_string(c)
        ------------------------------------------------------------
        elseif c == "-" then   -- "-" ("-", comment, or long comment)
          if nextc() ~= "-" then return "-" end
          c = nextc()    -- otherwise it is a comment
          if c == "[" and nextc() == "[" then
            read_long()  -- long comment
          else  -- short comment
            while c ~= "\n" and c ~= "EOZ" do c = nextc() end
          end
        ------------------------------------------------------------
        elseif c == "[" then   -- "[" ("[" or long string)
          if nextc() ~= "[" then return c end
          return "<string>", read_long(true)
        ------------------------------------------------------------
        elseif c == "." then   -- "." (".", concatenation, or dots)
          buff = ""
          c = save_next()
          if c == "." then   -- interpret 2 or 3 dots
            if save_next() == "." then save_next() end
            return buff
          end
          if find(c, "%d") then
            return "<number>", read_numeral(true)
          end
          return "."
        ------------------------------------------------------------
        else-- c == "\n" then  -- "\n" (newline)
          nextline()
        ------------------------------------------------------------
        end--if d/c
      ----------------------------------------------------------------
      -- number, end-of-file, identifier or reserved word
      ----------------------------------------------------------------
      elseif find(c, "%d") then  -- number
        return "<number>", read_numeral(false)
      ----------------------------------------------------------------
      elseif find(c, "[_%a]") then  -- reads a name
        if c == "EOZ" then return EOF end  -- end-of-file
        buff = ""
        repeat
          c = save_next()
        until c == "EOZ" or find(c, "[^_%w]")
        c = buff
        if kw[c] then return c end  -- reserved word
        return "<name>", c
      ----------------------------------------------------------------
      -- whitespace, other characters, control characters
      ----------------------------------------------------------------
      elseif find(c, "%s") then  -- whitespace
        nextc()
      ----------------------------------------------------------------
      elseif find(c, "%c") then  -- control characters
        lexerror("invalid control char", "char("..string.byte(c)..")")
      ----------------------------------------------------------------
      else  -- single-char tokens (+ - / etc.)
        nextc(); return c
      ----------------------------------------------------------------
      end--if d/c
    end--while
  end
--[[--------------------------------------------------------------------
-- initial processing (shbang handling)
----------------------------------------------------------------------]]
  nextc()  -- read first char
  if cur == "#" then  -- skip first line
    repeat nextc() until curr == "\n" or curr == "EOZ"
  end
  return luaX
--[[------------------------------------------------------------------]]
end
