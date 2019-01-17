:: Set up VS MSVC environment when running MSVC build mono-sgen.exe with all supplied arguments.
:: Simplify the setup of VS and MSVC toolchain, when running Mono AOT compiler
:: since it need to locate correct compiler and OS libraries as well as clang.exe and linker.exe
:: from VS setup for the corresponding architecture.

@echo off

setlocal

:: NOTE, MSVC build mono-sgen.exe AOT compiler currently support 64-bit AMD codegen. Below will only setup
:: amd64 versions of VS MSVC build environment and corresponding ClangC2 compiler.

set VS_2015_VCVARS_ARCH=amd64\vcvars64.bat
set VS_2015_CLANGC2_ARCH=amd64
set VS_2017_VCVARS_ARCH=vcvars64.bat
set VS_2017_CLANGC2_ARCH=HostX64

:: 32-bit AOT toolchains for MSVC build mono-sgen.exe is currently not supported.
:: set VS_2015_VCVARS_ARCH=vcvars32.bat
:: set VS_2015_CLANGC2_ARCH=x86
:: set VS_2017_VCVARS_ARCH=vcvars32.bat
:: set VS_2017_CLANGC2_ARCH=HostX86

set EXECUTE_RESULT=1
set MONO_AS_AOT_COMPILER=0
set VS_CLANGC2_TOOLS_BIN_PATH=

:: Optimization, check if we need to setup full build environment, only needed when running mono-sgen.exe as AOT compiler.
echo.%* | findstr /c:"--aot=" > nul && (
    set MONO_AS_AOT_COMPILER=1
)

if %MONO_AS_AOT_COMPILER% == 1 (
    goto SETUP_VS_ENV
)

:: mono-sgen.exe not invoked as a AOT compiler, no need to setup full build environment.
goto ON_EXECUTE

:: Try setting up VS MSVC build environment.
:SETUP_VS_ENV

:: Optimization, check if we have something that looks like a MSVC build environment already available.
if /i not "%VCINSTALLDIR%" == "" (
    if /i not "%INCLUDE%" == "" (
        if /i not "%LIB%" == "" (
            goto ON_EXECUTE
        )
    )
) 

:: Visual Studio 2015 == 14.0
if "%VisualStudioVersion%" == "14.0" (
    goto SETUP_VS_2015
)

:: Visual Studio 2017 == 15.0
if "%VisualStudioVersion%" == "15.0" (
    goto SETUP_VS_2017
)

:SETUP_VS_2015

set VS_2015_VCINSTALL_DIR=%ProgramFiles(x86)%\Microsoft Visual Studio 14.0\VC\
set VS_2015_DEV_CMD_PROMPT=%VS_2015_VCINSTALL_DIR%bin\%VS_2015_VCVARS_ARCH%
SET VS_2015_CLANGC2_TOOLS_BIN_PATH=%VS_2015_VCINSTALL_DIR%ClangC2\bin\%VS_2015_CLANGC2_ARCH%\
SET VS_2015_CLANGC2_TOOLS_BIN=%VS_2015_CLANGC2_TOOLS_BIN_PATH%clang.exe

if not exist "%VS_2015_CLANGC2_TOOLS_BIN%" (
    echo Could not find "%VS_2015_CLANGC2_TOOLS_BIN%", trying VS2017 build environment.
    goto SETUP_VS_2017
)

if not exist "%VS_2015_DEV_CMD_PROMPT%" (
    echo Could not find "%VS_2015_DEV_CMD_PROMPT%", trying VS2017 build environment.
    goto SETUP_VS_2017
)

call "%VS_2015_DEV_CMD_PROMPT%" > NUL && (
    set "VS_CLANGC2_TOOLS_BIN_PATH=%VS_2015_CLANGC2_TOOLS_BIN_PATH%"
    goto ON_EXECUTE
) || (
    echo Failed executing "%VS_2015_DEV_CMD_PROMPT%", trying VS2017 build environment.
)

:SETUP_VS_2017

set VSWHERE_TOOLS_BIN=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe
set VS_2017_VCINSTALL_DIR=
set VS_2017_DEV_CMD_PROMPT=

if exist "%VSWHERE_TOOLS_BIN%" (
    for /f "tokens=*" %%a in ('"%VSWHERE_TOOLS_BIN%" -latest -property installationPath') do (
        set VS_2017_VCINSTALL_DIR=%%a\VC\
    )
)

SET VS_2017_CLANGC2_VERSION_FILE=%VS_2017_VCINSTALL_DIR%Auxiliary/Build/Microsoft.ClangC2Version.default.txt
if not exist "%VS_2017_CLANGC2_VERSION_FILE%" (
	echo Could not find "%VS_2017_CLANGC2_VERSION_FILE%".
	goto ON_ENV_ERROR
)

set /p VS_2017_CLANGC2_VERSION=<"%VS_2017_CLANGC2_VERSION_FILE%"
set VS_2017_CLANGC2_TOOLS_BIN_PATH=%VS_2017_VCINSTALL_DIR%Tools\ClangC2\%VS_2017_CLANGC2_VERSION%\bin\%VS_2017_CLANGC2_ARCH%\
set VS_2017_CLANGC2_TOOLS_BIN=%VS_2017_CLANGC2_TOOLS_BIN_PATH%clang.exe
if not exist "%VS_2017_CLANGC2_TOOLS_BIN%" (
	echo Could not find "%VS_2017_CLANGC2_TOOLS_BIN%".
	goto ON_ENV_ERROR
)

set VS_2017_DEV_CMD_PROMPT=%VS_2017_VCINSTALL_DIR%Auxiliary\Build\%VS_2017_VCVARS_ARCH%
if not exist "%VS_2017_DEV_CMD_PROMPT%" (
    echo Could not find "%VS_2017_DEV_CMD_PROMPT%".
    goto ON_ENV_ERROR
)

call "%VS_2017_DEV_CMD_PROMPT%" > NUL && (
    set "VS_CLANGC2_TOOLS_BIN_PATH=%VS_2017_CLANGC2_TOOLS_BIN_PATH%"
    goto ON_EXECUTE
) || (
    echo Failed executing "%VS_2017_DEV_CMD_PROMPT%".
    goto ON_ENV_ERROR
)

:ON_ENV_ERROR

echo Warning, failed to setup build environment needed by MSVC build mono-sgen.exe running as an AOT compiler.
echo Incomplete build environment can cause AOT compiler build or link error's due to missing compiler, linker and platform libraries.

:ON_EXECUTE

:: Add ClangC2 to PATH
set "PATH=%VS_CLANGC2_TOOLS_BIN_PATH%;%PATH%"

call "%~dp0mono-sgen.exe" %* && (
    set EXCEUTE_RESULT=0
) || (
    set EXCEUTE_RESULT=1
    if not %ERRORLEVEL% == 0 (
        set EXCEUTE_RESULT=%ERRORLEVEL%
    )
)

exit /b %EXCEUTE_RESULT%

@echo on
