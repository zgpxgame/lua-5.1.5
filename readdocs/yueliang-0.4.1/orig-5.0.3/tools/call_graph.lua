--[[--------------------------------------------------------------------

  call_graph.lua
  Call graph generator.
  This file is part of Yueliang.

  Copyright (c) 2005-2006 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
-- Notes:
-- * the call tracer wraps function calls in tables to do its work
-- * not very elegant as the namespace of the table/module is affected
-- * tracing using the debugger is probably much more powerful...
-- * use of braces {} allows editors to match braces in the output
--   and do folding, if such facilities are available; for example, the
--   output looks better if Lua syntax highlighting is used on SciTE
----------------------------------------------------------------------]]

------------------------------------------------------------------------
-- options
------------------------------------------------------------------------

local SHOW_EXPDESC = true       -- show expdesc struct data

------------------------------------------------------------------------
-- load and initialize modules
------------------------------------------------------------------------
require("../lzio.lua")
require("../llex.lua")
require("../lopcodes.lua")
require("../ldump.lua")
require("../lcode.lua")
require("../lparser.lua")

function lua_assert(test)
  if not test then error("assertion failed!") end
end
luaX:init()
local LuaState = {}

------------------------------------------------------------------------
-- call graph generator
-- * (1) logging functions, (2) the wrapper initializer itself
------------------------------------------------------------------------

llog = {}

------------------------------------------------------------------------
-- initialize log file; the usual mode is append; can use stdout/stderr
------------------------------------------------------------------------
function llog:init(filename)
  if filename == "stdout" then self.h = io.stdout
  elseif filename == "stderr" then self.h = io.stderr
  else
    self.h = io.open(filename, "ab")
    if not self.h then
      error("can't open log file "..filename.."for writing")
    end
  end
  self.h:write("\n-- start of log --\n\n")
end

------------------------------------------------------------------------
-- cleanly closes log file
------------------------------------------------------------------------
function llog:exit()
  self.h:write("\n-- end of log --\n\n")
  if self.h ~= io.stdout and self.h ~= io.stderr then
    self.h:close()
  end
end

------------------------------------------------------------------------
-- logs a message at a particular call depth
------------------------------------------------------------------------
function llog:msg(msg, level)
  if level then msg = string.rep("  ", level)..msg end
  self.h:write(msg)
  self.h:flush()
end

