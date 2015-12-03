-- START OF SOURCE --
do
end
-- END OF SOURCE --

-- TOP: begin
  open_func
  
  chunk:
  -- STATEMENT: begin 'do' line=1
  do_stat: begin
  block: begin
    enterblock(isbreakable=false)
    chunk:
    leaveblock
  block: end
  do_stat: end
  -- STATEMENT: end 'do'
  
  close_func
-- TOP: end
