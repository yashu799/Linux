#!/bin/bash


###### Config Variables ######
headerText="Test Header Text"
headerColor="#000"
footerText="Test Footer Text"
footerColor="#990000"
# Paths to optional history and config files
dataRootPath="/etc/sysreport"
historyFilePath="/etc/sysreport/history"
configFilePath="/etc/sysreport/config"
topProcessCount=5
HTMLOutput=1
textOutput=0
headerOutput=1
footerOutput=1
helpOutput=1
goodDiskSpacePercentage=69
cautionDiskSpacePercentage=70
dangerdDiskSpacePercentage=90
helpContent="There isn't a help document for this script yet, but you can read details and contact the author at https://github.com/crlamke."


# Report header and data display formats
reportLabelDivider="********************"
subReportHeader="****************"
subReportFooter="****************"
headerFormat="%-10s %-13s %-13s %-24s %-8s"
dataFormat="%-10s %-13s %-13s %-24s %-8s"
NL=$'\n'
TAB=$'\t'
REDTEXT="\033[31;1m"
BLUETEXT="\033[34;1m"
GREENTEXT="\033[32;1m"
YELLOWTEXT="\033[33;1m"
COLOREND="\033[0m"

# Paths to external tools if needed



cores=$(getconf _NPROCESSORS_ONLN)
ram=$(grep 'MemTotal:' /proc/meminfo | awk '{print int($2 / 1024)}')
hostName=$(hostname)
hostIP=$(hostname -I)
runDTG=$(date +"%Y-%m-%d-%H:%M %Z")
reportName="StatusReport-"
reportName+=$(date +"%Y-%m-%d-%H-%M-%Z")

# Report Variables - used to build report after gathering sys info
hwBasicsHTML=""
hwBasicsText=""
topProcsByCPUHTML=""
topProcsByRAMText=""
topProcsByRAMHTML=""
topProcsByCPUText=""
diskStatsHTML=""
diskStatsText=""
dockerStatsHTML=""
dockerStatsText=""
packageChangeStatsHTML=""
packageChangeStatsText=""
recentUserStatsHTML=""
recentUserStatsText=""
anomalousStatsHTML=""
anomalousStatsText=""
syslogStatsHTML=""
syslogStatsText=""
#suggestionsHTML=""
#suggestionsText=""

# Name: readConfig
# Parameters: none
# Description: Read the config file, if it exists.
function readConfig
{
  if [ -f $serverConfigPath ]; then
    printf "Using $serverConfigPath as server config file.\n"
  else
    printf "$serverConfigPath not found\n"
    printUsage
    exit 1
  fi
}

# Name: readHistory
# Parameters: none
# Description: Read the historic data file, if it exists.
function readHistory
{
  if [ -f $serverConfigPath ]; then
    printf "Using $serverConfigPath as server config file.\n"
  else
    printf "$serverConfigPath not found\n"
    printUsage
    exit 1
  fi
}


# Name: reportHWBasicStats
# Parameters: none
# Description: Print report header with machine type and resource info
function reportHWBasicStats
{
  htmlOut="<table>"
  hwBasicsText+="Hardware Resources: ${cores} CPU cores | ${ram} MB RAM ${NL}"
  htmlOut+="<tr><th>CPU Cores</th><td>${cores}</td></tr>"
  htmlOut+="<tr><th>RAM (MB)</th><td>${ram}</td></tr>"
  vmtype=$(systemd-detect-virt)
  if [[ $? -eq 0 ]]; then
    hwBasicsText+="Virtualization: Machine is a VM with \"${vmtype}\" type virtualization.${NL}"
    htmlOut+="<tr><th>Virtualization</th><td>Machine is a VM with \"${vmtype}\" type virtualization.</td></tr>"
  else
    hwBasicsText+="Virtualization: No virtualization detected.${NL}"
    htmlOut+="<tr><td>Virtualization: Machine is a VM with \"${vmtype}\" type virtualization.</td></tr>"
  fi
  hwBasicsText+="Hostname: ${hostName}${NL}"
  htmlOut+="<tr><th>Hostname</th><td>${hostName}</td></tr>"
  hwBasicsText+="Host IPs: ${hostIP}${NL}"
  htmlOut+="<tr><th>Host IPs</th><td>${hostIP}</td></tr>"
  # TODO make cmd below support more platforms
  osText=$(cat /etc/redhat-release)
  hwBasicsText+="OS Name and Version: ${osText}${NL}"
  htmlOut+="<tr><th>OS Name and Version</th><td>${osText}</td></tr>"
  htmlOut+="</table>"
  hwBasicsHTML=$htmlOut
}


