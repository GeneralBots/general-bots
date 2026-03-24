#!/bin/bash
# fail2ban startup script for Incus containers
# Usage: Place in /opt/gbo/bin/ and run as root in container

LOGFILE=/opt/gbo/logs/fail2ban.log

mkdir -p /opt/gbo/logs
nohup /usr/bin/fail2ban-server -x -f > $LOGFILE 2>&1 &
sleep 2
fail2ban-client reload
echo "Fail2ban started - check status with: fail2ban-client status"