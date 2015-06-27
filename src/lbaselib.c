/*
** $Id: lbaselib.c,v 1.191.1.6 2008/02/14 16:46:22 roberto Exp $
** Basic library
** See Copyright Notice in lua.h
*/



#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define lbaselib_c
#define LUA_LIB

#include "lua.h"

#include "lauxlib.h"
#include "lualib.h"




/*
** print (···)
**
** Receives any number of arguments, and prints their values to stdout, using 
** the tostring function to convert them to strings. print is not intended for 
** formatted output, but only as a quick way to show a value, typically for 
** debugging. For formatted output, use string.format.
**
** If your system does not support `stdout', you can just remove this function.
** If you need, you can define your own `print' function, following this
** model but changing `fputs' to put the strings at a proper place
** (a console window or a log file, for instance).
*/
static int luaB_print (lua_State *L) {
  int n = lua_gettop(L);  /* number of arguments */
  int i;
  lua_getglobal(L, "tostring");
  for (i=1; i<=n; i++) {
    const char *s;
    lua_pushvalue(L, -1);  /* function to be called */
    lua_pushvalue(L, i);   /* value to print */
    lua_call(L, 1, 1);
    s = lua_tostring(L, -1);  /* get result */
    if (s == NULL)
      return luaL_error(L, LUA_QL("tostring") " must return a string to "
                           LUA_QL("print"));
    if (i>1) fputs("\t", stdout);
    fputs(s, stdout);
    lua_pop(L, 1);  /* pop result */
  }
  fputs("\n", stdout);
  return 0;
}


/*
** tonumber (e [, base])
**
** Tries to convert its argument to a number. If the argument is already a 
** number or a string convertible to a number, then tonumber returns this
** number; otherwise, it returns nil.
** An optional argument specifies the base to interpret the numeral. The base 
** may be any integer between 2 and 36, inclusive. In bases above 10, the letter
** 'A' (in either upper or lower case) represents 10, 'B' represents 11, and so 
** forth, with 'Z' representing 35. In base 10 (the default), the number can 
** have a decimal part, as well as an optional exponent part (see §2.1). In 
** other bases, only unsigned integers are accepted.
**
**
** unsigned long int strtoul(const char *nptr, char **endptr, int base);
** 
** The  strtoul() function converts the initial part of the string in nptr
** to an unsigned long int value according to the given base,  which  must
** be between 2 and 36 inclusive, or be the special value 0.
** The string may begin with an arbitrary amount of white space (as deter‐
** mined by isspace(3)) followed by a single optional '+' or '-' sign.  If
** base  is zero or 16, the string may then include a "0x" prefix, and the
** number will be read in base 16; otherwise, a zero base is taken  as  10
** (decimal)  unless  the next character is '0', in which case it is taken
** as 8 (octal).
** The remainder of the string is converted to an unsigned long int  value
** in  the  obvious manner, stopping at the first character which is not a
** valid digit in the given base.  (In bases above 10, the letter  'A'  in
** either  upper  or  lower  case represents 10, 'B' represents 11, and so
** forth, with 'Z' representing 35.)
** If endptr is not NULL,  strtoul()  stores  the  address  of  the  first
** invalid  character  in  *endptr.   If there were no digits at all, str‐
** toul() stores the original value of nptr in *endptr  (and  returns  0).
** In particular, if *nptr is not '\0' but **endptr is '\0' on return, the
** entire string is valid.
** The strtoull() function works just  like  the  strtoul()  function  but
** returns an unsigned long long int value.
**
**
** strtoul expects nptr to point to a string of the following form:
** [whitespace] [{+ | –}] [0 [{ x | X }]] [digits]
**
*/
static int luaB_tonumber (lua_State *L) {
  int base = luaL_optint(L, 2, 10);
  if (base == 10) {  /* standard conversion */
    luaL_checkany(L, 1);
    if (lua_isnumber(L, 1)) {
      lua_pushnumber(L, lua_tonumber(L, 1));
      return 1;
    }
  }
  else {
    const char *s1 = luaL_checkstring(L, 1);
    char *s2;
    unsigned long n;
    luaL_argcheck(L, 2 <= base && base <= 36, 2, "base out of range");
    n = strtoul(s1, &s2, base);
    if (s1 != s2) {  /* at least one valid digit? */
      while (isspace((unsigned char)(*s2))) s2++;  /* skip trailing spaces */
      if (*s2 == '\0') {  /* no invalid trailing characters? */
        lua_pushnumber(L, (lua_Number)n);
        return 1;
      }
    }
  }
  lua_pushnil(L);  /* else not a number */
  return 1;
}


