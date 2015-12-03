-- START OF SOURCE --
do return end
do return 123 end
do return "foo","bar" end
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'do' line=1
  do_stat: begin
  block: begin
    enterblock(isbreakable=false)
    chunk:
    -- STATEMENT: begin 'return' line=1
    return_stat: no return values
    -- STATEMENT: end 'return'
    leaveblock
  block: end
  do_stat: end
  -- STATEMENT: end 'do'
  
  -- STATEMENT: begin 'do' line=2
  do_stat: begin
  block: begin
    enterblock(isbreakable=false)
    chunk:
    -- STATEMENT: begin 'return' line=2
    return_stat: begin
      explist1: begin
      expr:
      simpleexp: <number>=123
      explist1: end
    return_stat: end
    -- STATEMENT: end 'return'
    leaveblock
  block: end
  do_stat: end
  -- STATEMENT: end 'do'
  
  -- STATEMENT: begin 'do' line=3
  do_stat: begin
  block: begin
    enterblock(isbreakable=false)
    chunk:
    -- STATEMENT: begin 'return' line=3
    return_stat: begin
      explist1: begin
      expr:
      simpleexp: <string>=foo
          codestring: "foo"
      explist1: ',' -- continuation
      expr:
      simpleexp: <string>=bar
          codestring: "bar"
      explist1: end
    return_stat: end
    -- STATEMENT: end 'return'
    leaveblock
  block: end
  do_stat: end
  -- STATEMENT: end 'do'
  
  close_func
-- TOP: end
