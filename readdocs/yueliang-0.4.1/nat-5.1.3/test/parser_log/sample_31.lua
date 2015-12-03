-- START OF SOURCE --
  for foo in bar() do
    print(foo)
  end
  for foo,bar,baz in spring() do
    print(foo,bar,baz)
  end
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'for' line=1
  for_stat: begin
    enterblock(isbreakable=true)
        str_checkname: 'foo'
    for_stat: list-based loop
      forlist: begin
          new_localvar: '(for generator)'
          new_localvar: '(for state)'
          new_localvar: '(for control)'
          new_localvar: 'foo'
      forlist: explist1
        explist1: begin
        expr:
        prefixexp: <name>
            str_checkname: 'bar'
            singlevar(kind): 'VGLOBAL'
        primaryexp: ( funcargs
          funcargs: begin '('
          funcargs: end -- expr is a VCALL
        explist1: end
      forlist: body
        enterblock(isbreakable=false)
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
                  str_checkname: 'foo'
                  singlevar(kind): 'VLOCAL'
              explist1: end
            funcargs: end -- expr is a VCALL
          expr_stat: function call k='VCALL'
          -- STATEMENT: end 'expr'
          
          leaveblock
        block: end
        leaveblock
      forlist: end
    leaveblock
  for_stat: end
  -- STATEMENT: end 'for'
  
  -- STATEMENT: begin 'for' line=4
  for_stat: begin
    enterblock(isbreakable=true)
        str_checkname: 'foo'
    for_stat: list-based loop
      forlist: begin
          new_localvar: '(for generator)'
          new_localvar: '(for state)'
          new_localvar: '(for control)'
          new_localvar: 'foo'
          str_checkname: 'bar'
          new_localvar: 'bar'
          str_checkname: 'baz'
          new_localvar: 'baz'
      forlist: explist1
        explist1: begin
        expr:
        prefixexp: <name>
            str_checkname: 'spring'
            singlevar(kind): 'VGLOBAL'
        primaryexp: ( funcargs
          funcargs: begin '('
          funcargs: end -- expr is a VCALL
        explist1: end
      forlist: body
        enterblock(isbreakable=false)
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
                  str_checkname: 'foo'
                  singlevar(kind): 'VLOCAL'
              explist1: ',' -- continuation
              expr:
              prefixexp: <name>
                  str_checkname: 'bar'
                  singlevar(kind): 'VLOCAL'
              explist1: ',' -- continuation
              expr:
              prefixexp: <name>
                  str_checkname: 'baz'
                  singlevar(kind): 'VLOCAL'
              explist1: end
            funcargs: end -- expr is a VCALL
          expr_stat: function call k='VCALL'
          -- STATEMENT: end 'expr'
          
          leaveblock
        block: end
        leaveblock
      forlist: end
    leaveblock
  for_stat: end
  -- STATEMENT: end 'for'
  
  close_func
-- TOP: end
