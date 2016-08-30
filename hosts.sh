#!/bin/bash
printf "Please enter current serer Hostname:"
read hn
echo "current Hostname is ${hn}"
IP=`ifconfig eth0  | grep -w "inet addr" |gawk  '{print $2}' | gawk -F: '{print $2}'`
echo "curenet eth0 ip is ${IP}"
sed -i '/HOSTNAME/d' /etc/sysconfig/network
echo "HOSTNAME=${hn}" >>/etc/sysconfig/network
cp -rf /etc/hosts /etc/hosts.bak
echo -e "$IP $hn" >>/etc/hosts

