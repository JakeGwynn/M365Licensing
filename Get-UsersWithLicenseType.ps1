<#
Copyright 2023 Jake Gwynn

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), 
to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>
function Get-UsersWithLicenseType {
    param (
        [Parameter(Mandatory=$true)]
        $LicenseSkuIdList,
        [Parameter(Mandatory=$false)]
        [string]$ExportFolderPath
    )
    # Generic List to store user info
    $UserList = New-Object System.Collections.Generic.List[psobject]

    # Get all users and groups in the tenant
    Write-Host "Getting all users in the tenant"
    $Users = Get-MsolUser -All  
    Write-Host "Getting all groups in the tenant"
    $Groups = Get-MsolGroup -All

    # Create the $ExportFolderPath if it doesn't exist
    if ($ExportFolderPath) {
        if (-not (Test-Path -Path $ExportFolderPath)) {
            New-Item -Path $ExportFolderPath -ItemType Directory
        }
    }

    foreach ($LicenseSkuId in $LicenseSkuIdList) {
        Write-Host "Checking for users with $($LicenseSkuId) license type"
        foreach ($User in $Users) {
            # Check if the user has the old license type
            $UserLicense = $null
            $DirectlyAssigned = $null
            $UserGroups = $null
            $UserGroupsCombinedArray = $null
            $UserGroupsCombined = $null
            $UserObject = [pscustomobject]@{
                UserPrincipalName = $null
                DirectlyAssigned = $null
                GroupAssigned = $null
                Groups = $null
            }

            $UserLicense = $User.Licenses | Where-Object {$_.AccountSkuId -eq $LicenseSkuId}
            #Write-Host "User $($User.UserPrincipalName) has $($UserLicense.GroupsAssigningLicense) license type"

            if ($UserLicense) {
                if ($User.ObjectId -in $UserLicense.GroupsAssigningLicense -or $UserLicense.GroupsAssigningLicense.Count -eq 0) {
                    $DirectlyAssigned = $true
                } else {
                    $DirectlyAssigned = $false
                }

                $UserGroups = $Groups | Where-Object {$_.ObjectId -in $UserLicense.GroupsAssigningLicense}
                
                if ($UserGroups) {
                    foreach ($Group in $UserGroups) {
                        $GroupDisplayName = $Group.DisplayName
                        $GroupId = $Group.ObjectId
                        Add-Member -InputObject $UserObject -MemberType NoteProperty -Name "'$GroupDisplayName' | $GroupId" -Value $true
                    }
                    $UserGroupsCombinedArray = $UserGroups | ForEach-Object {"$($_.DisplayName) | $($_.ObjectId)"}
                    $UserGroupsCombined = $UserGroupsCombinedArray -join "`n"
                    $GroupAssigned = $true
                } else {
                    $GroupAssigned = $false
                }

                # Add the user info to the list
                $UserObject.UserPrincipalName = $User.UserPrincipalName
                $UserObject.DirectlyAssigned = $DirectlyAssigned
                $UserObject.GroupAssigned = $GroupAssigned
                $UserObject.Groups = $UserGroupsCombined
                
                $UserList.Add($UserObject)
            }
        }
        if ($ExportFolderPath) {
            Write-Host "Exporting $($LicenseSkuId) license type users to CSV"
            $LicenseSkuName = ($LicenseSkuId -split ":")[1]
            $ExportPath = Join-Path -Path $ExportFolderPath -ChildPath "DirectlyLicensedUsers--$LicenseSkuName.csv"

            $PropertyList = $UserList | ForEach-object { $_.PSObject.Properties.Name } | Select-Object -Unique

            $UserList | Select-Object $PropertyList | Export-Csv -Path $ExportPath -NoTypeInformation
        } else {
            return $UserList
        }
    }
}

Connect-MsolService

# https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference
Get-MsolAccountSku

$LicensesToCheck = "jakegwynndemo:SPE_E5", "jakegwynndemo:SPE_E3", "jakegwynndemo:SPE_E1"


Get-UsersWithLicenseType -LicenseSkuId $LicensesToCheck -ExportFolderPath "C:\temp\"

