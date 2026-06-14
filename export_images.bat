@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
echo ============================================
echo   导出大数据镜像 (Windows → 虚拟机)
echo   前提：Windows 上装了 Docker Desktop
echo ============================================
echo.

mkdir images_export 2>nul

REM 依次拉取并导出每个镜像
call :pull_and_save "bde2020/hadoop-namenode:2.0.0-hadoop2.7.4-java8"
call :pull_and_save "bde2020/hadoop-datanode:2.0.0-hadoop2.7.4-java8"
call :pull_and_save "bde2020/hive:2.3.2-postgresql-metastore"
call :pull_and_save "postgres:9.6"
call :pull_and_save "mysql:5.7"

echo.
echo ============================================
echo   导出完成！
echo   把 images_export 文件夹传到 Ubuntu 虚拟机
echo   然后运行: bash load_images.sh
echo ============================================
pause
goto :eof

:pull_and_save
set IMG=%1
echo.
echo [拉取] !IMG!
docker pull !IMG!
if errorlevel 1 (
    echo [重试] 再试一次...
    docker pull !IMG!
)
if errorlevel 1 (
    echo [失败] !IMG! 拉取失败
    goto :eof
)
set FNAME=!IMG:/=_!
set FNAME=!FNAME::=_!
echo [导出] images_export\!FNAME!.tar
docker save !IMG! -o images_export\!FNAME!.tar
echo [OK]
goto :eof
