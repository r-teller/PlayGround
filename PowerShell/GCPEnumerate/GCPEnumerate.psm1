#https://codeandkeep.com/PowerShell-Get-Subnet-NetworkID/

class Instance {
    [string] $name
    [string] $network
    [string] $networkIp
    [string] $state
    [string] $projectId
}

class Subnet {
    [string] $name
    [string] $ipCidrRange="255.255.255.255/32"
    [Instance[]] $instances = @()
    [string] $region
    hidden [int64] $maxHosts = [math]::Pow(2,(32 - $this.ipCidrRange.split("/")[1] )) - 2
    hidden [int64] $usedHosts = $this.instances.count
    hidden [string] $percentUsed
    [psobject] ShowUtilization(){
        $_ShowUtilization = New-Object -TypeName PSObject 
        $utilization = @{
            InputObject=$_ShowUtilization;
            MemberType='NoteProperty';
        }
        $this.maxHosts = [math]::Pow(2,(32 - $this.ipCidrRange.split("/")[1] )) - 2
        $this.usedHosts = $this.instances.count
        $this.percentUsed = ($this.usedHosts / $this.maxHosts).ToString("P")
        
        Add-Member @utilization -Name maxHosts -Value $this.maxHosts
        Add-Member @utilization -Name usedHosts -Value $this.usedHosts
        Add-Member @utilization -Name percentUsed -Value $this.percentUsed
        return $_ShowUtilization
    }
}

class Network {
    [string] $name
    [Subnet[]] $subnets = @()
}

function ConvertFrom-CIDR {
    <#
    .SYNOPSIS
    Converts a number of bits (0-32) to an IPv4 network mask string (e.g., "255.255.255.0").
  
    .DESCRIPTION
    Converts a number of bits (0-32) to an IPv4 network mask string (e.g., "255.255.255.0").
  
    .PARAMETER MaskBits
    Specifies the number of bits in the mask.
    #>
    param(
      [parameter(Mandatory=$true)]
      [ValidateRange(0,32)]
      [Int] $MaskBits
    )
    $mask = ([Math]::Pow(2, $MaskBits) - 1) * [Math]::Pow(2, (32 - $MaskBits))
    $bytes = [BitConverter]::GetBytes([UInt32] $mask)
    (($bytes.Count - 1)..0 | ForEach-Object { [String] $bytes[$_] }) -join "."
}

function Get-BroadcastAddress {
    param(
        [string] $subnet,
        [string] $subnetMask
    )

    filter Convert-IP2Decimal {
        ([IPAddress][String]([IPAddress]$_)).Address
    }


    filter Convert-Decimal2IP {
        ([System.Net.IPAddress]$_).IPAddressToString 
    }

    [UInt32]$_ip = $subnet | Convert-IP2Decimal
    [UInt32]$_subnet = $subnetMask | Convert-IP2Decimal
    [UInt32]$_broadcast = $_ip -band $_subnet 
    $_broadcast -bor -bnot $_subnet | Convert-Decimal2IP
}

function CheckAddressRange {
    param(
        [string] $ipCidrRange,
        [string] $networkIp
    )

    $subnet,$cidr = $ipCidrRange.split("/")
    $subnetMask = ConvertFrom-CIDR -MaskBits $cidr
    $broadcast = Get-BroadcastAddress -subnet $subnet -subnetMask $subnetMask

    $_start = [ipaddress]::Parse($subnet).GetAddressBytes()
    [array]::Reverse($_start)
    $_start_int = [BitConverter]::ToUInt32($_start,0)

    $_end = [ipaddress]::Parse($broadcast).GetAddressBytes()
    [array]::Reverse($_end)
    $_end_int = [BitConverter]::ToUInt32($_end,0)

    $_ip = [ipaddress]::Parse($networkIp).GetAddressBytes()
    [array]::Reverse($_ip)
    $_ip_int = [BitConverter]::ToUInt32($_ip,0)

    $_start_int -le $_ip_int -and $_end_int -ge $_ip_int
}


function New-GCPSession {
    param (
        [string]$OrganizationId,
        [string]$HostProjectId
    )

    $OrgId, $DefaultDomainName = Select-Organization -OrganizationId $OrganizationId
    Set-Variable -Name OrgId -Value $OrgId -Scope Global
    Set-Variable -Name DefaultDomainName -Value $DefaultDomainName -Scope Global
    
    $XpnID = Select-HostProject -HostProjectId $HostProjectId
    Set-Variable -Name XpnID -value $XpnID -Scope Global
}

function Select-Organization {
    param (
        [string]$OrganizationId
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
    
    while (!$selectedOrg) {
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
            Write-Error -Message "Error: User decided to exit prompt" -Category CloseError -ErrorAction Stop
        } elseif ($orgs.Count -le $selection ) {
            Clear-Host
            Write-Host -ForegroundColor Red "`nProvide a proper selection, [$selection] is not within range 0 - $($orgs.Count-1)"
            Start-Sleep 3
            Clear-Host
            continue
        } else {
            $selectedOrg = $orgs[$selection].name.Split("/")[1]
            $domainName = $orgs[$selection].displayName
            break
        }
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

    while (!$selectedXPN) {
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
            Write-Error -Message "Error: User decided to exit prompt" -Category CloseError -ErrorAction Stop
        } elseif ($xpns.Count -le $selection ) {
            Clear-Host
            Write-Host -ForegroundColor Red "`nProvide a proper selection, [$selection] is not within range 0 - $($xpns.Count-1)"
            Start-Sleep 3
            Clear-Host
            continue
        } else {
            $selectedXPN = $xpns[$selection].name
        }       
    }
    return $selectedXPN
}

