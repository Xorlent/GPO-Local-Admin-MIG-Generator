$DomainName = $env:USERDOMAIN

# Prompt for OU
$OU = Read-Host "Enter the OU search path we will use to audit all local computer administrators:"
if ([string]::IsNullOrWhiteSpace($OU)) {
    Write-Error "OU path cannot be empty"
    exit 1
}

# Validate OU exists
try {
    $null = Get-ADOrganizationalUnit -Identity $OU
} catch {
    Write-Error "Invalid OU path: $OU"
    exit 1
}

$defaultOutput = ".\SvrLocalAdmins.csv"
$outputFile = Read-Host "Enter the output file path (press Enter for default: $defaultOutput)"
if ([string]::IsNullOrWhiteSpace($outputFile)) {
    $outputFile = $defaultOutput
}

# Validate output path
$outputDir = Split-Path -Parent $outputFile
if ($outputDir -and -not (Test-Path $outputDir)) {
    Write-Error "Output directory does not exist: $outputDir"
    exit 1
}

$Computers = Get-ADComputer -Filter "Enabled -eq 'True'" -SearchBase $OU | Select-Object DNSHostName, Name

# Read ignored users from configuration files
$ignoredUsers = @()

if (Test-Path "ignoredDomainUsers.txt") {
    $domainUsers = Get-Content "ignoredDomainUsers.txt" | Where-Object { $_ -match '\S' }
    $ignoredUsers += $domainUsers | ForEach-Object { "$DomainName\$_" }
}

if (Test-Path "ignoredDomainGroups.txt") {
    $domainGroups = Get-Content "ignoredDomainGroups.txt" | Where-Object { $_ -match '\S' }
    $ignoredUsers += $domainGroups | ForEach-Object { "$DomainName\$_" }
}

if (Test-Path "ignoredLocalUsers.txt") {
    $localUsers = Get-Content "ignoredLocalUsers.txt" | Where-Object { $_ -match '\S' }
}

function Get-LocalAdministrators {
    param ($strcomputer)  

    $admins = Invoke-Command -ComputerName $strcomputer -ScriptBlock {Get-WmiObject win32_groupuser -ErrorAction Stop} -ErrorAction SilentlyContinue
    $admins = $admins | Where-Object {$_.groupcomponent -like '*"Administrators"'}
    $admins | ForEach-Object {
        $_.partcomponent -match ".+Domain\=(.+)\,Name\=(.+)$" > $null  
        $matches[1].trim('"') + "\" + $matches[2].trim('"')  
    }
}

$List = "Host,User`r`n"
Write-Host "List of hosts with no local admin exceptions (inaccessible hosts ignored):"
Write-Host "-------------------------------------------------------------------------------------------------------"

foreach($Computer in $Computers) {
    $Counter = 0
    $ignoredLocalUsers = @()
    $ignoredLocalUsers += $localUsers | ForEach-Object { "$($Computer.Name)\$_" }
    $Accounts = Get-LocalAdministrators($Computer.DNSHostName)
    foreach($User in $Accounts) {
        if(-not ($ignoredUsers -contains $User) -and -not ($ignoredLocalUsers -contains $User)) {
            $List = $List + $Computer.Name + "," + $User + "`r`n"
            $Counter++
        }
    }
    if($Counter -eq 0 -and $Accounts.Count -gt 0) {
        # This machine had no local admin exceptions
        Write-Host $Computer.Name
    }
}

Out-File -FilePath $outputFile -InputObject $List -Encoding ASCII
Write-Host "Results have been saved to: $outputFile"

# Prompt for MIG file creation
$createMig = Read-Host "Would you like to create MIG files from these results? (Y/N)"
if ($createMig -eq 'Y' -or $createMig -eq 'y') {
    # Check if New-MigTablesByMembership script exists
    if (-not (Test-Path '.\New-MigTablesByMembership.ps1')) {
        Write-Error "Required script not found: .\New-MigTablesByMembership.ps1"
        exit 1
    }

    # Load the New-MigTablesByMembership function
    . '.\New-MigTablesByMembership.ps1'

    # Prompt for output folder
    $defaultMigFolder = ".\miglist"
    $migOutputFolder = Read-Host "Enter the MIG files output folder (press Enter for default: $defaultMigFolder)"
    if ([string]::IsNullOrWhiteSpace($migOutputFolder)) {
        $migOutputFolder = $defaultMigFolder
    }

    # Create MIG tables
    Write-Host "Creating MIG tables..."
    New-MigTablesByMembership -CsvPath $outputFile -OutputFolder $migOutputFolder
    Write-Host "MIG files have been created in: $migOutputFolder"
}