-- START OF SOURCE --
foo = function() return end
foo = function(x,y) return end
foo = function(...) return end
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'expr' line=1
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar: name='foo'
  expr_stat: assignment k='VLOCAL'
  assignment: '=' -- RHS elements follows
    explist1: begin
    expr:
    simpleexp: function
      open_func
      body: begin
      body: parlist
        parlist: begin
        parlist: end
      body: chunk
      chunk:
      -- STATEMENT: begin 'return' line=1
      return_stat: no return values
      -- STATEMENT: end 'return'
      body: end
      close_func
    explist1: end
  -- STATEMENT: end 'expr'
  
  -- STATEMENT: begin 'expr' line=2
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar: name='foo'
  expr_stat: assignment k='VLOCAL'
  assignment: '=' -- RHS elements follows
    explist1: begin
    expr:
    simpleexp: function
      open_func
      body: begin
      body: parlist
        parlist: begin
            str_checkname: 'x'
            str_checkname: 'y'
        parlist: end
      body: chunk
      chunk:
      -- STATEMENT: begin 'return' line=2
      return_stat: no return values
      -- STATEMENT: end 'return'
      body: end
      close_func
    explist1: end
  -- STATEMENT: end 'expr'
  
  -- STATEMENT: begin 'expr' line=3
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar: name='foo'
  expr_stat: assignment k='VLOCAL'
  assignment: '=' -- RHS elements follows
    explist1: begin
    expr:
    simpleexp: function
      open_func
      body: begin
      body: parlist
        parlist: begin
        parlist: ... (dots)
        parlist: end
      body: chunk
      chunk:
      -- STATEMENT: begin 'return' line=3
      return_stat: no return values
      -- STATEMENT: end 'return'
      body: end
      close_func
    explist1: end
  -- STATEMENT: end 'expr'
  
  close_func
-- TOP: end
