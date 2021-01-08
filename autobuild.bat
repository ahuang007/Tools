@echo off

set NotConfirmType=%1
if "%NotConfirmType%"=="-y"  goto Continue1
if "%NotConfirmType%"=="-Y"  goto Continue1
:Input
set /p input=Are you sure there is no uncommitted code in local ?(Y/N):
if "%input%"=="Y" goto Continue1
if "%input%"=="y" goto Continue1
if "%input%"=="N" goto End
if "%input%"=="n" goto End
goto Input
:Continue1

set Configuration=%2
if "%Configuration%"=="WinDebug"        goto Continue2
if "%Configuration%"=="WinRelease"      goto Continue2
if "%Configuration%"=="LinuxDebug"      goto Continue2
if "%Configuration%"=="LinuxRelease"    goto Continue2
set Configuration=LinuxRelease
:Continue2

set BuildType=%3
if "%BuildType%"=="build"   goto Continue3
if "%BuildType%"=="rebuild" goto Continue3
set BuildType=build
:Continue3

set Projects=       ^
BattleServer        ^
BattleServerMgr     ^
MatchServer         ^
ChargeServer        ^
ChatCenterServer    ^
ChatServer          ^
DBServer            ^
DispatcherServer    ^
FriendServer        ^
GameServer          ^
GMServer            ^
MainGMServer        ^
LocalPublicServer   ^
LoginServer         ^
LogServer           ^
RankServer          ^
TeamServer          ^
TransferServer

set CurDir=%~dp0
set SlnDir=%CurDir%..\

git fetch
git reset origin/head --hard

if exist %CurDir%out.log del /Q /F %CurDir%out.log

echo BuildAll StartTime %time%

for %%f in (%Projects%) do (
    call :BuildOneProj %%f
)

echo BuildAll StopTime %time%

goto End

set ErrorCode=0

:BuildOneProj
    echo %BuildType% %1 %Configuration% BeginTime %time%
    ::MSBuild %1 -t:build -p:Configuration=%Configuration%;Platform=x64 -nologo -nodeReuse:true -low:false
    devenv "%SlnDir%x-moba.sln" /%BuildType% "%Configuration%|x64" /project "%SlnDir%source\main\%1\%1.vcxproj" /Out "%CurDir%out.log"
    if %errorlevel% neq 0 set ErrorCode=%errorlevel%
    
    echo %BuildType% %1 %Configuration% EndTime %time%
goto:eof

:End
    
@pause

exit %ErrorCode%

