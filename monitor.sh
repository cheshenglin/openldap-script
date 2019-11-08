#!/bin/bash
CRITERIA_ZOMBIE='\[saslauthd\] <defunct>'
HOSTNAME='openldap'
RSYSLOG_SERVER=''

TESTSASLAUTH_USER=''
TESTSASLAUTH_PASSWORD=''
TESTSASLAUTH_REALM=''
TESTSASLAUTH_RESULT='/var/log/testsaslauthd.result'

function execute_testsaslauthd() {
    /usr/sbin/testsaslauthd -u $TESTSASLAUTH_USER -r $TESTSASLAUTH_REALM -p $TESTSASLAUTH_PASSWORD -f /var/run/saslauthd/mux  > $TESTSASLAUTH_RESULT &
    sleep 3
    local pid=$(ps aux | grep testsaslauthd | grep mux | awk '{print $2}')
    if [ -n "$pid" ]; then
        kill -9 $pid
    fi
}

function get_saslauthd_pid() {
    local pid_file=/var/run/saslauthd/saslauthd.pid
    if [ -f "$pid_file" ]; then
        printf "%s" "$(<$pid_file)"
    else
        echo ""
    fi
}

function get_slapd_pid() {
    printf "$(ps aux | grep openldap | grep slapd | awk '{print $2}')"
}

function saslauthd() {
    local name="saslauthd"
    local pid=$(get_saslauthd_pid)
    if [ -z "$pid" ]; then
        /usr/bin/systemctl start $name
        return 0
    fi
    local zombies_num=$(ps aux | grep "${CRITERIA_ZOMBIE}" | wc -l)
    local message="<14>$HOSTNAME $name[$pid] - $zombies_num zombie processes found."
    printf "$message" | nc -u $RSYSLOG_SERVER 514

    local is_valid=$(validate_saslauthd ${zombies_num})
    if [ $is_valid -eq 0 ]; then
        /usr/bin/systemctl stop $name
    fi
}

function slapd() {
    local name="slapd"
    local pid=$(get_slapd_pid)
    if [ -z "$pid" ]; then
        local command="/usr/bin/nohup /usr/local/openldap/libexec/slapd -d 256 >/dev/null 2>&1"
        nohup $command &
        return 0
    fi

    local connections=$(/usr/sbin/lsof -a -c slapd -i 4 2>/dev/null)
    local listen=$(printf "$connections" | grep 'LISTEN' | wc -l)
    local established=$(printf "$connections" | grep 'ESTABLISHED' | wc -l)
    local close_wait=$(printf "$connections" | grep 'CLOSE_WAIT' | wc -l)
    local time_wait=$(printf "$connections" | grep 'TIME_WAIT' | wc -l)
    local total=$(printf "$connections" | wc -l)

    local priority='13'
    if [ $close_wait -le 2 ]; then
         priority='14'
    elif [ $close_wait -ge 5 ]; then
         priority='12'
    fi

    local message="<$priority>$HOSTNAME $name[$pid] - $listen/$established/$close_wait/$time_wait/$total (L/E/CW/TW/Total) connections."
    printf "$message" | nc -u $RSYSLOG_SERVER 514
}

function validate_saslauthd() {
    args=("$@")
    local zombies_num=${args[0]}
    if [ "$zombies_num" -ge 3 ]; then
        echo 0; return 0
    fi
    $(execute_testsaslauthd)
    local success_match=$(cat $TESTSASLAUTH_RESULT 2>/dev/null | grep -o 'Success' | wc -c)
    if [ $success_match -eq 8 ]; then
        echo 1; return 0
    fi
    echo 0;
}

saslauthd
slapd
