-- START OF SOURCE --
local foo
local foo,bar,baz
local foo,bar="foo","bar"
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
  local_stat: local statement
    localstat: begin
        str_checkname: 'foo'
        new_localvar: 'foo'
        str_checkname: 'bar'
        new_localvar: 'bar'
        str_checkname: 'baz'
        new_localvar: 'baz'
    localstat: end
  -- STATEMENT: end 'local'
  
  -- STATEMENT: begin 'local' line=3
  local_stat: local statement
    localstat: begin
        str_checkname: 'foo'
        new_localvar: 'foo'
        str_checkname: 'bar'
        new_localvar: 'bar'
    localstat: -- assignment
      explist1: begin
      expr:
      simpleexp: <string>=foo
          codestring: "foo"
      explist1: ',' -- continuation
      expr:
      simpleexp: <string>=bar
          codestring: "bar"
      explist1: end
    localstat: end
  -- STATEMENT: end 'local'
  
  close_func
-- TOP: end
