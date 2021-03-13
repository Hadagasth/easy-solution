#!/bin/bash
#
################################################################################################################
# Descrição: O objetivo deste script é trazer informações úteis para analise, gerando um relatório no final.   #
# Funcionalidades: Serviços ativos | Porta | Memória | Load Average | CPU | Storage                            #
# Data: 13/03/2021                                                                                             #
# Criador: RHPB                                                                                                #
################################################################################################################
#
clear
sleep 1
clear
#
echo -e '\033[01;31m─────█─▄▀█──█▀▄─█──\033[00;38m'
echo -e '\033[01;31m────▐▌──────────▐▌──\033[00;38m'
echo -e '\033[01;31m────█▌▀▄──▄▄──▄▀▐█──\033[00;38m'
echo -e '\033[01;31m───▐██──▀▀──▀▀──██▌──\033[00;38m'
echo -e '\033[01;31m──▄████▄──▐▌──▄████▄─\033[00;38m'
#
sleep 1
clear
sleep 2
#
if [ $(date +%H) -lt $(echo "12") ]
then
        echo "Good Morning"
elif  [ $(date +%H) -gt $(echo "18") ]
then
        echo "Good Evening"
elif  [ $(date +%H) -gt $(echo "12") ]
then
        echo "Good Afternoon"
fi
echo  "Welcome again `logname` "
date +"Today is %A,%d of %B"
date +"The local time is %r"
#
echo "The server has been online for $(uptime | awk {'print $3'}) days, $(uptime | awk {'print $5'} | cut -d ":" -f 1) hour and $(uptime | awk {'print $5'} | cut -d ":" -f 2 | cut -d "," -f 1) minutes."
#
echo "The $(uptime | awk {'print $8,$9'} | cut -d ":" -f 1 ) in this server: $(uptime | awk {'print $10,$11,$12'})."
#
echo -e 'Online users:\033[01;34m '$(users)'\033[00;38m'
#
echo "10"
sleep 1
echo "09"
sleep 1
echo "08"
sleep 1
echo "07"
sleep 1
echo "06"
sleep 1
echo "05"
sleep 1
echo "04"
sleep 1
echo "03"
sleep 1
echo "02"
sleep 1
echo "01"
sleep 1
echo "00"
sleep 1
#
clear 
sleep 2
clear
#
echo "Starting analysis, at the end a TXT will be generated with today's date and time."
#
echo " "
#
rm -rf $(date +%B-%d-%m-%Y-%H).txt
sleep 2
touch $(date +%B-%d-%m-%Y-%H).txt
archsaveinfo=$(date +%B-%d-%m-%Y-%H).txt
#
sleep 1
#
echo "The server has been online for $(uptime | awk {'print $3'}) days, $(uptime | awk {'print $5'} | cut -d ":" -f 1) hour and $(uptime | awk {'print $5'} | cut -d ":" -f 2 | cut -d "," -f 1) minutes." >> $archsaveinfo
#
echo " " >> $archsaveinfo
#
echo "The $(uptime | awk {'print $8,$9'} | cut -d ":" -f 1 ) in this server: $(uptime | awk {'print $10,$11,$12'})." >> $archsaveinfo
#
echo " " >> $archsaveinfo
#
echo -e 'Online users:\033[01;34m '$(users)'\033[00;38m' >> $archsaveinfo
#
echo " " >> $archsaveinfo
echo " " >> $archsaveinfo
echo " " >> $archsaveinfo
#
echo "Active services::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::" >> $archsaveinfo
#
for services in $(sudo systemctl list-unit-files --type service --all | grep enabled | sed "s/.service//g" | cut -d " " -f 1) ; do echo " ||||||||||||||| $services ||||||||||||||| $(service $services status | grep 'Active' | awk {'print $1,$2'} | cut -d ":" -f 2)" ; done 2>/dev/null >> $archsaveinfo
#
echo " " >> $archsaveinfo
echo " " >> $archsaveinfo
echo " " >> $archsaveinfo
#
echo "All processes with open ssh port and all open ports::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::" >> $archsaveinfo
#
echo "COMMAND    PID USER   FD   TYPE    DEVICE  SIZE/OFF   NODE   NAME" >> $archsaveinfo
for portlistenopen in $(netstat -tulpn | grep 'LISTEN' | cut -d ":" -f 2 | cut -d " " -f 1) ; do lsof -i :$portlistenopen | grep 'LISTEN' | sed "s/COMMAND//g" ; done >> $archsaveinfo ; lsof -i :ssh | grep -v "COMMAND" >> $archsaveinfo
#
echo " " >> $archsaveinfo
echo " " >> $archsaveinfo
echo " " >> $archsaveinfo
#
echo "CPU offenders::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::" >> $archsaveinfo
#
ps aux | awk '{if ($3 > 1.0) print  $2 " "  $11 " " "CPU% " $3}' | sort -k 3 -r -n >> $archsaveinfo
#
echo " " >> $archsaveinfo
echo " " >> $archsaveinfo
echo " " >> $archsaveinfo
#
echo "Memory::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::" >> $archsaveinfo
#
echo "||Total||Used||Free||" >> $archsaveinfo
free -m | tail -n2 |  cut -d " " -f 1,12,21,30,31 >> $archsaveinfo
#
echo " " >> $archsaveinfo
echo " " >> $archsaveinfo
echo " " >> $archsaveinfo
#
echo "Storage::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::" >> $archsaveinfo
#
df -h >> $archsaveinfo
#
echo " " >> $archsaveinfo
#
echo -e 'Analysis completed successfully, in the \033[01;34m '$archsaveinfo'\033[00;38m file are all relevant information'
#
echo " "
#
echo "See you later!!!"