function Get-Organizations {
    $orgs = @(gcloud organizations list --format=json | ConvertFrom-Json)

    $orgs
}

function Get-HostProjects {
    param (
        [string]$OrganizationId = $Global:OrgId
    )

    $hostProjects = @(gcloud compute shared-vpc organizations list-host-projects $OrganizationId --format=json | ConvertFrom-Json)
    $hostProjects
}

function Get-ServiceProjects {
    param (
        [string]$HostProjectId  = $Global:XpnId
    )

    $serviceProjects = @(gcloud compute shared-vpc list-associated-resources $HostProjectId --format=json | ConvertFrom-Json)
    $serviceProjects
}

function Get-Subnets {
    param (
        [string]$HostProjectId  = $Global:XpnId
    )
    $subnets = @(gcloud compute networks subnets list --project=$HostProjectId --format=json | ConvertFrom-Json)
    $subnets
}

function Get-Networks {
    param (
        [string]$HostProjectId  = $Global:XpnId
    )
    $networks = @(gcloud compute networks list --project=$HostProjectId --format=json | ConvertFrom-Json)
    $networks
}

function Show-SubnetUtilization {
    $_subnetUtilization = Get-SubnetUtilization
        
    foreach ($network in $_subnetUtilization.keys) {
        Write-Host -ForegroundColor Green "VPC Network: "  -NoNewline
        Write-Host $network
        foreach ($subnet in $_subnetUtilization[$network].subnets) {
            Write-Host -ForegroundColor Red "`tSubnetwork: "  -NoNewline
            Write-Host "$($subnet.name) - $($subnet.ipCidrRange) [$($subnet.ShowUtilization().percentUsed)]"
        }
    }
}
function Get-SubnetUtilization {
    $_subnets = Get-Subnets
    $_networks = Get-networks
    $_serviceProjects = Get-ServiceProjects
    
    $networks = @{}
    foreach($_network in $_networks){
        $network = [Network]::new()
        $network.name = $_network.name
        $networks.add($_network.name,$network)
    }
    foreach($_subnet in $_subnets) {
        
        $subnet = [Subnet]::new()
        
        $subnet.name = $_subnet.name
        $subnet.region = $_subnet.region.split("/")[-1]
        $subnet.ipCidrRange = $_subnet.ipCidrRange
        $_subnet_network = $_subnet.network.split("/")[-1]
        $networks[$_subnet_network].subnets += $subnet | Add-Member index ($networks[$_subnet_network].subnets.count) -PassThru
    }

    foreach ($_project in $_serviceProjects) {
        $_instances = Get-Instances -ProjectId $_project.id
        foreach($_instance in $_instances) {
            foreach($_interface in @($_instance.additionalAttributes.networkInterfaces)) {
                $instance = [Instance]::new()
                $instance.name = $_instance.name.split("/")[-1]
                $instance.networkIp = $_interface.networkIp
                $instance.network =  $_interface.network.split("/")[-1]
                $instance.projectId =  $_instance.project.split("/")[-1]
                $instance.state = $_instance.state
                foreach ($_subnet in $networks[$instance.network].subnets) {
                    if (CheckAddressRange -ipCidrRange $_subnet.ipCidrRange -networkIp $instance.networkIp) { 
                        $networks[$instance.network].subnets[$_subnet.index].instances += $instance | Add-Member index ($networks[$instance.network].subnets[$_subnet.index].instances.count) -PassThru
                    }
                }
            }
        }
    }
    $networks
}

function Get-Instances {
    param (
        [string]$ProjectId
    )
    $instances = @(
        gcloud asset search-all-resources `
        --asset-types='compute.googleapis.com/Instance' `
        --scope="projects/$ProjectId" `
        --format=json | ConvertFrom-Json
    )
    $instances
}

# To be done
function Get-HttpProxys {

}

# To be done
function Get-HttpsProxys {
# gcloud asset search-all-resources \
#   --scope='organizations/778357758552' \
#   --query='location=us-central1' \
#   --asset-types='compute.googleapis.com/TargetHttpsProxy,compute.googleapis.com/TargetHttpProxy'
 
 
# gcloud asset search-all-resources --scope=organizations/778357758552 --query="location=us-central1" 
# --asset-types="compute.googleapis.com/TargetHttpsProxy,compute.googleapis.com/TargetHttpProxy" 
# --format="table[box,title='HTTPS LB'](displayName,project,parentFullResourceName,assetType)"
}

function Get-ForwardingRules {

}

# To be done
# Exported Functions
$Exports = @(
    "New-GCPSession"
    ,"Get-Organizations"
    ,"Get-HostProjects"
    ,"Get-ServiceProjects"
    ,"Get-Subnets"
    ,"Get-Networks"
    ,"Get-SubnetUtilization"
    ,"Get-Instances"
    ,"Show-SubnetUtilization"
)

Export-ModuleMember -Function $Exports