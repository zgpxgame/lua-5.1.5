-- START OF SOURCE --
  function foo(a,b)
    local bar = function(c,d)
      print(a,b,c,d)
    end
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
          str_checkname: 'a'
          new_localvar: 'a'
          str_checkname: 'b'
          new_localvar: 'b'
      parlist: end
    body: chunk
    chunk:
    -- STATEMENT: begin 'local' line=2
    local_stat: local statement
      localstat: begin
          str_checkname: 'bar'
          new_localvar: 'bar'
      localstat: -- assignment
        explist1: begin
        expr:
        simpleexp: function
          open_func
          body: begin
          body: parlist
            parlist: begin
                str_checkname: 'c'
                new_localvar: 'c'
                str_checkname: 'd'
                new_localvar: 'd'
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
                  singlevar(kind): 'VUPVAL'
              explist1: ',' -- continuation
              expr:
              prefixexp: <name>
                  str_checkname: 'b'
                  singlevar(kind): 'VUPVAL'
              explist1: ',' -- continuation
              expr:
              prefixexp: <name>
                  str_checkname: 'c'
                  singlevar(kind): 'VLOCAL'
              explist1: ',' -- continuation
              expr:
              prefixexp: <name>
                  str_checkname: 'd'
                  singlevar(kind): 'VLOCAL'
              explist1: end
            funcargs: end -- expr is a VCALL
          expr_stat: function call k='VCALL'
          -- STATEMENT: end 'expr'
          
          body: end
          close_func
        explist1: end
      localstat: end
    -- STATEMENT: end 'local'
    
    body: end
    close_func
  function_stat: end
  -- STATEMENT: end 'function'
  
  close_func
-- TOP: end
