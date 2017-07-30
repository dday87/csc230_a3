echo off
rem build_and_upload.bat
rem
rem This batch file (the windows equivalent of a shell script) assembles and uploads
rem an AVR .asm file. You may need to change the paths to the avrasm2.exe and avrdude.exe
rem programs, as well as the PORT variable (which may be any value from COM1 - COM6 depending
rem on your machine).
rem
rem B. Bird - 05/18/2017

set PORT=COM4
set INPUTFILE=%1
for /F %%i in ("%INPUTFILE%") do set DRIVE=%%~di 
for /F %%i in ("%INPUTFILE%") do set DRIVEPATH=%%~pi 
for /F %%i in ("%INPUTFILE%") do set HEXFILENAME=%%~ni.hex
for /F %%i in ("%INPUTFILE%") do set ASMFILENAME=%%~ni%%~xi
%DRIVE%
cd %DRIVEPATH%
"C:\Program Files (x86)\Atmel\AVR Tools\AvrAssembler2\avrasm2.exe" -fI -o %HEXFILENAME% %ASMFILENAME%
"C:\Program Files (x86)\Arduino\hardware\tools\avr\bin\avrdude.exe" -C "C:\Program Files (x86)\Arduino\hardware\tools\avr\etc\avrdude.conf" -p atmega2560 -c wiring -P %PORT% -b 115200 -D -F -U flash:w:%HEXFILENAME%


rem If you want the window to close automatically, add "rem " before the following line
pause