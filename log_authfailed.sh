#!/bin/bash
LOG_FILE="/var/log/openldap.log"

operations=$(grep 'err=49' $LOG_FILE | awk '{print $6,$7}')
operation=""
for token in $operations; do
    if [[ "$token" == "op"* && "$operation" == "conn"* ]]; then
        operation="$operation $token"
#        printf "$operation\n"
        result=$(/usr/bin/grep "${operation}" $LOG_FILE)
        printf "$result\n--\n"
    else
        operation="$token"
    fi
done
