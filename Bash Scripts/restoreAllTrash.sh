#!/bin/bash
# The below command will leverage the bw cli and jq to restore all deleted vault items from the trash.
# jq is required in $PATH https://stedolan.github.io/jq/download/
# bw is required in $PATH and logged in https://bitwarden.com/help/cli/

for i in $(bw list items --trash | jq -r '.[].id'); do bw restore item $i; done
