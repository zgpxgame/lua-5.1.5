-- START OF SOURCE --
  do
    local function foo() end
    bar = foo
  end
  baz = foo
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'do' line=1
  do_stat: begin
  block: begin
    enterblock(isbreakable=false)
    chunk:
    -- STATEMENT: begin 'local' line=2
    local_stat: local function
    localfunc: begin
        str_checkname: 'foo'
        new_localvar: 'foo'
    localfunc: body
      open_func
      body: begin
      body: parlist
        parlist: begin
        parlist: end
      body: chunk
      chunk:
      body: end
      close_func
    localfunc: end
    -- STATEMENT: end 'local'
    
    -- STATEMENT: begin 'expr' line=3
    prefixexp: <name>
        str_checkname: 'bar'
        singlevar(kind): 'VGLOBAL'
    expr_stat: assignment k='VGLOBAL'
    assignment: '=' -- RHS elements follows
      explist1: begin
      expr:
      prefixexp: <name>
          str_checkname: 'foo'
          singlevar(kind): 'VLOCAL'
      explist1: end
    -- STATEMENT: end 'expr'
    
    leaveblock
  block: end
  do_stat: end
  -- STATEMENT: end 'do'
  
  -- STATEMENT: begin 'expr' line=5
  prefixexp: <name>
      str_checkname: 'baz'
      singlevar(kind): 'VGLOBAL'
  expr_stat: assignment k='VGLOBAL'
  assignment: '=' -- RHS elements follows
    explist1: begin
    expr:
    prefixexp: <name>
        str_checkname: 'foo'
        singlevar(kind): 'VGLOBAL'
    explist1: end
  -- STATEMENT: end 'expr'
  
  close_func
-- TOP: end