/*
** error (message [, level])
**
** Terminates the last protected function called and returns message as the 
** error message. Function error never returns.
** Usually, error adds some information about the error position at the 
** beginning of the message. The level argument specifies how to get the error 
** position. With level 1 (the default), the error position is where the error 
** function was called. Level 2 points the error to where the function that 
** called error was called; and so on. Passing a level 0 avoids the addition of 
** error position information to the message.
*/
static int luaB_error (lua_State *L) {
  int level = luaL_optint(L, 2, 1);
  lua_settop(L, 1);
  if (lua_isstring(L, 1) && level > 0) {  /* add extra information? */
    luaL_where(L, level);
    lua_pushvalue(L, 1);
    lua_concat(L, 2);
  }
  return lua_error(L);
}


/*
** getmetatable (object)
**
** If object does not have a metatable, returns nil. Otherwise, if the object's 
** metatable has a "__metatable" field, returns the associated value. Otherwise,
** returns the metatable of the given object.
*/
static int luaB_getmetatable (lua_State *L) {
  luaL_checkany(L, 1);
  if (!lua_getmetatable(L, 1)) {
    lua_pushnil(L);
    return 1;  /* no metatable */
  }
  luaL_getmetafield(L, 1, "__metatable");
  return 1;  /* returns either __metatable field (if present) or metatable */
}


/*
** setmetatable (table, metatable)
**
** Sets the metatable for the given table. (You cannot change the metatable of 
** other types from Lua, only from C.) If metatable is nil, removes the 
** metatable of the given table. If the original metatable has a "__metatable" 
** field, raises an error.
** This function returns table.
*/
static int luaB_setmetatable (lua_State *L) {
  int t = lua_type(L, 2);
  luaL_checktype(L, 1, LUA_TTABLE);
  luaL_argcheck(L, t == LUA_TNIL || t == LUA_TTABLE, 2,
                    "nil or table expected");
  if (luaL_getmetafield(L, 1, "__metatable"))
    luaL_error(L, "cannot change a protected metatable");
  lua_settop(L, 2);
  lua_setmetatable(L, 1);
  return 1;
}


static void getfunc (lua_State *L, int opt) {
  if (lua_isfunction(L, 1)) lua_pushvalue(L, 1);
  else {
    lua_Debug ar;
    int level = opt ? luaL_optint(L, 1, 1) : luaL_checkint(L, 1);
    luaL_argcheck(L, level >= 0, 1, "level must be non-negative");
    if (lua_getstack(L, level, &ar) == 0)
      luaL_argerror(L, 1, "invalid level");
    lua_getinfo(L, "f", &ar);
    if (lua_isnil(L, -1))
      luaL_error(L, "no function environment for tail call at level %d",
                    level);
  }
}


/*
** getfenv ([f])
**
** Returns the current environment in use by the function. f can be a Lua 
** function or a number that specifies the function at that stack level: Level 1
** is the function calling getfenv. If the given function is not a Lua function,
** or if f is 0, getfenv returns the global environment. The default for f is 1.
*/
static int luaB_getfenv (lua_State *L) {
  getfunc(L, 1);
  if (lua_iscfunction(L, -1))  /* is a C function? */
    lua_pushvalue(L, LUA_GLOBALSINDEX);  /* return the thread's global env. */
  else
    lua_getfenv(L, -1);
  return 1;
}


