@echo off

setlocal enabledelayedexpansion

set BuildType=%1
set ServerType=%2
set PackType=%3
set Version=%4

::  ServerName          ServerType
set SERVER_LIST=            ^
    BattleServer        18  ^
    BattleServerMgr     17  ^
    MatchServer         16  ^
    ChargeServer        6   ^
    ChatCenterServer    14  ^
    ChatServer          15  ^
    DBServer            13  ^
    DispatcherServer    2   ^
    FriendServer        19  ^
    GameServer          12  ^
    GMServer            8   ^
    MainGMServer        7   ^
    LocalPublicServer   5   ^
    LoginServer         11  ^
    LogServer           9   ^
    RankServer          21  ^
    TeamServer          20  ^
    TransferServer      3

set ServerListLen=0
for %%f in (%SERVER_LIST%) do (
    set /a ServerListLen += 1
)
set /a ServerListLen /= 2

for /l %%i in (1 1 !ServerListLen!) do (
    set /a "ServerNameID=2*(%%i-1)+1"
    set /a "ServerTypeID=2*(%%i-1)+2"

    set id=0
    for %%x in (%SERVER_LIST%) do (
        set /a id += 1
        if "!id!"=="!ServerNameID!" (
            set SERVER_ARR[%%i].ServerName=%%x
        )
        if "!id!"=="!ServerTypeID!" (
            set SERVER_ARR[%%i].ServerType=%%x
        )
    )
)

if "%BuildType%"=="debug"   goto Continue1
if "%BuildType%"=="release" goto Continue1
echo "Usage: %0 [debug|release]"
echo     "debug  - deploy debug   server"
echo     "deploy - deploy release server"
exit 1
:Continue1

set ServerTypeCorrect=false
if "%ServerType%"=="all" (
    set ServerTypeCorrect=true
) else (
    for /l %%i in (1 1 %ServerListLen%) do (
        if "!SERVER_ARR[%%i].ServerName!" == "%ServerType%" (
            set ServerTypeCorrect=true
        )
    )
)

if "%ServerTypeCorrect%" == "false" (
    echo "Usage: %0 %1 [all|ServerName]"
    echo     "all        - deploy all server"
    echo     "ServerName - deploy one server"
    exit 2
)

if "%PackType%"=="all"      goto Continue3
if "%PackType%"=="bin"      goto Continue3
if "%PackType%"=="csv"      goto Continue3
if "%PackType%"=="config"   goto Continue3
if "%PackType%"=="bincsv"   goto Continue3
echo "Usage: %0 %1 %2 [all|bin|csv|config|bincsv]"
echo     "all    - pack all file"
echo     "bin    - pack binary file"
echo     "csv    - pack csv file"
echo     "config - pack config file"
echo     "bincsv - pack binary + csv file"
exit 3
:Continue3

if "%Version%" == "" (
    echo "Usage: %0 %1 %2 %3 [version]"
    exit 4
)

set CurDir=%~dp0
set SlnDir=%CurDir%..

set ServerIndex=0
set ServerName=""
set FileServerIP=192.168.1.10
set FileServerUser=dasheng
set FileServerPassword=123456
set FileServerHTTP=http://dasheng.x1.cc
set FIleServerDir=/home/dasheng/gohttpserver/share/

if "%ServerType%" == "all" (
    call :pack_all
) else (
    call :pack %ServerType%
)

call :gen_download_xml
call :upload_files

goto :END

