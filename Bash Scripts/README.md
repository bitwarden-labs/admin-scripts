# General guide and description of the scripts

## List of things you generally need to run the scripts in this repo:
1. Bitwarden CLI
https://bitwarden.com/help/cli/#download-and-install

2. "jq" JSON Tool
https://jqlang.github.io/jq/download/

3. For scripts requiring the Bitwarden CLI, you may need:
- The personal API key (Client ID & Secret)
https://bitwarden.com/help/personal-api-key/#get-your-personal-api-key

- The Master Password, encrypted in a file. (See the instructions in each script)

4. For scripts requiring access to the Bitwarden Public API, you will need the Organization's API Keys (Client ID & Secret)
https://bitwarden.com/help/public-api/#authentication


## Short description of the scripts in this repo

- bwChangeAllUsersRole.sh<br>
This script will change the roles of all users from role X to role Y. For example, it can change all accounts with the "admin" role to the "owner" role.

- bwConfirmAcceptedPeople.sh<br>
This script will automatically confirm all members that are still in "Need confirmation" state. For one-time run.

- bwConfirmAcceptedPeopleSM.sh<br>
This script will automatically confirm all members who are still in the "Need confirmation" state. It uses Bitwarden Secrets Manager to store the API key and the Master Password.

- bwConfirmAcceptedPeopleWPass.sh<br>
This script will automatically confirm all members that are still in "Need confirmation" state. Read the comment in the script on how to store the master password encrypted.

- bwDeleteAllCollections.sh<br>
This script will delete all collections in the organization

- bwDeletePermTrashOrg.sh<br>
This script will purge the trash and permanently delete all items in the trash

- bwFindAndEmptyExternalId.sh<br>
This script will clear the external ID of a user, setting it to empty. This can be used in case there is a duplicate external ID due to an email change.

- bwPurgeGroups.sh<br>
This script will delete all groups in the organization

- bwPurgeNotAcceptedUsers.sh<br>
This script will remove all members who are still in the "Invited" state.

- bwReinvitePeople.sh<br>
This script will re-send invitations to all members who are still in the "Invited" state.

- bwRestoreAllTrash.sh<br>
This script will restore all items in the trash

- bwlistcollectionsbygroup.sh<br>
This script will list all groups with their collection permission

- changedPasswordsReport.sh<br>
This script will list all items and create a CSV file. There are three fields: Item name, Username, the password field's last updated date.

- createCollectionsForAllGroups.sh<br>
This script will create a collection for each group and assign the collection to the group

- createCollectionsForAllMembers.sh<br>
This script will create a collection for each member and assign the collection to the member

- createCollectionsForAllMembersNested.sh<br>
This script will create a nested collection for each member and assign the collection to the member

- createItemAndShareWithCollection.sh<br>
This script will create a login item and move it into the organization vault and assign it into a collection

- createMissingParents.sh<br>
This script will create collections based on the names in a CSV file

- createSecureNoteAndShareWithCollection.sh<br>
This script will create a secure note and move it into the organization vault and assign it into a collection

- exportOrgVaultCronjob.sh<br>
Cronjob script to automatically export the organization vault for backup purposes

- inheritparentpermissions.sh<br>
This script will copy the group permissions of a collection from the parent (top-most collection) down to all the children (and grandchildren).

- listmembers.sh<br>
This script will give output of the list of all members in comma-separated format

- removeIndividualAccountPerms.sh<br>
This script will remove all collection permission from individual accounts

- setItemsMatchDetection.sh<br>
This script will set the match detection of all shared items to "Host." You can modify the script to set it to other values based on your needs.

To be deleted:

- findDuplicates.sh<br>
No needed. Just a generic script.

- bwConfirmAcceptedPeople_MoveGroupToManager.sh
- bwConfirmAcceptedPeople_MoveToManager.sh<br>

No longer needed. Manager role is deprecated.