# Name: reportTopProcessesByCPU
# Parameters: none
# Description: Report on processes consuming the most RAM and CPU
function reportTopProcessesByCPU()
{
  # Add one to topProcessCount to account for showing the header line.
  processLinesToShow=$(($topProcessCount+1))

  textOut="${subReportHeader}Top Processes By CPU${subReportHeader}${NL}"

  mkfifo tpPipe0
  IFS=" "
  htmlOut="<table><tr><th>% CPU</th><th>PID</th><th>User</th><th>% Mem</th><th>Process Details</th></tr>"
  ps -Ao pcpu,pid,user,pmem,cmd --sort=-pcpu --noheaders | \
    head -n 10 > tpPipe0 &
  while read -r cpu pid user mem cmd
  do
    htmlOut+="<tr><td>${cpu}</td><td>${pid}</td>"
    htmlOut+="<td>${user}</td><td>${mem}</td><td>${cmd}</td></tr>"
    textOut+="${cpu} | ${pid} | ${user} | ${mem} | ${cmd}${NL}"
  done < tpPipe0
  htmlOut+="</table>"
  rm tpPipe0

  topProcsByCPUText=$textOut
  topProcsByCPUHTML=$htmlOut
}


# Name: reportTopProcessesByRAM
# Parameters: none
# Description: Report on processes consuming the most RAM and CPU
function reportTopProcessesByRAM()
{
  # Add one to topProcessCount to account for showing the header line.
  processLinesToShow=$(($topProcessCount+1))

  textOut="${subReportHeader}Top Processes By RAM${subReportHeader}${NL}"

  mkfifo tpPipe0
  IFS=" "
  htmlOut="<table><tr><th>% Mem</th><th>% CPU</th><th>PID</th><th>User</th><th>Process Details</th></tr>"
  ps -Ao pmem,pcpu,pid,user,cmd --sort=-pmem --noheaders | \
    head -n 10 > tpPipe0 &
  while read -r mem cpu pid user cmd
  do
    htmlOut+="<tr><td>${mem}</td><td>${cpu}</td>"
    htmlOut+="<td>${pid}</td><td>${user}</td><td>${cmd}</td></tr>"
    textOut+="${mem} | ${cpu} | ${pid} | ${user} | ${cmd}${NL}"
  done < tpPipe0
  htmlOut+="</table>"
  rm tpPipe0

  topProcsByRAMText=$textOut
  topProcsByRAMHTML=$htmlOut
}


# Name: reportDiskStats
# Parameters: none
# Description: Report on disk status, usage and mounts
function reportDiskStats()
{
  htmlOut="<table><tr><th>% Used</th><th>Size</th><th>Mounted On</th><th>Filesystem</th></tr>"
  textOut="***Disk Space***\n"
  IFS=" "
  while read -r fileSystem size used avail percentUsed mountedOn
  do
    usedInt=$(sed 's/%//' <<< $percentUsed)
    #usedInt=$(($usedInt + 60)) # Used to test logic below and color printing
    if [[ $usedInt -ge 90 ]]; then
      usedColor="redText"
    elif [[ $usedInt -ge 70 ]]; then
      usedColor="yellowText"
    else
      usedColor="greenText"
    fi
    htmlOut+="<tr><td class=\"${usedColor}\">${percentUsed}</td><td>${size}</td><td>${mountedOn}</td>"
    htmlOut+="<td>${fileSystem}</td></tr>"
    textOut+="${percentUsed} | ${size} | ${mountedOn} | ${fileSystem}${NL}"
  done <<< $(df -khP | sed '1d')

  htmlOut+="</table>"
  diskStatsText=$textOut
  diskStatsHTML=$htmlOut
  #printf "%s\n\n" "$diskStatsText"
  #printf "HTML is %s\n\n" "$diskStatsHTML"
}