/*
** setfenv (f, table)
**
** Sets the environment to be used by the given function. f can be a Lua 
** function or a number that specifies the function at that stack level: Level 1
** is the function calling setfenv. setfenv returns the given function.
**
** As a special case, when f is 0 setfenv changes the environment of the running
** thread. In this case, setfenv returns no values.
*/
static int luaB_setfenv (lua_State *L) {
  luaL_checktype(L, 2, LUA_TTABLE);
  getfunc(L, 0);
  lua_pushvalue(L, 2);
  if (lua_isnumber(L, 1) && lua_tonumber(L, 1) == 0) {
    /* change environment of current thread */
    lua_pushthread(L);
    lua_insert(L, -2);
    lua_setfenv(L, -2);
    return 0;
  }
  else if (lua_iscfunction(L, -2) || lua_setfenv(L, -2) == 0)
    luaL_error(L,
          LUA_QL("setfenv") " cannot change environment of given object");
  return 1;
}


/*
** rawequal (v1, v2)
**
** Checks whether v1 is equal to v2, without invoking any metamethod. Returns a 
** boolean.
*/
static int luaB_rawequal (lua_State *L) {
  luaL_checkany(L, 1);
  luaL_checkany(L, 2);
  lua_pushboolean(L, lua_rawequal(L, 1, 2));
  return 1;
}


/*
** rawget (table, index)
** 
** Gets the real value of table[index], without invoking any metamethod. table 
** must be a table; index may be any value.
*/
static int luaB_rawget (lua_State *L) {
  luaL_checktype(L, 1, LUA_TTABLE);
  luaL_checkany(L, 2);
  lua_settop(L, 2);
  lua_rawget(L, 1);
  return 1;
}


/*
** rawset (table, index, value)
**
** Sets the real value of table[index] to value, without invoking any 
** metamethod. table must be a table, index any value different from nil, and 
** value any Lua value.
** This function returns table.
*/
static int luaB_rawset (lua_State *L) {
  luaL_checktype(L, 1, LUA_TTABLE);
  luaL_checkany(L, 2);
  luaL_checkany(L, 3);
  lua_settop(L, 3);
  lua_rawset(L, 1);
  return 1;
}


/*
** gcinfo()
**
** Returns two results: the number of Kbytes of dynamic memory that Lua is using
** and the current garbage collector threshold (also in Kbytes).
** Function gcinfo is deprecated; use collectgarbage("count") instead.
*/
static int luaB_gcinfo (lua_State *L) {
  lua_pushinteger(L, lua_getgccount(L));
  return 1;
}


/*
** collectgarbage ([opt [, arg]])
**
** This function is a generic interface to the garbage collector. It performs
** different functions according to its first argument, opt:
**
** (*) "collect": performs a full garbage-collection cycle. This is the default
**     option.
** (*) "stop": stops the garbage collector.
** (*) "restart": restarts the garbage collector.
** (*) "count": returns the total memory in use by Lua (in Kbytes).
** (*) "step": performs a garbage-collection step. The step "size" is controlled 
**     by arg (larger values mean more steps) in a non-specified way. If you 
**     want to control the step size you must experimentally tune the value of 
**     arg. Returns true if the step finished a collection cycle.
** (*) "setpause": sets arg as the new value for the pause of the collector 
**     (see §2.10). Returns the previous value for pause.
** (*) "setstepmul": sets arg as the new value for the step multiplier of the 
**     collector (see §2.10). Returns the previous value for step.
*/
static int luaB_collectgarbage (lua_State *L) {
  static const char *const opts[] = {"stop", "restart", "collect",
    "count", "step", "setpause", "setstepmul", NULL};
  static const int optsnum[] = {LUA_GCSTOP, LUA_GCRESTART, LUA_GCCOLLECT,
    LUA_GCCOUNT, LUA_GCSTEP, LUA_GCSETPAUSE, LUA_GCSETSTEPMUL};
  int o = luaL_checkoption(L, 1, "collect", opts);
  int ex = luaL_optint(L, 2, 0);
  int res = lua_gc(L, optsnum[o], ex);
  switch (optsnum[o]) {
    case LUA_GCCOUNT: {
      int b = lua_gc(L, LUA_GCCOUNTB, 0);
      lua_pushnumber(L, res + ((lua_Number)b/1024));
      return 1;
    }
    case LUA_GCSTEP: {
      lua_pushboolean(L, res);
      return 1;
    }
    default: {
      lua_pushnumber(L, res);
      return 1;
    }
  }
}


