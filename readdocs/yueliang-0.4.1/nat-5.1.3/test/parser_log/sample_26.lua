-- START OF SOURCE --
  function foo:bar()
    print(self)
  end
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'function' line=1
  function_stat: begin
    funcname: begin
        str_checkname: 'foo'
        singlevar(kind): 'VGLOBAL'
    funcname: -- ':' field
      field: operator=:
        checkname:
        str_checkname: 'bar'
        codestring: "bar"
    funcname: end
  function_stat: body needself='true'
    open_func
    body: begin
        new_localvar: 'self'
    body: parlist
      parlist: begin
      parlist: end
    body: chunk
    chunk:
    -- STATEMENT: begin 'expr' line=2
    prefixexp: <name>
        str_checkname: 'print'
        singlevar(kind): 'VGLOBAL'
    primaryexp: ( funcargs
      funcargs: begin '('
        explist1: begin
        expr:
        prefixexp: <name>
            str_checkname: 'self'
            singlevar(kind): 'VLOCAL'
        explist1: end
      funcargs: end -- expr is a VCALL
    expr_stat: function call k='VCALL'
    -- STATEMENT: end 'expr'
    
    body: end
    close_func
  function_stat: end
  -- STATEMENT: end 'function'
  
  close_func
-- TOP: end
