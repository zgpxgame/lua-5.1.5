-- START OF SOURCE --
function foo.bar(p) return end
function foo.bar.baz(p) return end
function foo:bar(p) return end
function foo.bar.baz(p) return end
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'function' line=1
  function_stat: begin
    funcname: begin
        str_checkname: 'foo'
        singlevar: name='foo'
    funcname: -- '.' field
      field: operator=.
        checkname:
        str_checkname: 'bar'
        codestring: "bar"
    funcname: end
  function_stat: body needself='false'
    open_func
    body: begin
    body: parlist
      parlist: begin
          str_checkname: 'p'
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
    funcname: -- '.' field
      field: operator=.
        checkname:
        str_checkname: 'bar'
        codestring: "bar"
    funcname: -- '.' field
      field: operator=.
        checkname:
        str_checkname: 'baz'
        codestring: "baz"
    funcname: end
  function_stat: body needself='false'
    open_func
    body: begin
    body: parlist
      parlist: begin
          str_checkname: 'p'
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
    funcname: -- ':' field
      field: operator=:
        checkname:
        str_checkname: 'bar'
        codestring: "bar"
    funcname: end
  function_stat: body needself='true'
    open_func
    body: begin
    body: parlist
      parlist: begin
          str_checkname: 'p'
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
    funcname: -- '.' field
      field: operator=.
        checkname:
        str_checkname: 'bar'
        codestring: "bar"
    funcname: -- '.' field
      field: operator=.
        checkname:
        str_checkname: 'baz'
        codestring: "baz"
    funcname: end
  function_stat: body needself='false'
    open_func
    body: begin
    body: parlist
      parlist: begin
          str_checkname: 'p'
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
