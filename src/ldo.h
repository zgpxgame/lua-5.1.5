/*
** $Id: ldo.h,v 2.7.1.1 2007/12/27 13:02:25 roberto Exp $
** Stack and Call structure of Lua
** See Copyright Notice in lua.h
*/

#ifndef ldo_h
#define ldo_h


#include "lobject.h"
#include "lstate.h"
#include "lzio.h"

/* 在栈中增加n个元素的空间 */
#define luaD_checkstack(L,n)	\
  if ((char *)L->stack_last - (char *)L->top <= (n)*(int)sizeof(TValue)) \
    luaD_growstack(L, n); \
  else condhardstacktests(luaD_reallocstack(L, L->stacksize - EXTRA_STACK - 1));

/* 栈指针上移。栈空间不足时，增加1个栈空间 */
#define incr_top(L) {luaD_checkstack(L,1); L->top++;}

/* 
** 保存p在栈空间的偏移量，在某些操作之后，栈空间的内存可能会重新分配，之后根据偏
** 移，用宏restorestack重新取得新的元素地址
*/
#define savestack(L,p)		((char *)(p) - (char *)L->stack)
/* 恢复栈元素地址，即取出栈底偏移到n的地址 */
#define restorestack(L,n)	((TValue *)((char *)L->stack + (n)))
/* 保存偏移量 */
#define saveci(L,p)		((char *)(p) - (char *)L->base_ci)
/* 取得偏移量n的地址 */
#define restoreci(L,n)		((CallInfo *)((char *)L->base_ci + (n)))


/*
** results from luaD_precall
** "PCR" means "pre call result"
*/
#define PCRLUA		0	/* initiated a call to a Lua function */
#define PCRC		1	/* did a call to a C function */
#define PCRYIELD	2	/* C funtion yielded */


/* type of protected functions, to be ran by `runprotected' */
typedef void (*Pfunc) (lua_State *L, void *ud);

LUAI_FUNC int luaD_protectedparser (lua_State *L, ZIO *z, const char *name);
LUAI_FUNC void luaD_callhook (lua_State *L, int event, int line);
LUAI_FUNC int luaD_precall (lua_State *L, StkId func, int nresults);
LUAI_FUNC void luaD_call (lua_State *L, StkId func, int nResults);
LUAI_FUNC int luaD_pcall (lua_State *L, Pfunc func, void *u,
                                        ptrdiff_t oldtop, ptrdiff_t ef);
LUAI_FUNC int luaD_poscall (lua_State *L, StkId firstResult);
LUAI_FUNC void luaD_reallocCI (lua_State *L, int newsize);
LUAI_FUNC void luaD_reallocstack (lua_State *L, int newsize);
LUAI_FUNC void luaD_growstack (lua_State *L, int n);

LUAI_FUNC void luaD_throw (lua_State *L, int errcode);
LUAI_FUNC int luaD_rawrunprotected (lua_State *L, Pfunc f, void *ud);

LUAI_FUNC void luaD_seterrorobj (lua_State *L, int errcode, StkId oldtop);

#endif


