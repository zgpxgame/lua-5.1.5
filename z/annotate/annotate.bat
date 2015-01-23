@echo off

for /R src %%s in (*.h *.c) do ( 
	call annotations.bat %%s
) 