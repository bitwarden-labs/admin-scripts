#!/bin/bash

read -p 'Organization Id: ' organization_id
session_key="$(bw unlock --raw)"
org_members="$(bw list --session $session_key org-members --organizationid $organization_id | jq -c '.[] | select( .status == 1 )' | jq -c '.id' | tr -d '"')"
for member_id in ${org_members[@]} ; do
	bw confirm --session $session_key org-member $member_id --organizationid $organization_id
done
