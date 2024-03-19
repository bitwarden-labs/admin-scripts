# Prompt for input

$cloud_flag = 1 # Self-hosted Bitwarden or Cloud?
if ($cloud_flag -eq 1) {
    $api_url = "https://api.bitwarden.com"
    $identity_url = "https://identity.bitwarden.com"
}
else {
    $api_url = "https://YOUR-FQDN/api" # Set your Self-Hosted API URL
    $identity_url = "https://YOUR-FQDN/identity" # Set your Self-Hosted Identity URL
}

#$org_client_id = Read-Host 'Organization Client ID'
#$org_client_secret_hidden = Read-Host 'Organization Client Secret (Hidden)' -AsSecureString
# Convert the secure string to plain text (for simplicity)
#$org_client_secret = [System.Net.NetworkCredential]::new('', $org_client_secret_hidden).Password

$org_client_id = "<REPLACE WITH YOUR CLIENT ID>"
$org_client_secret = "<REPLACE WITH YOUR CLIENT SECRET>"


# Request the token
$body = @{
    grant_type = 'client_credentials'
    scope = 'api.organization'
    client_id = $org_client_id
    client_secret = $org_client_secret
}

$response = Invoke-RestMethod -Uri "$identity_url/connect/token" -Method POST -ContentType 'application/x-www-form-urlencoded' -Body $body
$ACCESS_TOKEN = $response.access_token

# Get the organization members
$headers = @{
	'Content-Type' = 'application/json'
	'Accept' = 'application/json'
    Authorization = "Bearer $ACCESS_TOKEN"
}

$membersData = Invoke-RestMethod -Uri "$api_url/public/members/" -Headers $headers

Write-Output "Modifying the following members:"
Write-Output "member id,email,externalid"

foreach ($member in $membersData.data) {
    $memberid = $member.id
    $email = $member.email
    $externalid = $member.externalid
    
    #this checking is for skipping OKTA external ID and empty external ID. Please modify it based on your use case.
    if (-not [string]::IsNullOrEmpty($externalid) -and $externalid.Length -ne 20) {
        Write-Output "$memberid,$email,$externalid"
		$member_data = (Invoke-RestMethod -Method GET -Uri $api_url/public/members/$memberid -Headers $headers)
		$params = @{'type'=$member_data.'type';accessAll=$member_data.accessAll;externalId=$null;resetPasswordEnrolled=$member_data.resetPasswordEnrolled;collections=$member_data.collections} | ConvertTo-Json
		
		#adding confirmation so that the script won't modify all users at the beginning. Remove it if you want to modify all non-interactively.
		$answer = Read-Host "Do you want to empty this member? (Y/N)"
		if ($answer -eq 'Y' -or $answer -eq 'y') {
			Invoke-RestMethod -Method PUT -Uri $api_url/public/members/$memberid -Headers $headers -Body $params		
			Start-Sleep -Milliseconds 300
		}
	}

}
