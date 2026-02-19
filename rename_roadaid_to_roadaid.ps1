# PowerShell script to rename all RoadAid references to RoadAid
# Run from project root

Write-Host "Starting RoadAid -> RoadAid rename operation..." -ForegroundColor Green

# Define replacement mappings (order matters - do specific cases first)
$replacements = @(
    @{From='RoadAidTheme'; To='RoadAidTheme'},
    @{From='RoadAidHomePage'; To='RoadAidHomePage'},
    @{From='_RoadAidHomePageState'; To='_RoadAidHomePageState'},
    @{From='RoadAidDrawer'; To='RoadAidDrawer'},
    @{From='_RoadAidDrawerState'; To='_RoadAidDrawerState'},
    @{From='RoadAidBottomNavBar'; To='RoadAidBottomNavBar'},
    @{From='RoadAidBody'; To='RoadAidBody'},
    @{From='_RoadAidBodyState'; To='_RoadAidBodyState'},
    @{From='RoadAidDeepLinkService'; To='RoadAidDeepLinkService'},
    @{From='roadaid_deep_link_service'; To='roadaid_deep_link_service'},
    @{From='roadaid_colors'; To='roadaid_colors'},
    @{From='roadaid_theme'; To='roadaid_theme'},
    @{From='roadaid_widgets'; To='roadaid_widgets'},
    @{From='roadaid/phone_launcher'; To='roadaid/phone_launcher'},
    @{From='RoadAid red'; To='RoadAid red'},
    @{From='RoadAid brand'; To='RoadAid brand'},
    @{From='RoadAid Logo'; To='RoadAid Logo'},
    @{From='RoadAid'; To='RoadAid'},
    @{From='roadaidapp'; To='RoadAidapp'},
    @{From='roadaid'; To='RoadAid'},
    @{From='ROADAID'; To='RoadAid'}
)

# File extensions to process
$extensions = @('*.dart', '*.yaml', '*.yml', '*.md', '*.xml', '*.json', '*.kt', '*.swift', '*.ps1', '*.sql', '*.xcscheme')

# Directories to exclude
$excludeDirs = @('.dart_tool', 'build', '.git', '.idea', 'node_modules')

# Get all files
$files = Get-ChildItem -Path . -Include $extensions -Recurse | Where-Object {
    $file = $_
    $excluded = $false
    foreach ($dir in $excludeDirs) {
        if ($file.FullName -like "*\$dir\*") {
            $excluded = $true
            break
        }
    }
    -not $excluded -and -not $file.PSIsContainer
}

Write-Host "Found $($files.Count) files to process" -ForegroundColor Cyan

$filesModified = 0

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    
    if ($null -eq $content) {
        continue
    }
    
    $originalContent = $content
    $modified = $false
    
    # Apply all replacements
    foreach ($replacement in $replacements) {
        if ($content -match [regex]::Escape($replacement.From)) {
            $content = $content -replace [regex]::Escape($replacement.From), $replacement.To
            $modified = $true
        }
    }
    
    # Write back if modified
    if ($modified) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        $filesModified++
        Write-Host "  ✓ $($file.Name)" -ForegroundColor Green
    }
}

Write-Host "`n✅ Rename complete!" -ForegroundColor Green
Write-Host "   Modified: $filesModified files" -ForegroundColor Cyan
Write-Host "`nManual steps still needed:" -ForegroundColor Yellow
Write-Host "   1. Update Supabase auth redirect URLs" -ForegroundColor Yellow
Write-Host "   2. Rebuild app with flutter clean and flutter pub get" -ForegroundColor Yellow
