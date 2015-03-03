/*
** $Id: lvm.c,v 2.63.1.5 2011/08/17 20:43:11 roberto Exp $
** Lua virtual machine
** See Copyright Notice in lua.h
*/


#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define lvm_c
#define LUA_CORE

#include "lua.h"

#include "ldebug.h"
#include "ldo.h"
#include "lfunc.h"
#include "lgc.h"
#include "lobject.h"
#include "lopcodes.h"
#include "lstate.h"
#include "lstring.h"
#include "ltable.h"
#include "ltm.h"
#include "lvm.h"



/* limit for table tag-method chains (to avoid loops) */
#define MAXTAGLOOP	100


const TValue *luaV_tonumber (const TValue *obj, TValue *n) {
  lua_Number num;
  if (ttisnumber(obj)) return obj;
  if (ttisstring(obj) && luaO_str2d(svalue(obj), &num)) {
    setnvalue(n, num);
    return n;
  }
  else
    return NULL;
}


int luaV_tostring (lua_State *L, StkId obj) {
  if (!ttisnumber(obj))
    return 0;
  else {
    char s[LUAI_MAXNUMBER2STR];
    lua_Number n = nvalue(obj);
    lua_number2str(s, n);
    setsvalue2s(L, obj, luaS_new(L, s));
    return 1;
  }
}


static void traceexec (lua_State *L, const Instruction *pc) {
  lu_byte mask = L->hookmask;
  const Instruction *oldpc = L->savedpc;
  L->savedpc = pc;
  if ((mask & LUA_MASKCOUNT) && L->hookcount == 0) {
    resethookcount(L);
    luaD_callhook(L, LUA_HOOKCOUNT, -1);
  }
  if (mask & LUA_MASKLINE) {
    Proto *p = ci_func(L->ci)->l.p;
    int npc = pcRel(pc, p);
    int newline = getline(p, npc);
    /* call linehook when enter a new function, when jump back (loop),
       or when enter a new line */
    if (npc == 0 || pc <= oldpc || newline != getline(p, pcRel(oldpc, p)))
      luaD_callhook(L, LUA_HOOKLINE, newline);
  }
}


static void callTMres (lua_State *L, StkId res, const TValue *f,
                        const TValue *p1, const TValue *p2) {
  ptrdiff_t result = savestack(L, res);
  setobj2s(L, L->top, f);  /* push function */
  setobj2s(L, L->top+1, p1);  /* 1st argument */
  setobj2s(L, L->top+2, p2);  /* 2nd argument */
  luaD_checkstack(L, 3);
  L->top += 3;
  luaD_call(L, L->top - 3, 1);
  res = restorestack(L, result);
  L->top--;
  setobjs2s(L, res, L->top);
}



static void callTM (lua_State *L, const TValue *f, const TValue *p1,
                    const TValue *p2, const TValue *p3) {
  setobj2s(L, L->top, f);  /* push function */
  setobj2s(L, L->top+1, p1);  /* 1st argument */
  setobj2s(L, L->top+2, p2);  /* 2nd argument */
  setobj2s(L, L->top+3, p3);  /* 3th argument */
  luaD_checkstack(L, 4);
  L->top += 4;
  luaD_call(L, L->top - 4, 0);
}


void luaV_gettable (lua_State *L, const TValue *t, TValue *key, StkId val) {
  int loop;
  for (loop = 0; loop < MAXTAGLOOP; loop++) {
    const TValue *tm;
    if (ttistable(t)) {  /* `t' is a table? */
      Table *h = hvalue(t);
      const TValue *res = luaH_get(h, key); /* do a primitive get */
      if (!ttisnil(res) ||  /* result is no nil? */
          (tm = fasttm(L, h->metatable, TM_INDEX)) == NULL) { /* or no TM? */
        setobj2s(L, val, res);
        return;
      }
      /* else will try the tag method */
    }
    else if (ttisnil(tm = luaT_gettmbyobj(L, t, TM_INDEX)))
      luaG_typeerror(L, t, "index");
    if (ttisfunction(tm)) {
      callTMres(L, val, tm, t, key);
      return;
    }
    t = tm;  /* else repeat with `tm' */ 
  }
  luaG_runerror(L, "loop in gettable");
}


void luaV_settable (lua_State *L, const TValue *t, TValue *key, StkId val) {
  int loop;
  TValue temp;
  for (loop = 0; loop < MAXTAGLOOP; loop++) {
    const TValue *tm;
    if (ttistable(t)) {  /* `t' is a table? */
      Table *h = hvalue(t);
      TValue *oldval = luaH_set(L, h, key); /* do a primitive set */
      if (!ttisnil(oldval) ||  /* result is no nil? */
          (tm = fasttm(L, h->metatable, TM_NEWINDEX)) == NULL) { /* or no TM? */
        setobj2t(L, oldval, val);
        h->flags = 0;
        luaC_barriert(L, h, val);
        return;
      }
      /* else will try the tag method */
    }
    else if (ttisnil(tm = luaT_gettmbyobj(L, t, TM_NEWINDEX)))
      luaG_typeerror(L, t, "index");
    if (ttisfunction(tm)) {
      callTM(L, tm, t, key, val);
      return;
    }
    /* else repeat with `tm' */
    setobj(L, &temp, tm);  /* avoid pointing inside table (may rehash) */
    t = &temp;
  }
  luaG_runerror(L, "loop in settable");
}


static int call_binTM (lua_State *L, const TValue *p1, const TValue *p2,
                       StkId res, TMS event) {
  const TValue *tm = luaT_gettmbyobj(L, p1, event);  /* try first operand */
  if (ttisnil(tm))
    tm = luaT_gettmbyobj(L, p2, event);  /* try second operand */
  if (ttisnil(tm)) return 0;
  callTMres(L, res, tm, p1, p2);
  return 1;
}