/*
** type (v)
**
** Returns the type of its only argument, coded as a string. The possible 
** results of this function are "nil" (a string, not the value nil), "number", 
** "string", "boolean", "table", "function", "thread", and "userdata".
*/
static int luaB_type (lua_State *L) {
  luaL_checkany(L, 1);
  lua_pushstring(L, luaL_typename(L, 1));
  return 1;
}


/*
** next (table [, index])
** 
** Allows a program to traverse all fields of a table. Its first argument is a 
** table and its second argument is an index in this table. next returns the 
** next index of the table and its associated value. When called with nil as its
** second argument, next returns an initial index and its associated value. When
** called with the last index, or with nil in an empty table, next returns nil. 
** If the second argument is absent, then it is interpreted as nil. In 
** particular, you can use next(t) to check whether a table is empty.
**
** The order in which the indices are enumerated is not specified, even for 
** numeric indices. (To traverse a table in numeric order, use a numerical for 
** or the ipairs function.)
**
** The behavior of next is undefined if, during the traversal, you assign any 
** value to a non-existent field in the table. You may however modify existing 
** fields. In particular, you may clear existing fields.
*/
static int luaB_next (lua_State *L) {
  luaL_checktype(L, 1, LUA_TTABLE);
  lua_settop(L, 2);  /* create a 2nd argument if there isn't one */
  if (lua_next(L, 1))
    return 2;
  else {
    lua_pushnil(L);
    return 1;
  }
}


/*
** pairs (t)
**
** Returns three values: the next function, the table t, and nil, so that the 
** construction
**
**      for k,v in pairs(t) do body end
**
** will iterate over all key–value pairs of table t.
**
** See function next for the caveats of modifying the table during its traversal.
*/
static int luaB_pairs (lua_State *L) {
  luaL_checktype(L, 1, LUA_TTABLE);
  lua_pushvalue(L, lua_upvalueindex(1));  /* return generator, */
  lua_pushvalue(L, 1);  /* state, */
  lua_pushnil(L);  /* and initial value */
  return 3;
}


static int ipairsaux (lua_State *L) {
  int i = luaL_checkint(L, 2);
  luaL_checktype(L, 1, LUA_TTABLE);
  i++;  /* next value */
  lua_pushinteger(L, i);
  lua_rawgeti(L, 1, i);
  return (lua_isnil(L, -1)) ? 0 : 2;
}


/*
** ipairs (t)
**
** Returns three values: an iterator function, the table t, and 0, so that the 
** construction
**
**      for i,v in ipairs(t) do body end
**
** will iterate over the pairs (1,t[1]), (2,t[2]), ···, up to the first integer 
** key absent from the table.
*/
static int luaB_ipairs (lua_State *L) {
  luaL_checktype(L, 1, LUA_TTABLE);
  lua_pushvalue(L, lua_upvalueindex(1));  /* return generator, */
  lua_pushvalue(L, 1);  /* state, */
  lua_pushinteger(L, 0);  /* and initial value */
  return 3;
}


static int load_aux (lua_State *L, int status) {
  if (status == 0)  /* OK? */
    return 1;
  else {
    lua_pushnil(L);
    lua_insert(L, -2);  /* put before error message */
    return 2;  /* return nil plus error message */
  }
}


/*
** loadstring (string [, chunkname])
**
** Similar to load, but gets the chunk from the given string.
**
** To load and run a given string, use the idiom
**
**      assert(loadstring(s))()
**
** When absent, chunkname defaults to the given string.
*/
static int luaB_loadstring (lua_State *L) {
  size_t l;
  const char *s = luaL_checklstring(L, 1, &l);
  const char *chunkname = luaL_optstring(L, 2, s);
  return load_aux(L, luaL_loadbuffer(L, s, l, chunkname));
}


/*
** loadfile ([filename])
**
** Similar to load, but gets the chunk from file filename or from the standard 
** input, if no file name is given.
*/
static int luaB_loadfile (lua_State *L) {
  const char *fname = luaL_optstring(L, 1, NULL);
  return load_aux(L, luaL_loadfile(L, fname));
}


