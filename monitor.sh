#!/bin/bash
CRITERIA_ZOMBIE='\[saslauthd\] <defunct>'
RSYSLOG_SERVER=''

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
    local message="<14>ixq-ldap $name[$pid] - $zombies_num zombie processes found."
    printf "$message" | nc -u $RSYSLOG_SERVER 514
    if [ "$zombies_num" -ge 3 ]; then
        /usr/bin/systemctl stop $name
        return 0
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

    local message="<14>ixq-ldap $name[$pid] - $listen/$established/$close_wait/$time_wait/$total (L/E/CW/TW/Total) connections."
    printf "$message" | nc -u $RSYSLOG_SERVER 514
}