static const TValue *get_compTM (lua_State *L, Table *mt1, Table *mt2,
                                  TMS event) {
  const TValue *tm1 = fasttm(L, mt1, event);
  const TValue *tm2;
  if (tm1 == NULL) return NULL;  /* no metamethod */
  if (mt1 == mt2) return tm1;  /* same metatables => same metamethods */
  tm2 = fasttm(L, mt2, event);
  if (tm2 == NULL) return NULL;  /* no metamethod */
  if (luaO_rawequalObj(tm1, tm2))  /* same metamethods? */
    return tm1;
  return NULL;
}


static int call_orderTM (lua_State *L, const TValue *p1, const TValue *p2,
                         TMS event) {
  const TValue *tm1 = luaT_gettmbyobj(L, p1, event);
  const TValue *tm2;
  if (ttisnil(tm1)) return -1;  /* no metamethod? */
  tm2 = luaT_gettmbyobj(L, p2, event);
  if (!luaO_rawequalObj(tm1, tm2))  /* different metamethods? */
    return -1;
  callTMres(L, L->top, tm1, p1, p2);
  return !l_isfalse(L->top);
}


static int l_strcmp (const TString *ls, const TString *rs) {
  const char *l = getstr(ls);
  size_t ll = ls->tsv.len;
  const char *r = getstr(rs);
  size_t lr = rs->tsv.len;
  for (;;) {
    int temp = strcoll(l, r);
    if (temp != 0) return temp;
    else {  /* strings are equal up to a `\0' */
      size_t len = strlen(l);  /* index of first `\0' in both strings */
      if (len == lr)  /* r is finished? */
        return (len == ll) ? 0 : 1;
      else if (len == ll)  /* l is finished? */
        return -1;  /* l is smaller than r (because r is not finished) */
      /* both strings longer than `len'; go on comparing (after the `\0') */
      len++;
      l += len; ll -= len; r += len; lr -= len;
    }
  }
}


int luaV_lessthan (lua_State *L, const TValue *l, const TValue *r) {
  int res;
  if (ttype(l) != ttype(r))
    return luaG_ordererror(L, l, r);
  else if (ttisnumber(l))
    return luai_numlt(nvalue(l), nvalue(r));
  else if (ttisstring(l))
    return l_strcmp(rawtsvalue(l), rawtsvalue(r)) < 0;
  else if ((res = call_orderTM(L, l, r, TM_LT)) != -1)
    return res;
  return luaG_ordererror(L, l, r);
}


static int lessequal (lua_State *L, const TValue *l, const TValue *r) {
  int res;
  if (ttype(l) != ttype(r))
    return luaG_ordererror(L, l, r);
  else if (ttisnumber(l))
    return luai_numle(nvalue(l), nvalue(r));
  else if (ttisstring(l))
    return l_strcmp(rawtsvalue(l), rawtsvalue(r)) <= 0;
  else if ((res = call_orderTM(L, l, r, TM_LE)) != -1)  /* first try `le' */
    return res;
  else if ((res = call_orderTM(L, r, l, TM_LT)) != -1)  /* else try `lt' */
    return !res;
  return luaG_ordererror(L, l, r);
}


int luaV_equalval (lua_State *L, const TValue *t1, const TValue *t2) {
  const TValue *tm;
  lua_assert(ttype(t1) == ttype(t2));
  switch (ttype(t1)) {
    case LUA_TNIL: return 1;
    case LUA_TNUMBER: return luai_numeq(nvalue(t1), nvalue(t2));
    case LUA_TBOOLEAN: return bvalue(t1) == bvalue(t2);  /* true must be 1 !! */
    case LUA_TLIGHTUSERDATA: return pvalue(t1) == pvalue(t2);
    case LUA_TUSERDATA: {
      if (uvalue(t1) == uvalue(t2)) return 1;
      tm = get_compTM(L, uvalue(t1)->metatable, uvalue(t2)->metatable,
                         TM_EQ);
      break;  /* will try TM */
    }
    case LUA_TTABLE: {
      if (hvalue(t1) == hvalue(t2)) return 1;
      tm = get_compTM(L, hvalue(t1)->metatable, hvalue(t2)->metatable, TM_EQ);
      break;  /* will try TM */
    }
    default: return gcvalue(t1) == gcvalue(t2);
  }
  if (tm == NULL) return 0;  /* no TM? */
  callTMres(L, L->top, tm, t1, t2);  /* call TM */
  return !l_isfalse(L->top);
}


void luaV_concat (lua_State *L, int total, int last) {
  do {
    StkId top = L->base + last + 1;
    int n = 2;  /* number of elements handled in this pass (at least 2) */
    if (!(ttisstring(top-2) || ttisnumber(top-2)) || !tostring(L, top-1)) {
      if (!call_binTM(L, top-2, top-1, top-2, TM_CONCAT))
        luaG_concaterror(L, top-2, top-1);
    } else if (tsvalue(top-1)->len == 0)  /* second op is empty? */
      (void)tostring(L, top - 2);  /* result is first op (as string) */
    else {
      /* at least two string values; get as many as possible */
      size_t tl = tsvalue(top-1)->len;
      char *buffer;
      int i;
      /* collect total length */
      for (n = 1; n < total && tostring(L, top-n-1); n++) {
        size_t l = tsvalue(top-n-1)->len;
        if (l >= MAX_SIZET - tl) luaG_runerror(L, "string length overflow");
        tl += l;
      }
      buffer = luaZ_openspace(L, &G(L)->buff, tl);
      tl = 0;
      for (i=n; i>0; i--) {  /* concat all strings */
        size_t l = tsvalue(top-i)->len;
        memcpy(buffer+tl, svalue(top-i), l);
        tl += l;
      }
      setsvalue2s(L, top-n, luaS_newlstr(L, buffer, tl));
    }
    total -= n-1;  /* got `n' strings to create 1 new */
    last -= n-1;
  } while (total > 1);  /* repeat until only 1 result left */
}


