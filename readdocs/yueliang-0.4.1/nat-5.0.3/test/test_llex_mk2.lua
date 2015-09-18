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

local zio_init = require("../lzio_mk2")
local lex_init = require("../llex_mk2")

------------------------------------------------------------------------
-- simple manual tests
------------------------------------------------------------------------

--[[
local function dump(z, source)
  local luaX = lex_init(z, source)
  while true do
    local tok, seminfo = luaX:lex()
    if tok == "<name>" then
      seminfo = " "..seminfo
    elseif tok == "<number>" then
      seminfo = " "..seminfo
    elseif tok == "<string>" then
      seminfo = " '"..seminfo.."'"
    else
      seminfo = ""
    end
    io.stdout:write(tok..seminfo.."\n")
    if tok == "<eof>" then break end
  end
end

local function try_string(chunk)
  dump(zio_init(chunk), "=string")
end
local function try_file(filename)
  local f = "@"..filename
  dump(zio_init(f), f)
end

z = try_string("local c = z:getc()")
z = try_file("test_lzio_mk2.lua")
z = try_file("test_llex_mk2.lua")
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
      PASS, "1 <eof>",
    },
    -------------------------------------------------------------
    { "line number counting",
      "\n\n\r\n",
      PASS, "4 <eof>",
    },
    -------------------------------------------------------------
    { "various whitespaces",
      "  \n\t\t\n  \t  \t \n\n",
      PASS, "5 <eof>",
    },
    -------------------------------------------------------------
    { "short comment ending in EOS",
      "-- moo moo",
      PASS, "1 <eof>",
    },
    -------------------------------------------------------------
    { "short comment ending in newline",
      "-- moo moo\n",
      PASS, "2 <eof>",
    },
    -------------------------------------------------------------
    { "several lines of short comments",
      "--moo\n-- moo moo\n\n--\tmoo\n",
      PASS, "5 <eof>",
    },
    -------------------------------------------------------------
    { "basic block comment",
      "--[[bovine]]",
      PASS, "1 <eof>",
    },
    -------------------------------------------------------------
    { "unterminated block comment 1",
      "--[[bovine",
      FAIL, ":1: unfinished long comment near '<eof>'",
    },
    -------------------------------------------------------------
    { "unterminated block comment 2",
      "--[[bovine]",
      FAIL, ":1: unfinished long comment near '<eof>'",
    },
    -------------------------------------------------------------
    { "unterminated block comment 3",
      "--[[bovine\nmoo moo\nwoof",
      FAIL, ":3: unfinished long comment near '<eof>'",
    },
    -------------------------------------------------------------
    { "basic long string",
      "\n[[bovine]]\n",
      PASS, "2 <string> = bovine\n3 <eof>",
    },
    -------------------------------------------------------------
    { "first newline consumed in long string",
      "[[\nmoo]]",
      PASS, "2 <string> = moo\n2 <eof>",
    },
    -------------------------------------------------------------
    { "multiline long string",
      "[[moo\nmoo moo\n]]",
      PASS, "3 <string> = moo\nmoo moo\n\n3 <eof>",
    },
    -------------------------------------------------------------
    { "unterminated long string 1",
      "\n[[\nbovine",
      FAIL, ":3: unfinished long string near '<eof>'",
    },
    -------------------------------------------------------------
    { "unterminated long string 2",
      "[[bovine]",
      FAIL, ":1: unfinished long string near '<eof>'",
    },
    -------------------------------------------------------------
    { "unterminated long string 3",
      "[[[[ \n",
      FAIL, ":2: unfinished long string near '<eof>'",
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
      PASS, "1 <string> = moo\n1 <name> = moo\n1 CHAR = ']'\n1 CHAR = ']'\n1 <eof>",
    },
    -------------------------------------------------------------
    { "keywords 1",
      "and break do else",
      PASS, "1 and\n1 break\n1 do\n1 else\n1 <eof>",
    },
    -------------------------------------------------------------
    { "keywords 2",
      "elseif end false for",
      PASS, "1 elseif\n1 end\n1 false\n1 for\n1 <eof>",
    },
    -------------------------------------------------------------
    { "keywords 3",
      "function if in local nil",
      PASS, "1 function\n1 if\n1 in\n1 local\n1 nil\n1 <eof>",
    },
    -------------------------------------------------------------
    { "keywords 4",
      "not or repeat return",
      PASS, "1 not\n1 or\n1 repeat\n1 return\n1 <eof>",
    },
    -------------------------------------------------------------
    { "keywords 5",
      "then true until while",
      PASS, "1 then\n1 true\n1 until\n1 while\n1 <eof>",
    },
    -------------------------------------------------------------
    { "concat and dots",
      ".. ...",
      PASS, "1 ..\n1 ...\n1 <eof>",
    },
    -------------------------------------------------------------
    { "shbang handling 1",
      "#blahblah",
      PASS, "1 <eof>",
    },
    -------------------------------------------------------------
    { "shbang handling 2",
      "#blahblah\nmoo moo\n",
      PASS, "2 <name> = moo\n2 <name> = moo\n3 <eof>",
    },
    -------------------------------------------------------------
    { "empty string",
      [['']],
      PASS, "1 <string> = \n1 <eof>",
    },
    -------------------------------------------------------------
    { "single-quoted string",
      [['bovine']],
      PASS, "1 <string> = bovine\n1 <eof>",
    },
    -------------------------------------------------------------
    { "double-quoted string",
      [["bovine"]],
      PASS, "1 <string> = bovine\n1 <eof>",
    },
    -------------------------------------------------------------
    { "unterminated string 1",
      [['moo ]],
      FAIL, ":1: unfinished string near '<eof>'",
    },
    -------------------------------------------------------------
    { "unterminated string 2",
      [["moo \n]],
      FAIL, ":1: unfinished string near '<eof>'",
    },
    -------------------------------------------------------------
    { "escaped newline in string, line number counted",
      "\"moo\\\nmoo\\\nmoo\"",
      PASS, "3 <string> = moo\nmoo\nmoo\n3 <eof>",
    },
    -------------------------------------------------------------
    { "escaped characters in string 1",
      [["moo\amoo"]],
      PASS, "1 <string> = moo\amoo",
    },
    -------------------------------------------------------------
    { "escaped characters in string 2",
      [["moo\bmoo"]],
      PASS, "1 <string> = moo\bmoo",
    },
    -------------------------------------------------------------
    { "escaped characters in string 3",
      [["moo\f\n\r\t\vmoo"]],
      PASS, "1 <string> = moo\f\n\r\t\vmoo",
    },
    -------------------------------------------------------------
    { "escaped characters in string 4",
      [["\\ \" \' \? \[ \]"]],
      PASS, "1 <string> = \\ \" \' \? \[ \]",
    },
    -------------------------------------------------------------
    { "escaped characters in string 5",
      [["\z \k \: \;"]],
      PASS, "1 <string> = z k : ;",
    },
    -------------------------------------------------------------
    { "escaped characters in string 6",
      [["\8 \65 \160 \180K \097097"]],
      PASS, "1 <string> = \8 \65 \160 \180K \097097\n",
    },
    -------------------------------------------------------------
    { "escaped characters in string 7",
      [["\666"]],
      FAIL, ":1: escape sequence too large near '\"'",
    },
    -------------------------------------------------------------
    { "simple numbers",
      "123 123+",
      PASS, "1 <number> = 123\n1 <number> = 123\n1 CHAR = '+'\n1 <eof>",
    },
    -------------------------------------------------------------
    { "longer numbers",
      "1234567890 12345678901234567890",
      PASS, "1 <number> = 1234567890\n1 <number> = 1.2345678901235e+19\n",
    },
    -------------------------------------------------------------
    { "fractional numbers",
      ".123 .12345678901234567890",
      PASS, "1 <number> = 0.123\n1 <number> = 0.12345678901235\n",
    },
    -------------------------------------------------------------
    { "more numbers with decimal points",
      "12345.67890 1.1.",
      PASS, "1 <number> = 12345.6789\n1 <number> = 1.1\n1 CHAR = '.'\n",
    },
    -------------------------------------------------------------
    { "double decimal points",
      ".1.1",
      FAIL, ":1: malformed number near '.1.1'",
    },
    -------------------------------------------------------------
    { "double dots within numbers",
      "1..1",
      FAIL, ":1: ambiguous syntax (dots follows digits) near '1..'",
    },
    -------------------------------------------------------------
    { "incomplete exponential numbers",
      "123e",
      FAIL, ":1: malformed number near '123e'",
    },
    -------------------------------------------------------------
    { "exponential numbers 1",
      "1234e5 1234e5.",
      PASS, "1 <number> = 123400000\n1 <number> = 123400000\n1 CHAR = '.'",
    },
    -------------------------------------------------------------
    { "exponential numbers 2",
      "1234e56 1.23e123",
      PASS, "1 <number> = 1.234e+59\n1 <number> = 1.23e+123\n",
    },
    -------------------------------------------------------------
    { "exponential numbers 3",
      "12.34e+",
      FAIL, ":1: malformed number near '12.34e+'",
    },
    -------------------------------------------------------------
    { "exponential numbers 4",
      "12.34e+5 123.4e-5 1234.E+5",
      PASS, "1 <number> = 1234000\n1 <number> = 0.001234\n1 <number> = 123400000\n",
    },
    -------------------------------------------------------------
    { "single character symbols 1",
      "= > < ~",
      PASS, "1 CHAR = '='\n1 CHAR = '>'\n1 CHAR = '<'\n1 CHAR = '~'\n",
    },
    -------------------------------------------------------------
    { "double character symbols",
      "== >= <= ~=",
      PASS, "1 ==\n1 >=\n1 <=\n1 ~=\n",
    },
    -------------------------------------------------------------
    { "simple identifiers",
      "abc ABC",
      PASS, "1 <name> = abc\n1 <name> = ABC\n1 <eof>",
    },
    -------------------------------------------------------------
    { "more identifiers",
      "_abc _ABC",
      PASS, "1 <name> = _abc\n1 <name> = _ABC\n1 <eof>",
    },
    -------------------------------------------------------------
    { "still more identifiers",
      "_aB_ _123",
      PASS, "1 <name> = _aB_\n1 <name> = _123\n1 <eof>",
    },
    -------------------------------------------------------------
    { "invalid control character",
      "\4",
      FAIL, ":1: invalid control char near 'char(4)'",
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
      PASS, "1 <name> = _\n1 CHAR = '-'\n1 CHAR = '+'\n1 CHAR = '\\'\n1 CHAR = '|'\n",
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
    local z = zio_init(chunk)
    local luaX = lex_init(z, "=test")
    -- lexer test loop
    local status, token, seminfo
    repeat
      -- protected call
      status, token, seminfo = pcall(luaX.lex, luaX)
      output = output..luaX.lineno.." "
      if status then
        -- successful call
        if string.len(token) > 1 then
          if token == "<name>"
             or token == "<number>"
             or token == "<string>" then
            token = token.." = "..seminfo
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
    until token == "<eof>"
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