/*
** Reader for generic `load' function: `lua_load' uses the
** stack for internal stuff, so the reader cannot change the
** stack top. Instead, it keeps its resulting string in a
** reserved slot inside the stack.
*/
static const char *generic_reader (lua_State *L, void *ud, size_t *size) {
  (void)ud;  /* to avoid warnings */
  luaL_checkstack(L, 2, "too many nested functions");
  lua_pushvalue(L, 1);  /* get function */
  lua_call(L, 0, 1);  /* call it */
  if (lua_isnil(L, -1)) {
    *size = 0;
    return NULL;
  }
  else if (lua_isstring(L, -1)) {
    lua_replace(L, 3);  /* save string in a reserved stack slot */
    return lua_tolstring(L, 3, size);
  }
  else luaL_error(L, "reader function must return a string");
  return NULL;  /* to avoid warnings */
}


/*
** load (func [, chunkname])
**
** Loads a chunk using function func to get its pieces. Each call to func must 
** return a string that concatenates with previous results. A return of an empty
** string, nil, or no value signals the end of the chunk.
**
** If there are no errors, returns the compiled chunk as a function; otherwise, 
** returns nil plus the error message. The environment of the returned function 
** is the global environment.
**
** chunkname is used as the chunk name for error messages and debug information.
** When absent, it defaults to "=(load)".
*/
static int luaB_load (lua_State *L) {
  int status;
  const char *cname = luaL_optstring(L, 2, "=(load)");
  luaL_checktype(L, 1, LUA_TFUNCTION);
  lua_settop(L, 3);  /* function, eventual name, plus one reserved slot */
  status = lua_load(L, generic_reader, NULL, cname);
  return load_aux(L, status);
}


/*
** dofile ([filename])
** 
** Opens the named file and executes its contents as a Lua chunk. When called 
** without arguments, dofile executes the contents of the standard input 
** (stdin). Returns all values returned by the chunk. In case of errors, dofile
** propagates the error to its caller (that is, dofile does not run in protected
** mode).
*/
static int luaB_dofile (lua_State *L) {
  const char *fname = luaL_optstring(L, 1, NULL);
  int n = lua_gettop(L);
  if (luaL_loadfile(L, fname) != 0) lua_error(L);
  lua_call(L, 0, LUA_MULTRET);
  return lua_gettop(L) - n;
}


/*
** assert (v [, message])
**
** Issues an error when the value of its argument v is false (i.e., nil or 
** false); otherwise, returns all its arguments. message is an error message; 
** when absent, it defaults to "assertion failed!"
*/
static int luaB_assert (lua_State *L) {
  luaL_checkany(L, 1);
  if (!lua_toboolean(L, 1))
    return luaL_error(L, "%s", luaL_optstring(L, 2, "assertion failed!"));
  return lua_gettop(L);
}


/*
** unpack (list [, i [, j]])
**
** Returns the elements from the given table. This function is equivalent to
**
**      return list[i], list[i+1], ···, list[j]
** 
** except that the above code can be written only for a fixed number of 
** elements. By default, i is 1 and j is the length of the list, as defined by 
** the length operator (see §2.5.5).
*/
static int luaB_unpack (lua_State *L) {
  int i, e, n;
  luaL_checktype(L, 1, LUA_TTABLE);
  i = luaL_optint(L, 2, 1);
  e = luaL_opt(L, luaL_checkint, 3, luaL_getn(L, 1));
  if (i > e) return 0;  /* empty range */
  n = e - i + 1;  /* number of elements */
  if (n <= 0 || !lua_checkstack(L, n))  /* n <= 0 means arith. overflow */
    return luaL_error(L, "too many results to unpack");
  lua_rawgeti(L, 1, i);  /* push arg[i] (avoiding overflow problems) */
  while (i++ < e)  /* push arg[i + 1...e] */
    lua_rawgeti(L, 1, i);
  return n;
}


/*
** select (index, ···)
**
** If index is a number, returns all arguments after argument number index. 
** Otherwise, index must be the string "#", and select returns the total number 
** of extra arguments it received.
*/
static int luaB_select (lua_State *L) {
  int n = lua_gettop(L);
  if (lua_type(L, 1) == LUA_TSTRING && *lua_tostring(L, 1) == '#') {
    lua_pushinteger(L, n-1);
    return 1;
  }
  else {
    int i = luaL_checkint(L, 1);
    if (i < 0) i = n + i;
    else if (i > n) i = n;
    luaL_argcheck(L, 1 <= i, 1, "index out of range");
    return n - i;
  }
}


