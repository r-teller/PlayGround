function New-GCPSession {
    param (
        [string]$OrganizationId,
        [switch]$NoPrompt = $false
    )


    
#     # Set-Variable -Name Folders -Value (New-FolderLookup -OrganizationId $selectedOrg) -Scope Global
#     # Set-Variable -Name Projects -Value (New-ProjectLookup -OrganizationId $selectedOrg) -Scope Global
    # Set-Variable -Name XpnID -value (Get-HostProjects -OrganizationId $selectedOrg) -Scope Global
    # Set-Variable -Name OrgId -Value $selectedOrg -Scope Global
    $OrgId, $DefaultDomainName = Select-Organization $OrganizationId
    Set-Variable -Name OrgId -Value $OrgId -Scope Global
    Set-Variable -Name DefaultDomainName -Value $DefaultDomainName -Scope Global

}

function Select-Organization {
    param (
        [string]$OrganizationId = ""
    )

    $orgs = Get-Organizations
    $org =  $orgs | Where-Object{$_.name.split("/") -eq $OrganizationId}
    if ($org) {
        $selectedOrg = $org.name.Split("/")[1]
        $domainName = $org.displayName
    } else {
        $selectedOrg = ""
        $domainName = ""
    }

    $orgLookup = @{}
    $counter = 1
    foreach ($org in $orgs) {        
        $orglookup.Add($org.displayName, $counter)
        $counter ++
    }
    
    while ($True) {
        Write-Host -ForegroundColor Green "[+] Select a organization: `n"
        for ($i = 1 ; $i -lt $orgs.Count + 1; $i++) {
            Write-Host -ForegroundColor Green "[$i] " -NoNewline
            Write-Host "$($orgs[$i -1].displayName)"
        }
        Write-Host -ForegroundColor Green "`n[Q]" -NoNewline
        write-Host " to Quit"
        Write-Host
        $selection = Read-Host
        if ($selection -eq "q") {
            Clear-Host
            Write-Error -Message "Error: User decided to exit prompt" -Category CloseError -ErrorAction Stop
        }
        try {
            $orgLookup.ContainsKey($orgs[$selection - 1].displayName)
        }
        catch {
            Clear-Host
            Write-Host -ForegroundColor Red "`nProvide a proper selection"
            Start-Sleep 3
            Clear-Host
            continue
        }
        
        while ($true) {
            Clear-Host
            $confirm = @"
Confirm selection y/n or q to Quit
    Selected org: $($orgs[$selection - 1].displayName)
"@
            $confirm = Read-Host -Prompt $confirm
            if ($confirm -eq "y") {
                $selectedOrg = $orgs[$selection - 1].name.Split("/")[1]
                $domainName = $orgs[$selection - 1].displayName
                break
            }
            elseif ($confirm -eq "n") {
            Clear-Host
                break
            }
            elseif ($confirm -eq "q") {
                Write-Error -Message "Error: User decided to exit prompt" -Category CloseError -ErrorAction Stop
            }
            Clear-Host
            Write-Host -ForegroundColor Red "`nIncorrect key [$confirm] pressed, Please confirm selection with y or n."
            Start-Sleep 3
            Clear-Host
            continue
        }
        break
    }
    return  $selectedOrg, $domainName
}

function Select-HostProject {
    $counter = 1
    foreach ($org in $orgs) {
        $orglookup.Add($org.displayName, $counter)
        $counter ++ 
    }
    $selectedOrg = ""
    $domainName = ""
    while ($true) {
        Write-Host -ForegroundColor Green "[+] Select a organization: `n"
        for ($i = 1 ; $i -lt $orgs.Count + 1; $i++) {
            Write-Host -ForegroundColor Green "[$i] " -NoNewline
            Write-Host "$($orgs[$i -1].displayName)"
        }
        Write-Host
        $selection = Read-Host
        try {
            $orglookup.ContainsKey($orgs[$selection - 1].displayName)
        }
        catch {
            Clear-Host
            Write-Host -ForegroundColor Red "`nProvide a proper selection"
            Start-Sleep 3
            Clear-Host
            continue
        }
        
        Clear-Host
        $confirm = @"
        Confirm selection y/n
Selected org: $($orgs[$selection - 1].displayName)
"@
        $confirm = Read-Host -Prompt $confirm
        if ($confirm -eq "y") {
            $selectedOrg = $orgs[$selection - 1].name.Split("/")[1]
            $domainName = $orgs[$selection - 1].displayName
            break
        }
        if ($confirm -eq "n") {
            Clear-Host
            continue
        }
        Clear-Host
    }
}

function Get-Organizations {
    $orgs = gcloud organizations list --format=json | ConvertFrom-Json

    $orgs
}

function Get-HostProjects {
    <#
    .SYNOPSIS
    Creates in memory key value lookup where key is projectid and value is project display name
    
    .DESCRIPTION
    This function uses the asset inventory api to dump all host projects in the entire organization

    .PARAMETER OrganizationId
    GCP Organization ID 
    
    .EXAMPLE
    $projects = Get-HostProjects -OrganizationId "123456789"
    
    .NOTES
    Access project name: $projects["1097427954669"]  
    #>
    param (
        [string]$OrganizationId = $Global:OrgId
    )

    $hostProjects = gcloud compute shared-vpc organizations list-host-projects $OrganizationId `
        --page-size=500 `
        --format=json `
        | ConvertFrom-Json

    $hostProjects
}

# Exported Functions
$Exports = @(
    "New-GCPSession"
    ,"Get-Organizations"
    ,"Get-HostProjects"
    # "Get-HostProjects"
)

Export-ModuleMember -Function $Exports