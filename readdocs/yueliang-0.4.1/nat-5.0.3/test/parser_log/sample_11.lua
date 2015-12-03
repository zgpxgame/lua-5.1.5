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
    enterblock(isbreakable=false)
        str_checkname: 'i'
    for_stat: numerical loop
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
        enterblock(isbreakable=true)
        block: begin
          enterblock(isbreakable=false)
          chunk:
          -- STATEMENT: begin 'expr' line=1
          prefixexp: <name>
              str_checkname: 'foo'
              singlevar: name='foo'
          expr_stat: assignment k='VLOCAL'
          assignment: '=' -- RHS elements follows
            explist1: begin
            expr:
            prefixexp: <name>
                str_checkname: 'i'
                singlevar: name='i'
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
    enterblock(isbreakable=false)
        str_checkname: 'i'
    for_stat: numerical loop
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
        enterblock(isbreakable=true)
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
    enterblock(isbreakable=false)
        str_checkname: 'i'
    for_stat: list-based loop
      forlist: begin
      forlist: explist1
        explist1: begin
        expr:
        prefixexp: <name>
            str_checkname: 'foo'
            singlevar: name='foo'
        explist1: end
      forlist: body
        enterblock(isbreakable=true)
        block: begin
          enterblock(isbreakable=false)
          chunk:
          -- STATEMENT: begin 'expr' line=3
          prefixexp: <name>
              str_checkname: 'bar'
              singlevar: name='bar'
          expr_stat: assignment k='VLOCAL'
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
    enterblock(isbreakable=false)
        str_checkname: 'i'
    for_stat: list-based loop
      forlist: begin
          str_checkname: 'j'
      forlist: explist1
        explist1: begin
        expr:
        prefixexp: <name>
            str_checkname: 'foo'
            singlevar: name='foo'
        explist1: ',' -- continuation
        expr:
        prefixexp: <name>
            str_checkname: 'bar'
            singlevar: name='bar'
        explist1: end
      forlist: body
        enterblock(isbreakable=true)
        block: begin
          enterblock(isbreakable=false)
          chunk:
          -- STATEMENT: begin 'expr' line=4
          prefixexp: <name>
              str_checkname: 'baz'
              singlevar: name='baz'
          expr_stat: assignment k='VLOCAL'
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
