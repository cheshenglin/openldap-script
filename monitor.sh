#!/bin/bash
CRITERIA_ZOMBIE='\[saslauthd\] <defunct>'
RSYSLOG_SERVER=''

# Check if there are saslauthd zombie processes; If yes, restart saslauthd
# Check if there are CLOSE_WAIT LDAP connections; If yes, restart slapd

# zombie_processes=$(cat ./saslauthd-defunct.txt | grep "${CRITERIA_ZOMBIE}" | wc -l)
zombie_processes=$(ps aux | grep "${CRITERIA_ZOMBIE}" | wc -l)
printf "<14>ixq-ldap saslauthd[$(/usr/bin/cat /var/run/saslauthd/saslauthd.pid)] - $zombie_processes zombie processes found." | nc -u $RSYSLOG_SERVER 514
# printf "$zombie_processes zombie processes found.\n"

slapd_conn=$(/usr/sbin/lsof -a -c slapd -i 4 2>/dev/null| wc -l)
printf "<14>ixq-ldap slapd[$(ps aux | grep openldap | grep slapd | awk '{print $2}')] - $slapd_conn slapd connections found." | nc -u $RSYSLOG_SERVER 514
