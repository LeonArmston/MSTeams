<#
Script Generates report of MS Teams in an Office 365 tenancy created in the past specified number of days
Requires an account with the minimum Office 365 roles SharePoint Administrator and Teams Service Administrator
Enter output CSV Path, SP Admin Site &amp; number of previous days to report on.

Blog Article
https://www.leonarmston.com/2019/12/report-on-all-microsoft-teams-created-in-the-past-x-number-of-days/

#>
$outputpath = "c:\temp\leonarmston_Teams1.csv"
$SPOAdminSite = "https://leonarmston-admin.sharepoint.com"
 
$offsetDays = 7 #Enter the number of previous days to report on
 
if (Get-InstalledModule -Name "MicrosoftTeams" -ErrorAction SilentlyContinue)
{
    $TeamsModule = Get-InstalledModule -Name "MicrosoftTeams" -ErrorAction SilentlyContinue
    Write-Host "Module: $($TeamsModule.Name) installed and it is version $($TeamsModule.Version)" -ForegroundColor Green
}
else
{
    Write-Host "Microsoft Teams PowerShell Module (MicrosoftTeams) Not Installed" -ForegroundColor Red
    Write-Host "Run PowerShell as an Administrator and install the PowerShell module MicrosoftTeams Online by running the command:"
    Write-Host "Install-Module MicrosoftTeams" -ForegroundColor Yellow
    Return
}
 
if (Get-InstalledModule -Name "SharePointPnPPowerShellOnline" -ErrorAction SilentlyContinue)
{
    $PnPModule = Get-InstalledModule -Name "SharePointPnPPowerShellOnline" -ErrorAction SilentlyContinue
    Write-Host "Module: $($PnPModule.Name) installed and it is version $($PnPModule.Version)" -ForegroundColor Green
}
else
{
    Write-Host "PnP PowerShell Module (SharePointPnPPowerShellOnline) Not Installed" -ForegroundColor Red
    Write-Host "Run PowerShell ISE as an Administrator and install the PowerShell module SharePointPnPPowerShell Online by running the command:"
    Write-Host "Install-Module SharePointPnPPowerShellOnline" -ForegroundColor Yellow
    Return
}

if (Get-InstalledModule -Name "AzureAD" -ErrorAction SilentlyContinue)
{
    $AADModule = Get-InstalledModule -Name "AzureAD" -ErrorAction SilentlyContinue
    Write-Host "Module: $($AADModule.Name) installed and it is version $($AADModule.Version)" -ForegroundColor Green
}
else
{
    Write-Host "Azure Active Directory Module (AzureAD) Not Installed" -ForegroundColor Red
    Write-Host "Run PowerShell ISE as an Administrator and install the PowerShell module AzureAD by running the command:"
    Write-Host "Install-Module SharePointPnPPowerShellOnline" -ForegroundColor Yellow
    Return
}
 
 
if ($null -eq $cred)
{
    $cred = Get-Credential -Message "Enter an account with Teams Administrative credentials"
}
 
try
{
    Connect-MicrosoftTeams -Credential $cred -ErrorAction Stop
    Connect-PnPOnline -Url $SPOAdminSite -Credentials $cred -ErrorAction Stop
    Connect-AzureAD -Credential $cred
    $teams = Get-Team -ErrorAction Stop
    $list = Get-PnPList -Identity "/Lists/DO_NOT_DELETE_SPLIST_TENANTADMIN_AGGREGATED_SITECO" -ErrorAction Stop
    $sites = Get-PnPListItem -List $list -Query `
        "<View><Query><Where><Geq><FieldRef Name='TimeCreated' /><Value Type='DateTime'><Today OffsetDays='-$offsetDays' /></Value></Geq></Where></Query></View>" -ErrorAction Stop
}
Catch
{
    Write-Host "Error Message: $($_.exception.message) - TERMINATING SCRIPT" -ForegroundColor Red
    Return
}
 
 
$Hashtable = @()
 
foreach ($team in $teams)
{
    $connectedSPSite = $sites.FieldValues | Where-Object { $_.GroupId -eq $team.GroupId }
    if ($connectedSPSite.Count)
    {
 
        $channels = Get-TeamChannel -GroupId $team.GroupId
 
        $users = Get-TeamUser -GroupId $team.GroupId
 
        $owners = $users | Where-Object { $_.Role -eq "owner" }

        $OwnersArray = @{ }
        $owners | ForEach-Object { $user = Get-AzureADUser -ObjectId $_.UserId; $OwnersArray.Add($user.Mail, $user.Mail) }
        $OwnersArrayDelimited = $OwnersArray.Values -join ";"
 
        $members = $users | Where-Object { $_.Role -eq "member" }
     
        $guestusers = $users | Where-Object { $_.Role -eq "guest" }
 
        if ($team.Archived -eq $false)
        {
            $status = "Active"
        }
 
        if ($team.Archived -eq $true)
        {
            $status = "Archived"
        }
 
        $connectedSPSite = $sites.FieldValues | Where-Object { $_.GroupId -eq $team.GroupId }
 
        $Hashtable += New-Object psobject -Property @{
            'DisplayName'       = $team.DisplayName;
            'Channels'          = $channels.Count;
            'Team members'      = $members.count;
            'Created By'        = $connectedSPSite.CreatedBy;
            'Owners'            = $owners.count;
            'OwnersMail'        = $OwnersArrayDelimited;
            'Guests'            = $guestusers.count;
            'Privacy'           = $team.Visibility;
            'Status'            = $status;
            'Description'       = $team.Description;
            'Classification'    = $team.Classification
            'Group ID'          = $team.GroupId;
            'MailNickName'      = $team.MailNickName;
            'Connected SP Site' = $connectedSPSite.SiteUrl;
            'Time Created'      = $connectedSPSite.TimeCreated;
            'Storage Used'      = $connectedSPSite.StorageUsed;
            'Num Of Files'      = $connectedSPSite.NumOfFiles;
        }
    }
 
}
 
 
$Hashtable | Select-Object 'Time Created', DisplayName, Channels, "Created By", "Team members", Owners, OwnersMail, Guests, `
    Privacy, Status, Description, Classification, "Group ID", MailNickName, "Connected SP Site", `
    "Storage Used", "Num Of Files" | Export-Csv $outputpath -NoTypeInformation