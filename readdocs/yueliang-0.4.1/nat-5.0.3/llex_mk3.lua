--[[--------------------------------------------------------------------

  llex.lua
  Lua 5 lexical analyzer in Lua
  This file is part of Yueliang.

  Copyright (c) 2006 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- Notes:
-- * takes in the entire source at once
-- * code is heavily optimized for size
--
-- local lex_init = require("llex.lua")
-- local llex = lex_init(z, source)
-- llex:chunkid()
--   * returns formatted name of chunk id
-- llex:errorline(s, line)
--   * throws an error with a formatted message
-- llex:lex()
--   * returns next lexical element (token, seminfo)
-- llex.ln
--   * line number
----------------------------------------------------------------------]]

return
function(z, source)
  --------------------------------------------------------------------
  -- initialize variables
  -- * I is the upvalue, i is the local version for space/efficiency
  --------------------------------------------------------------------
  local string = string
  local find, sub = string.find, string.sub
  local EOF = "<eof>"
  local luaX = { ln = 1 }
  local I = 1
  --------------------------------------------------------------------
  -- initialize keyword list
  --------------------------------------------------------------------
  local kw = {}
  for v in string.gfind([[
and break do else elseif end false for function if in
local nil not or repeat return then true until while]], "%S+") do
    kw[v] = true
  end
  --------------------------------------------------------------------
  -- returns a chunk name or id
  --------------------------------------------------------------------
  function luaX:chunkid()
    if find(source, "^[=@]") then
      return sub(source, 2)  -- remove first char
    end
    return "[string]"
  end
  --------------------------------------------------------------------
  -- formats error message and throws error
  -- * a simplified version, does not report what token was responsible
  --------------------------------------------------------------------
  function luaX:errorline(s, line)
    error(string.format("%s:%d: %s", self:chunkid(), line or self.ln, s))
  end
  ----------------------------------------------------------------------
  -- reads a long string or long comment
  ----------------------------------------------------------------------
  local function read_long(i, is_str)
    local luaX = luaX
    local string = string
    local cont = 1
    if sub(z, i, i) == "\n" then
      i = i + 1
      luaX.ln = luaX.ln + 1
    end
    local j = i
    while true do
      local p, q, r = find(z, "([\n%[%]])", i) -- (long range)
      if not p then
        luaX:errorline(is_str and "unfinished long string" or
                       "unfinished long comment")
      end
      i = p + 1
      if r == "\n" then
        luaX.ln = luaX.ln + 1
      elseif sub(z, i, i) == r then -- only [[ or ]]
        i = i + 1
        if r == "[" then
          cont = cont + 1
        else-- r == "]" then
          if cont == 1 then break end   -- last ]] found
          cont = cont - 1
        end
      end
    end--while
    I = i
    return sub(z, j, i - 3)
  end
  ----------------------------------------------------------------------
  -- reads a string
  ----------------------------------------------------------------------
  local function read_string(i, del)
    local luaX = luaX
    local string = string
    local buff = ""
    while true do
      local p, q, r = find(z, "([\n\\\"\'])", i) -- (long range)
      if p then
        if r == "\n" then
          luaX:errorline("unfinished string")
        end
        buff = buff..sub(z, i, p - 1)           -- normal portions
        i = p
        if r == "\\" then                       -- handle escapes
          i = i + 1
          r = sub(z, i, i)
          if r == "" then break end -- (error)
          p = find("\nabfnrtv", r, 1, 1)
          ------------------------------------------------------
          if p then                             -- special escapes
            r = sub("\n\a\b\f\n\r\t\v", p, p)
            if p == 1 then luaX.ln = luaX.ln + 1 end
            i = i + 1
          ------------------------------------------------------
          elseif find(r, "%D") then             -- other non-digits
            i = i + 1
          ------------------------------------------------------
          else                                  -- \xxx sequence
            local p, q, s = find(z, "^(%d%d?%d?)", i)
            i = q + 1
            if s + 1 > 256 then -- UCHAR_MAX
              luaX:errorline("escape sequence too large")
            end
            r = string.char(s)
          ------------------------------------------------------
          end--if p
        else
          i = i + 1
          if r == del then
            I = i
            return buff                         -- ending delimiter
          end
        end--if r
        buff = buff..r
      else
        break -- (error)
      end--if p
    end--while
    luaX:errorline("unfinished string")
  end
  ----------------------------------------------------------------------
  -- main lexer function
  ----------------------------------------------------------------------
  function luaX:lex()
    local string = string
    local find, len = find, string.len
    while true do--outer
      local i = I
      -- inner loop allows break to be used to nicely section tests
      while true do--inner
        ----------------------------------------------------------------
        local p, _, r = find(z, "^([_%a][_%w]*)", i)
        if p then
          I = i + len(r)
          if kw[r] then return r end            -- keyword
          return "<name>", r                    -- identifier
        end
        ----------------------------------------------------------------
        local p, q, r = find(z, "^(%.?)%d", i)
        if p then                               -- numeral
          if r == "." then i = i + 1 end
          local _, n, r, s = find(z, "^%d*(%.?%.?)%d*([eE]?)", i)
          q = n
          i = q + 1
          if len(r) == 2 then
            self:errorline("ambiguous syntax (dots follows digits)")
          end
          if len(s) == 1 then                   -- optional exponent
            local _, n = find(z, "^[%+%-]?%d*", i) -- optional sign
            q = n
            i = q + 1
          end
          r = tonumber(sub(z, p, q))
          I = i
          if not r then self:errorline("malformed number") end
          return "<number>", r
        end
        ----------------------------------------------------------------
        local p, q, r = find(z, "^(%s)[ \t]*", i)
        if p then
          if r == "\n" then                     -- newline
            self.ln = self.ln + 1
            I = i + 1
          else
            I = q + 1                           -- whitespace
          end
          break -- (continue)
        end
        ----------------------------------------------------------------
        local p, _, r = find(z, "^(%p)", i)     -- symbols/punctuation
        if p then
          local q = find("-[\"\'.=<>~", r, 1, 1)
          if q then -- further processing for more complex symbols
            ----------------------------------------------------
            if q <= 2 then
              if q == 1 then                    -- minus
                if find(z, "^%-%-", i) then
                  i = i + 2
                  if find(z, "^%[%[", i) then   -- long comment
                    read_long(i + 2)
                  else                          -- short comment
                    I = find(z, "\n", i) or (len(z) + 1)
                  end
                  break -- (continue)
                end
                -- (fall through for "-")
              elseif q == 2 then                -- [ or long string
                if find(z, "^%[%[", i) then
                  return "<string>", read_long(i + 2, true)
                end
                -- (fall through for "[")
              end
            ----------------------------------------------------
            elseif q <= 5 then
              if q < 5 then                     -- strings
                return "<string>", read_string(i + 1, r)
              end
              local _, _, s = find(z, "^(%.%.?%.?)", i) -- dots
              r = s
              -- (fall through)
            ----------------------------------------------------
            else                                -- relational/logic
              local _, _, s = find(z, "^(%p=?)", i)
              r = s
              -- (fall through)
            end
          end
          I = i + len(r); return r -- for other symbols, fall through
        end
        ----------------------------------------------------------------
        local r = sub(z, i, i)
        if r ~= "" then
          if find(r, "%c") then                 -- invalid control char
            self:errorline("invalid control char("..string.byte(r)..")")
          end
          I = i + 1; return r                   -- other single-char tokens
        end
        return EOF                              -- end of stream
        ----------------------------------------------------------------
      end--while inner
    end--while outer
  end
  --------------------------------------------------------------------
  -- initial processing (shbang handling)
  --------------------------------------------------------------------
  local p, q, r = find(z, "^#[^\n]*(\n?)")
  if p then                             -- skip first line
    I = q + 1
    if r == "\n" then luaX.ln = luaX.ln + 1 end
  end
  return luaX
  --------------------------------------------------------------------
end
