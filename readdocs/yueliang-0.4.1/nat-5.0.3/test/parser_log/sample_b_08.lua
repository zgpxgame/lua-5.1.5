-- START OF SOURCE --
  local foo
  local function bar()
    local function baz()
      local foo, bar
      foo = bar
      foo = baz
    end
    foo = bar
    foo = baz
  end
  foo = bar
  foo = baz
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
    -- STATEMENT: begin 'local' line=3
    local_stat: local function
    localfunc: begin
        str_checkname: 'baz'
        new_localvar: 'baz'
    localfunc: body
      open_func
      body: begin
      body: parlist
        parlist: begin
        parlist: end
      body: chunk
      chunk:
      -- STATEMENT: begin 'local' line=4
      local_stat: local statement
        localstat: begin
            str_checkname: 'foo'
            new_localvar: 'foo'
            str_checkname: 'bar'
            new_localvar: 'bar'
        localstat: end
      -- STATEMENT: end 'local'
      
      -- STATEMENT: begin 'expr' line=5
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
      
      -- STATEMENT: begin 'expr' line=6
      prefixexp: <name>
          str_checkname: 'foo'
          singlevar(kind): 'VLOCAL'
      expr_stat: assignment k='VLOCAL'
      assignment: '=' -- RHS elements follows
        explist1: begin
        expr:
        prefixexp: <name>
            str_checkname: 'baz'
            singlevar(kind): 'VUPVAL'
        explist1: end
      -- STATEMENT: end 'expr'
      
      body: end
      close_func
    localfunc: end
    -- STATEMENT: end 'local'
    
    -- STATEMENT: begin 'expr' line=8
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
      explist1: end
    -- STATEMENT: end 'expr'
    
    -- STATEMENT: begin 'expr' line=9
    prefixexp: <name>
        str_checkname: 'foo'
        singlevar(kind): 'VUPVAL'
    expr_stat: assignment k='VUPVAL'
    assignment: '=' -- RHS elements follows
      explist1: begin
      expr:
      prefixexp: <name>
          str_checkname: 'baz'
          singlevar(kind): 'VLOCAL'
      explist1: end
    -- STATEMENT: end 'expr'
    
    body: end
    close_func
  localfunc: end
  -- STATEMENT: end 'local'
  
  -- STATEMENT: begin 'expr' line=11
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
  
  -- STATEMENT: begin 'expr' line=12
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar(kind): 'VLOCAL'
  expr_stat: assignment k='VLOCAL'
  assignment: '=' -- RHS elements follows
    explist1: begin
    expr:
    prefixexp: <name>
        str_checkname: 'baz'
        singlevar(kind): 'VGLOBAL'
    explist1: end
  -- STATEMENT: end 'expr'
  
  close_func
-- TOP: end
