#######################
##### DESCRIPTION #####
#######################
# This Powershell script relies on the Bitwarden CLI tool, which can be found here: https://bitwarden.com/help/cli/#download-and-install
# This Powershell script will attempt the following steps:
# 1. Log into Bitwarden
# 2. Obtain your Organization ID
# 3. Obtain a list of all Login Items in your Bitwarden Organization Vault
# 4. Output the Login Item name, username, and Item ID 
# 5. Save the output to $($CsvPath).
# 6. Log out of Bitwarden. 
# This script is provided as a courtesy. It is not official Bitwarden software. 
# Bitwarden does not make any guarantees to support this script's functionality in future updates. 
# This script does not attempt to provide rigorous error handling.
#######################
#######################
######## NOTES ########
#######################
# This script was tested using Bitwarden version 2022.8.0
# Depending on how Bitwarden CLI is configured on your machine, you may need to change references to "./bw" to just "bw".
#######################


#Variables
$CsvPath = "C:\temp\bwitems.csv"

#Text introduction
write-host "This Powershell script relies on the Bitwarden CLI tool, which can be found here: `n
https://bitwarden.com/help/cli/#download-and-install `n
`n
This Powershell script will attempt the following steps:`n
1. Log into Bitwarden `n
2. Obtain your Organization ID `n
3. Obtain a list of all Login Items in your Bitwarden Organization Vault `n
4. Output the Login Item name, username, and Item ID `n
5. Save the output to $($CsvPath).`n
6. Log out of Bitwarden. `n
This script is provided as a courtesy. It is not official Bitwarden software. `n
Bitwarden does not make any guarantees to support this script's functionality in future updates. `n
This script does not attempt to provide rigorous error handling.`n
`n
Please enter your Bitwarden login information." 

# Bitwarden login prompt. Saves session key to prevent repetitive login prompts.
$sessionKey = powershell -c './bw login --raw'

# gets details of your Organizations
$org = ./bw.exe list --session $sessionKey organizations | ConvertFrom-Json

write-host "The Organization name is $($org.name) and the ID is $($org.id)"

# lists all Items in the Organization. 
# assuming only one Organization exists. If so, $org.id is your Organization's id.
$response = ./bw.exe list --session $sessionKey items --organizationid $org.id
$items = $response | ConvertFrom-Json

#displays on screen the name, username, and id for all items in Organization
foreach ($item in $items)
{
write-host "$($item.name) : $($item.login.username) : $($item.id)"
}

#log out of Bitwarden.
./bw.exe logout

#goes through items, pipes into a csv file
ForEach-Object {
	foreach ($item in $items)
	{
		[pscustomobject]@{
			"Item Name" = $item.name
			"Username" = $item.login.username
			"Item ID" = $item.id
		}
	} 
} |
Export-Csv $CsvPath

write-host "Created csv file at $($CsvPath)."

#keeps window open for 30 seconds
Start-Sleep -Seconds 30