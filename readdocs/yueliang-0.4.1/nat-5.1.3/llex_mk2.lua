--[[--------------------------------------------------------------------

  llex.lua
  Lua 5.1 lexical analyzer in Lua
  This file is part of Yueliang.

  Copyright (c) 2008 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- Notes:
-- * takes in the entire source at once
-- * greatly simplified chunkid, error handling
-- * NO shbang handling (it's done elsewhere in Lua 5.1)
-- * NO localized decimal point replacement magic
-- * NO limit to number of lines (MAX_INT = 2147483645)
-- * NO support for compatible long strings (LUA_COMPAT_LSTR)
-- * NO next(), lookahead() because I want next() to set tok and
--   seminfo that are locals, and that can only be done easily in
--   lparser, not llex. lastline would be handled in lparser too.
--
-- Usage example:
--   local llex = require("llex_mk2")
--   llex.init(source_code, source_code_name)
--   repeat
--      local token, seminfo = llex.llex()
--   until token == "<eof>"
--
----------------------------------------------------------------------]]

local base = _G
local string = require "string"
module "llex"

----------------------------------------------------------------------
-- initialize keyword list
----------------------------------------------------------------------
local kw = {}
for v in string.gmatch([[
and break do else elseif end false for function if in
local nil not or repeat return then true until while]], "%S+") do
  kw[v] = true
end

----------------------------------------------------------------------
-- initialize lexer for given source _z and source name _sourceid
----------------------------------------------------------------------
local z, sourceid, I
local find = string.find
local match = string.match
local sub = string.sub

function init(_z, _sourceid)
  z = _z                        -- source
  sourceid = _sourceid          -- name of source
  I = 1                         -- lexer's position in source
  ln = 1                        -- line number
end

----------------------------------------------------------------------
-- returns a chunk name or id, no truncation for long names
----------------------------------------------------------------------
function chunkid()
  if sourceid and match(sourceid, "^[=@]") then
    return sub(sourceid, 2)  -- remove first char
  end
  return "[string]"
end

----------------------------------------------------------------------
-- formats error message and throws error
-- * a simplified version, does not report what token was responsible
----------------------------------------------------------------------
function errorline(s, line)
  base.error(string.format("%s:%d: %s", chunkid(), line or ln, s))
end

----------------------------------------------------------------------
-- handles line number incrementation and end-of-line characters
----------------------------------------------------------------------

local function inclinenumber(i)
  local sub = sub
  local old = sub(z, i, i)
  i = i + 1  -- skip '\n' or '\r'
  local c = sub(z, i, i)
  if (c == "\n" or c == "\r") and (c ~= old) then
    i = i + 1  -- skip '\n\r' or '\r\n'
  end
  ln = ln + 1
  I = i
  return i
end

------------------------------------------------------------------------
-- count separators ("=") in a long string delimiter
------------------------------------------------------------------------
local function skip_sep(i)
  local sub = sub
  local s = sub(z, i, i)
  i = i + 1
  local count = #match(z, "=*", i)  -- note, take the length
  i = i + count
  I = i
  return (sub(z, i, i) == s) and count or (-count) - 1
end

----------------------------------------------------------------------
-- reads a long string or long comment
----------------------------------------------------------------------

local function read_long_string(is_str, sep)
  local i = I + 1  -- skip 2nd '['
  local sub = sub
  local buff = ""
  local c = sub(z, i, i)
  if c == "\r" or c == "\n" then  -- string starts with a newline?
    i = inclinenumber(i)  -- skip it
  end
  local j = i
  while true do
    local p, q, r = find(z, "([\r\n%]])", i) -- (long range)
    if not p then
      errorline(is_str and "unfinished long string" or
                "unfinished long comment")
    end
    if is_str then
      buff = buff..sub(z, i, p - 1)     -- save string portions
    end
    i = p
    if r == "]" then                    -- delimiter test
      if skip_sep(i) == sep then
        i = I + 1  -- skip 2nd ']'
        break
      end
      buff = buff..sub(z, i, I - 1)
      i = I
    else                                -- newline
      buff = buff.."\n"
      i = inclinenumber(i)
    end
  end--while
  I = i
  return buff
end

----------------------------------------------------------------------
-- reads a string
----------------------------------------------------------------------
local function read_string(del)
  local i = I
  local find = find
  local sub = sub
  local buff = ""
  while true do
    local p, q, r = find(z, "([\n\r\\\"\'])", i) -- (long range)
    if p then
      if r == "\n" or r == "\r" then
        errorline("unfinished string")
      end
      buff = buff..sub(z, i, p - 1)             -- normal portions
      i = p
      if r == "\\" then                         -- handle escapes
        i = i + 1
        r = sub(z, i, i)
        if r == "" then break end -- (EOZ error)
        p = find("abfnrtv\n\r", r, 1, true)
        ------------------------------------------------------
        if p then                               -- special escapes
          if p > 7 then
            r = "\n"
            i = inclinenumber(i)
          else
            r = sub("\a\b\f\n\r\t\v", p, p)
            i = i + 1
          end
        ------------------------------------------------------
        elseif find(r, "%D") then               -- other non-digits
          i = i + 1
        ------------------------------------------------------
        else                                    -- \xxx sequence
          local p, q, s = find(z, "^(%d%d?%d?)", i)
          i = q + 1
          if s + 1 > 256 then -- UCHAR_MAX
            errorline("escape sequence too large")
          end
          r = string.char(s)
        ------------------------------------------------------
        end--if p
      else
        i = i + 1
        if r == del then                        -- ending delimiter
          I = i; return buff                    -- return string
        end
      end--if r
      buff = buff..r -- handled escapes falls through to here
    else
      break -- (error)
    end--if p
  end--while
  errorline("unfinished string")
end

------------------------------------------------------------------------
-- main lexer function
------------------------------------------------------------------------
function llex()
  local find = find
  local match = match
  while true do--outer
    local i = I
    -- inner loop allows break to be used to nicely section tests
    while true do--inner
      ----------------------------------------------------------------
      local p, _, r = find(z, "^([_%a][_%w]*)", i)
      if p then
        I = i + #r
        if kw[r] then return r end              -- reserved word (keyword)
        return "<name>", r                      -- identifier
      end
      ----------------------------------------------------------------
      local p, _, r = find(z, "^(%.?)%d", i)
      if p then                                 -- numeral
        if r == "." then i = i + 1 end
        local _, q, r = find(z, "^%d*[%.%d]*([eE]?)", i)
        i = q + 1
        if #r == 1 then                         -- optional exponent
          if match(z, "^[%+%-]", i) then        -- optional sign
            i = i + 1
          end
        end
        local _, q = find(z, "^[_%w]*", i)
        I = q + 1
        local v = base.tonumber(sub(z, p, q))   -- handles hex also
        if not v then errorline("malformed number") end
        return "<number>", v
      end
      ----------------------------------------------------------------
      local p, q, r = find(z, "^(%s)[ \t]*", i)
      if p then
        if r == "\n" or r == "\r" then          -- newline
          inclinenumber(i)
        else
          I = q + 1                             -- whitespace
        end
        break -- (continue)
      end
      ----------------------------------------------------------------
      local r = match(z, "^%p", i)
      if r then
        local p = find("-[\"\'.=<>~", r, 1, true)
        if p then
          -- two-level if block for punctuation/symbols
          --------------------------------------------------------
          if p <= 2 then
            if p == 1 then                      -- minus
              local c = match(z, "^%-%-(%[?)", i)
              if c then
                i = i + 2
                local sep = -1
                if c == "[" then
                  sep = skip_sep(i)
                end
                if sep >= 0 then                -- long comment
                  read_long_string(false, sep)
                else                            -- short comment
                  I = find(z, "[\n\r]", i) or (#z + 1)
                end
                break -- (continue)
              end
              -- (fall through for "-")
            else                                -- [ or long string
              local sep = skip_sep(i)
              if sep >= 0 then
                return "<string>", read_long_string(true, sep)
              elseif sep == -1 then
                return "["
              else
                errorline("invalid long string delimiter")
              end
            end
          --------------------------------------------------------
          elseif p <= 5 then
            if p < 5 then                       -- strings
              I = i + 1
              return "<string>", read_string(r)
            end
            r = match(z, "^%.%.?%.?", i)        -- .|..|... dots
            -- (fall through)
          --------------------------------------------------------
          else                                  -- relational
            r = match(z, "^%p=?", i)
            -- (fall through)
          end
        end
        I = i + #r; return r  -- for other symbols, fall through
      end
      ----------------------------------------------------------------
      local r = sub(z, i, i)
      if r ~= "" then
        I = i + 1; return r                     -- other single-char tokens
      end
      return "<eof>"                            -- end of stream
      ----------------------------------------------------------------
    end--while inner
  end--while outer
end

return base.getfenv()