static void Arith (lua_State *L, StkId ra, const TValue *rb,
                   const TValue *rc, TMS op) {
  TValue tempb, tempc;
  const TValue *b, *c;
  if ((b = luaV_tonumber(rb, &tempb)) != NULL &&
      (c = luaV_tonumber(rc, &tempc)) != NULL) {
    lua_Number nb = nvalue(b), nc = nvalue(c);
    switch (op) {
      case TM_ADD: setnvalue(ra, luai_numadd(nb, nc)); break;
      case TM_SUB: setnvalue(ra, luai_numsub(nb, nc)); break;
      case TM_MUL: setnvalue(ra, luai_nummul(nb, nc)); break;
      case TM_DIV: setnvalue(ra, luai_numdiv(nb, nc)); break;
      case TM_MOD: setnvalue(ra, luai_nummod(nb, nc)); break;
      case TM_POW: setnvalue(ra, luai_numpow(nb, nc)); break;
      case TM_UNM: setnvalue(ra, luai_numunm(nb)); break;
      default: lua_assert(0); break;
    }
  }
  else if (!call_binTM(L, rb, rc, ra, op))
    luaG_aritherror(L, rb, rc);
}



/*
** some macros for common tasks in `luaV_execute'
*/

#define runtime_check(L, c)	{ if (!(c)) break; }

#define RA(i)	(base+GETARG_A(i))
/* to be used after possible stack reallocation */
#define RB(i)	check_exp(getBMode(GET_OPCODE(i)) == OpArgR, base+GETARG_B(i))
#define RC(i)	check_exp(getCMode(GET_OPCODE(i)) == OpArgR, base+GETARG_C(i))
#define RKB(i)	check_exp(getBMode(GET_OPCODE(i)) == OpArgK, \
	ISK(GETARG_B(i)) ? k+INDEXK(GETARG_B(i)) : base+GETARG_B(i))
#define RKC(i)	check_exp(getCMode(GET_OPCODE(i)) == OpArgK, \
	ISK(GETARG_C(i)) ? k+INDEXK(GETARG_C(i)) : base+GETARG_C(i))
#define KBx(i)	check_exp(getBMode(GET_OPCODE(i)) == OpArgK, k+GETARG_Bx(i))


#define dojump(L,pc,i)	{(pc) += (i); luai_threadyield(L);}


#define Protect(x)	{ L->savedpc = pc; {x;}; base = L->base; }


#define arith_op(op,tm) { \
        TValue *rb = RKB(i); \
        TValue *rc = RKC(i); \
        if (ttisnumber(rb) && ttisnumber(rc)) { \
          lua_Number nb = nvalue(rb), nc = nvalue(rc); \
          setnvalue(ra, op(nb, nc)); \
        } \
        else \
          Protect(Arith(L, ra, rb, rc, tm)); \
      }



