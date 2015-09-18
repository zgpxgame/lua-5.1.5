-- START OF SOURCE --
  local c,d
  function foo(a,b,c)
    print(a,c,d,e)
  end
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'local' line=1
  local_stat: local statement
    localstat: begin
        str_checkname: 'c'
        new_localvar: 'c'
        str_checkname: 'd'
        new_localvar: 'd'
    localstat: end
  -- STATEMENT: end 'local'
  
  -- STATEMENT: begin 'function' line=2
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
          str_checkname: 'a'
          new_localvar: 'a'
          str_checkname: 'b'
          new_localvar: 'b'
          str_checkname: 'c'
          new_localvar: 'c'
      parlist: end
    body: chunk
    chunk:
    -- STATEMENT: begin 'expr' line=3
    prefixexp: <name>
        str_checkname: 'print'
        singlevar(kind): 'VGLOBAL'
    primaryexp: ( funcargs
      funcargs: begin '('
        explist1: begin
        expr:
        prefixexp: <name>
            str_checkname: 'a'
            singlevar(kind): 'VLOCAL'
        explist1: ',' -- continuation
        expr:
        prefixexp: <name>
            str_checkname: 'c'
            singlevar(kind): 'VLOCAL'
        explist1: ',' -- continuation
        expr:
        prefixexp: <name>
            str_checkname: 'd'
            singlevar(kind): 'VUPVAL'
        explist1: ',' -- continuation
        expr:
        prefixexp: <name>
            str_checkname: 'e'
            singlevar(kind): 'VGLOBAL'
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
