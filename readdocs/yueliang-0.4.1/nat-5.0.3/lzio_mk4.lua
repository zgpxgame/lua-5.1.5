--[[--------------------------------------------------------------------

  lzio.lua
  Lua 5 buffered streams in Lua
  This file is part of Yueliang.

  Copyright (c) 2006 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- Notes:
-- * this is a line-based input streamer for the MK4 lexer
-- * all EOL (end-of-line) characters are translated to "\n"
-- * if last line in a file does not have an EOL character, this
--   streamer adds one, the ambiguity is due to "*l" stripping
-- * EOF uses an empty string to simplify testing in lexer
----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- local zio_init = require("lzio.lua")
-- local z = zio_init("@<filename>")
-- local z = zio_init("<string>")
-- z:getln()
-- * get next line from input stream
-- z.name
-- * name of the chunk, "@<filename>" or "=string"
----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- Format of z structure (ZIO)
-- z.getln   -- chunk reader function, reads line-by-line
-- z.name    -- name of stream
----------------------------------------------------------------------]]

return
function(buff)
--[[--------------------------------------------------------------------
-- initialize reader
-- * reader should return a string with an EOL character, or an empty
--   string if there is nothing else to parse
----------------------------------------------------------------------]]
  local reader
  local z = {}
  if string.sub(buff, 1, 1) == "@" then
    ----------------------------------------------------------------
    -- create a chunk reader function from a source file
    ----------------------------------------------------------------
    z.name = buff
    local h = io.open(string.sub(buff, 2), "r")
    if not h then return nil end
    reader = function()
      if not h or io.type(h) == "closed file" then return nil end
      local data = h:read("*l")
      if not data then h:close(); return "" end
      return data.."\n"
    end
  else
    ----------------------------------------------------------------
    -- create a chunk reader function from a source string
    ----------------------------------------------------------------
    z.name = "=string"
    reader = function()
      if not buff then return nil end
      local p, q, data, eol = string.find(buff, "([^\r\n]*)(\r?\n?)")
      buff = string.sub(buff, q + 1)
      if data == "" and eol == "" then return "" end
      return data..eol
    end
  end
--[[--------------------------------------------------------------------
-- initialize input stream object
----------------------------------------------------------------------]]
  if not reader then return end
  z.getln = reader
  return z
--[[------------------------------------------------------------------]]
end
