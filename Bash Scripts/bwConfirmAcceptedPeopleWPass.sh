#!/bin/bash
#Requires .p0 file which should consist of the user account password in base64. You can create a temp file with the clear text password and then process it using `base64 clearTextFile > .p0`. Make sure to delete the temp file after creating the .p0 file. The .p0 file should be owned and locked down by a unique account that is only utilized to run this script.

organization_id="b9c70d44-2615-4c84-9913-ac330139c9eb"
file=/home/bitwarden/.p0

p0=$(cat $file | base64 -d)
session_key="$(printf $p0 | bw unlock --raw)"
org_members="$(bw list --session "$session_key" org-members --organizationid $organization_id | jq -c '.[] | select( .status == 1 )' | jq -c '.id' | tr -d '"')"
for member_id in ${org_members[@]} ; do
	bw confirm --session $session_key org-member $member_id --organizationid $organization_id
done