/*
** pcall (f, arg1, ···)
**
** Calls function f with the given arguments in protected mode. This means that 
** any error inside f is not propagated; instead, pcall catches the error and 
** returns a status code. Its first result is the status code (a boolean), which
** is true if the call succeeds without errors. In such case, pcall also returns
** all results from the call, after this first result. In case of any error, 
** pcall returns false plus the error message.
*/
static int luaB_pcall (lua_State *L) {
  int status;
  luaL_checkany(L, 1);
  status = lua_pcall(L, lua_gettop(L) - 1, LUA_MULTRET, 0);
  lua_pushboolean(L, (status == 0));
  lua_insert(L, 1);
  return lua_gettop(L);  /* return status + all results */
}


/*
** xpcall (f, err)
**
** This function is similar to pcall, except that you can set a new error 
** handler.
**
** xpcall calls function f in protected mode, using err as the error handler.
** Any error inside f is not propagated; instead, xpcall catches the error, 
** calls the err function with the original error object, and returns a status 
** code. Its first result is the status code (a boolean), which is true if the 
** call succeeds without errors. In this case, xpcall also returns all results 
** from the call, after this first result. In case of any error, xpcall returns 
** false plus the result from err.
*/
static int luaB_xpcall (lua_State *L) {
  int status;
  luaL_checkany(L, 2);
  lua_settop(L, 2);
  lua_insert(L, 1);  /* put error function under function to be called */
  status = lua_pcall(L, 0, LUA_MULTRET, 1);
  lua_pushboolean(L, (status == 0));
  lua_replace(L, 1);
  return lua_gettop(L);  /* return status + all results */
}


/*
** tostring (e)
**
** Receives an argument of any type and converts it to a string in a reasonable 
** format. For complete control of how numbers are converted, use string.format.
**
** If the metatable of e has a "__tostring" field, then tostring calls the 
** corresponding value with e as argument, and uses the result of the call as 
** its result.
*/
static int luaB_tostring (lua_State *L) {
  luaL_checkany(L, 1);
  if (luaL_callmeta(L, 1, "__tostring"))  /* is there a metafield? */
    return 1;  /* use its value */
  switch (lua_type(L, 1)) {
    case LUA_TNUMBER:
      lua_pushstring(L, lua_tostring(L, 1));
      break;
    case LUA_TSTRING:
      lua_pushvalue(L, 1);
      break;
    case LUA_TBOOLEAN:
      lua_pushstring(L, (lua_toboolean(L, 1) ? "true" : "false"));
      break;
    case LUA_TNIL:
      lua_pushliteral(L, "nil");
      break;
    default:
      lua_pushfstring(L, "%s: %p", luaL_typename(L, 1), lua_topointer(L, 1));
      break;
  }
  return 1;
}


static int luaB_newproxy (lua_State *L) {
  lua_settop(L, 1);
  lua_newuserdata(L, 0);  /* create proxy */
  if (lua_toboolean(L, 1) == 0)
    return 1;  /* no metatable */
  else if (lua_isboolean(L, 1)) {
    lua_newtable(L);  /* create a new metatable `m' ... */
    lua_pushvalue(L, -1);  /* ... and mark `m' as a valid metatable */
    lua_pushboolean(L, 1);
    lua_rawset(L, lua_upvalueindex(1));  /* weaktable[m] = true */
  }
  else {
    int validproxy = 0;  /* to check if weaktable[metatable(u)] == true */
    if (lua_getmetatable(L, 1)) {
      lua_rawget(L, lua_upvalueindex(1));
      validproxy = lua_toboolean(L, -1);
      lua_pop(L, 1);  /* remove value */
    }
    luaL_argcheck(L, validproxy, 1, "boolean or proxy expected");
    lua_getmetatable(L, 1);  /* metatable is valid; get it */
  }
  lua_setmetatable(L, 2);
  return 1;
}