:gen_download_xml
    cd "%CurDir%\%Version%"

    echo "<?xml version='1.0' encoding='utf-8'?>" >tmp.xml
    echo "<Config>" >>tmp.xml
    echo "    <ServiceDownList>" >>tmp.xml

    set DownloadList=""
    if "%ServerType%" == "all" (
        for /l %%i in (1 1 %ServerListLen%) do (
            set ServerName=!SERVER_ARR[%%i].ServerName!
            set ServerTypeId=!SERVER_ARR[%%i].ServerType%!
            set BinPath=%FileServerHTTP%/%Version%/!ServerName!.tar.gz
            set BinMD5=""

            set id=0
            for /f "delims=" %%i in ('certutil -hashfile !ServerName!.tar.gz MD5') do (
                set /a id += 1
                if "!id!" == "2" (
                    set BinMD5=%%i
                )
            )

            set DownloadLine="        <Service ServiceName='!ServerName!' ServiceType='!ServerTypeId!' Version='%Version%' BinPath='!BinPath!' BinMD5='!BinMD5!'/>"
            echo !DownloadLine! >>tmp.xml
        )
    ) else (
        set ServerName=""
        set ServerTypeId=1
        for /l %%i in (1 1 %ServerListLen%) do (
            if "!SERVER_ARR[%%i].ServerName!" == "%ServerType%" (
                set ServerName=!SERVER_ARR[%%i].ServerName!
                set ServerTypeId=!SERVER_ARR[%%i].ServerType!
            )
        )

        set BinPath=%FileServerHTTP%/%Version%/%ServerName%.tar.gz
        set BinMD5=""

        set id=0
        for /f "delims=" %%i in ('certutil -hashfile %ServerName%.tar.gz MD5') do (
            set /a id += 1
            if "!id!" == "2" (
                set BinMD5=%%i
            )
        )

        set DownloadList="        <Service ServiceName='%ServerName%' ServiceType='!ServerTypeId!' Version='%Version%' BinPath='!BinPath!' BinMD5='!BinMD5!'/>"
        echo !DownloadList! >>tmp.xml 
    )
    
    echo "    </ServiceDownList>" >>tmp.xml
    echo "</Config>" >>tmp.xml
    
    if exist download.xml (
        del /q download.xml
    )
    for /f "delims=" %%a in (tmp.xml) do (
        set a=%%a
        set a=!a:"=!
        echo !a! >>download.xml
    )
    del /q tmp.xml
goto:eof

:upload_files
    cd %CurDir%
    ssh %FileServerUser%@%FileServerIP% "cd %FIleServerDir% && rm -rf %Version%"
    WinSCP.exe /defaults scp://%FileServerUser%:%FileServerPassword%@%FileServerIP%:22%FIleServerDir% /upload %Version%
    rd /s /q "%Version%"
goto:eof

:pack
    set ServerName=%1
    set BinDir="%SlnDir%\bin\%BuildType%\bin\%ServerName%"
    set ConfigDir="%SlnDir%\bin\config\template\%ServerName%"
    set CSVDir="%SlnDir%\bin\csv\bin\%ServerName%"
    set PackrdDir="%CurDir%\%Version%\%ServerName%"

    md "%PackrdDir%"

    set IsCopyBin=false
    if "%PackType%" == "all" (
        set IsCopyBin=true
    )
    if "%PackType%" == "bin" (
        set IsCopyBin=true
    )
    if "%PackType%" == "bincsv" (
        set IsCopyBin=true
    )

    if "%IsCopyBin%" == "true" (
        if exist "%BinDir%" (
             xcopy /s "%BinDir%" "%PackrdDir%"
        )
    )

    set IsCopyCSV=false 
    if "%PackType%" == "all" (
        set IsCopyCSV=true
    )
    if "%PackType%" == "csv" (
        set IsCopyCSV=true
    )
    if "%PackType%" == "bincsv" (
        set IsCopyCSV=true
    )

    if "%IsCopyCSV%" == "true" (
        if exist "%CSVDir%" (
            xcopy /s "%CSVDir%" "%PackrdDir%"
        )
    )

    set IsCopyConfig=false
    if "%PackType%" == "all" (
        set IsCopyConfig=true
    )
    if "%PackType%" == "config" (
        set IsCopyConfig=true
    )

    if "%IsCopyConfig%" == "true" (
        if exist "%ConfigDir%" (
            xcopy /s "%ConfigDir%" "%PackrdDir%"
        )
    )

    cd "%PackrdDir%\.."
    7z a -ttar %ServerName%.tar "%PackrdDir%"
    7z a -tgzip %ServerName%.tar.gz ".\%ServerName%.tar"
    del "%ServerName%.tar"
    rd /s /q "%PackrdDir%"
goto:eof

:pack_all
    for /l %%i in (1 1 %ServerListLen%) do (
        set ServerName=!SERVER_ARR[%%i].ServerName!
        call :pack !ServerName!
    )
goto:eof

:END
