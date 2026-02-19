# Rename RoadAid to RoadAid
Write-Host "Starting rename..." -ForegroundColor Green

$replacements = @(
    @('RoadAidTheme', 'RoadAidTheme'),
    @('RoadAidHomePage', 'RoadAidHomePage'),
    @('_RoadAidHomePageState', '_RoadAidHomePageState'),
    @('RoadAidDrawer', 'RoadAidDrawer'),
    @('_RoadAidDrawerState', '_RoadAidDrawerState'),
    @('RoadAidBottomNavBar', 'RoadAidBottomNavBar'),
    @('RoadAidBody', 'RoadAidBody'),
    @('_RoadAidBodyState', '_RoadAidBodyState'),
    @('RoadAidDeepLinkService', 'RoadAidDeepLinkService'),
    @('roadaid_deep_link_service', 'roadaid_deep_link_service'),
    @('roadaid_colors', 'roadaid_colors'),
    @('roadaid_theme', 'roadaid_theme'),
    @('roadaid_widgets', 'roadaid_widgets'),
    @('roadaid/phone_launcher', 'roadaid/phone_launcher'),
    @('RoadAid red', 'RoadAid red'),
    @('RoadAid brand', 'RoadAid brand'),
    @('RoadAid Logo', 'RoadAid Logo'),
    @('RoadAid', 'RoadAid'),
    @('roadaidapp', 'RoadAidapp'),
    @('roadaid', 'RoadAid'),
    @('ROADAID', 'RoadAid')
)

$extensions = @('*.dart', '*.yaml', '*.yml', '*.md', '*.xml', '*.json', '*.kt', '*.swift', '*.sql', '*.xcscheme')
$excludeDirs = @('.dart_tool', 'build', '.git', '.idea', 'node_modules')

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

Write-Host "Found $($files.Count) files" -ForegroundColor Cyan

$count = 0
foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) { continue }
    
    $original = $content
    foreach ($pair in $replacements) {
        $from = [regex]::Escape($pair[0])
        $to = $pair[1]
        $content = $content -replace $from, $to
    }
    
    if ($content -ne $original) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        $count++
        Write-Host "  Modified: $($file.Name)" -ForegroundColor Green
    }
}

Write-Host "Done! Modified $count files" -ForegroundColor Green