static const luaL_Reg base_funcs[] = {
  {"assert", luaB_assert},
  {"collectgarbage", luaB_collectgarbage},
  {"dofile", luaB_dofile},
  {"error", luaB_error},
  {"gcinfo", luaB_gcinfo},
  {"getfenv", luaB_getfenv},
  {"getmetatable", luaB_getmetatable},
  {"loadfile", luaB_loadfile},
  {"load", luaB_load},
  {"loadstring", luaB_loadstring},
  {"next", luaB_next},
  {"pcall", luaB_pcall},
  {"print", luaB_print},
  {"rawequal", luaB_rawequal},
  {"rawget", luaB_rawget},
  {"rawset", luaB_rawset},
  {"select", luaB_select},
  {"setfenv", luaB_setfenv},
  {"setmetatable", luaB_setmetatable},
  {"tonumber", luaB_tonumber},
  {"tostring", luaB_tostring},
  {"type", luaB_type},
  {"unpack", luaB_unpack},
  {"xpcall", luaB_xpcall},
  {NULL, NULL}
};


/*
** {======================================================
** Coroutine library
** =======================================================
*/

#define CO_RUN	0	/* running */
#define CO_SUS	1	/* suspended */
#define CO_NOR	2	/* 'normal' (it resumed another coroutine) */
#define CO_DEAD	3

static const char *const statnames[] =
    {"running", "suspended", "normal", "dead"};

static int costatus (lua_State *L, lua_State *co) {
  if (L == co) return CO_RUN;
  switch (lua_status(co)) {
    case LUA_YIELD:
      return CO_SUS;
    case 0: {
      lua_Debug ar;
      if (lua_getstack(co, 0, &ar) > 0)  /* does it have frames? */
        return CO_NOR;  /* it is running */
      else if (lua_gettop(co) == 0)
          return CO_DEAD;
      else
        return CO_SUS;  /* initial state */
    }
    default:  /* some error occured */
      return CO_DEAD;
  }
}


/*
** coroutine.status (co)
** 
** Returns the status of coroutine co, as a string: "running", if the coroutine 
** is running (that is, it called status); "suspended", if the coroutine is 
** suspended in a call to yield, or if it has not started running yet; "normal" 
** if the coroutine is active but not running (that is, it has resumed another
** coroutine); and "dead" if the coroutine has finished its body function, or if
** it has stopped with an error.
*/
static int luaB_costatus (lua_State *L) {
  lua_State *co = lua_tothread(L, 1);
  luaL_argcheck(L, co, 1, "coroutine expected");
  lua_pushstring(L, statnames[costatus(L, co)]);
  return 1;
}


static int auxresume (lua_State *L, lua_State *co, int narg) {
  int status = costatus(L, co);
  if (!lua_checkstack(co, narg))
    luaL_error(L, "too many arguments to resume");
  if (status != CO_SUS) {
    lua_pushfstring(L, "cannot resume %s coroutine", statnames[status]);
    return -1;  /* error flag */
  }
  lua_xmove(L, co, narg);
  lua_setlevel(L, co);
  status = lua_resume(co, narg);
  if (status == 0 || status == LUA_YIELD) {
    int nres = lua_gettop(co);
    if (!lua_checkstack(L, nres + 1))
      luaL_error(L, "too many results to resume");
    lua_xmove(co, L, nres);  /* move yielded values */
    return nres;
  }
  else {
    lua_xmove(co, L, 1);  /* move error message */
    return -1;  /* error flag */
  }
}


/*
** coroutine.resume (co [, val1, ···])
** 
** Starts or continues the execution of coroutine co. The first time you resume 
** a coroutine, it starts running its body. The values val1, ··· are passed as 
** the arguments to the body function. If the coroutine has yielded, resume 
** restarts it; the values val1, ··· are passed as the results from the yield.
** If the coroutine runs without any errors, resume returns true plus any values
** passed to yield (if the coroutine yields) or any values returned by the body 
** function (if the coroutine terminates). If there is any error, resume returns
** false plus the error message.
*/
static int luaB_coresume (lua_State *L) {
  lua_State *co = lua_tothread(L, 1);
  int r;
  luaL_argcheck(L, co, 1, "coroutine expected");
  r = auxresume(L, co, lua_gettop(L) - 1);
  if (r < 0) {
    lua_pushboolean(L, 0);
    lua_insert(L, -2);
    return 2;  /* return false + error message */
  }
  else {
    lua_pushboolean(L, 1);
    lua_insert(L, -(r + 1));
    return r + 1;  /* return true + `resume' returns */
  }
}


