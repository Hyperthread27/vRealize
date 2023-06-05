<#Get-vRADeploymentVMList
This PowerShell script gathers a list of all the Deployments within vRealize/Aria Automation, and outputs the Deployment Name,attached VMs, and Project ID to a CSV#>

# Set the necessary variables
$vraUrl = Read-Host "Enter the vRA URL.ex=https://acme-vra-001.acme.com"
$logindomain = Read-Host "Enter the login domain.ex=acme.com"
$cred = Get-Credential
$headers = @{
    'Accept' = 'application/json'
    'Content-Type' = 'application/json'
}

$password = $cred.GetNetworkCredential().Password

# Authenticate and get the refresh token
$authData = @{
    'username' = $cred.UserName
    'password' = $password
    'domain'   = $logindomain
}
$authUrl = "$vraUrl/csp/gateway/am/api/login?access_token"
$authResponse = Invoke-RestMethod -Uri $authUrl -Method Post -Headers $headers -Body ($authData | ConvertTo-Json) -SkipCertificateCheck
$refreshtoken = $authResponse.refresh_token

# Use Refresh Token to get Access Token
$accesstokenUrl = "$vraURL/iaas/api/login"
$TokenResponse = Invoke-RestMethod -Uri $accesstokenUrl -Method Post -Headers $headers -Body (@{'refreshToken' = $refreshtoken} | ConvertTo-Json) -SkipCertificateCheck
$accessToken = $TokenResponse.token
# Set the headers with the access token
$headers['Authorization'] = "Bearer $accessToken"

<#Get the total number of pages of deployments
 size must be used in conjunction with the page number for pagination to work, maximum size of 200 #>
$deploymentsUrl = "$vraUrl/deployment/api/deployments?page=0&size=100"
$deploymentsResponse = Invoke-RestMethod -Uri $deploymentsUrl -Headers $headers -SkipCertificateCheck
$deploymentsPageTotal = $deploymentsResponse.totalPages
$incpages = 0
$deploymentsarray = @()

# Populate the Deployment Array
Do {
    $incpages++
    $url = $deploymentsUrl -replace 'page=0', "page=$incpages"
    $getresults = Invoke-RestMethod -Uri $url -Headers $headers -SkipCertificateCheck
    $deploymentsarray += $getresults.content
} while ($incpages -lt $deploymentsPageTotal)

# Create an array to store the VM data
$vmData = @()

# Iterate through each deployment
foreach ($deployment in $deploymentsArray) {
    $deploymentName = $deployment.name
    $projectId = $deployment.projectId
    write-host $projectId
    

    # Get the project details
    $projectUrl = "$vraUrl/project-service/api/projects/$projectId"
    $projectResponse = Invoke-RestMethod -Uri ($projectUrl) -Headers $headers -SkipCertificateCheck
    $projectName = $projectResponse.name
    Write-Host $projectName

    # Get the virtual machines in the deployment
    $virtualMachinesUrl = "$vraUrl/deployment/api/deployments/$($deployment.id)/resources"
    $virtualMachinesResponse = Invoke-RestMethod -Uri ("$virtualMachinesUrl" + "?resourceTypes=Cloud.vSphere.Machine") -Headers $headers -SkipCertificateCheck
    $virtualMachines = $virtualMachinesResponse.content.properties.resourceName
    Write-Host $virtualMachines

    # Create an array to store the virtual machines within the deployment
    $vmDataDeployment = @()

    # Add VM data to the deployment array
    foreach ($virtualMachine in $virtualMachines) {
        $vmName = $virtualMachine
        $vmDataDeployment += [PSCustomObject]@{
            'Deployment Name' = $deploymentName
            'Project Name' = $projectName
            'VM Name' = $vmName
        }
    }

    # Add the deployment's virtual machines to the main VM data array
    $vmData += $vmDataDeployment
}

# Generate CSV file name with current date and time
$dateTime = Get-Date -Format 'yyyyMMdd_HHmmss'
$csvFileName = "vRA_VMInventory_$dateTime.csv"

# Export VM data to a CSV file
$desktopPath = [Environment]::GetFolderPath('Desktop')
$csvPath = Join-Path -Path $desktopPath -ChildPath $csvFileName
$vmData | Export-Csv -Path $csvPath -NoTypeInformation

Write-Host "VM inventory exported to: $csvPath"
