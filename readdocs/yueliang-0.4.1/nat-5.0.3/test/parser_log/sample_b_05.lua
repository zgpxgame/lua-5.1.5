-- START OF SOURCE --
  local function foo() end
  bar = foo
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'local' line=1
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
  
  -- STATEMENT: begin 'expr' line=2
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
  
  close_func
-- TOP: end
