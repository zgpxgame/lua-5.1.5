-- START OF SOURCE --
  do
    local a
    print(a)
  end
  print(a)
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'do' line=1
  do_stat: begin
  block: begin
    enterblock(isbreakable=false)
    chunk:
    -- STATEMENT: begin 'local' line=2
    local_stat: local statement
      localstat: begin
          str_checkname: 'a'
          new_localvar: 'a'
      localstat: end
    -- STATEMENT: end 'local'
    
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
        explist1: end
      funcargs: end -- expr is a VCALL
    expr_stat: function call k='VCALL'
    -- STATEMENT: end 'expr'
    
    leaveblock
  block: end
  do_stat: end
  -- STATEMENT: end 'do'
  
  -- STATEMENT: begin 'expr' line=5
  prefixexp: <name>
      str_checkname: 'print'
      singlevar(kind): 'VGLOBAL'
  primaryexp: ( funcargs
    funcargs: begin '('
      explist1: begin
      expr:
      prefixexp: <name>
          str_checkname: 'a'
          singlevar(kind): 'VGLOBAL'
      explist1: end
    funcargs: end -- expr is a VCALL
  expr_stat: function call k='VCALL'
  -- STATEMENT: end 'expr'
  
  close_func
-- TOP: end
