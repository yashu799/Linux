# Linux
A Linux bash script useful for determining system resources and health.


Current functionality
Generates single file HTML report, useful for cron based automated run and email
Disk space stats
Top processes by CPU
Top processes by RAM
Docker stats
Recent package changes (e.g. yum or apt history)
Recent user history
Recent sys logs (currently only dmesg)
Planned functionality
Generate plain text report
Add apt history (currently only RHEL/CENTOS yum history is supported)
Add mem and disk deltas capability to bash monitor scripts (depends on data from each run being stored on machine)
Add more detailed container monitoring
Add color key below tables with colored elements
Requirements to run script
You must run this script as root/superuser.
This script outputs HTML and text results and requires the ability to write files to the current/run directory
Tools required for the script to fully run
systemd-detect-virt - to determine whether the script is running in a VM and if so what type of VM
getconf - used to determine number of processors online
column - used to format text output
This script fully supports RHEL/CENTOS 7 and partially supports Ubuntu 20.x LTS. More support will be added as time allows.
bash v4.2 or later
Note that tools like ps, sed, awk, etc. universally included in Linux distros are required for this script but not listed here.
mailx - Only if you want the email functionality
Optional components that will be reported if present
If docker is running, the script will provide information on docker containers (currently) with more info to be added.
Inspired By
The article Linux Performance Analysis in 60,000 Milliseconds | Netflix TechBlog
