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
-- * EOZ is implemented as a string, "EOZ"
-- * Format of z structure (ZIO)
--     z.n       -- bytes still unread
--     z.p       -- last read position in buffer
--     z.reader  -- chunk reader function
--     z.data    -- additional data
--     z.name    -- name of stream
-- * Current position, p, is now last read index instead of a pointer
--
-- Not implemented:
-- * luaZ_lookahead: used only in lapi.c:lua_load to detect binary chunk
-- * luaZ_read: used only in lundump.c:ezread to read +1 bytes
-- * luaZ_openspace: dropped; let Lua handle buffers as strings
-- * luaZ buffer macros: dropped; unused for now
--
-- Alternatives:
-- * zname(z) is z.name
--
-- Added:
-- (both of the following are vaguely adapted from lauxlib.c)
-- * luaZ:make_getS: create Chunkreader from a string
-- * luaZ:make_getF: create Chunkreader that reads from a file
----------------------------------------------------------------------]]

luaZ = {}

------------------------------------------------------------------------
-- * reader() should return a string, or nil if nothing else to parse.
--   Unlike Chunkreaders, there are no arguments like additional data
-- * Chunkreaders are handled in lauxlib.h, see luaL_load(file|buffer)
-- * Original Chunkreader:
--   const char * (*lua_Chunkreader) (lua_State *L, void *ud, size_t *sz);
-- * This Lua chunk reader implementation:
--   returns string or nil, no arguments to function
------------------------------------------------------------------------

------------------------------------------------------------------------
-- create a chunk reader from a source string
------------------------------------------------------------------------
function luaZ:make_getS(buff)
  local b = buff
  return function() -- chunk reader anonymous function here
    if not b then return nil end
    local data = b
    b = nil
    return data
  end
end

------------------------------------------------------------------------
-- create a chunk reader from a source file
------------------------------------------------------------------------
function luaZ:make_getF(filename)
  local LUAL_BUFFERSIZE = 512
  local h = io.open(filename, "r")
  if not h then return nil end
  return function() -- chunk reader anonymous function here
    if not h or io.type(h) == "closed file" then return nil end
    local buff = h:read(LUAL_BUFFERSIZE)
    if not buff then h:close(); h = nil end
    return buff
  end
end

------------------------------------------------------------------------
-- creates a zio input stream
-- returns the ZIO structure, z
------------------------------------------------------------------------
function luaZ:init(reader, data, name)
  if not reader then return end
  local z = {}
  z.reader = reader
  z.data = data or ""
  z.name = name
  -- set up additional data for reading
  if not data or data == "" then z.n = 0 else z.n = string.len(data) end
  z.p = 0
  return z
end

------------------------------------------------------------------------
-- fill up input buffer
------------------------------------------------------------------------
function luaZ:fill(z)
  local data = z.reader()
  z.data = data
  if not data or data == "" then return "EOZ" end
  z.n = string.len(data) - 1
  z.p = 1
  return string.sub(data, 1, 1)
end

------------------------------------------------------------------------
-- get next character from the input stream
------------------------------------------------------------------------
function luaZ:zgetc(z)
  if z.n > 0 then
    z.n = z.n - 1
    z.p = z.p + 1
    return string.sub(z.data, z.p, z.p)
  else
    return self:fill(z)
  end
end
