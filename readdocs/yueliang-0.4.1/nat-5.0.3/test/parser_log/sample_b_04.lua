-- START OF SOURCE --
  local a,b,c
  do
    local b
    print(b)
  end
  print(b)
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'local' line=1
  local_stat: local statement
    localstat: begin
        str_checkname: 'a'
        new_localvar: 'a'
        str_checkname: 'b'
        new_localvar: 'b'
        str_checkname: 'c'
        new_localvar: 'c'
    localstat: end
  -- STATEMENT: end 'local'
  
  -- STATEMENT: begin 'do' line=2
  do_stat: begin
  block: begin
    enterblock(isbreakable=false)
    chunk:
    -- STATEMENT: begin 'local' line=3
    local_stat: local statement
      localstat: begin
          str_checkname: 'b'
          new_localvar: 'b'
      localstat: end
    -- STATEMENT: end 'local'
    
    -- STATEMENT: begin 'expr' line=4
    prefixexp: <name>
        str_checkname: 'print'
        singlevar(kind): 'VGLOBAL'
    primaryexp: ( funcargs
      funcargs: begin '('
        explist1: begin
        expr:
        prefixexp: <name>
            str_checkname: 'b'
            singlevar(kind): 'VLOCAL'
        explist1: end
      funcargs: end -- expr is a VCALL
    expr_stat: function call k='VCALL'
    -- STATEMENT: end 'expr'
    
    leaveblock
  block: end
  do_stat: end
  -- STATEMENT: end 'do'
  
  -- STATEMENT: begin 'expr' line=6
  prefixexp: <name>
      str_checkname: 'print'
      singlevar(kind): 'VGLOBAL'
  primaryexp: ( funcargs
    funcargs: begin '('
      explist1: begin
      expr:
      prefixexp: <name>
          str_checkname: 'b'
          singlevar(kind): 'VLOCAL'
      explist1: end
    funcargs: end -- expr is a VCALL
  expr_stat: function call k='VCALL'
  -- STATEMENT: end 'expr'
  
  close_func
-- TOP: end
