-- START OF SOURCE --
foo=true
foo=false
foo=nil
foo=1.23e45
foo=-1
foo=(0)
foo=1+2
foo=1+2*3-4/5
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'expr' line=1
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar: name='foo'
  expr_stat: assignment k='VLOCAL'
  assignment: '=' -- RHS elements follows
    explist1: begin
    expr:
    simpleexp: true
    explist1: end
  -- STATEMENT: end 'expr'
  
  -- STATEMENT: begin 'expr' line=2
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar: name='foo'
  expr_stat: assignment k='VLOCAL'
  assignment: '=' -- RHS elements follows
    explist1: begin
    expr:
    simpleexp: false
    explist1: end
  -- STATEMENT: end 'expr'
  
  -- STATEMENT: begin 'expr' line=3
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar: name='foo'
  expr_stat: assignment k='VLOCAL'
  assignment: '=' -- RHS elements follows
    explist1: begin
    expr:
    simpleexp: nil
    explist1: end
  -- STATEMENT: end 'expr'
  
  -- STATEMENT: begin 'expr' line=4
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar: name='foo'
  expr_stat: assignment k='VLOCAL'
  assignment: '=' -- RHS elements follows
    explist1: begin
    expr:
    simpleexp: <number>=1.23e+45
    explist1: end
  -- STATEMENT: end 'expr'
  
  -- STATEMENT: begin 'expr' line=5
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar: name='foo'
  expr_stat: assignment k='VLOCAL'
  assignment: '=' -- RHS elements follows
    explist1: begin
    expr:
      subexpr: uop='-'
    simpleexp: <number>=1
    explist1: end
  -- STATEMENT: end 'expr'
  
  -- STATEMENT: begin 'expr' line=6
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar: name='foo'
  expr_stat: assignment k='VLOCAL'
  assignment: '=' -- RHS elements follows
    explist1: begin
    expr:
      prefixexp: begin ( expr ) 
      expr:
      simpleexp: <number>=0
      prefixexp: end ( expr ) 
    explist1: end
  -- STATEMENT: end 'expr'
  
  -- STATEMENT: begin 'expr' line=7
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar: name='foo'
  expr_stat: assignment k='VLOCAL'
  assignment: '=' -- RHS elements follows
    explist1: begin
    expr:
    simpleexp: <number>=1
      subexpr: binop='+'
      simpleexp: <number>=2
      subexpr: -- evaluate
    explist1: end
  -- STATEMENT: end 'expr'
  
  -- STATEMENT: begin 'expr' line=8
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar: name='foo'
  expr_stat: assignment k='VLOCAL'
  assignment: '=' -- RHS elements follows
    explist1: begin
    expr:
    simpleexp: <number>=1
      subexpr: binop='+'
      simpleexp: <number>=2
        subexpr: binop='*'
        simpleexp: <number>=3
        subexpr: -- evaluate
      subexpr: -- evaluate
      subexpr: binop='-'
      simpleexp: <number>=4
        subexpr: binop='/'
        simpleexp: <number>=5
        subexpr: -- evaluate
      subexpr: -- evaluate
    explist1: end
  -- STATEMENT: end 'expr'
  
  close_func
-- TOP: end
