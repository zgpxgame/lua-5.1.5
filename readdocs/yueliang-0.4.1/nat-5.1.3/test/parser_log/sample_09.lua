-- START OF SOURCE --
while true do foo=not foo end
while foo~=42 do foo=foo-1 end
while true do break end
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'while' line=1
  while_stat: begin/condition
    cond: begin
    expr:
    simpleexp: true
    cond: end
    enterblock(isbreakable=true)
    while_stat: block
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
          subexpr: uop='not'
        prefixexp: <name>
            str_checkname: 'foo'
            singlevar(kind): 'VGLOBAL'
        explist1: end
      -- STATEMENT: end 'expr'
      
      leaveblock
    block: end
    leaveblock
  while_stat: end
  -- STATEMENT: end 'while'
  
  -- STATEMENT: begin 'while' line=2
  while_stat: begin/condition
    cond: begin
    expr:
    prefixexp: <name>
        str_checkname: 'foo'
        singlevar(kind): 'VGLOBAL'
      subexpr: binop='~='
      simpleexp: <number>=42
      subexpr: -- evaluate
    cond: end
    enterblock(isbreakable=true)
    while_stat: block
    block: begin
      enterblock(isbreakable=false)
      chunk:
      -- STATEMENT: begin 'expr' line=2
      prefixexp: <name>
          str_checkname: 'foo'
          singlevar(kind): 'VGLOBAL'
      expr_stat: assignment k='VGLOBAL'
      assignment: '=' -- RHS elements follows
        explist1: begin
        expr:
        prefixexp: <name>
            str_checkname: 'foo'
            singlevar(kind): 'VGLOBAL'
          subexpr: binop='-'
          simpleexp: <number>=1
          subexpr: -- evaluate
        explist1: end
      -- STATEMENT: end 'expr'
      
      leaveblock
    block: end
    leaveblock
  while_stat: end
  -- STATEMENT: end 'while'
  
  -- STATEMENT: begin 'while' line=3
  while_stat: begin/condition
    cond: begin
    expr:
    simpleexp: true
    cond: end
    enterblock(isbreakable=true)
    while_stat: block
    block: begin
      enterblock(isbreakable=false)
      chunk:
      -- STATEMENT: begin 'break' line=3
      break_stat: -- break out of loop
      -- STATEMENT: end 'break'
      leaveblock
    block: end
    leaveblock
  while_stat: end
  -- STATEMENT: end 'while'
  
  close_func
-- TOP: end
