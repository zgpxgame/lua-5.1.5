-- START OF SOURCE --
foo()
foo{}
foo""
foo:bar()
foo=false
foo.bar=true
foo[true]=nil
foo,bar=1,"a"
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'expr' line=1
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar(kind): 'VGLOBAL'
  primaryexp: ( funcargs
    funcargs: begin '('
    funcargs: end -- expr is a VCALL
  expr_stat: function call k='VCALL'
  -- STATEMENT: end 'expr'
  
  -- STATEMENT: begin 'expr' line=2
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar(kind): 'VGLOBAL'
  primaryexp: { funcargs
    funcargs: begin '{'
      constructor: begin
      constructor: end
    funcargs: end -- expr is a VCALL
  expr_stat: function call k='VCALL'
  -- STATEMENT: end 'expr'
  
  -- STATEMENT: begin 'expr' line=3
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar(kind): 'VGLOBAL'
  primaryexp: <string> funcargs
    funcargs: begin <string>
        codestring: ""
    funcargs: end -- expr is a VCALL
  expr_stat: function call k='VCALL'
  -- STATEMENT: end 'expr'
  
  -- STATEMENT: begin 'expr' line=4
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar(kind): 'VGLOBAL'
  primaryexp: :<name> funcargs
      checkname:
      str_checkname: 'bar'
      codestring: "bar"
    funcargs: begin '('
    funcargs: end -- expr is a VCALL
  expr_stat: function call k='VCALL'
  -- STATEMENT: end 'expr'
  
  -- STATEMENT: begin 'expr' line=5
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar(kind): 'VGLOBAL'
  expr_stat: assignment k='VGLOBAL'
  assignment: '=' -- RHS elements follows
    explist1: begin
    expr:
    simpleexp: false
    explist1: end
  -- STATEMENT: end 'expr'
  
  -- STATEMENT: begin 'expr' line=6
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar(kind): 'VGLOBAL'
  primaryexp: '.' field
    field: operator=.
      checkname:
      str_checkname: 'bar'
      codestring: "bar"
  expr_stat: assignment k='VINDEXED'
  assignment: '=' -- RHS elements follows
    explist1: begin
    expr:
    simpleexp: true
    explist1: end
  -- STATEMENT: end 'expr'
  
  -- STATEMENT: begin 'expr' line=7
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar(kind): 'VGLOBAL'
  primaryexp: [ exp1 ]
    index: begin '['
    expr:
    simpleexp: true
    index: end ']'
  expr_stat: assignment k='VGLOBAL'
  assignment: '=' -- RHS elements follows
    explist1: begin
    expr:
    simpleexp: nil
    explist1: end
  -- STATEMENT: end 'expr'
  
  -- STATEMENT: begin 'expr' line=8
  prefixexp: <name>
      str_checkname: 'foo'
      singlevar(kind): 'VGLOBAL'
  expr_stat: assignment k='VGLOBAL'
  assignment: ',' -- next LHS element
  prefixexp: <name>
      str_checkname: 'bar'
      singlevar(kind): 'VGLOBAL'
  assignment: '=' -- RHS elements follows
    explist1: begin
    expr:
    simpleexp: <number>=1
    explist1: ',' -- continuation
    expr:
    simpleexp: <string>=a
        codestring: "a"
    explist1: end
  -- STATEMENT: end 'expr'
  
  close_func
-- TOP: end
