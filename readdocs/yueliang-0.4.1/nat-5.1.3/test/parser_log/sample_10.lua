-- START OF SOURCE --
repeat foo=foo.."bar" until false
repeat foo=foo/2 until foo<1
repeat break until false
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'repeat' line=1
  repeat_stat: begin
    enterblock(isbreakable=true)
      enterblock(isbreakable=false)
      chunk:
      -- STATEMENT: begin 'expr' line=1
      prefixexp: <name>
          str_checkname: 'foo'
          singlevar(kind): 'VGLOBAL'
      expr_stat: assignment k='VGLOBAL'
      assignment: '=' -- RHS elements follows
        explist1: begin
        expr:
        prefixexp: <name>
            str_checkname: 'foo'
            singlevar(kind): 'VGLOBAL'
          subexpr: binop='..'
          simpleexp: <string>=bar
              codestring: "bar"
          subexpr: -- evaluate
        explist1: end
      -- STATEMENT: end 'expr'
      
      repeat_stat: condition
        cond: begin
        expr:
        simpleexp: false
        cond: end
      leaveblock
    leaveblock
  repeat_stat: end
  -- STATEMENT: end 'repeat'
  
  -- STATEMENT: begin 'repeat' line=2
  repeat_stat: begin
    enterblock(isbreakable=true)
      enterblock(isbreakable=false)
      chunk:
      -- STATEMENT: begin 'expr' line=2
      prefixexp: <name>
          str_checkname: 'foo'
          singlevar(kind): 'VGLOBAL'
      expr_stat: assignment k='VGLOBAL'
      assignment: '=' -- RHS elements follows
        explist1: begin
        expr:
        prefixexp: <name>
            str_checkname: 'foo'
            singlevar(kind): 'VGLOBAL'
          subexpr: binop='/'
          simpleexp: <number>=2
          subexpr: -- evaluate
        explist1: end
      -- STATEMENT: end 'expr'
      
      repeat_stat: condition
        cond: begin
        expr:
        prefixexp: <name>
            str_checkname: 'foo'
            singlevar(kind): 'VGLOBAL'
          subexpr: binop='<'
          simpleexp: <number>=1
          subexpr: -- evaluate
        cond: end
      leaveblock
    leaveblock
  repeat_stat: end
  -- STATEMENT: end 'repeat'
  
  -- STATEMENT: begin 'repeat' line=3
  repeat_stat: begin
    enterblock(isbreakable=true)
      enterblock(isbreakable=false)
      chunk:
      -- STATEMENT: begin 'break' line=3
      break_stat: -- break out of loop
      -- STATEMENT: end 'break'
      repeat_stat: condition
        cond: begin
        expr:
        simpleexp: false
        cond: end
      leaveblock
    leaveblock
  repeat_stat: end
  -- STATEMENT: end 'repeat'
  
  close_func
-- TOP: end
