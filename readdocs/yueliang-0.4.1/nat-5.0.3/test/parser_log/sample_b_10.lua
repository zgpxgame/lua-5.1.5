-- START OF SOURCE --
  function foo(...)
    print(arg)
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
    funcname: end
  function_stat: body needself='false'
    open_func
    body: begin
    body: parlist
      parlist: begin
      parlist: ... (dots)
          new_localvar: 'arg'
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
            str_checkname: 'arg'
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
