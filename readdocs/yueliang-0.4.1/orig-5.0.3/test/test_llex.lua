--[[--------------------------------------------------------------------

  test_llex.lua
  Test for llex.lua
  This file is part of Yueliang.

  Copyright (c) 2005-2006 Kein-Hong Man <khman@users.sf.net>
  The COPYRIGHT file describes the conditions
  under which this software may be distributed.

  See the ChangeLog for more information.

----------------------------------------------------------------------]]

------------------------------------------------------------------------
-- if BRIEF is not set to false, auto-test will silently succeed
------------------------------------------------------------------------
BRIEF = true  -- if set to true, messages are less verbose

require("../lzio")
require("../llex")
luaX:init()

------------------------------------------------------------------------
-- simple manual tests
------------------------------------------------------------------------

--[[
local L = {} -- LuaState
local LS = {} -- LexState

local function dump(z)
  luaX:setinput(L, LS, z, z.name)
  while true do
    LS.t.token = luaX:lex(LS, LS.t)
    local tok, seminfo = LS.t.token, LS.t.seminfo
    if tok == "TK_NAME" then
      seminfo = " "..seminfo
    elseif tok == "TK_NUMBER" then
      seminfo = " "..seminfo
    elseif tok == "TK_STRING" then
      seminfo = " '"..seminfo.."'"
    else
      seminfo = ""
    end
    io.stdout:write(tok..seminfo.."\n")
    if tok == "TK_EOS" then break end
  end
end

local function try_string(chunk)
  dump(luaZ:init(luaZ:make_getS(chunk), nil, "=string"))
end
local function try_file(filename)
  dump(luaZ:init(luaZ:make_getF(filename), nil, filename))
end

z = try_string("local c = luaZ:zgetc(z)")
z = try_file("test_lzio.lua")
z = try_file("test_llex.lua")
os.exit()
--]]

------------------------------------------------------------------------
-- auto-testing of simple test cases to validate lexer behaviour:
-- * NOTE coverage has not been checked; not comprehensive
-- * only test cases with non-empty comments are processed
-- * if no result, then the output is displayed for manual decision
--   (output may be used to set expected success or fail text)
-- * cases expected to be successful may be a partial match
-- * cases expected to fail may also be a partial match
------------------------------------------------------------------------

