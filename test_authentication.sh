#!/bin/bash

HOST_URL="ldap://localhost:389"
SASL_SOCKET="/var/run/saslauthd/mux"

declare -A META_ACCOUNTS
META_ACCOUNTS["cn=User1,dc=meta"]="secret"
META_ACCOUNTS["cn=User2,dc=meta"]="secret"

declare -A SASL_ACCOUNTS
SASL_ACCOUNTS["user1@example.com"]="secret"
SASL_ACCOUNTS["user2@example.com"]="secret"

function ldap_authenticate() {
    args=("$@")
    result=$(ldapsearch -b "" -H $HOST_URL -D "${args[0]}" -w "${args[1]}" | grep -o -E "result: [0-9]{2}")
    echo "$result"
}

function sasl_authenticate() {
    result=$(testsaslauthd -u $1 -r $2 -p $3 -f $SASL_SOCKET)
    echo "$result"
}

function show_message_from_ldap_result() {
    if [ $(echo $1 | wc -c) -eq 11 ]; then
        echo "Success"
    else
        echo "Failed"
    fi
}

function show_message_from_sasl_result() {
    args=("$@")
    if [ "${args[0]}" == '0: OK "Success."' ]; then
        echo "Success"
    elif [ "${args[0]}" == '0: NO "authentication failed"' ]; then
        echo "Failed"
    else
        echo "${args[0]}"
    fi
}

printf "#####\n# TEST META-DIRECTORY AUTHENTICATION\n#####\n"
for account in "${!META_ACCOUNTS[@]}";
do
    printf "Try $account ... "
    result_mesage=$(ldap_authenticate "$account" "${META_ACCOUNTS[$account]}" 2>&1)
    show_message_from_ldap_result "$result_mesage"
done

printf "\n"

printf "#####\n# TEST SASL AUTHENTICATION\n#####\n"
for account in "${!SASL_ACCOUNTS[@]}";
do
    IFS='@' read -r -a split_account <<< "$account"
    printf "Try ${split_account[0]} ${split_account[1]} ... "
    result_mesage=$(sasl_authenticate "${split_account[0]}" "${split_account[1]}" "${SASL_ACCOUNTS[$account]}" 2>&1)
    show_message_from_sasl_result "$result_mesage"
done
