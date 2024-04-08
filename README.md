# Welcome to the Admin Scripts Repo!

Here you will find a variety of Bash, Powershell and Python script examples that can be utilized as a jumping off point for creating your own automation scripts to be used with the [Bitwarden CLI](https://bitwarden.com/help/cli/) and/or [APIs](https://bitwarden.com/help/bitwarden-apis/). 

***Important things to note:***
- Admin Scripts are currently divided into separate folders by type: _API Scripts, Bash, Powershell, and Python_
- Admin scripts are meant to act as examples. They are not written in a way that can be run as is and so will require at least some modifcations/insertions
- Most scripts contain commented instructions, so please read through thoroughly/carefully

*Additional documenation to help you get started:*<br>
[Password Manager CLI Guide](https://bitwarden.com/help/cli/)<Br>
[Vault Management API Reference](https://bitwarden.com/help/vault-management-api/)<br>
[Bitwarden Public API Reference](https://bitwarden.com/help/api/)<br>
[Guide to using Postman to access the Bitwarden API](https://community.bitwarden.com/t/guide-to-using-postman-to-access-the-bitwarden-api/56475)<br>
[Guide for using the Vault Management API in Python](https://github.com/bitwarden-labs/admin-scripts/wiki/Vault-Management-API-in-Python)



## Commonly Used Scripts Examples

### Collection Permission Inheritance
[Inherit Parent Permissions (CLI/Bash)](https://github.com/bitwarden-labs/admin-scripts/blob/main/Bash%20Scripts/inheritparentpermissions.sh)


### Confirm Accepted Users
[Password Manager: Confirm All Accepted Users (CLI/Bash)](https://github.com/bitwarden-labs/admin-scripts/blob/main/Bash%20Scripts/bwConfirmAcceptedPeople.sh)<br>
[Password Manager: Confirm All Accepted Users (CLI/Powershell)](https://github.com/bitwarden-labs/admin-scripts/blob/main/Powershell/bwConfirmAcceptedPeople.ps1)<br>
[Password Manager: Confirm All Accepted Users (API/Powershell)](https://github.com/bitwarden-labs/admin-scripts/blob/main/API%20Scripts/Bitwarden%20Public%20API/bwConfirmAccepted-api.ps1)<br>
[Password Manager: Confirm All Accepted Users with Password (CLI/Bash)](https://github.com/bitwarden-labs/admin-scripts/blob/main/Bash%20Scripts/bwConfirmAcceptedPeopleWPass.sh)<br>
[Secrets Manager: Confirmed All Accepted Users (CLI/Bash)](https://github.com/bitwarden-labs/admin-scripts/blob/main/Bash%20Scripts/bwConfirmAcceptedPeopleSM.sh)<br>
[Secrets Manager: Confirmed All Accepted Users (CLI/Powershell)](https://github.com/bitwarden-labs/admin-scripts/blob/main/Powershell/bwConfirmAcceptedPeopleSM.ps1)

### List Organization Members
[List All Organization Members (CLI/Bash)](https://github.com/bitwarden-labs/admin-scripts/blob/main/Bash%20Scripts/listmembers.sh)<Br>
[List All Organization Members (CLI/Powershell)](https://github.com/bitwarden-labs/admin-scripts/blob/main/Powershell/ListMembers.ps1)<Br>
[List ALl Organization Members w/ 2FA Check (CLI/Powershell)](https://github.com/bitwarden-labs/admin-scripts/blob/main/Powershell/ListMembers2FACheck.ps1)



## Disclaimer
Please note that the projects in Bitwarden Labs are experimental and not officially supported by Bitwarden. They are provided "as is" with no guarantees.
