--[[--------------------------------------------------------------------

  lzio.lua
  Lua 5 buffered streams in Lua
  This file is part of Yueliang.

  Copyright (c) 2005-2006 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- Notes:
-- *
----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- local zio_init = require("lzio.lua")
-- local z = zio_init("@<filename>")
-- local z = zio_init("<string>")
-- z:getc()
-- * get next character from input stream
-- z:fill()
-- * fills an empty stream buffer
-- z.name
-- * name of the chunk, "@<filename>" or "=string"
----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- Format of z structure (ZIO)
-- z.n       -- bytes still unread
-- z.p       -- last read position in buffer
-- z.reader  -- chunk reader function
-- z.data    -- data buffer
-- z.name    -- name of stream
----------------------------------------------------------------------]]

return
function(buff)
--[[--------------------------------------------------------------------
-- initialize reader
-- * reader should return a string, or nil if nothing else to parse
----------------------------------------------------------------------]]
  local reader
  local z = {}
  if string.sub(buff, 1, 1) == "@" then
    ----------------------------------------------------------------
    -- create a chunk reader function from a source file
    ----------------------------------------------------------------
    z.name = buff
    local BUFFERSIZE = 512
    local h = io.open(string.sub(buff, 2), "r")
    if not h then return nil end
    reader = function()
      if not h or io.type(h) == "closed file" then return nil end
      local buff = h:read(BUFFERSIZE)
      if not buff then h:close(); h = nil end
      return buff
    end
  else
    ----------------------------------------------------------------
    -- create a chunk reader function from a source string
    ----------------------------------------------------------------
    z.name = "=string"
    reader = function()
      if not buff then return nil end
      local data = buff
      buff = nil
      return data
    end
  end
--[[--------------------------------------------------------------------
-- fills an empty stream buffer, returns first character
----------------------------------------------------------------------]]
  function z:fill()
    local data = z.reader()
    z.data = data
    if not data or data == "" then return "EOZ" end
    z.n, z.p = string.len(data) - 1, 1
    return string.sub(data, 1, 1)
  end
--[[--------------------------------------------------------------------
-- get next character, fills buffer if characters needed
----------------------------------------------------------------------]]
  function z:getc()
    local n, p = z.n, z.p + 1
    if n > 0 then
      z.n, z.p = n - 1, p
      return string.sub(z.data, p, p)
    else
      return self:fill()
    end
  end
--[[--------------------------------------------------------------------
-- initialize input stream object
----------------------------------------------------------------------]]
  if not reader then return end
  z.reader = reader
  z.data = ""
  z.n, z.p = 0, 0
  return z
--[[------------------------------------------------------------------]]
end
