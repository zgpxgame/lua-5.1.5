-- START OF SOURCE --
  local foo
  local function bar()
    baz = nil
    foo = bar()
  end
  foo = bar
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'local' line=1
  local_stat: local statement
    localstat: begin
        str_checkname: 'foo'
        new_localvar: 'foo'
    localstat: end
  -- STATEMENT: end 'local'
  
  -- STATEMENT: begin 'local' line=2
  local_stat: local function
  localfunc: begin
      str_checkname: 'bar'
      new_localvar: 'bar'
  localfunc: body
    open_func
    body: begin
    body: parlist
      parlist: begin
      parlist: end
    body: chunk
    chunk:
    -- STATEMENT: begin 'expr' line=3
    prefixexp: <name>
        str_checkname: 'baz'
        singlevar(kind): 'VGLOBAL'
    expr_stat: assignment k='VGLOBAL'
    assignment: '=' -- RHS elements follows
      explist1: begin
      expr:
      simpleexp: nil
      explist1: end
    -- STATEMENT: end 'expr'
    
    -- STATEMENT: begin 'expr' line=4
    prefixexp: <name>
        str_checkname: 'foo'
        singlevar(kind): 'VUPVAL'
    expr_stat: assignment k='VUPVAL'
    assignment: '=' -- RHS elements follows
      explist1: begin
      expr:
      prefixexp: <name>
          str_checkname: 'bar'
          singlevar(kind): 'VUPVAL'
      primaryexp: ( funcargs
        funcargs: begin '('
        funcargs: end -- expr is a VCALL
      explist1: end
    -- STATEMENT: end 'expr'
    
    body: end
    close_func
  localfunc: end
  -- STATEMENT: end 'local'
  
  -- STATEMENT: begin 'expr' line=6
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar(kind): 'VLOCAL'
  expr_stat: assignment k='VLOCAL'
  assignment: '=' -- RHS elements follows
    explist1: begin
    expr:
    prefixexp: <name>
        str_checkname: 'bar'
        singlevar(kind): 'VLOCAL'
    explist1: end
  -- STATEMENT: end 'expr'
  
  close_func
-- TOP: end
