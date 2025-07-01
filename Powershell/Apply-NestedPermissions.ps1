<#
.SYNOPSIS
    Recursively applies permissions to all sub-collections starting from a specified root collection and displays a tree structure of the collections with their permissions.

.PARAMETER EMAIL
    The email for the Bitwarden CLI login.

.PARAMETER MASTER_PASSWORD
    The master password for the CLI login, passed securely.

.PARAMETER ORGANIZATION_ID
    The ID of the organization whose collections should be managed.

.PARAMETER ROOT_COLLECTION
    The name of the root collection to start applying permissions from.

.PARAMETER LOG_FILE
    Optional log file for storing script logs.

.EXAMPLE
    bw logout; bw config server https://vault.bitwarden.eu; .\Apply-NestedPermissions.ps1 -EMAIL "user@example.com" -MASTER_PASSWORD (ConvertTo-SecureString "YourPassword" -AsPlainText -Force) -ORGANIZATION_ID "your-organization-id" -ROOT_COLLECTION "YourRootCollection"

    This command logs out of Bitwarden, configures the server URL, and runs the script with specified email, master password, organization ID, and root collection name.

.EXAMPLE
    bw logout; .\Apply-NestedPermissions.ps1 -EMAIL "admin@domain.com" -MASTER_PASSWORD (ConvertTo-SecureString "AdminPassword" -AsPlainText -Force) -ORGANIZATION_ID "org-1234" -ROOT_COLLECTION "AdminCollection"

    This command logs out of Bitwarden, and then runs the script with the provided login credentials and parameters for applying permissions to a specified root collection.
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$EMAIL,

    [Parameter(Mandatory=$true)]
    [SecureString]$MASTER_PASSWORD,

    [Parameter(Mandatory=$true)]
    [string]$ORGANIZATION_ID,

    [Parameter(Mandatory=$true)]
    [string]$ROOT_COLLECTION,

    [string]$LOG_FILE
)

# Helper function for logging
function Write-Log {
    param (
        [string]$Message,
        [string]$Type = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Type] - $Message"
    Write-Host "$logEntry"

    if ($LOG_FILE) {
        Add-Content -Path $LOG_FILE -Value $logEntry
    }
}

# Convert secure strings to plain text
function ConvertFrom-SecureStringPlain {
    param ([SecureString]$SecureString)
    return [System.Runtime.InteropServices.Marshal]::PtrToStringUni(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    )
}

# CLI authentication and session setup
function Authenticate-Bitwarden {
    Write-Log "Authenticating with Bitwarden CLI..."
    $password = ConvertFrom-SecureStringPlain -SecureString $MASTER_PASSWORD
    $loginResult = & bw login $EMAIL $password --raw

    if (!$loginResult) {
        Write-Log "Failed to authenticate with Bitwarden CLI." "ERROR"
        exit 1
    }

    Write-Log "🔓 Unlocking Bitwarden vault..."
    $sessionKey = & bw unlock $password --raw

    if (!$sessionKey) {
        Write-Log "Failed to unlock Bitwarden vault." "ERROR"
        exit 1
    }

    Write-Log "Successfully unlocked Bitwarden vault."
    $env:BW_SESSION = $sessionKey
}

# Helper function to format and display the tree
function Display-Tree {
    param (
        [array]$Nodes,
        [string]$Indent = ""
    )

    foreach ($node in $Nodes) {
        Write-Host "$Indent$($node.Name)"
        Write-Host "$Indent   Permissions: $($node.Permissions -join ', ')"
        if ($node.Children.Count -gt 0) {
            Display-Tree -Nodes $node.Children -Indent "$Indent   "
        }
    }
}

# Recursive function for permission application
function Apply-RecursivePermissions {
    param (
        [string]$ParentName,
        [string]$ParentID,
        [array]$AllCollections,
        [int]$Depth = 0
    )

    # Fetch parent permissions
    Write-Log "Fetching permissions for parent collection: $ParentName ($ParentID)"
    $parentPermissions = & bw get org-collection $ParentID --organizationid $ORGANIZATION_ID --session $env:BW_SESSION | ConvertFrom-Json
    if (-not $parentPermissions) {
        Write-Log "Failed to fetch parent collection permissions for $ParentName ($ParentID)" "ERROR"
        return
    }

    $groupPermissions = $parentPermissions.groups

    # Node to represent the current parent in the tree
    $currentNode = @{
        Name = $ParentName
        Permissions = $groupPermissions | ForEach-Object {
            "$($_.id) - Manage: $($_.manage), ReadOnly: $($_.readOnly), HidePasswords: $($_.hidePasswords)"
        }
        Children = @()
    }

    # Find direct children of the current parent
    $childCollections = $AllCollections | Where-Object { $_.name -match "^$($ParentName)/" -and ($_.name -split '/').Count -eq ($ParentName -split '/').Count + 1 }

    foreach ($child in $childCollections) {
        Write-Log "[Depth $Depth] Applying permissions to child collection: $($child.name)"

        # Update child collection permissions using CLI
        $childPermissionsJson = & bw get org-collection $child.id --organizationid $ORGANIZATION_ID --session $env:BW_SESSION | ConvertFrom-Json
        $childPermissionsJson.groups = $groupPermissions

        # Update the child collection with new permissions
        $updatedCollectionJson = $childPermissionsJson | ConvertTo-Json -Depth 10
        try {
            $encodedJson = $updatedCollectionJson | bw encode
            & bw edit org-collection $child.id --organizationid $ORGANIZATION_ID --session $env:BW_SESSION --raw $encodedJson
        } catch {
            Write-Log "Failed to apply permissions to child collection: $($child.name) - $_" "ERROR"
            continue
        }

        Write-Log "   Permissions applied to child collection: $($child.name)"

        # Recurse into this child collection
        $childNode = Apply-RecursivePermissions -ParentName $child.name -ParentID $child.id -AllCollections $AllCollections -Depth ($Depth + 1)
        $currentNode.Children += $childNode
    }

    return $currentNode
}

# Main function
function Main {
    Write-Log "Starting Bitwarden multilevel permission script."

    Authenticate-Bitwarden

    # Retrieve collections
    Write-Log "Fetching all collections for organization ID: $ORGANIZATION_ID"
    $collections = & bw list org-collections --organizationid $ORGANIZATION_ID --session $env:BW_SESSION | ConvertFrom-Json

    # Find root collection
    $rootCollection = $collections | Where-Object { $_.name -eq $ROOT_COLLECTION }
    if (-not $rootCollection) {
        Write-Log "Root collection '$ROOT_COLLECTION' not found. Exiting." "ERROR"
        exit 1
    }

    $tree = Apply-RecursivePermissions -ParentName $rootCollection.name -ParentID $rootCollection.id -AllCollections $collections

    # Display the tree
    Write-Log "Displaying collection hierarchy with permissions:"
    Display-Tree -Nodes @($tree)

    Write-Log "Successfully completed multilevel permission inheritance."
}

# Execute the main function
Main
