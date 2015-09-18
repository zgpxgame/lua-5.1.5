-- START OF SOURCE --
  local a
  print(a)
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'local' line=1
  local_stat: local statement
    localstat: begin
        str_checkname: 'a'
        new_localvar: 'a'
    localstat: end
  -- STATEMENT: end 'local'
  
  -- STATEMENT: begin 'expr' line=2
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
  
  close_func
-- TOP: end
