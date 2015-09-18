-- START OF SOURCE --
local function foo() return end
local function foo(a) return end
local function foo(x,y,z) return end
local function foo(x,...) return end
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'local' line=1
  local_stat: local function
  localfunc: begin
      str_checkname: 'foo'
  localfunc: body
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
  localfunc: end
  -- STATEMENT: end 'local'
  
  -- STATEMENT: begin 'local' line=2
  local_stat: local function
  localfunc: begin
      str_checkname: 'foo'
  localfunc: body
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
  localfunc: end
  -- STATEMENT: end 'local'
  
  -- STATEMENT: begin 'local' line=3
  local_stat: local function
  localfunc: begin
      str_checkname: 'foo'
  localfunc: body
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
  localfunc: end
  -- STATEMENT: end 'local'
  
  -- STATEMENT: begin 'local' line=4
  local_stat: local function
  localfunc: begin
      str_checkname: 'foo'
  localfunc: body
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
  localfunc: end
  -- STATEMENT: end 'local'
  
  close_func
-- TOP: end
