-- START OF SOURCE --
if foo then foo=1 end
if foo then foo=1 else foo=0 end
if foo then foo=1 elseif not foo then foo=0 end
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'if' line=1
  if_stat: if...then
  test_then_block: test condition
    cond: begin
    expr:
    prefixexp: <name>
        str_checkname: 'foo'
        singlevar(kind): 'VGLOBAL'
    cond: end
  test_then_block: then block
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
      simpleexp: <number>=1
      explist1: end
    -- STATEMENT: end 'expr'
    
    leaveblock
  block: end
  if_stat: end
  -- STATEMENT: end 'if'
  
  -- STATEMENT: begin 'if' line=2
  if_stat: if...then
  test_then_block: test condition
    cond: begin
    expr:
    prefixexp: <name>
        str_checkname: 'foo'
        singlevar(kind): 'VGLOBAL'
    cond: end
  test_then_block: then block
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
      simpleexp: <number>=1
      explist1: end
    -- STATEMENT: end 'expr'
    
    leaveblock
  block: end
  if_stat: else...
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
      simpleexp: <number>=0
      explist1: end
    -- STATEMENT: end 'expr'
    
    leaveblock
  block: end
  if_stat: end
  -- STATEMENT: end 'if'
  
  -- STATEMENT: begin 'if' line=3
  if_stat: if...then
  test_then_block: test condition
    cond: begin
    expr:
    prefixexp: <name>
        str_checkname: 'foo'
        singlevar(kind): 'VGLOBAL'
    cond: end
  test_then_block: then block
  block: begin
    enterblock(isbreakable=false)
    chunk:
    -- STATEMENT: begin 'expr' line=3
    prefixexp: <name>
        str_checkname: 'foo'
        singlevar(kind): 'VGLOBAL'
    expr_stat: assignment k='VGLOBAL'
    assignment: '=' -- RHS elements follows
      explist1: begin
      expr:
      simpleexp: <number>=1
      explist1: end
    -- STATEMENT: end 'expr'
    
    leaveblock
  block: end
  if_stat: elseif...then
  test_then_block: test condition
    cond: begin
    expr:
      subexpr: uop='not'
    prefixexp: <name>
        str_checkname: 'foo'
        singlevar(kind): 'VGLOBAL'
    cond: end
  test_then_block: then block
  block: begin
    enterblock(isbreakable=false)
    chunk:
    -- STATEMENT: begin 'expr' line=3
    prefixexp: <name>
        str_checkname: 'foo'
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
  if_stat: end
  -- STATEMENT: end 'if'
  
  close_func
-- TOP: end