------------------------------------------------------------------------
-- set up wrapper functions to do tracing on a per-module basis
------------------------------------------------------------------------
function llog:calltrace(parms)
  ------------------------------------------------------------------
  -- process parameters
  ------------------------------------------------------------------
  local module = parms.module
  local modulename = parms.modulename
  if type(module) ~= "table" then
    error("module table parameter required")
  elseif not modulename then
    error("module name parameter required")
  end
  ------------------------------------------------------------------
  -- use either allow or deny list
  ------------------------------------------------------------------
  local allow = parms.allow or {}
  local deny = parms.deny or {}
  if table.getn(allow) > 0 and table.getn(deny) > 0 then
    error("can't apply both allow and deny lists at the same time")
  end
  ------------------------------------------------------------------
  -- select functions to wrap
  ------------------------------------------------------------------
  local flist = {}
  for i, f in pairs(module) do
    local wrapthis
    if table.getn(allow) > 0 then  -- allow some only
      wrapthis = false
      for j, v in ipairs(allow) do
        if i == v then wrapthis = true; break end
      end
    elseif table.getn(deny) > 0 then  -- deny some only
      wrapthis = true
      for j, v in ipairs(deny) do
        if i == v then wrapthis = false; break end
      end
    else  -- default include
      wrapthis = true
    end
    if wrapthis then flist[i] = f end
  end
  ------------------------------------------------------------------
  -- wrapped function(s) in a module for tracing
  ------------------------------------------------------------------
  llog.level = 0  -- nesting level
  for i, f in pairs(flist) do
    local ModuleName = modulename..":"
    local OldName, OldFunc = i, f
    if type(OldFunc) == "function" then
      local NewName = "__"..OldName
      while module[NewName] ~= nil do  -- avoid collisions
        NewName = "_"..NewName
      end
      module[NewName] = OldFunc
      module[OldName] =
        ----------------------------------------------------------
        -- wrapper function for a module's function
        -- old function XYZ is renamed __XYZ
        ----------------------------------------------------------
        function(self, ...)
          local parms = " ("
          local exps = {}
          -- look for expdesc structs, identify FuncState structs too
          local function checkexpdesc(v)
            local typ = type(v)
            if typ == "table" then
              if v.code then return "func"
              elseif v.L then return "ls"
              elseif v.seminfo then return "token"
              elseif v.k then
                table.insert(exps, v)
                return "exp"..table.getn(exps)
              end
            end
            return typ
          end
          -- format parameters for printing
          for i,v in ipairs(arg) do
            if type(v) == "number" then parms = parms..v..","
            elseif type(v) == "string" then parms = parms.."'"..v.."',"
            elseif type(v) == "boolean" then parms = parms..tostring(v)..","
            elseif SHOW_EXPDESC then parms = parms..checkexpdesc(v)..","
            else parms = parms..type(v)..","
            end
          end
          if table.getn(arg) > 0 then  -- chop last comma
            parms = string.sub(parms, 1, -2)
          end
          -- up level
          llog:msg(ModuleName..OldName..parms..") {\n", llog.level)
          llog.level = llog.level + 1
          -- display contents of expdesc
          if SHOW_EXPDESC and table.getn(exps) > 0 then
            for i,v in ipairs(exps) do
              parms = "k:'"..v.k.."',"
              if v.info then parms = parms.."info:"..v.info.."," end
              if v.aux then parms = parms.."aux:"..v.aux.."," end
              if v.t then parms = parms.."t:"..v.t.."," end
              if v.f then parms = parms.."f:"..v.f.."," end
              parms = string.sub(parms, 1, -2)
              llog:msg("exp"..i.."("..parms..")\n", llog.level)
            end
          end
          -- original function called here...
          local retval = {self[NewName](self, unpack(arg))}
          -- format return values
          local rets = " = "
          for i,v in ipairs(retval) do
            if type(v) == "number" then rets = rets..v..","
            elseif type(v) == "string" then rets = rets.."'"..v.."',"
            elseif type(v) == "boolean" then rets = rets..tostring(v)..","
            else rets = rets..type(v)..","
            end
          end
          if table.getn(retval) > 0 then  -- chop last comma
            rets = string.sub(rets, 1, -2)
          else
            rets = ""
          end
          -- down level
          llog.level = llog.level - 1
          llog:msg("} "..ModuleName..OldName..rets.."\n", llog.level)
          return unpack(retval)
        end--function
        ----------------------------------------------------------
      --print("patched "..OldName)
    end--if
  end--for
end

------------------------------------------------------------------------
-- testing here
-- * allow/deny works a bit like a somewhat similar Apache syntax
-- * e.g. to show only function 'lex' and 'save' -> allow={"lex","save",}
--        to not show function 'save_and_next' -> deny={"save_and_next",}
-- * you can't do both allow and deny at the same time
------------------------------------------------------------------------

-- select the file or stream to output to
--llog:init("calls.log")
llog:init("stdout")

-- select modules to trace
llog:calltrace{module=luaX, modulename="luaX", allow={"lex"} }
  -- here we trace only the main lex() function, to avoid showing
  -- too many lexer calls; we want to focus on luaY and luaK
llog:calltrace{module=luaY, modulename="luaY", deny={"growvector"} }
  -- growvector() is just a limit checker in Yueliang, so drop it
  -- to simplify the output log
llog:calltrace{module=luaK, modulename="luaK"}
--llog:calltrace{module=luaU, modulename="luaU"}

-- select input stream
local zio = luaZ:init(luaZ:make_getS("local a = 1"), nil, "=string")
--local zio = luaZ:init(luaZ:make_getF("sample.lua"), nil, "@sample.lua")

-- compile the source
local Func = luaY:parser(LuaState, zio, nil)

-- write binary chunk
local Writer, Buff = luaU:make_setF("call_graph.out")
luaU:dump(LuaState, Func, Writer, Buff)

llog:exit()
--end
