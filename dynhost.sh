#!/usr/bin/env bash

# Account configuration
DOMAIN=mydomain.com
LOGIN=ovh-dyndns-login
PASSWORD=ovh-dyndns-password

LOG_PATH=/var/log/dynhostovh.log

DEBUG=true

#Log script event
# Usage: 
#     log DEBUG|INFO|WARNING|ERROR|CRITICAL "message to log"
# Ex:
#     /bin/toto || log ERROR "Something unexpected happen with the command /bin/toto."
#     log INFO  "The command /bin/toto has been executed"
#
# Arg[1]:
#   DEBUG   : Debug messages
#   INFO    : Information messages
#   WARNING : For warning
#   ERROR   : Error message
#   CRITICAL: Critical message (Any critical message cause the script to exit Code 1)
#
# Arg[2]:
#   Message to display between double quote : "This is my message"
log()
{

    local logType=${1}
    local msg=${2}
    local currentDate="$(date +"%Y-%m-%d %T")"
    [[ ${logType} == "DEBUG"    ]] && echo "${currentDate} - ${logType} - ${msg}"
    [[ ${logType} == "INFO"     ]] && echo "${currentDate} - ${logType} - ${msg}"
    [[ ${logType} == "WARNING"  ]] && echo "${currentDate} - ${logType} - ${msg}"
    [[ ${logType} == "ERROR"    ]] && echo "${currentDate} - ${logType} - ${msg}"
    [[ ${logType} == "CRITICAL" ]] && echo "${currentDate} - ${logType} - ${msg}" && exit 1

}

# Log the script output into your log file
exec > >(tee -a $LOG_PATH) 2>&1

[[ $(which dig  2>/dev/null) ]] || log CRITICAL "Dig command not found in path"
[[ $(which curl 2>/dev/null) ]] || log CRITICAL "Curl command not found in path. Try 'apt install curl' or 'dnf install curl'"

# Get current IPv4 and corresponding configured
[[ $DEBUG == true ]] && log DEBUG "Try to get domain $DOMAIN IP using dig command"
DOMAIN_IP=$(dig +short $DOMAIN A)
[[ $DEBUG == true ]] && log DEBUG "$DOMAIN IP is: ${DOMAIN_IP}"
CURRENT_IP=$(curl -m 5 -4 ifconfig.co 2>/dev/null)
[[ $DEBUG == true ]] && log DEBUG "CURRENT_IP is ${CURRENT_IP}"

# Check if returned IP is valid
if [[ ! "$CURRENT_IP" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]
then

  log CRITICAL "IP retrived using dig doesn't match the valid IPv4 Regex"

fi


if [[ -z "$CURRENT_IP" ]]
then

  log WARNING "Fail to get IP using ifconfig.co"
  CURRENT_IP=$(dig +short ${DOMAIN} @resolver1.opendns.com)

fi


# Update dynamic IPv4, if needed
if [[ -z "${CURRENT_IP}" ]] || [[ -z "${DOMAIN_IP}" ]]
then
  log ERROR "No IP retrieved"
else
  if [[ "${DOMAIN_IP}" != "${CURRENT_IP}" ]]
  then
    RESULT=$(curl -m 5 -L --location-trusted --user "$LOGIN:$PASSWORD" "https://www.ovh.com/nic/update?system=dyndns&hostname=$DOMAIN&myip=$CURRENT_IP")
    if [[ $RESULT =~ "good" ]]
    then
      log INFO "IPv4 has changed - request to OVH DynHost: $RESULT"
    else
      log ERROR "Fail to update $DOMAIN IP with error: $RESULT"
    fi
  fi
fi
