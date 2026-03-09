Write-Host "Start script @$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')@"


Write-Host
Write-Host 'Import modules'
Write-Host '  AddressFormatter'
Import-Module (Split-Path $PSScriptRoot)
Write-Host '  powershell-yaml'
Import-Module (Join-Path $PSScriptRoot '..\nestedModules\powershell-yaml')

$submoduleID = 'subModules/OpenCageData/address-formatting'
$gitModulesFile = Join-Path $PSScriptRoot '..\.gitmodules'

# Query the .gitmodules file directly using git config
$relativeModulePath = git config -f $gitModulesFile --get "submodule.$($submoduleID).path"

if ($null -ne $relativeModulePath) {
    # Resolve to absolute path relative to the .gitmodules file
    $submoduleRoot = Join-Path (Split-Path $gitModulesFile) $relativeModulePath
    $gitInfo = git -C $submoduleRoot log -1 --format="%h|%cI" 2>$null
} else {
    $gitInfo = "Could not resolve submodule ID '$submoduleID'"
}


Write-Host
Write-Host 'Submodule OpenCageData/address-formatting'
Write-Host "  Commit $($gitInfo.Split('|')[0]), dated $($gitInfo.Split('|')[1])"


Write-Host
Write-Host 'Running test cases'
$TestCaseFilesCount = 0
$TestCaseCount = 0
$TestCaseErrorCount = 0
$TestCaseErrors = @()

foreach ($TestCaseFile in
    @(
        Get-ChildItem (Join-Path $PSScriptRoot '..\subModules\OpenCageData\address-formatting\testcases') -Include '*.yaml' -File -Recurse
    )
) {
    $TestCaseFilesCount++

    $TestCaseCount += @(ConvertFrom-Yaml -Yaml (Get-Content $TestCaseFile.fullname -Raw -Encoding UTF8) -AllDocuments).Count
}

Write-Host "  $TestCaseCount test cases from $TestCaseFilesCount files"

foreach ($TestCaseFile in
    @(
        Get-ChildItem (Join-Path $PSScriptRoot '..\subModules\OpenCageData\address-formatting\testcases') -Include '*.yaml' -File -Recurse
    )
) {
    foreach ($TestCase in @(ConvertFrom-Yaml -Yaml (Get-Content $TestCaseFile.fullname -Raw -Encoding UTF8) -AllDocuments)) {
        if ((Split-Path (Split-Path $TestCaseFile.fullname) -Leaf) -ieq 'abbreviations') {
            $result = (Format-PostalAddress -Components $TestCase.components -Abbreviate)
        } else {
            $result = (Format-PostalAddress -Components $TestCase.components)
        }

        $TestCase.expected = $TestCase.expected -replace '\n$', '' # We do not add a trailing newline

        if ($result -ne $TestCase.expected) {
            $TestCaseErrorCount++

            $TestCaseErrors += $TestCaseFile.fullname
            $TestCaseErrors += "  $($TestCase.description)"

            @(
                '    Expected lines:'
                $TestCase.expected -split '\r?\n' | ForEach-Object {
                    "      '$($_)'"
                }
                '    Returned lines:'
                $result -split '\r?\n' | ForEach-Object {
                    "      '$($_)'"
                }
            ) | ForEach-Object {
                $TestCaseErrors += $_
            }
        }
    }
}


Write-Host
Write-Host 'Test results'
Write-Host "  Passed: $($TestCaseCount - $TestCaseErrorCount)/$($TestCaseCount) ($((($TestCaseCount - $TestCaseErrorCount) * 100 / $TestCaseCount).ToString('F2')) %)"
Write-Host "  Failed: $($TestCaseErrorCount)/$($TestCaseCount) ($(($TestCaseErrorCount * 100 / $TestCaseCount).ToString('F2')) %)"

$TestCaseErrors | ForEach-Object {
    Write-Host "    $($_)"
}


Write-Host
Write-Host "End script @$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')@"