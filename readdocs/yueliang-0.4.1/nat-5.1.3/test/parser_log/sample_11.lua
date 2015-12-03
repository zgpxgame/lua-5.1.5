-- START OF SOURCE --
for i=1,10 do foo=i end
for i=1,10,2 do break end
for i in foo do bar=0 end
for i,j in foo,bar do baz=0 end
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'for' line=1
  for_stat: begin
    enterblock(isbreakable=true)
        str_checkname: 'i'
    for_stat: numerical loop
        new_localvar: '(for index)'
        new_localvar: '(for limit)'
        new_localvar: '(for step)'
        new_localvar: 'i'
      fornum: begin
      fornum: index start
        exp1: begin
        expr:
        simpleexp: <number>=1
        exp1: end
      fornum: index stop
        exp1: begin
        expr:
        simpleexp: <number>=10
        exp1: end
      fornum: body
        enterblock(isbreakable=false)
        block: begin
          enterblock(isbreakable=false)
          chunk:
          -- STATEMENT: begin 'expr' line=1
          prefixexp: <name>
              str_checkname: 'foo'
              singlevar(kind): 'VGLOBAL'
          expr_stat: assignment k='VGLOBAL'
          assignment: '=' -- RHS elements follows
            explist1: begin
            expr:
            prefixexp: <name>
                str_checkname: 'i'
                singlevar(kind): 'VLOCAL'
            explist1: end
          -- STATEMENT: end 'expr'
          
          leaveblock
        block: end
        leaveblock
      fornum: end
    leaveblock
  for_stat: end
  -- STATEMENT: end 'for'
  
  -- STATEMENT: begin 'for' line=2
  for_stat: begin
    enterblock(isbreakable=true)
        str_checkname: 'i'
    for_stat: numerical loop
        new_localvar: '(for index)'
        new_localvar: '(for limit)'
        new_localvar: '(for step)'
        new_localvar: 'i'
      fornum: begin
      fornum: index start
        exp1: begin
        expr:
        simpleexp: <number>=1
        exp1: end
      fornum: index stop
        exp1: begin
        expr:
        simpleexp: <number>=10
        exp1: end
      fornum: index step
        exp1: begin
        expr:
        simpleexp: <number>=2
        exp1: end
      fornum: body
        enterblock(isbreakable=false)
        block: begin
          enterblock(isbreakable=false)
          chunk:
          -- STATEMENT: begin 'break' line=2
          break_stat: -- break out of loop
          -- STATEMENT: end 'break'
          leaveblock
        block: end
        leaveblock
      fornum: end
    leaveblock
  for_stat: end
  -- STATEMENT: end 'for'
  
  -- STATEMENT: begin 'for' line=3
  for_stat: begin
    enterblock(isbreakable=true)
        str_checkname: 'i'
    for_stat: list-based loop
      forlist: begin
          new_localvar: '(for generator)'
          new_localvar: '(for state)'
          new_localvar: '(for control)'
          new_localvar: 'i'
      forlist: explist1
        explist1: begin
        expr:
        prefixexp: <name>
            str_checkname: 'foo'
            singlevar(kind): 'VGLOBAL'
        explist1: end
      forlist: body
        enterblock(isbreakable=false)
        block: begin
          enterblock(isbreakable=false)
          chunk:
          -- STATEMENT: begin 'expr' line=3
          prefixexp: <name>
              str_checkname: 'bar'
              singlevar(kind): 'VGLOBAL'
          expr_stat: assignment k='VGLOBAL'
          assignment: '=' -- RHS elements follows
            explist1: begin
            expr:
            simpleexp: <number>=0
            explist1: end
          -- STATEMENT: end 'expr'
          
          leaveblock
        block: end
        leaveblock
      forlist: end
    leaveblock
  for_stat: end
  -- STATEMENT: end 'for'
  
  -- STATEMENT: begin 'for' line=4
  for_stat: begin
    enterblock(isbreakable=true)
        str_checkname: 'i'
    for_stat: list-based loop
      forlist: begin
          new_localvar: '(for generator)'
          new_localvar: '(for state)'
          new_localvar: '(for control)'
          new_localvar: 'i'
          str_checkname: 'j'
          new_localvar: 'j'
      forlist: explist1
        explist1: begin
        expr:
        prefixexp: <name>
            str_checkname: 'foo'
            singlevar(kind): 'VGLOBAL'
        explist1: ',' -- continuation
        expr:
        prefixexp: <name>
            str_checkname: 'bar'
            singlevar(kind): 'VGLOBAL'
        explist1: end
      forlist: body
        enterblock(isbreakable=false)
        block: begin
          enterblock(isbreakable=false)
          chunk:
          -- STATEMENT: begin 'expr' line=4
          prefixexp: <name>
              str_checkname: 'baz'
              singlevar(kind): 'VGLOBAL'
          expr_stat: assignment k='VGLOBAL'
          assignment: '=' -- RHS elements follows
            explist1: begin
            expr:
            simpleexp: <number>=0
            explist1: end
          -- STATEMENT: end 'expr'
          
          leaveblock
        block: end
        leaveblock
      forlist: end
    leaveblock
  for_stat: end
  -- STATEMENT: end 'for'
  
  close_func
-- TOP: end
