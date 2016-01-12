FUNC=expr
FUNC_RE=
MAXDEPTH=100
IGNORE="isnumeral;getbinopr;getunopr;enterlevel;leavelevel;codestring;luaK_code;checkname;constfolding;freeexp;luaK_reserveregs;freereg;need_value;check_match;check_next;enterblock;leaveblock;testnext;str_checkname"
IGNORE_RE="luaX_.*;luaM_.*;luaO_.*;luaC_.*;luaH_.*"
SHOW="body;constructor;simpleexp"
SHOW_RE=
OUTPUT_TYPE=html
LAYOUT=LR

gengraph --function=$FUNC --func-re="$FUNC_RE" --maxdepth=$MAXDEPTH --ignore="$IGNORE" --ignore-re="$IGNORE_RE" --show="$SHOW" --show-re="$SHOW_RE" --output-type=$OUTPUT_TYPE --output-layout=$LAYOUT

FUNC=chunk
IGNORE="isnumeral;getbinopr;getunopr;enterlevel;leavelevel;codestring;luaK_code;checkname;constfolding;freeexp;luaK_reserveregs;freereg;need_value;check_match;checknext;enterblock;leaveblock;testnext;str_checkname;init_exp;errorlimit;check_conflict"
IGNORE_RE="luaX_.*;luaM_.*;luaO_.*;luaC_.*;luaH_.*;luaK_.*;luaD_.*"
SHOW=
gengraph --function=$FUNC --func-re="$FUNC_RE" --maxdepth=$MAXDEPTH --ignore="$IGNORE" --ignore-re="$IGNORE_RE" --show="$SHOW" --show-re="$SHOW_RE" --output-type=$OUTPUT_TYPE --output-layout=$LAYOUT