static int luaB_auxwrap (lua_State *L) {
  lua_State *co = lua_tothread(L, lua_upvalueindex(1));
  int r = auxresume(L, co, lua_gettop(L));
  if (r < 0) {
    if (lua_isstring(L, -1)) {  /* error object is a string? */
      luaL_where(L, 1);  /* add extra info */
      lua_insert(L, -2);
      lua_concat(L, 2);
    }
    lua_error(L);  /* propagate error */
  }
  return r;
}


/*
** coroutine.create (f)
** 
** Creates a new coroutine, with body f. f must be a Lua function. Returns this 
** new coroutine, an object with type "thread".
*/
static int luaB_cocreate (lua_State *L) {
  lua_State *NL = lua_newthread(L);
  luaL_argcheck(L, lua_isfunction(L, 1) && !lua_iscfunction(L, 1), 1,
    "Lua function expected");
  lua_pushvalue(L, 1);  /* move function to top */
  lua_xmove(L, NL, 1);  /* move function from L to NL */
  return 1;
}


/*
** coroutine.wrap (f)
** 
** Creates a new coroutine, with body f. f must be a Lua function. Returns a
** function that resumes the coroutine each time it is called. Any arguments
** passed to the function behave as the extra arguments to resume. Returns the
** same values returned by resume, except the first boolean. In case of error, 
** propagates the error.
*/
static int luaB_cowrap (lua_State *L) {
  luaB_cocreate(L);
  lua_pushcclosure(L, luaB_auxwrap, 1);
  return 1;
}


/*
** coroutine.yield (···)
** 
** Suspends the execution of the calling coroutine. The coroutine cannot be 
** running a C function, a metamethod, or an iterator. Any arguments to yield 
** are passed as extra results to resume.
*/
static int luaB_yield (lua_State *L) {
  return lua_yield(L, lua_gettop(L));
}


/*
** coroutine.running ()
** 
** Returns the running coroutine, or nil when called by the main thread.
*/
static int luaB_corunning (lua_State *L) {
  if (lua_pushthread(L))
    lua_pushnil(L);  /* main thread is not a coroutine */
  return 1;
}


static const luaL_Reg co_funcs[] = {
  {"create", luaB_cocreate},
  {"resume", luaB_coresume},
  {"running", luaB_corunning},
  {"status", luaB_costatus},
  {"wrap", luaB_cowrap},
  {"yield", luaB_yield},
  {NULL, NULL}
};

/* }====================================================== */


static void auxopen (lua_State *L, const char *name,
                     lua_CFunction f, lua_CFunction u) {
  lua_pushcfunction(L, u);
  lua_pushcclosure(L, f, 1);
  lua_setfield(L, -2, name);
}


static void base_open (lua_State *L) {
  /* set global _G */
  lua_pushvalue(L, LUA_GLOBALSINDEX);
  lua_setglobal(L, "_G");
  /* open lib into global table */
  luaL_register(L, "_G", base_funcs);
  lua_pushliteral(L, LUA_VERSION);
  lua_setglobal(L, "_VERSION");  /* set global _VERSION */
  /* `ipairs' and `pairs' need auxiliary functions as upvalues */
  auxopen(L, "ipairs", luaB_ipairs, ipairsaux);
  auxopen(L, "pairs", luaB_pairs, luaB_next);
  /* `newproxy' needs a weaktable as upvalue */
  lua_createtable(L, 0, 1);  /* new table `w' */
  lua_pushvalue(L, -1);  /* `w' will be its own metatable */
  lua_setmetatable(L, -2);
  lua_pushliteral(L, "kv");
  lua_setfield(L, -2, "__mode");  /* metatable(w).__mode = "kv" */
  lua_pushcclosure(L, luaB_newproxy, 1);
  lua_setglobal(L, "newproxy");  /* set global `newproxy' */
}


LUALIB_API int luaopen_base (lua_State *L) {
  base_open(L);
  luaL_register(L, LUA_COLIBNAME, co_funcs);
  return 2;
}


