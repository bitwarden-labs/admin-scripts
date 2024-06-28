# Powershell scripting best-practices

## General guidance

The [Bitwarden CLI](https://bitwarden.com/help/cli/) provides administrators with the ability to automate common administrative tasks. Some of these tasks may be one-off, where others you may wish to run on a schedule via the Windows Task Scheduler. If your preferred workstation is Windows-based, this repository contains examples of different use-cases from past customer feedback. This guide intends to provide reference information on how to start writing your own automation scripts for the Bitwarden CLI and APIs. Use the information below to handle the initial setup of the script, and then add your own business logic as-needed.

## Storing authentication information

Windows provides built-ins for encrypting data at-rest based on the users' existing credentials called SecureString. How many of these files you need depends on how many secrets you need to store. This allows you to write scripts that retrieve their own authentication credentials, rather than having to supply them at runtime. The examples below are recommended to be the first couple of lines of your script, and also serve as self-documenting setup instructions for the script itself.

### One Secret

```
# Depends on file "secureString.txt" which can be created by first running:
# Read-Host "Enter Master Password" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString.txt"
```

### Two Secrets

```
# Depends on file "secureString.txt" which can be created by first running:
# Read-Host "Enter Master Password" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString.txt"
# Depends on file "secureString_secret.txt" which can be created by first running:
# Read-Host "Enter client_secret" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString_secret.txt"
```

### Three Secrets

```
# Depends on file "secureString.txt" which can be created by first running:
# Read-Host "Enter Master Password" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString.txt"
# Depends on file "secureString_secret.txt" which can be created by first running:
# Read-Host "Enter client_secret" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString_secret.txt"
# Depends on file "secureString_usersecret.txt" which can be created by first running:
# Read-Host "Enter user client_secret" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString_usersecret.txt"
```

## Retrieving Stored Authentication information

At the appropriate time in your script, you will need to retrieve the secured authentication information and pass it into whichever interface you are interacting with.

### Authenticate with the CLI

```
$password = Get-Content "secureString.txt" | ConvertTo-SecureString
$cred = New-Object System.Management.Automation.PSCredential "null", $password
$session_key = , $cred.GetNetworkCredential().password | powershell -c 'bw unlock --raw'
```

You may now export `$session_key` to a global variable, or pass it inline to `bw.exe --session`.

### Authenticate with an API

```
$org_client_secret = Get-Content "secureString_secret.txt" | ConvertTo-SecureString
$body = "grant_type=client_credentials&scope=api.organization&client_id=$org_client_id&client_secret=$org_client_secret_key"
$bearer_token = (Invoke-RestMethod -Method POST -Uri $identity_url/connect/token -Body $body).access_token

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add('Authorization',('Bearer {0}' -f $bearer_token))
$headers.Add('Accept','application/json')
$headers.Add('Content-Type','application/json')
```

You may now reference the `$headers` variable to include your authentication token in, for example, `Invoke-RestMethod -Headers $headers`.

# Running a script

Whether you are downloading one of our examples, or writing your own, after you have your script ready we recommend ensuring you have the Bitwarden CLI installed and present in your $PATH. Most of our example scripts assume that you have logged into the CLI tool using an administrative account, but not unlocked the Vault. This ensures you can, for example, configure the CLI to default to a self-hosted server or Cloud environment as-needed.
