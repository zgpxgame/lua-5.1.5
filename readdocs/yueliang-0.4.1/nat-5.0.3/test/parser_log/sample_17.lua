-- START OF SOURCE --
foo = {}
foo = { 1,2,3; "foo"; }
foo = { bar=77, baz=88, }
foo = { ["bar"]=77, ["baz"]=88, }
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
    simpleexp: constructor
      constructor: begin
      constructor: end
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
    simpleexp: constructor
      constructor: begin
      listfield: expr
      expr:
      simpleexp: <number>=1
      listfield: expr
      expr:
      simpleexp: <number>=2
      listfield: expr
      expr:
      simpleexp: <number>=3
      listfield: expr
      expr:
      simpleexp: <string>=foo
          codestring: "foo"
      constructor: end
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
    simpleexp: constructor
      constructor: begin
      recfield: name
          checkname:
          str_checkname: 'bar'
          codestring: "bar"
      expr:
      simpleexp: <number>=77
      recfield: name
          checkname:
          str_checkname: 'baz'
          codestring: "baz"
      expr:
      simpleexp: <number>=88
      constructor: end
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
    simpleexp: constructor
      constructor: begin
      recfield: [ exp1 ]
        index: begin '['
        expr:
        simpleexp: <string>=bar
            codestring: "bar"
        index: end ']'
      expr:
      simpleexp: <number>=77
      recfield: [ exp1 ]
        index: begin '['
        expr:
        simpleexp: <string>=baz
            codestring: "baz"
        index: end ']'
      expr:
      simpleexp: <number>=88
      constructor: end
    explist1: end
  -- STATEMENT: end 'expr'
  
  close_func
-- TOP: end