-- [[
local function auto_test()
  local PASS, FAIL = true, false
  ------------------------------------------------------------------
  -- table of test cases
  ------------------------------------------------------------------
  local test_cases =
  {
    -------------------------------------------------------------
  --{ "comment",  -- comment about the test
  --  "chunk",    -- chunk to test
  --  PASS,       -- PASS or FAIL outcome
  --  "output",   -- output to compare against
  --},
    -------------------------------------------------------------
    { "empty chunk string, test EOS",
      "",
      PASS, "1 TK_EOS",
    },
    -------------------------------------------------------------
    { "line number counting",
      "\n\n\r\n",
      PASS, "4 TK_EOS",
    },
    -------------------------------------------------------------
    { "various whitespaces",
      "  \n\t\t\n  \t  \t \n\n",
      PASS, "5 TK_EOS",
    },
    -------------------------------------------------------------
    { "short comment ending in EOS",
      "-- moo moo",
      PASS, "1 TK_EOS",
    },
    -------------------------------------------------------------
    { "short comment ending in newline",
      "-- moo moo\n",
      PASS, "2 TK_EOS",
    },
    -------------------------------------------------------------
    { "several lines of short comments",
      "--moo\n-- moo moo\n\n--\tmoo\n",
      PASS, "5 TK_EOS",
    },
    -------------------------------------------------------------
    { "basic block comment",
      "--[[bovine]]",
      PASS, "1 TK_EOS",
    },
    -------------------------------------------------------------
    { "unterminated block comment 1",
      "--[[bovine",
      FAIL, ":1: unfinished long comment near `<eof>'",
    },
    -------------------------------------------------------------
    { "unterminated block comment 2",
      "--[[bovine]",
      FAIL, ":1: unfinished long comment near `<eof>'",
    },
    -------------------------------------------------------------
    { "unterminated block comment 3",
      "--[[bovine\nmoo moo\nwoof",
      FAIL, ":3: unfinished long comment near `<eof>'",
    },
    -------------------------------------------------------------
    { "basic long string",
      "\n[[bovine]]\n",
      PASS, "2 TK_STRING = bovine\n3 TK_EOS",
    },
    -------------------------------------------------------------
    { "first newline consumed in long string",
      "[[\nmoo]]",
      PASS, "2 TK_STRING = moo\n2 TK_EOS",
    },
    -------------------------------------------------------------
    { "multiline long string",
      "[[moo\nmoo moo\n]]",
      PASS, "3 TK_STRING = moo\nmoo moo\n\n3 TK_EOS",
    },
    -------------------------------------------------------------
    { "unterminated long string 1",
      "\n[[\nbovine",
      FAIL, ":3: unfinished long string near `<eof>'",
    },
    -------------------------------------------------------------
    { "unterminated long string 2",
      "[[bovine]",
      FAIL, ":1: unfinished long string near `<eof>'",
    },
    -------------------------------------------------------------
    { "unterminated long string 3",
      "[[[[ \n",
      FAIL, ":2: unfinished long string near `<eof>'",
    },
    -------------------------------------------------------------
    { "nested long string 1",
      "[[moo[[moo]]moo]]",
      PASS, "moo[[moo]]moo",
    },
    -------------------------------------------------------------
    { "nested long string 2",
      "[[moo[[moo[[[[]]]]moo]]moo]]",
      PASS, "moo[[moo[[[[]]]]moo]]moo",
    },
    -------------------------------------------------------------
    { "nested long string 3",
      "[[[[[[]]]][[[[]]]]]]",
      PASS, "[[[[]]]][[[[]]]]",
    },
    -------------------------------------------------------------
    { "brackets in long strings 1",
      "[[moo[moo]]",
      PASS, "moo[moo",
    },
    -------------------------------------------------------------
    { "brackets in long strings 2",
      "[[moo[[moo]moo]]moo]]",
      PASS, "moo[[moo]moo]]moo",
    },
    -------------------------------------------------------------
    { "unprocessed escapes in long strings",
      [[ [[\a\b\f\n\r\t\v\123]] ]],
      PASS, [[\a\b\f\n\r\t\v\123]],
    },
    -------------------------------------------------------------
    { "unbalanced long string",
      "[[moo]]moo]]",
      PASS, "1 TK_STRING = moo\n1 TK_NAME = moo\n1 CHAR = ']'\n1 CHAR = ']'\n1 TK_EOS",
    },
    -------------------------------------------------------------
    { "keywords 1",
      "and break do else",
      PASS, "1 TK_AND\n1 TK_BREAK\n1 TK_DO\n1 TK_ELSE\n1 TK_EOS",
    },
    -------------------------------------------------------------
    { "keywords 2",
      "elseif end false for",
      PASS, "1 TK_ELSEIF\n1 TK_END\n1 TK_FALSE\n1 TK_FOR\n1 TK_EOS",
    },
    -------------------------------------------------------------
    { "keywords 3",
      "function if in local nil",
      PASS, "1 TK_FUNCTION\n1 TK_IF\n1 TK_IN\n1 TK_LOCAL\n1 TK_NIL\n1 TK_EOS",
    },
    -------------------------------------------------------------
    { "keywords 4",
      "not or repeat return",
      PASS, "1 TK_NOT\n1 TK_OR\n1 TK_REPEAT\n1 TK_RETURN\n1 TK_EOS",
    },
    -------------------------------------------------------------
    { "keywords 5",
      "then true until while",
      PASS, "1 TK_THEN\n1 TK_TRUE\n1 TK_UNTIL\n1 TK_WHILE\n1 TK_EOS",
    },
    -------------------------------------------------------------
    { "concat and dots",
      ".. ...",
      PASS, "1 TK_CONCAT\n1 TK_DOTS\n1 TK_EOS",
    },
    -------------------------------------------------------------
    { "shbang handling 1",
      "#blahblah",
      PASS, "1 TK_EOS",
    },
    -------------------------------------------------------------
    { "shbang handling 2",
      "#blahblah\nmoo moo\n",
      PASS, "2 TK_NAME = moo\n2 TK_NAME = moo\n3 TK_EOS",
    },
    -------------------------------------------------------------
    { "empty string",
      [['']],
      PASS, "1 TK_STRING = \n1 TK_EOS",
    },
    -------------------------------------------------------------
    { "single-quoted string",
      [['bovine']],
      PASS, "1 TK_STRING = bovine\n1 TK_EOS",
    },
    -------------------------------------------------------------
    { "double-quoted string",
      [["bovine"]],
      PASS, "1 TK_STRING = bovine\n1 TK_EOS",
    },
    -------------------------------------------------------------
    { "unterminated string 1",
      [['moo ]],
      FAIL, ":1: unfinished string near `<eof>'",
    },
    -------------------------------------------------------------
    { "unterminated string 2",
      [["moo \n]],
      FAIL, ":1: unfinished string near `<eof>'",
    },
    -------------------------------------------------------------
    { "escaped newline in string, line number counted",
      "\"moo\\\nmoo\\\nmoo\"",
      PASS, "3 TK_STRING = moo\nmoo\nmoo\n3 TK_EOS",
    },
    -------------------------------------------------------------
    { "escaped characters in string 1",
      [["moo\amoo"]],
      PASS, "1 TK_STRING = moo\amoo",
    },
    -------------------------------------------------------------
    { "escaped characters in string 2",
      [["moo\bmoo"]],
      PASS, "1 TK_STRING = moo\bmoo",
    },
    -------------------------------------------------------------
    { "escaped characters in string 3",
      [["moo\f\n\r\t\vmoo"]],
      PASS, "1 TK_STRING = moo\f\n\r\t\vmoo",
    },
    -------------------------------------------------------------
    { "escaped characters in string 4",
      [["\\ \" \' \? \[ \]"]],
      PASS, "1 TK_STRING = \\ \" \' \? \[ \]",
    },
    -------------------------------------------------------------
    { "escaped characters in string 5",
      [["\z \k \: \;"]],
      PASS, "1 TK_STRING = z k : ;",
    },
    -------------------------------------------------------------
    { "escaped characters in string 6",
      [["\8 \65 \160 \180K \097097"]],
      PASS, "1 TK_STRING = \8 \65 \160 \180K \097097\n",
    },
    -------------------------------------------------------------
    { "escaped characters in string 7",
      [["\666"]],
      FAIL, ":1: escape sequence too large near `\"'",
    },
    -------------------------------------------------------------
    { "simple numbers",
      "123 123+",
      PASS, "1 TK_NUMBER = 123\n1 TK_NUMBER = 123\n1 CHAR = '+'\n1 TK_EOS",
    },
    -------------------------------------------------------------
    { "longer numbers",
      "1234567890 12345678901234567890",
      PASS, "1 TK_NUMBER = 1234567890\n1 TK_NUMBER = 1.2345678901235e+19\n",
    },
    -------------------------------------------------------------
    { "fractional numbers",
      ".123 .12345678901234567890",
      PASS, "1 TK_NUMBER = 0.123\n1 TK_NUMBER = 0.12345678901235\n",
    },
    -------------------------------------------------------------
    { "more numbers with decimal points",
      "12345.67890 1.1.",
      PASS, "1 TK_NUMBER = 12345.6789\n1 TK_NUMBER = 1.1\n1 CHAR = '.'\n",
    },
    -------------------------------------------------------------
    { "double decimal points",
      ".1.1",
      FAIL, ":1: malformed number near `.1.1'",
    },
    -------------------------------------------------------------
    { "double dots within numbers",
      "1..1",
      FAIL, ":1: ambiguous syntax (decimal point x string concatenation) near `1..'",
    },
    -------------------------------------------------------------
    { "incomplete exponential numbers",
      "123e",
      FAIL, ":1: malformed number near `123e'",
    },
    -------------------------------------------------------------
    { "exponential numbers 1",
      "1234e5 1234e5.",
      PASS, "1 TK_NUMBER = 123400000\n1 TK_NUMBER = 123400000\n1 CHAR = '.'",
    },
    -------------------------------------------------------------
    { "exponential numbers 2",
      "1234e56 1.23e123",
      PASS, "1 TK_NUMBER = 1.234e+59\n1 TK_NUMBER = 1.23e+123\n",
    },
    -------------------------------------------------------------
    { "exponential numbers 3",
      "12.34e+",
      FAIL, ":1: malformed number near `12.34e+'",
    },
    -------------------------------------------------------------
    { "exponential numbers 4",
      "12.34e+5 123.4e-5 1234.E+5",
      PASS, "1 TK_NUMBER = 1234000\n1 TK_NUMBER = 0.001234\n1 TK_NUMBER = 123400000\n",
    },
    -------------------------------------------------------------
    { "single character symbols 1",
      "= > < ~",
      PASS, "1 CHAR = '='\n1 CHAR = '>'\n1 CHAR = '<'\n1 CHAR = '~'\n",
    },
    -------------------------------------------------------------
    { "double character symbols",
      "== >= <= ~=",
      PASS, "1 TK_EQ\n1 TK_GE\n1 TK_LE\n1 TK_NE\n",
    },
    -------------------------------------------------------------
    { "simple identifiers",
      "abc ABC",
      PASS, "1 TK_NAME = abc\n1 TK_NAME = ABC\n1 TK_EOS",
    },
    -------------------------------------------------------------
    { "more identifiers",
      "_abc _ABC",
      PASS, "1 TK_NAME = _abc\n1 TK_NAME = _ABC\n1 TK_EOS",
    },
    -------------------------------------------------------------
    { "still more identifiers",
      "_aB_ _123",
      PASS, "1 TK_NAME = _aB_\n1 TK_NAME = _123\n1 TK_EOS",
    },
    -------------------------------------------------------------
    { "invalid control character",
      "\4",
      FAIL, ":1: invalid control char near `char(4)'",
    },
    -------------------------------------------------------------
    { "single character symbols 2",
      "` ! @ $ %",
      PASS, "1 CHAR = '`'\n1 CHAR = '!'\n1 CHAR = '@'\n1 CHAR = '$'\n1 CHAR = '%'\n",
    },
    -------------------------------------------------------------
    { "single character symbols 3",
      "^ & * ( )",
      PASS, "1 CHAR = '^'\n1 CHAR = '&'\n1 CHAR = '*'\n1 CHAR = '('\n1 CHAR = ')'\n",
    },
    -------------------------------------------------------------
    { "single character symbols 4",
      "_ - + \\ |",
      PASS, "1 TK_NAME = _\n1 CHAR = '-'\n1 CHAR = '+'\n1 CHAR = '\\'\n1 CHAR = '|'\n",
    },
    -------------------------------------------------------------
    { "single character symbols 5",
      "{ } [ ] :",
      PASS, "1 CHAR = '{'\n1 CHAR = '}'\n1 CHAR = '['\n1 CHAR = ']'\n1 CHAR = ':'\n",
    },
    -------------------------------------------------------------
    { "single character symbols 6",
      "; , . / ?",
      PASS, "1 CHAR = ';'\n1 CHAR = ','\n1 CHAR = '.'\n1 CHAR = '/'\n1 CHAR = '?'\n",
    },
    -------------------------------------------------------------
  }
  ------------------------------------------------------------------
  -- perform a test case
  ------------------------------------------------------------------
  function do_test_case(count, test_case)
    if comment == "" then return end  -- skip empty entries
    local comment, chunk, outcome, matcher = unpack(test_case)
    local result = PASS
    local output = ""
    -- initialize lexer
    local L, LS  = {}, {}
    local z = luaZ:init(luaZ:make_getS(chunk), nil, "=test")
    luaX:setinput(L, LS, z, z.name)
    -- lexer test loop
    repeat
      -- protected call
      local status, token = pcall(luaX.lex, luaX, LS, LS.t)
      LS.t.token = token
      output = output..LS.linenumber.." "
      if status then
        -- successful call
        if string.len(token) > 1 then
          if token == "TK_NAME"
             or token == "TK_NUMBER"
             or token == "TK_STRING" then
            token = token.." = "..LS.t.seminfo
          end
        elseif string.byte(token) >= 32 then  -- displayable chars
          token = "CHAR = '"..token.."'"
        else  -- control characters
          token = "CHAR = (".. string.byte(token)..")"
        end
        output = output..token.."\n"
      else
        -- failed call
        output = output..token  -- token is the error message
        result = FAIL
        break
      end
    until LS.t.token == "TK_EOS"
    -- decision making and reporting
    local head = "Test "..count..": "..comment
    if matcher == "" then
      -- nothing to check against, display for manual check
      print(head.."\nMANUAL please check manually"..
            "\n--chunk---------------------------------\n"..chunk..
            "\n--actual--------------------------------\n"..output..
            "\n\n")
      return
    else
      if outcome == PASS then
        -- success expected, may be a partial match
        if string.find(output, matcher, 1, 1) and result == PASS then
          if not BRIEF then print(head.."\nOK expected success\n") end
          return
        end
      else
        -- failure expected, may be a partial match
        if string.find(output, matcher, 1, 1) and result == FAIL then
          if not BRIEF then print(head.."\nOK expected failure\n") end
          return
        end
      end
      -- failed because of unmatched string or boolean result
      local function passfail(status)
        if status == PASS then return "PASS" else return "FAIL" end
      end
      print(head.." *FAILED*"..
            "\noutcome="..passfail(outcome)..
            "\nactual= "..passfail(result)..
            "\n--chunk---------------------------------\n"..chunk..
            "\n--expected------------------------------\n"..matcher..
            "\n--actual--------------------------------\n"..output..
            "\n\n")
    end
  end
  ------------------------------------------------------------------
  -- perform auto testing
  ------------------------------------------------------------------
  for i,test_case in ipairs(test_cases) do
    do_test_case(i, test_case)
  end
end

auto_test()
--]]
