<#
Imports CSV file in format Host, User and generates MIG files necessary to cover all possible combinations of local admin memberships found.

    # Example usage:
    New-MigTablesByMembership -CsvPath ".\localadmins.csv" -OutputFolder ".\miglist"
#>

# Load New-MigTable function
if (Test-Path '.\New-MigTable.ps1') {
    . $newMigTablePath
} else {
    Write-Error "Required script not found: $newMigTablePath"
    exit 1
}

function New-MigTablesByMembership {
    param (
        [Parameter(Mandatory=$true)]
        [string]$CsvPath,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputFolder
    )

    # Create output folder if it doesn't exist
    if (-not (Test-Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder | Out-Null
    }

    # Import CSV data
    $adminData = Import-Csv -Path $CsvPath

    # Group hosts by their membership patterns
    $groupedHosts = $adminData | Group-Object -Property Host | ForEach-Object {
        $hostname = $_.Name
        $members = $_.Group | Select-Object Member, 'Member Type'
        
        # Create a string key from sorted members for consistent grouping
        $memberKey = ($members | Sort-Object Member | ForEach-Object { 
            "$($_.Member)::$($_.'Member Type')" 
        }) -join '|'
        
        [PSCustomObject]@{
            Host = $hostname
            MemberKey = $memberKey
            Members = $members
        }
    } | Group-Object -Property MemberKey

    # Process each unique membership pattern
    foreach ($group in $groupedHosts) {
        $users = @()
        $groups = @()
        
        # Split members into users and groups
        $firstHost = $group.Group[0]
        foreach ($member in $firstHost.Members) {
            if ($member.'Member Type' -eq 'User') {
                $users += $member.Member
            }
            elseif ($member.'Member Type' -eq 'Group') {
                $groups += $member.Member
            }
        }

        # Create a descriptive filename
        $hostCount = $group.Group.Count
        $memberCount = $users.Count + $groups.Count
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $filename = "MigTable_${hostCount}Hosts_${memberCount}Members_$timestamp.migtable"
        $outputPath = Join-Path $OutputFolder $filename

        # Create the migration table
        New-MigTable -UserNames $users -GroupNames $groups -OutputFile $outputPath

        # Output summary information
        [PSCustomObject]@{
            OutputFile = $filename
            HostCount = $hostCount
            UserCount = $users.Count
            GroupCount = $groups.Count
            Hosts = $group.Group.Host -join ', '
        }

        # Create companion file with host list for configuring GPO apply permissions
        $hostListFile = Join-Path $OutputFolder "$([System.IO.Path]::GetFileNameWithoutExtension($filename))_hosts.txt"
        $group.Group.Host | Sort-Object | Out-File -FilePath $hostListFile
    }
}