#---------------------------------------------------------[Initialisations]--------------------------------------------------------
# Set Error Action to Silently Continue
$ErrorActionPreference = 'SilentlyContinue'

# Import Modules & Snap-ins
#Import-Module VMware.VimAutomation.Core -WarningAction SilentlyContinue
Import-Module VMware.VimAutomation.Core

#Import Logging Module
Import-Module /tmp/scripts/send-syslogmessage.psm1

#Set-PowerCLIConfiguration -Scope AllUsers -DefaultVIServerMode Multiple -InvalidCertificateAction Ignore -ParticipateInCEIP:$False -DisplayDeprecationWarnings:$False -Confirm:$False
Set-PowerCLIConfiguration -Scope ([VMware.VimAutomation.ViCore.Types.V1.ConfigurationScope]::User -bor [VMware.VimAutomation.ViCore.Types.V1.ConfigurationScope]::AllUsers -bor [VMware.VimAutomation.ViCore.Types.V1.ConfigurationScope]::Session) -DefaultVIServerMode Multiple -InvalidCertificateAction Ignore -ParticipateInCEIP:$False -DisplayDeprecationWarnings:$False -Confirm:$False
Import-Module PSLogging



#----------------------------------------------------------[Declarations]----------------------------------------------------------
#vCenter Credentials
$vCenterUser = "administrator@vsphere.local"
$vCenterPassword = "PASSWORD"


#-----------------------------------------------------------[Functions]------------------------------------------------------------

# Function to connect to Ralph3 inventory and return the authentication token and Ralph Server URL
Function Get-RalphToken
{
  $User = "USER"
  $Password = "PASSWORD"
  $Server = "ralph.example.com"
  $url = "https://$Server/api-token-auth/"
  $data = @{
    username = $User
    password = $Password
  }
  $resp = Invoke-RestMethod -Method 'Post' -Uri $url -Body $data
  return $resp.token,$Server
}

#Function to return the list of vCenter servers from Ralph3 inventory
Function  Get-RalphVirtualServers
{
  $vCentersRalphList = New-Object System.Collections.Generic.List[System.Object]
  $Filters = New-Object System.Collections.Generic.List[System.Object]
  $Filters = @( 'tag=mgmt')
  foreach ($Filter in $Filters)
  {
  $TokenServer, $ServerName = Get-RalphToken
  $Server = $ServerName
  $token = $TokenServer
  $token = "Token " + $token.Trim()
  $url = "https://$Server/api/virtual-servers/"
  if ($null -ne $Filter)
  {
    $url += "?$Filter"
  }
  $headers = @{
    "Authorization" = $token
  }
  $resp = Invoke-RestMethod -Method 'Get' -Uri $url -Headers $headers
  $vCentersRalphList += $resp.results.hostname
}
return $vCentersRalphList
}

# Function to connect to each vCenter server and list snapshots of the VMs
Function List_Snapshots {
    Param (
        [Parameter(Mandatory=$true)]
        [string]$vCenterServer
    )

    $thisconn = Connect-VIServer -Server $vCenterServer -User $vCenterUser -Password $vCenterPassword

    $output = @()

    $vms = Get-VM

    foreach ($vm in $vms) {
        $snapshots = Get-Snapshot -VM $vm
        if ($snapshots) {
            foreach ($snapshot in $snapshots) {
                $output += [PSCustomObject]@{
                    vCenterServer = $vCenterServer
                    VMName = $vm.Name
                    SnapshotName = $snapshot.Name
                    SnapshotSize = [math]::Round($snapshot.SizeGB, 1)
                    CreationDate = $snapshot.Created
                }
            }
        }
    }

    $message = $output

    Disconnect-VIServer -Server $vCenterServer -Confirm:$false

    return $message
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------
#Script Execution goes here
#main()

$vCentersList = Get-RalphVirtualServers

$emailBodyHTML = ""

foreach ($vCenterServer in $vCentersList) {
    $allMessages = List_Snapshots $vCenterServer

    if ($allMessages.Count -gt 0) {
        $tableRows = foreach ($message in $allMessages) {
            $vmName = $message.VMName
            $snapshotName = $message.SnapshotName
            $snapshotSize = $message.SnapshotSize.ToString("F1")
            $creationDate = $message.CreationDate

            "<tr style='border: 1px solid black;'>
                <td style='border: 1px solid black; padding: 8px;'>$vmName</td>
                <td style='border: 1px solid black; padding: 8px;'>$snapshotName</td>
                <td style='border: 1px solid black; padding: 8px;'>$snapshotSize</td>
                <td style='border: 1px solid black; padding: 8px;'>$creationDate</td>
            </tr>"
        }

        $vCenterEmailBodyHTML = @"
            <h2><strong>vCenter Server: $vCenterServer</strong></h2>
            <table style='border-collapse: collapse;'>
                <thead>
                    <tr style='border: 1px solid black;'>
                        <th style='border: 1px solid black; padding: 8px;'>VM Name</th>
                        <th style='border: 1px solid black; padding: 8px;'>Snapshot Name</th>
                        <th style='border: 1px solid black; padding: 8px;'>Snapshot Size (GB)</th>
                        <th style='border: 1px solid black; padding: 8px;'>Creation Date</th>
                    </tr>
                </thead>
                <tbody>
                    $($tableRows -join "")
                </tbody>
            </table>
"@

        $emailBodyHTML += $vCenterEmailBodyHTML
    } else {
        $emailBodyHTML += "<h2><strong>vCenter Server: $vCenterServer</strong></h2>"
        $emailBodyHTML += "<p>No snapshots found</p>"
    }
}

$emailBodyHTML = "<html><body>" + $emailBodyHTML + "</body></html>"

$emailParams = @{
    From = "from@example.com"
    To = "to@example.com"
    Subject = "Management VMs Snapshots Checker Report"
    Body = $emailBodyHTML
    BodyAsHtml = $true
    Priority = "High"
    SmtpServer = "smtp.example.com"
}

Send-MailMessage @emailParams

