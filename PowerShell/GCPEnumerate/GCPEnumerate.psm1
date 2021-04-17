function New-GCPSession {
    param (
        [string]$OrganizationId,
        [string]$HostProjectId,
        [switch]$NoPrompt = $false
    )


    
    # Set-Variable -Name Folders -Value (New-FolderLookup -OrganizationId $selectedOrg) -Scope Global
    # Set-Variable -Name Projects -Value (New-ProjectLookup -OrganizationId $selectedOrg) -Scope Global
    #Set-Variable -Name OrgId -Value $selectedOrg -Scope Global
    $OrgId, $DefaultDomainName = Select-Organization -OrganizationId $OrganizationId
    $XpnID = Select-HostProject -HostProjectId $HostProjectId
    Set-Variable -Name OrgId -Value $OrgId -Scope Global
    Set-Variable -Name DefaultDomainName -Value $DefaultDomainName -Scope Global
    Set-Variable -Name XpnID -value $XpnID -Scope Global
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
    
    while ($True) {
        Write-Host -ForegroundColor Green "[+] Select a organization: `n"
        for ($i = 0 ; $i -lt $orgs.Count; $i++) {
            Write-Host -ForegroundColor Green "[$i] " -NoNewline
            Write-Host "$($orgs[$i].displayName) [$($orgs[$i].name.Split("/")[1])]"
        }
        Write-Host -ForegroundColor Green "`n[Q]" -NoNewline
        write-Host " to Quit"
        Write-Host
        $selection = Read-Host
        if ($selection -eq "q") {
            Clear-Host
            Write-Error -Message "Error: User decided to exit prompt" -Category CloseError -ErrorAction Stop
        } elseif ($orgs.Count -le $selection ) {
            Clear-Host
            Write-Host -ForegroundColor Red "`nProvide a proper selection, [$selection] is not within range 0 - $($orgs.Count-1)"
            Start-Sleep 3
            Clear-Host
            continue
        }
        
        while ($true) {
            Clear-Host
            $confirm = @"
Confirm selection y/n or q to Quit
    Selected org: $($orgs[$selection].displayName)
"@
            $confirm = Read-Host -Prompt $confirm
            if ($confirm -eq "y") {
                $selectedOrg = $orgs[$selection].name.Split("/")[1]
                $domainName = $orgs[$selection].displayName
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
        if ($selectedOrg) {break}
    }
    return  $selectedOrg, $domainName
}

function Select-HostProject {
    param (
        [string]$HostProjectId
    )
    $xpns = Get-HostProjects 
    $xpn = $xpns | Where-Object{$_.name -eq $HostProjectId}

    if ($xpn) {
        $selectedXPN = $xpn.name
    } else {
        $selectedXPN = ""
    }

    while ($True) {
        Write-Host -ForegroundColor Green "[+] Select a Host Project: `n"
        for ($i = 0 ; $i -lt $xpns.Count; $i++) {
            Write-Host -ForegroundColor Green "[$i] " -NoNewline
            Write-Host "$($xpns[$i].name)"
        }
        Write-Host -ForegroundColor Green "`n[Q]" -NoNewline
        write-Host " to Quit"
        Write-Host
        $selection = Read-Host
        if ($selection -eq "q") {
            Clear-Host
            Write-Error -Message "Error: User decided to exit prompt" -Category CloseError -ErrorAction Stop
        } elseif ($orgs.Count -le $selection ) {
            Clear-Host
            Write-Host -ForegroundColor Red "`nProvide a proper selection, [$selection] is not within range 0 - $($orgs.Count-1)"
            Start-Sleep 3
            Clear-Host
            continue
        }

        while ($true) {
            Clear-Host
            $confirm = @"
Confirm selection y/n or q to Quit
    Selected Host Project: $($xpns[$selection].name)
"@
            $confirm = Read-Host -Prompt $confirm
            if ($confirm -eq "y") {
                $selectedXPN = $xpns[$selection].name
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
        if ($selectedXPN) {break}        
    }
    return $selectedXPN
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

function Get-HttpProxys {

}

function Get-HttpsProxys {

}

function Get-ForwardingRules {

}

# Exported Functions
$Exports = @(
    "New-GCPSession"
    ,"Get-Organizations"
    ,"Get-HostProjects"
)

Export-ModuleMember -Function $Exports