void luaV_execute (lua_State *L, int nexeccalls) {
  LClosure *cl;
  StkId base;
  TValue *k;
  const Instruction *pc;
 reentry:  /* entry point */
  lua_assert(isLua(L->ci));
  pc = L->savedpc;
  cl = &clvalue(L->ci->func)->l;
  base = L->base;
  k = cl->p->k;
  /* main loop of interpreter */
  for (;;) {
    const Instruction i = *pc++;
    StkId ra;
    if ((L->hookmask & (LUA_MASKLINE | LUA_MASKCOUNT)) &&
        (--L->hookcount == 0 || L->hookmask & LUA_MASKLINE)) {
      traceexec(L, pc);
      if (L->status == LUA_YIELD) {  /* did hook yield? */
        L->savedpc = pc - 1;
        return;
      }
      base = L->base;
    }
    /* warning!! several calls may realloc the stack and invalidate `ra' */
    ra = RA(i);
    lua_assert(base == L->base && L->base == L->ci->base);
    lua_assert(base <= L->top && L->top <= L->stack + L->stacksize);
    lua_assert(L->top == L->ci->top || luaG_checkopenop(i));
    switch (GET_OPCODE(i)) {
      /* 
	  ** Instruction Notation
	  ** R(A) Register A (specified in instruction field A)
	  ** R(B) Register B (specified in instruction field B)
	  ** R(C) Register C (specified in instruction field C)
	  ** PC Program Counter
	  ** Kst(n) Element n in the constant list
	  ** Upvalue[n] Name of upvalue with index n
	  ** Gbl[sym] Global variable indexed by symbol sym
	  ** RK(B) Register B or a constant index
	  ** RK(C) Register C or a constant index
	  ** sBx Signed displacement (in field sBx) for all kinds of jumps
	  */

      /*
      ** MOVE A B R(A) := R(B)
      ** Copies the value of register R(B) into register R(A). If R(B) holds a table,
      ** function or userdata, then the reference to that object is copied. MOVE is
      ** often used for moving values into place for the next operation.
      ** The opcode for MOVE has a second purpose ¨C it is also used in creating
      ** closures, always appearing after the CLOSURE instruction; see CLOSURE
      ** for more information.
	  */
      case OP_MOVE: {
        setobjs2s(L, ra, RB(i));
        continue;
      }

      /*
	  ** LOADK A Bx R(A) := Kst(Bx)
      ** Loads constant number Bx into register R(A). Constants are usually
      ** numbers or strings. Each function has its own constant list, or pool.
	  */
      case OP_LOADK: {
        setobj2s(L, ra, KBx(i));
        continue;
      }
      
      /*
	  ** LOADBOOL A B C R(A) := (Bool)B; if (C) PC++
	  ** Loads a boolean value (true or false) into register R(A). true is usually
	  ** encoded as an integer 1, false is always 0. If C is non-zero, then the next
	  ** instruction is skipped (this is used when you have an assignment
	  ** statement where the expression uses relational operators, e.g. M = K>5.)
	  ** You can use any non-zero value for the boolean true in field B, but since
	  ** you cannot use booleans as numbers in Lua, it¡¯s best to stick to 1 for true. 
	  */
      case OP_LOADBOOL: {
        setbvalue(ra, GETARG_B(i));
        if (GETARG_C(i)) pc++;  /* skip next instruction (if C) */
        continue;
      }

      /*
	  ** LOADNIL A B R(A) := ... := R(B) := nil
	  ** Sets a range of registers from R(A) to R(B) to nil. If a single register is to
	  ** be assigned to, then R(A) = R(B). When two or more consecutive locals
	  ** need to be assigned nil values, only a single LOADNIL is needed.
	  */
      case OP_LOADNIL: {
        TValue *rb = RB(i);
        do {
          setnilvalue(rb--);
        } while (rb >= ra);
        continue;
      }

      /*
	  ** GETUPVAL A B R(A) := UpValue[B]
	  ** Copies the value in upvalue number B into register R(A). Each function
	  ** may have its own upvalue list. This upvalue list is internal to the virtual
	  ** machine; the list of upvalue name strings in a prototype is not mandatory.
	  ** The opcode for GETUPVAL has a second purpose ¨C it is also used in
	  ** creating closures, always appearing after the CLOSURE instruction; see
	  ** CLOSURE for more information.
	  */
      case OP_GETUPVAL: {
        int b = GETARG_B(i);
        setobj2s(L, ra, cl->upvals[b]->v);
        continue;
      }

      /*
	  ** GETGLOBAL A Bx R(A) := Gbl[Kst(Bx)]
	  ** Copies the value of the global variable whose name is given in constant
	  ** number Bx into register R(A). The name constant must be a string.
	  */
      case OP_GETGLOBAL: {
        TValue g;
        TValue *rb = KBx(i);
        sethvalue(L, &g, cl->env);
        lua_assert(ttisstring(rb));
        Protect(luaV_gettable(L, &g, rb, ra));
        continue;
      }

      /*
	  ** GETTABLE A B C R(A) := R(B)[RK(C)]
	  ** Copies the value from a table element into register R(A). The table is
	  ** referenced by register R(B), while the index to the table is given by RK(C),
	  ** which may be the value of register R(C) or a constant number.
	  */
      case OP_GETTABLE: {
        Protect(luaV_gettable(L, RB(i), RKC(i), ra));
        continue;
      }

      /*
	  ** SETGLOBAL A Bx Gbl[Kst(Bx)] := R(A)
	  ** Copies the value from register R(A) into the global variable whose name is
	  ** given in constant number Bx. The name constant must be a string.
	  */
      case OP_SETGLOBAL: {
        TValue g;
        sethvalue(L, &g, cl->env);
        lua_assert(ttisstring(KBx(i)));
        Protect(luaV_settable(L, &g, KBx(i), ra));
        continue;
      }

      /*
	  ** SETUPVAL A B UpValue[B] := R(A)
	  ** Copies the value from register R(A) into the upvalue number B in the
	  ** upvalue list for that function.
	  */
      case OP_SETUPVAL: {
        UpVal *uv = cl->upvals[GETARG_B(i)];
        setobj(L, uv->v, ra);
        luaC_barrier(L, uv, ra);
        continue;
      }

      /*
	  ** SETTABLE A B C R(A)[RK(B)] := RK(C)
	  ** Copies the value from register R(C) or a constant into a table element. The
	  ** table is referenced by register R(A), while the index to the table is given by
	  ** RK(B), which may be the value of register R(B) or a constant number.
	  */
      case OP_SETTABLE: {
        Protect(luaV_settable(L, ra, RKB(i), RKC(i)));
        continue;
      }

      /*
	  ** NEWTABLE A B C R(A) := {} (size = B,C)
	  ** Creates a new empty table at register R(A). B and C are the encoded size
	  ** information for the array part and the hash part of the table, respectively.
	  ** Appropriate values for B and C are set in order to avoid rehashing when
	  ** initially populating the table with array values or hash key-value pairs.
	  ** Operand B and C are both encoded as a ¡°floating point byte¡± (so named in
	  ** lobject.c) which is eeeeexxx in binary, where x is the mantissa and e
	  ** is the exponent. The actual value is calculated as 1xxx*2^(eeeee-1) if
	  ** eeeee is greater than 0 (a range of 8 to 15*2^30.) If eeeee is 0, the actual
	  ** value is xxx (a range of 0 to 7.)
	  ** If an empty table is created, both sizes are zero. If a table is created with a
	  ** number of objects, the code generator counts the number of array
	  ** elements and the number of hash elements. Then, each size value is
	  ** rounded up and encoded in B and C using the floating point byte format.
	  */
      case OP_NEWTABLE: {
        int b = GETARG_B(i);
        int c = GETARG_C(i);
        sethvalue(L, ra, luaH_new(L, luaO_fb2int(b), luaO_fb2int(c)));
        Protect(luaC_checkGC(L));
        continue;
      }

      /*
	  ** SELF A B C R(A+1) := R(B); R(A) := R(B)[RK(C)]
	  ** For object-oriented programming using tables. Retrieves a function
	  ** reference from a table element and places it in register R(A), then a
	  ** reference to the table itself is placed in the next register, R(A+1). This
	  ** instruction saves some messy manipulation when setting up a method call.
	  ** R(B) is the register holding the reference to the table with the method. The
	  ** method function itself is found using the table index RK(C), which may be
	  ** the value of register R(C) or a constant number.
	  */
      case OP_SELF: {
        StkId rb = RB(i);
        setobjs2s(L, ra+1, rb);
        Protect(luaV_gettable(L, rb, RKC(i), ra));
        continue;
      }

      /*
	  ** ADD A B C R(A) := RK(B) + RK(C)
	  ** SUB A B C R(A) := RK(B) ¨C RK(C)
	  ** MUL A B C R(A) := RK(B) * RK(C)
	  ** DIV A B C R(A) := RK(B) / RK(C)
	  ** MOD A B C R(A) := RK(B) % RK(C)
	  ** POW A B C R(A) := RK(B) ^ RK(C)
	  ** Binary operators (arithmetic operators with two inputs.) The result of the
	  ** operation between RK(B) and RK(C) is placed into R(A). These
	  ** instructions are in the classic 3-register style. RK(B) and RK(C) may be
	  ** either registers or constants in the constant pool.
	  ** ADD is addition. SUB is subtraction. MUL is multiplication. DIV is division.
	  ** MOD is modulus (remainder). POW is exponentiation.
	  */
      case OP_ADD: {
        arith_op(luai_numadd, TM_ADD);
        continue;
      }
      case OP_SUB: {
        arith_op(luai_numsub, TM_SUB);
        continue;
      }
      case OP_MUL: {
        arith_op(luai_nummul, TM_MUL);
        continue;
      }
      case OP_DIV: {
        arith_op(luai_numdiv, TM_DIV);
        continue;
      }
      case OP_MOD: {
        arith_op(luai_nummod, TM_MOD);
        continue;
      }
      case OP_POW: {
        arith_op(luai_numpow, TM_POW);
        continue;
      }

      /*
	  ** UNM A B R(A) := -R(B)
	  ** Unary minus (arithmetic operator with one input.) R(B) is negated and the
	  ** value placed in R(A). R(A) and R(B) are always registers.
	  */
      case OP_UNM: {
        TValue *rb = RB(i);
        if (ttisnumber(rb)) {
          lua_Number nb = nvalue(rb);
          setnvalue(ra, luai_numunm(nb));
        }
        else {
          Protect(Arith(L, ra, rb, rb, TM_UNM));
        }
        continue;
      }

      /*
	  ** NOT A B R(A) := not R(B)
	  ** Applies a boolean NOT to the value in R(B) and places the result in R(A).
	  ** R(A) and R(B) are always registers.
	  */
      case OP_NOT: {
        int res = l_isfalse(RB(i));  /* next assignment may change this value */
        setbvalue(ra, res);
        continue;
      }

      /*
	  ** LEN A B R(A) := length of R(B)
	  ** Returns the length of the object in R(B). For strings, the string length is
	  ** returned, while for tables, the table size (as defined in Lua) is returned. For
	  ** other objects, the metamethod is called. The result, which is a number, is
	  ** placed in R(A).
	  */
      case OP_LEN: {
        const TValue *rb = RB(i);
        switch (ttype(rb)) {
          case LUA_TTABLE: {
            setnvalue(ra, cast_num(luaH_getn(hvalue(rb))));
            break;
          }
          case LUA_TSTRING: {
            setnvalue(ra, cast_num(tsvalue(rb)->len));
            break;
          }
          default: {  /* try metamethod */
            Protect(
              if (!call_binTM(L, rb, luaO_nilobject, ra, TM_LEN))
                luaG_typeerror(L, rb, "get length of");
            )
          }
        }
        continue;
      }

      /*
	  ** CONCAT A B C R(A) := R(B).. ... ..R(C)
	  ** Performs concatenation of two or more strings. In a Lua source, this is
	  ** equivalent to one or more concatenation operators (¡®..¡¯) between two or
	  ** more expressions. The source registers must be consecutive, and C must
	  ** always be greater than B. The result is placed in R(A).
	  */
      case OP_CONCAT: {
        int b = GETARG_B(i);
        int c = GETARG_C(i);
        Protect(luaV_concat(L, c-b+1, c); luaC_checkGC(L));
        setobjs2s(L, RA(i), base+b);
        continue;
      }

      /*
	  ** JMP sBx PC += sBx
	  ** Performs an unconditional jump, with sBx as a signed displacement. sBx is
	  ** added to the program counter (PC), which points to the next instruction to
	  ** be executed. E.g., if sBx is 0, the VM will proceed to the next instruction.
	  ** JMP is used in loops, conditional statements, and in expressions when a
	  ** boolean true/false need to be generated.
	  */
      case OP_JMP: {
        dojump(L, pc, GETARG_sBx(i));
        continue;
      }

      /*
	  ** EQ A B C if ((RK(B) == RK(C)) ~= A) then PC++
	  ** LT A B C if ((RK(B) < RK(C)) ~= A) then PC++
	  ** LE A B C if ((RK(B) <= RK(C)) ~= A) then PC++
	  ** Compares RK(B) and RK(C), which may be registers or constants. If the
	  ** boolean result is not A, then skip the next instruction. Conversely, if the
	  ** boolean result equals A, continue with the next instruction.
	  ** EQ is for equality. LT is for ¡°less than¡± comparison. LE is for ¡°less than or
	  ** equal to¡± comparison. The boolean A field allows the full set of relational
	  ** comparison operations to be synthesized from these three instructions.
	  ** The Lua code generator produces either 0 or 1 for the boolean A.
	  ** For the fall-through case, a JMP is always expected, in order to optimize
	  ** execution in the virtual machine. In effect, EQ, LT and LE must always be
	  ** paired with a following JMP instruction.
	  */
      case OP_EQ: {
        TValue *rb = RKB(i);
        TValue *rc = RKC(i);
        Protect(
          if (equalobj(L, rb, rc) == GETARG_A(i))
            dojump(L, pc, GETARG_sBx(*pc));
        )
        pc++;
        continue;
      }
      case OP_LT: {
        Protect(
          if (luaV_lessthan(L, RKB(i), RKC(i)) == GETARG_A(i))
            dojump(L, pc, GETARG_sBx(*pc));
        )
        pc++;
        continue;
      }
      case OP_LE: {
        Protect(
          if (lessequal(L, RKB(i), RKC(i)) == GETARG_A(i))
            dojump(L, pc, GETARG_sBx(*pc));
        )
        pc++;
        continue;
      }

      /*
	  ** TEST A C if not (R(A) <=> C) then PC++
	  ** TESTSET A B C if (R(B) <=> C) then R(A) := R(B) else PC++
	  ** Used to implement and and or logical operators, or for testing a single
	  ** register in a conditional statement.
	  ** For TESTSET, register R(B) is coerced into a boolean and compared to
	  ** the boolean field C. If R(B) matches C, the next instruction is skipped,
	  ** otherwise R(B) is assigned to R(A) and the VM continues with the next
	  ** instruction. The and operator uses a C of 0 (false) while or uses a C value
	  ** of 1 (true).
	  ** TEST is a more primitive version of TESTSET. TEST is used when the
	  ** assignment operation is not needed, otherwise it is the same as TESTSET
	  ** except that the operand slots are different.
	  ** For the fall-through case, a JMP is always expected, in order to optimize
	  ** execution in the virtual machine. In effect, TEST and TESTSET must
	  ** always be paired with a following JMP instruction.
	  */
      case OP_TEST: {
        if (l_isfalse(ra) != GETARG_C(i))
          dojump(L, pc, GETARG_sBx(*pc));
        pc++;
        continue;
      }
      case OP_TESTSET: {
        TValue *rb = RB(i);
        if (l_isfalse(rb) != GETARG_C(i)) {
          setobjs2s(L, ra, rb);
          dojump(L, pc, GETARG_sBx(*pc));
        }
        pc++;
        continue;
      }

      /*
	  ** CALL A B C R(A), ... ,R(A+C-2) := R(A)(R(A+1), ... ,R(A+B-1))
	  ** Performs a function call, with register R(A) holding the reference to the
	  ** function object to be called. Parameters to the function are placed in the
	  ** registers following R(A). If B is 1, the function has no parameters. If B is 2
	  ** or more, there are (B-1) parameters.
	  ** If B is 0, the function parameters range from R(A+1) to the top of the stack.
	  ** This form is used when the last expression in the parameter list is a
	  ** function call, so the number of actual parameters is indeterminate.
	  ** Results returned by the function call is placed in a range of registers
	  ** starting from R(A). If C is 1, no return results are saved. If C is 2 or more,
	  ** (C-1) return values are saved. If C is 0, then multiple return results are
	  ** saved, depending on the called function.
	  ** CALL always updates the top of stack value. CALL, RETURN, VARARG
	  ** and SETLIST can use multiple values (up to the top of the stack.)
	  */
      case OP_CALL: {
        int b = GETARG_B(i);
        int nresults = GETARG_C(i) - 1;
        if (b != 0) L->top = ra+b;  /* else previous instruction set top */
        L->savedpc = pc;
        switch (luaD_precall(L, ra, nresults)) {
          case PCRLUA: {
            nexeccalls++;
            goto reentry;  /* restart luaV_execute over new Lua function */
          }
          case PCRC: {
            /* it was a C function (`precall' called it); adjust results */
            if (nresults >= 0) L->top = L->ci->top;
            base = L->base;
            continue;
          }
          default: {
            return;  /* yield */
          }
        }
      }

      /*
	  ** TAILCALL A B C return R(A)(R(A+1), ... ,R(A+B-1))
	  ** Performs a tail call, which happens when a return statement has a single
	  ** function call as the expression, e.g. return foo(bar). A tail call is
	  ** effectively a goto, and avoids nesting calls another level deeper. Only Lua
	  ** functions can be tailcalled.
	  ** Like CALL, register R(A) holds the reference to the function object to be
	  ** called. B encodes the number of parameters in the same manner as a
	  ** CALL instruction.
	  ** C isn¡¯t used by TAILCALL, since all return results are significant. In any
	  ** case, Lua always generates a 0 for C, to denote multiple return results.
	  */
      case OP_TAILCALL: {
        int b = GETARG_B(i);
        if (b != 0) L->top = ra+b;  /* else previous instruction set top */
        L->savedpc = pc;
        lua_assert(GETARG_C(i) - 1 == LUA_MULTRET);
        switch (luaD_precall(L, ra, LUA_MULTRET)) {
          case PCRLUA: {
            /* tail call: put new frame in place of previous one */
            CallInfo *ci = L->ci - 1;  /* previous frame */
            int aux;
            StkId func = ci->func;
            StkId pfunc = (ci+1)->func;  /* previous function index */
            if (L->openupval) luaF_close(L, ci->base);
            L->base = ci->base = ci->func + ((ci+1)->base - pfunc);
            for (aux = 0; pfunc+aux < L->top; aux++)  /* move frame down */
              setobjs2s(L, func+aux, pfunc+aux);
            ci->top = L->top = func+aux;  /* correct top */
            lua_assert(L->top == L->base + clvalue(func)->l.p->maxstacksize);
            ci->savedpc = L->savedpc;
            ci->tailcalls++;  /* one more call lost */
            L->ci--;  /* remove new frame */
            goto reentry;
          }
          case PCRC: {  /* it was a C function (`precall' called it) */
            base = L->base;
            continue;
          }
          default: {
            return;  /* yield */
          }
        }
      }

      /*
	  ** RETURN A B return R(A), ... ,R(A+B-2)
	  ** Returns to the calling function, with optional return values. If B is 1, there
	  ** are no return values. If B is 2 or more, there are (B-1) return values,
	  ** located in consecutive registers from R(A) onwards.
	  ** If B is 0, the set of values from R(A) to the top of the stack is returned. This
	  ** form is used when the last expression in the return list is a function call, so
	  ** the number of actual values returned is indeterminate.
	  ** RETURN also closes any open upvalues, equivalent to a CLOSE
	  ** instruction. See the CLOSE instruction for more information.
	  */
      case OP_RETURN: {
        int b = GETARG_B(i);
        if (b != 0) L->top = ra+b-1;
        if (L->openupval) luaF_close(L, base);
        L->savedpc = pc;
        b = luaD_poscall(L, ra);
        if (--nexeccalls == 0)  /* was previous function running `here'? */
          return;  /* no: return */
        else {  /* yes: continue its execution */
          if (b) L->top = L->ci->top;
          lua_assert(isLua(L->ci));
          lua_assert(GET_OPCODE(*((L->ci)->savedpc - 1)) == OP_CALL);
          goto reentry;
        }
      }

      /*
	  ** FORPREP A sBx R(A) -= R(A+2); PC += sBx
	  ** FORLOOP A sBx R(A) += R(A+2)
	  **               if R(A) <?= R(A+1) then {
	  **                 PC += sBx; R(A+3) = R(A)
	  **               }
	  ** FORPREP initializes a numeric for loop, while FORLOOP performs an
	  ** iteration of a numeric for loop.
	  ** A numeric for loop requires 4 registers on the stack, and each register
	  ** must be a number. R(A) holds the initial value and doubles as the internal
	  ** loop variable (the internal index); R(A+1) is the limit; R(A+2) is the stepping
	  ** value; R(A+3) is the actual loop variable (the external index) that is local to
	  ** the for block.
	  ** FORPREP sets up a for loop. Since FORLOOP is used for initial testing of
	  ** the loop condition as well as conditional testing during the loop itself,
	  ** FORPREP performs a negative step and jumps unconditionally to
	  ** FORLOOP so that FORLOOP is able to correctly make the initial loop test.
	  ** After this initial test, FORLOOP performs a loop step as usual, restoring
	  ** the initial value of the loop index so that the first iteration can start.
	  ** In FORLOOP, a jump is made back to the start of the loop body if the limit
	  ** has not been reached or exceeded. The sense of the comparison depends
	  ** on whether the stepping is negative or positive, hence the ¡°<?=¡± operator.
	  ** Jumps for both instructions are encoded as signed displacements in the
	  ** sBx field. An empty loop has a FORLOOP sBx value of -1.
	  ** FORLOOP also sets R(A+3), the external loop index that is local to the
	  ** loop block. This is significant if the loop index is used as an upvalue (see
	  ** below.) R(A), R(A+1) and R(A+2) are not visible to the programmer.
	  ** The loop variable ends with the last value before the limit is reached
	  ** (unlike C) because it is not updated unless the jump is made. However,
	  ** since loop variables are local to the loop itself, you should not be able to
	  ** use it unless you cook up an implementation-specific hack.
	  */
      case OP_FORLOOP: {
        lua_Number step = nvalue(ra+2);
        lua_Number idx = luai_numadd(nvalue(ra), step); /* increment index */
        lua_Number limit = nvalue(ra+1);
        if (luai_numlt(0, step) ? luai_numle(idx, limit)
                                : luai_numle(limit, idx)) {
          dojump(L, pc, GETARG_sBx(i));  /* jump back */
          setnvalue(ra, idx);  /* update internal index... */
          setnvalue(ra+3, idx);  /* ...and external index */
        }
        continue;
      }
      case OP_FORPREP: {
        const TValue *init = ra;
        const TValue *plimit = ra+1;
        const TValue *pstep = ra+2;
        L->savedpc = pc;  /* next steps may throw errors */
        if (!tonumber(init, ra))
          luaG_runerror(L, LUA_QL("for") " initial value must be a number");
        else if (!tonumber(plimit, ra+1))
          luaG_runerror(L, LUA_QL("for") " limit must be a number");
        else if (!tonumber(pstep, ra+2))
          luaG_runerror(L, LUA_QL("for") " step must be a number");
        setnvalue(ra, luai_numsub(nvalue(ra), nvalue(pstep)));
        dojump(L, pc, GETARG_sBx(i));
        continue;
      }

      /*
	  ** TFORLOOP A C R(A+3), ... ,R(A+2+C) := R(A)(R(A+1), R(A+2));
	  **              if R(A+3) ~= nil then {
	  **                R(A+2) = R(A+3);
	  **              } else {
	  **                PC++;
	  **              }
	  ** Performs an iteration of a generic for loop. A Lua 5-style generic for loop
	  ** keeps 3 items in consecutive register locations to keep track of things. R(A)
	  ** is the iterator function, which is called once per loop. R(A+1) is the state,
	  ** and R(A+2) is the enumeration index. At the start, R(A+2) has an initial
	  ** value. R(A), R(A+1) and R(A+2) are internal to the loop and cannot be
	  ** accessed by the programmer; at first, they are set with an initial state.
	  ** In addition to these internal loop variables, the programmer specifies one
	  ** or more loop variables that are external and visible to the programmer.
	  ** These loop variables reside at locations R(A+3) onwards, and their count is
	  ** specified in operand C. Operand C must be at least 1. They are also local
	  ** to the loop body, like the external loop index in a numerical for loop.
	  ** Each time TFORLOOP executes, the iterator function referenced by R(A)
	  ** is called with two arguments: the state and the enumeration index (R(A+1)
	  ** and R(A+2).) The results are returned in the local loop variables, from
	  ** R(A+3) onwards, up to R(A+2+C).
	  ** Next, the first return value, R(A+3), is tested. If it is nil, the iterator loop is
	  ** at an end, and TFORLOOP skips the next instruction and the for loop
	  ** block ends. Note that the state of the generic for loop does not depend on
	  ** any of the external iterator variables that are visible to the programmer.
	  ** If R(A+3) is not nil, there is another iteration, and R(A+3) is assigned as
	  ** the new value of the enumeration index, R(A+2). Then next instruction,
	  ** which must be a JMP, is immediately executed, sending execution back to
	  ** the beginning of the loop. This is an optimization case; TFORLOOP will not
	  ** work correctly without the JMP instruction.
	  */
      case OP_TFORLOOP: {
        StkId cb = ra + 3;  /* call base */
        setobjs2s(L, cb+2, ra+2);
        setobjs2s(L, cb+1, ra+1);
        setobjs2s(L, cb, ra);
        L->top = cb+3;  /* func. + 2 args (state and index) */
        Protect(luaD_call(L, cb, GETARG_C(i)));
        L->top = L->ci->top;
        cb = RA(i) + 3;  /* previous call may change the stack */
        if (!ttisnil(cb)) {  /* continue loop? */
          setobjs2s(L, cb-1, cb);  /* save control variable */
          dojump(L, pc, GETARG_sBx(*pc));  /* jump back */
        }
        pc++;
        continue;
      }

      /*
	  ** SETLIST A B C R(A)[(C-1)*FPF+i] := R(A+i), 1 <= i <= B
	  ** Sets the values for a range of array elements in a table referenced by
	  ** R(A). Field B is the number of elements to set. Field C encodes the block
	  ** number of the table to be initialized. The values used to initialize the table
	  ** are located in registers R(A+1), R(A+2), and so on.
	  ** The block size is denoted by FPF. FPF is ¡°fields per flush¡±, defined as
	  ** LFIELDS_PER_FLUSH in the source file lopcodes.h, with a value of 50.
	  ** For example, for array locations 1 to 20, C will be 1 and B will be 20.
	  ** If B is 0, the table is set with a variable number of array elements, from
	  ** register R(A+1) up to the top of the stack. This happens when the last
	  ** element in the table constructor is a function call or a vararg operator.
	  ** If C is 0, the next instruction is cast as an integer, and used as the C value.
	  ** This happens only when operand C is unable to encode the block number,
	  ** i.e. when C > 511, equivalent to an array index greater than 25550.
	  */
      case OP_SETLIST: {
        int n = GETARG_B(i);
        int c = GETARG_C(i);
        int last;
        Table *h;
        if (n == 0) {
          n = cast_int(L->top - ra) - 1;
          L->top = L->ci->top;
        }
        if (c == 0) c = cast_int(*pc++);
        runtime_check(L, ttistable(ra));
        h = hvalue(ra);
        last = ((c-1)*LFIELDS_PER_FLUSH) + n;
        if (last > h->sizearray)  /* needs more space? */
          luaH_resizearray(L, h, last);  /* pre-alloc it at once */
        for (; n > 0; n--) {
          TValue *val = ra+n;
          setobj2t(L, luaH_setnum(L, h, last--), val);
          luaC_barriert(L, h, val);
        }
        continue;
      }

      /*
	  ** CLOSE A close all variables in the stack up to (>=) R(A)
	  ** Closes all local variables in the stack from register R(A) onwards. This
	  ** instruction is only generated if there is an upvalue present within those
	  ** local variables. It has no effect if a local isn¡¯t used as an upvalue.
	  ** If a local is used as an upvalue, then the local variable need to be placed
	  ** somewhere, otherwise it will go out of scope and disappear when a lexical
	  ** block enclosing the local variable ends. CLOSE performs this operation for
	  ** all affected local variables for do end blocks or loop blocks. RETURN also
	  ** does an implicit CLOSE when a function returns.
	  */
      case OP_CLOSE: {
        luaF_close(L, ra);
        continue;
      }

      /*
	  ** CLOSURE A Bx R(A) := closure(KPROTO[Bx], R(A), ... ,R(A+n))
	  ** Creates an instance (or closure) of a function. Bx is the function number of
	  ** the function to be instantiated in the table of function prototypes. This table
	  ** is located after the constant table for each function in a binary chunk. The
	  ** first function prototype is numbered 0. Register R(A) is assigned the
	  ** reference to the instantiated function object.
	  ** For each upvalue used by the instance of the function KPROTO[Bx], there
	  ** is a pseudo-instruction that follows CLOSURE. Each upvalue corresponds
	  ** to either a MOVE or a GETUPVAL pseudo-instruction. Only the B field on
	  ** either of these pseudo-instructions are significant.
	  ** A MOVE corresponds to local variable R(B) in the current lexical block,
	  ** which will be used as an upvalue in the instantiated function. A
	  ** GETUPVAL corresponds upvalue number B in the current lexical block.
	  ** The VM uses these pseudo-instructions to manage upvalues.
	  */
      case OP_CLOSURE: {
        Proto *p;
        Closure *ncl;
        int nup, j;
        p = cl->p->p[GETARG_Bx(i)];
        nup = p->nups;
        ncl = luaF_newLclosure(L, nup, cl->env);
        ncl->l.p = p;
        for (j=0; j<nup; j++, pc++) {
          if (GET_OPCODE(*pc) == OP_GETUPVAL)
            ncl->l.upvals[j] = cl->upvals[GETARG_B(*pc)];
          else {
            lua_assert(GET_OPCODE(*pc) == OP_MOVE);
            ncl->l.upvals[j] = luaF_findupval(L, base + GETARG_B(*pc));
          }
        }
        setclvalue(L, ra, ncl);
        Protect(luaC_checkGC(L));
        continue;
      }

      /*
	  ** VARARG A B R(A), R(A+1), ..., R(A+B-1) = vararg
	  ** VARARG implements the vararg operator ¡®...¡¯ in expressions. VARARG
	  ** copies B-1 parameters into a number of registers starting from R(A),
	  ** padding with nils if there aren¡¯t enough values. If B is 0, VARARG copies
	  ** as many values as it can based on the number of parameters passed. If a
	  ** fixed number of values is required, B is a value greater than 1. If any
	  ** number of values is required, B is 0.
	  */
      case OP_VARARG: {
        int b = GETARG_B(i) - 1;
        int j;
        CallInfo *ci = L->ci;
        int n = cast_int(ci->base - ci->func) - cl->p->numparams - 1;
        if (b == LUA_MULTRET) {
          Protect(luaD_checkstack(L, n));
          ra = RA(i);  /* previous call may change the stack */
          b = n;
          L->top = ra + n;
        }
        for (j = 0; j < b; j++) {
          if (j < n) {
            setobjs2s(L, ra + j, ci->base - n + j);
          }
          else {
            setnilvalue(ra + j);
          }
        }
        continue;
      }
    }
  }
}


