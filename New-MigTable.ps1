function New-MigTable {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$UserNames,
        
        [Parameter(Mandatory=$false)]
        [string[]]$GroupNames,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputFile,

        [Parameter(Mandatory=$false)]
        [string[]]$DomainName = $env:USERDOMAIN
    )

    # Read ignored users and groups from configuration files
    $ignoredUsers = @()
    $ignoredGroups = @()
    
    if (Test-Path "ignoredDomainUsers.txt") {
        $domainUsers = Get-Content "ignoredDomainUsers.txt" | Where-Object { $_ -match '\S' }
        $ignoredUsers += $domainUsers | ForEach-Object { "$DomainName\$_" }
    }

    if (Test-Path "ignoredLocalUsers.txt") {
        $localUsers = Get-Content "ignoredLocalUsers.txt" | Where-Object { $_ -match '\S' }
        $ignoredUsers += $localUsers | ForEach-Object { "$($Computer.Name)\$_" }
    }

    if (Test-Path "ignoredDomainGroups.txt") {
        $domainGroups = Get-Content "ignoredDomainGroups.txt" | Where-Object { $_ -match '\S' }
        $ignoredGroups += $domainGroups | ForEach-Object { "$DomainName\$_" }
    }

    # Create new XML document
    $xml = New-Object System.Xml.XmlDocument
    $xml.AppendChild($xml.CreateXmlDeclaration("1.0", "utf-16", $null))

    # Create root element with namespaces
    $root = $xml.CreateElement("MigrationTable")
    $root.SetAttribute("xmlns:xsd", "http://www.w3.org/2001/XMLSchema")
    $root.SetAttribute("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance")
    $root.SetAttribute("xmlns", "http://www.microsoft.com/GroupPolicy/GPOOperations/MigrationTable")
    $xml.AppendChild($root)

    $NumUsers = 0
    $MaxPlaceholderUsers = 16

    # Create mapping for each username
    foreach ($user in $UserNames) {
        if(-not ($ignoredUsers -contains $user) -and $NumUsers -lt $MaxPlaceholderUsers) {
            $sourceName = "$DomainName\PlaceholderUser$NumUsers"
            $mapping = $xml.CreateElement("Mapping")
        
            $type = $xml.CreateElement("Type")
            $type.InnerText = "User"
        
            $source = $xml.CreateElement("Source")
            $source.InnerText = $sourceName
        
            $dest = $xml.CreateElement("Destination")
            $dest.InnerText = "$DomainName\$user"
        
            $mapping.AppendChild($type)
            $mapping.AppendChild($source)
            $mapping.AppendChild($dest)
        
            $root.AppendChild($mapping)
            $NumUsers++
        }
    }

    $NumGroups = 0
    $MaxPlaceholderGroups = 10

    # Create mapping for each group if provided
    if ($GroupNames) {
        foreach ($group in $GroupNames) {
            if(-not ($ignoredGroups -contains $group) -and $NumGroups -lt $MaxPlaceholderGroups) {
                $sourceName = "$DomainName\PlaceholderGroup$NumGroups"
                $mapping = $xml.CreateElement("Mapping")
            
                $type = $xml.CreateElement("Type")
                $type.InnerText = "Group"
            
                $source = $xml.CreateElement("Source")
                $source.InnerText = $sourceName
            
                $dest = $xml.CreateElement("Destination")
                $dest.InnerText = "$DomainName\$group"
            
                $mapping.AppendChild($type)
                $mapping.AppendChild($source)
                $mapping.AppendChild($dest)
            
                $root.AppendChild($mapping)
                $NumGroups++
            }
        }
    }

    # Save the XML file
    $xml.Save($OutputFile)

    if($NumUsers -gt $MaxPlaceholderUsers -or $NumGroups -gt $MaxPlaceholderGroups){
        $ErrorFile = "$OutputFile.ERROR"
        New-Item -ItemType File -Name $ErrorFile -Value "TOO MANY USER OR GROUP MEMBERS. $OutputFile RESULTS TRUNCATED."
    }
}