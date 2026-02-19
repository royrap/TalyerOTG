@echo off
echo Running COMPLETE_CONNECTION_FIX.sql...
echo This will establish all mechanic-shop and customer-mechanic connections
echo.

REM Try to find psql in common installation paths
set PSQL_PATH=""

if exist "C:\Program Files\PostgreSQL\15\bin\psql.exe" (
    set PSQL_PATH="C:\Program Files\PostgreSQL\15\bin\psql.exe"
) else if exist "C:\Program Files\PostgreSQL\16\bin\psql.exe" (
    set PSQL_PATH="C:\Program Files\PostgreSQL\16\bin\psql.exe"
) else if exist "C:\Program Files\PostgreSQL\14\bin\psql.exe" (
    set PSQL_PATH="C:\Program Files\PostgreSQL\14\bin\psql.exe"
) else if exist "C:\Program Files\PostgreSQL\13\bin\psql.exe" (
    set PSQL_PATH="C:\Program Files\PostgreSQL\13\bin\psql.exe"
) else if exist "C:\Program Files (x86)\PostgreSQL\15\bin\psql.exe" (
    set PSQL_PATH="C:\Program Files (x86)\PostgreSQL\15\bin\psql.exe"
)

if %PSQL_PATH%=="" (
    echo PostgreSQL psql not found in standard installation paths
    echo Please install PostgreSQL or add psql to your PATH
    pause
    exit /b 1
)

echo Using psql from: %PSQL_PATH%
echo.

REM Execute the SQL file
%PSQL_PATH% "postgresql://postgres.olxquclxgtrbyxfxxscj:Capstone123!@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres" -f "COMPLETE_CONNECTION_FIX.sql"

if %ERRORLEVEL%==0 (
    echo.
    echo ✅ CONNECTION FIX COMPLETED SUCCESSFULLY!
    echo.
    echo Next steps:
    echo 1. Run validation queries to check connections
    echo 2. Test the views: v_mechanic_shop_connections and v_customer_mechanic_connections
    echo 3. Verify triggers are working for future connections
) else (
    echo.
    echo ❌ ERROR OCCURRED DURING EXECUTION
    echo Please check the output above for details
)

echo.
pause