# Name: reportDockerStatus
# Parameters: none
# Description: Report on Docker status
function reportDockerStatus()
{
  pgrep -f docker > /dev/null
  if [[ $? -ne 0 ]]; then
    dockerStatsText="Docker not running"
    dockerStatsHTML="Docker not running"
    return 1
  fi

  #htmlOut="<table><tr><th>Container ID</th><th>Image</th><th>Command</th><th>Created</th>"
  #htmlOut+="<th>Status</th><th>Ports</th><th>Names</th></tr>"
  htmlOut="<table><tr><th>Container ID</th><th>Image</th><th>Command | Created | Status | Ports | Names</th></tr>"
  textOut="***Docker Status***\n"
  IFS=" "
  while read -r id image command created status ports names
  do
    htmlOut+="<tr><td>${id}</td><td>${image}</td><td>${command} ${created} ${status} ${ports} ${names}</td></tr>"
    #htmlOut+="<tr><td>${id}</td><td>${image}</td><td>${command}</td>"
    #htmlOut+="<td>${created}</td><td>${status}</td><td>${ports}</td>"
    #htmlOut+="<td>${names}</td></tr>"
    textOut+="${id} | ${image} | ${command} | ${created} | ${status} | ${ports}${NL}"
    textOut+="| ${names}${NL}"
  done <<< $(docker ps -a | sed '1d')

  htmlOut+="</table>"
  dockerStatsText=$textOut
  dockerStatsHTML=$htmlOut
}


# Name: reportAnomalousProcesses
# Parameters: none
# Description: Report zombie, orphan, and other potentially anomalous processes
function reportAnomalousProcesses()
{
  printf "\n%s %s %s\n" "$subReportHeader" "Anomalous Processes" "$subReportHeader" 
  printf "Checking for zombie processes using \"ps axo pid=,stat= | awk '$2~/^Z/ { print $1 }'\"\n"
  ps axo pid=,stat= | awk '$2~/^Z/ { print $1 }'
  printf "Checking for orphan processes - not yet implemented\n"
}


# Name: reportRecentUsers
# Parameters: none
# Description: Report recently logged in users
function reportRecentUsers()
{
  htmlOut="<table><tr><th>User  port/tty  IP/Hostname  Session Start/Stop Duration</th></tr>"
  textOut="***Recent User logins***\n"
  IFS=" "
  while read -r line
  do
    htmlOut+="<tr><td>${line}</td></tr>"
    textOut+="${line}${NL}"
  done <<< $(last -F -n 20)

  htmlOut+="</table>"
  recentUserStatsText=$textOut
  recentUserStatsHTML=$htmlOut
}


# Name: reportRecentPackageChanges
# Parameters: none
# Description: Report recent system changes via yum
function reportRecentPackageChanges()
{
  htmlOut="<table><tr><th>yum history</th></tr>"
  textOut="***Package Changes (yum history)***\n"
  IFS=" "
  while read -r line
  do
    #printf "%s\n" "$fileSystem | $size | $used | $avail | $percentUsed | $mountedOn"
    htmlOut+="<tr><td>${line}</td></tr>"
    textOut+="${line}${NL}"
  done <<< $(yum history | sed '1d;3d')

  htmlOut+="</table>"
  packageChangeStatsText=$textOut
  packageChangeStatsHTML=$htmlOut
}


# Name: reportSysLogEvents
# Parameters: none
# Description: Report recent syslog events
function reportSysLogEvents()
{
  htmlOut="<table><tr><th>dmesg log</th></tr>"
  textOut="***dmesg log***\n"
  IFS=" "
  while read -r line
  do
    htmlOut+="<tr><td>${line}</td></tr>"
    textOut+="${line}${NL}"
  done <<< $(dmesg | tail -20)

  htmlOut+="</table>"
  syslogStatsHTML=$htmlOut
  syslogStatsText=$textOut
}


