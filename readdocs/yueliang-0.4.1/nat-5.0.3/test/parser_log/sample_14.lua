-- START OF SOURCE --
function foo() return end
function foo(a) return end
function foo(x,y,z) return end
function foo(x,...) return end
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'function' line=1
  function_stat: begin
    funcname: begin
        str_checkname: 'foo'
        singlevar: name='foo'
    funcname: end
  function_stat: body needself='false'
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
  function_stat: end
  -- STATEMENT: end 'function'
  
  -- STATEMENT: begin 'function' line=2
  function_stat: begin
    funcname: begin
        str_checkname: 'foo'
        singlevar: name='foo'
    funcname: end
  function_stat: body needself='false'
    open_func
    body: begin
    body: parlist
      parlist: begin
          str_checkname: 'a'
      parlist: end
    body: chunk
    chunk:
    -- STATEMENT: begin 'return' line=2
    return_stat: no return values
    -- STATEMENT: end 'return'
    body: end
    close_func
  function_stat: end
  -- STATEMENT: end 'function'
  
  -- STATEMENT: begin 'function' line=3
  function_stat: begin
    funcname: begin
        str_checkname: 'foo'
        singlevar: name='foo'
    funcname: end
  function_stat: body needself='false'
    open_func
    body: begin
    body: parlist
      parlist: begin
          str_checkname: 'x'
          str_checkname: 'y'
          str_checkname: 'z'
      parlist: end
    body: chunk
    chunk:
    -- STATEMENT: begin 'return' line=3
    return_stat: no return values
    -- STATEMENT: end 'return'
    body: end
    close_func
  function_stat: end
  -- STATEMENT: end 'function'
  
  -- STATEMENT: begin 'function' line=4
  function_stat: begin
    funcname: begin
        str_checkname: 'foo'
        singlevar: name='foo'
    funcname: end
  function_stat: body needself='false'
    open_func
    body: begin
    body: parlist
      parlist: begin
          str_checkname: 'x'
      parlist: ... (dots)
      parlist: end
    body: chunk
    chunk:
    -- STATEMENT: begin 'return' line=4
    return_stat: no return values
    -- STATEMENT: end 'return'
    body: end
    close_func
  function_stat: end
  -- STATEMENT: end 'function'
  
  close_func
-- TOP: end
