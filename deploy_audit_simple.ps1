# DEPLOY AUDIT LOGGING SYSTEM
# This PowerShell script will help you deploy the audit logging system

Write-Host "RoadAid Audit Logging System Deployment" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "MANUAL DEPLOYMENT STEPS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Open your Supabase Dashboard:" -ForegroundColor White
Write-Host "   https://app.supabase.com/project/olxquclxgtrbyxfxxscj" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Navigate to SQL Editor:" -ForegroundColor White
Write-Host "   - Click on SQL Editor in the left sidebar" -ForegroundColor Gray
Write-Host "   - Click New Query" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Copy and Paste SQL Script:" -ForegroundColor White
Write-Host "   - Open the file: AUDIT_LOGGING_SYSTEM.sql" -ForegroundColor Gray
Write-Host "   - Copy ALL content (Ctrl+A, Ctrl+C)" -ForegroundColor Gray
Write-Host "   - Paste into Supabase SQL Editor (Ctrl+V)" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Run the Script:" -ForegroundColor White
Write-Host "   - Click Run button or press Ctrl+Enter" -ForegroundColor Gray
Write-Host "   - Wait for completion message" -ForegroundColor Gray
Write-Host ""
Write-Host "5. Verify Deployment:" -ForegroundColor White
Write-Host "   - Check for audit_logs table in Table Editor" -ForegroundColor Gray
Write-Host "   - Look for success message" -ForegroundColor Gray
Write-Host ""

# Try to open the SQL file for easy copying
$sqlFile = "AUDIT_LOGGING_SYSTEM.sql"
if (Test-Path $sqlFile) {
    Write-Host "Opening SQL file for easy copying..." -ForegroundColor Green
    try {
        Start-Process notepad.exe $sqlFile
        Write-Host "SQL file opened in Notepad" -ForegroundColor Green
    } catch {
        Write-Host "Could not open SQL file automatically" -ForegroundColor Red
        Write-Host "Please open $sqlFile manually" -ForegroundColor Gray
    }
} else {
    Write-Host "SQL file not found: $sqlFile" -ForegroundColor Red
    Write-Host "Make sure you are in the correct directory" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Opening Supabase Dashboard..." -ForegroundColor Green
try {
    Start-Process "https://app.supabase.com/project/olxquclxgtrbyxfxxscj/sql/new"
    Write-Host "Supabase SQL Editor opened in browser" -ForegroundColor Green
} catch {
    Write-Host "Could not open browser automatically" -ForegroundColor Red
    Write-Host "Please open: https://app.supabase.com/project/olxquclxgtrbyxfxxscj/sql/new" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "QUICK FIX FOR YOUR APP:" -ForegroundColor Yellow
Write-Host "After deploying the SQL script, your service request creation will work!" -ForegroundColor White
Write-Host ""
Write-Host "WHAT THIS FIXES:" -ForegroundColor Yellow
Write-Host "   ERROR: function public.log_action(...) does not exist" -ForegroundColor Red
Write-Host "   SOLUTION: Creates audit_logs table and log_action function" -ForegroundColor Green
Write-Host ""

Read-Host "Press Enter after you have deployed the SQL script..."

Write-Host ""
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "You can now:" -ForegroundColor White
Write-Host "   - Create service requests without errors" -ForegroundColor Gray
Write-Host "   - View audit logs in Supabase dashboard" -ForegroundColor Gray
Write-Host "   - Track all system activities" -ForegroundColor Gray