# Name: reportRecentEvents
# Parameters: none
# Description: Report current system status
function reportRecentEvents
{
  printf "\n%s %s %s\n" "$reportLabelDivider" "Recent System Events" "$reportLabelDivider"

}


# Name: reportSuggestions
# Parameters: none
# Description: Report current system status
function reportSuggestions
{
  #printf "\n%s %s %s\n" $reportLabelDivider "Troubleshooting Suggestions" $reportLabelDivider"
  printf "\nSuggestions not yet implemented\n"

}


# Name: gatherInfo
# Parameters: 
# Description: Run functions that gather the sys info
function gatherInfo
{
  reportHWBasicStats
  reportDiskStats
  reportTopProcessesByCPU
  reportTopProcessesByRAM
  reportDockerStatus
  #reportAnomalousProcesses
  reportRecentUsers
  reportRecentPackageChanges
  reportSysLogEvents
  #reportRecentEvents
  #reportSuggestions
}


# Name: createHTMLReport
# Description: Build the HTML report output file
function createHTMLReport
{
  echo "Writing HTML Output to ${reportName}.html"
  htmlPage="<!DOCTYPE html><html><head><title>"
  htmlPage+="Status Report"
  htmlPage+="</title></head>"
  htmlPage+="<style>"
  htmlPage+="#toc { border: 1px solid #aaa; display: table; "
  htmlPage+="margin-bottom: 1em; padding: 20px; width: auto;}"
  htmlPage+=".pageHeader{text-align:center;font-size:20px;font-family:'Courier New',monospace;color:${headerColor}}"
  htmlPage+=".pageFooter{text-align:center;font-size:20px;font-family:'Courier New',monospace;color:${footerColor}}}"
  htmlPage+="ol, li { list-style: outside none none}"
  htmlPage+=".backToTop {text-align: center;font-size:15px}"
  htmlPage+=".greenText {color: green} .yellowText {color: yellow} .redText {color: red}"
  htmlPage+=".runtime {text-align: center;font-size:15px}"
  htmlPage+="table, th, td { border: 1px solid black; border-collapse: collapse;}"
  htmlPage+="th {text-align: left; white-space: nowrap;background:#33cc33}"
  htmlPage+="tr:nth-child(even) {background-color: #dddddd;}"
  htmlPage+="h2, h4 {text-align: center;}"
  htmlPage+=".sectionTitle { border: 5px blue; background-color: lightblue;"
  htmlPage+="text-align: center; font-weight: bold;}"
  htmlPage+="</style>"
  htmlPage+="<body>"
  if (( $headerOutput != 0 )); then
    htmlPage+="<h3><p class=\"pageHeader\">${headerText}</p></h2>"
  fi
  htmlPage+="<h2><p class=\"pageTitle\">Status Report for ${hostName}</p></h2>"
  htmlPage+="<p class=\"runtime\">Report Run Time: ${runDTG}</p>"
  htmlPage+="<div id=\"toc\"><h4>Contents</h4>"
  htmlPage+="<ol class=\"tocList\">"
  htmlPage+="<li><a href="#BasicInfo">Basic Machine Info</a></li>"
  htmlPage+="<li><a href="#DiskStats">Disk Stats</a></li>"
  htmlPage+="<li><a href="#TopProcsByCPU">Top Processes By CPU</a></li>"
  htmlPage+="<li><a href="#TopProcsByRAM">Top Processes By RAM</a></li>"
  htmlPage+="<li><a href="#DockerStats">Docker Stats</a></li>"
  htmlPage+="<li><a href="#PackageChanges">Package Changes</a></li>"
  htmlPage+="<li><a href="#RecentUsers">Recent Users</a></li>"
  htmlPage+="<li><a href="#SysLog">Sys Logs</a></li>"
  htmlPage+="<li><a href="#Help">Report Help</a></li>"
  htmlPage+="</ol></div>"
  htmlPage+="<div id=\"BasicInfo\"><p class=\"sectionTitle\">Basic Machine Info</p>"
  htmlPage+="$hwBasicsHTML"
  htmlPage+="<p class=\"backToTop\"><a href="#toc">Back to Top</a></p>"
  htmlPage+="</div>"
  htmlPage+="<div id=\"DiskStats\"><p class=\"sectionTitle\">Disk Stats</p>"
  htmlPage+="$diskStatsHTML"
  htmlPage+="<p class=\"backToTop\"><a href="#toc">Back to Top</a></p>"
  htmlPage+="</div>"
  htmlPage+="<div id=\"TopProcsByCPU\"><p class=\"sectionTitle\">Top Processes By CPU</p>"
  htmlPage+="$topProcsByCPUHTML"
  htmlPage+="<p class=\"backToTop\"><a href="#toc">Back to Top</a></p>"
  htmlPage+="</div>"
  htmlPage+="<div id=\"TopProcsByRAM\"><p class=\"sectionTitle\">Top Processes By RAM</p>"
  htmlPage+="$topProcsByRAMHTML"
  htmlPage+="<p class=\"backToTop\"><a href="#toc">Back to Top</a></p>"
  htmlPage+="</div>"
  htmlPage+="<div id=\"DockerStats\"><p class=\"sectionTitle\">Docker Stats</p>"
  htmlPage+="$dockerStatsHTML"
  htmlPage+="<p class=\"backToTop\"><a href="#toc">Back to Top</a></p>"
  htmlPage+="</div>"
  htmlPage+="<div id=\"PackageChanges\"><p class=\"sectionTitle\">Package Changes (yum history)</p>"
  htmlPage+="$packageChangeStatsHTML"
  htmlPage+="<p class=\"backToTop\"><a href="#toc">Back to Top</a></p>"
  htmlPage+="</div>"
  htmlPage+="<div id=\"RecentUsers\"><p class=\"sectionTitle\">Recent Users (Using \"last\")</p>"
  htmlPage+="$recentUserStatsHTML"
  htmlPage+="<p class=\"backToTop\"><a href="#toc">Back to Top</a></p>"
  htmlPage+="</div>"
  #htmlPage+="$anomalousStatsHTML"
  htmlPage+="<div id=\"SysLog\"><p class=\"sectionTitle\">Syslog</p>"
  htmlPage+="$syslogStatsHTML"
  htmlPage+="<p class=\"backToTop\"><a href="#toc">Back to Top</a></p>"
  htmlPage+="</div>"
  #htmlPage+="$suggestionsHTML"
  if (( $helpOutput != 0 )); then
    htmlPage+="<div id=\"Help\"><p class=\"sectionTitle\">Help</p>"
    htmlPage+="$helpContent"
    htmlPage+="<p class=\"backToTop\"><a href="#toc">Back to Top</a></p>"
    htmlPage+="</div>"
  fi
  if (( $footerOutput != 0 )); then
    htmlPage+="<h3><p class=\"pageFooter\">${footerText}</p></h2>"
  fi
  htmlPage+="</body></html>"
  echo $htmlPage >./${reportName}.html
}

# Name: createTextReport
# Parameters: 
# Description: Build the Text report output file
function createTextReport
{
  echo "Writing Text Output to ${reportName}.txt"
  textOut="${NL}${NL}${reportLabelDivider} ${hostName} Status Report ${reportLabelDivider}${NL}"
#hwBasicsText=""
#topProcStatsText=""
#diskStatsText=""
#dockerStatsText=""
#packageChangeStatsText=""
#recentUserStatsText=""
#anomalousStatsText=""
#syslogStatsText=""
#suggestionsText=""
#footerText=""
  echo $textOut >./${reportName}.txt
}

# Trap ctrl + c 
trap ctrl_c INT
function ctrl_c() 
{
  printf "\n\nctrl-c received. Exiting\n"
  exit
}

#First, check that we have sudo permissions so we can gather the info we need.
if [ "$EUID" -ne 0 ]
  then echo "Please run as root/sudo"
  exit
fi

# Check whether there's existing data in /etc/sysreport


#Run the sys info gathering functions
gatherInfo

if (( $HTMLOutput != 0 )); then
  createHTMLReport
fi

if (( $textOutput != 0 )); then
  createTextReport
fi
