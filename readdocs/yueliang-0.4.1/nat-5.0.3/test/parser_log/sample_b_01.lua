-- START OF SOURCE --
  print(a)
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'expr' line=1
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
