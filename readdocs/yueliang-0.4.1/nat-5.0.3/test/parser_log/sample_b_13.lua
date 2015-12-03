-- START OF SOURCE --
  for i = 1,10 do
    print(i)
  end
  for i = 1,10,-2 do
    print(i)
  end
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'for' line=1
  for_stat: begin
    enterblock(isbreakable=false)
        str_checkname: 'i'
    for_stat: numerical loop
        new_localvar: 'i'
        new_localvar: '(for limit)'
        new_localvar: '(for step)'
      fornum: begin
      fornum: index start
        exp1: begin
        expr:
        simpleexp: <number>=1
        exp1: end
      fornum: index stop
        exp1: begin
        expr:
        simpleexp: <number>=10
        exp1: end
      fornum: body
        enterblock(isbreakable=true)
        block: begin
          enterblock(isbreakable=false)
          chunk:
          -- STATEMENT: begin 'expr' line=2
          prefixexp: <name>
              str_checkname: 'print'
              singlevar(kind): 'VGLOBAL'
          primaryexp: ( funcargs
            funcargs: begin '('
              explist1: begin
              expr:
              prefixexp: <name>
                  str_checkname: 'i'
                  singlevar(kind): 'VLOCAL'
              explist1: end
            funcargs: end -- expr is a VCALL
          expr_stat: function call k='VCALL'
          -- STATEMENT: end 'expr'
          
          leaveblock
        block: end
        leaveblock
      fornum: end
    leaveblock
  for_stat: end
  -- STATEMENT: end 'for'
  
  -- STATEMENT: begin 'for' line=4
  for_stat: begin
    enterblock(isbreakable=false)
        str_checkname: 'i'
    for_stat: numerical loop
        new_localvar: 'i'
        new_localvar: '(for limit)'
        new_localvar: '(for step)'
      fornum: begin
      fornum: index start
        exp1: begin
        expr:
        simpleexp: <number>=1
        exp1: end
      fornum: index stop
        exp1: begin
        expr:
        simpleexp: <number>=10
        exp1: end
      fornum: index step
        exp1: begin
        expr:
          subexpr: uop='-'
        simpleexp: <number>=2
        exp1: end
      fornum: body
        enterblock(isbreakable=true)
        block: begin
          enterblock(isbreakable=false)
          chunk:
          -- STATEMENT: begin 'expr' line=5
          prefixexp: <name>
              str_checkname: 'print'
              singlevar(kind): 'VGLOBAL'
          primaryexp: ( funcargs
            funcargs: begin '('
              explist1: begin
              expr:
              prefixexp: <name>
                  str_checkname: 'i'
                  singlevar(kind): 'VLOCAL'
              explist1: end
            funcargs: end -- expr is a VCALL
          expr_stat: function call k='VCALL'
          -- STATEMENT: end 'expr'
          
          leaveblock
        block: end
        leaveblock
      fornum: end
    leaveblock
  for_stat: end
  -- STATEMENT: end 'for'
  
  close_func
-- TOP: end
