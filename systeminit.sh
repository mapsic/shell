#!/bin/bash
#Date 20160822
#Version 1.0

#设置trade用户密码
tpasswd=trade

#1.检查是否为root用户，脚本必须使用root权限运行
if [[ "$(whoami)" != "root" ]]; then
    echo "please run this script as root !" >&2
    exit 1
fi

#2.关闭iptables
iptables -F
service iptables save
service iptables restart
chkconfig iptables off
service iptables stop
service ip6tables stop
if [ $? -ne 0 ]; then
    echo "stop iptables filed" >&2
    exit 1
fi

#3.关闭ipv6
echo "NETWORKING_IPV6=no" >>/etc/sysconfig/network
echo "alias net-pf-10 off" >> /etc/modprobe.conf
echo "alias ipv6 off" >> /etc/modprobe.conf
/sbin/chkconfig ip6tables off

#4.关闭SELinux
sed -i '/SELINUX/s/enforcing/disabled/' /etc/selinux/config
setenforce 0

#5.设置时区并设置crontab同步时间
yes | cp -a /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
rpm -q ntpdate
if [ $? -eq 0 ] ;then
   echo "ntpdate is installed" >&2
   else
   yum -y install ntpdate >&2
fi
cat >> /var/spool/cron/root <<EOF
*/10 * * * * /usr/sbin/ntpdate -u ntp1.aliyun.com > /dev/null 2>&1
EOF
service crond restart

#6.设置主机名和hosts
printf "Please enter current serer Hostname:"
read hn
echo "current Hostname is ${hn}"
IP=`ifconfig eth0  | grep -w "inet addr" |gawk  '{print $2}' | gawk -F: '{print $2}'`
echo "curenet eth0 ip is ${IP}"
sed -i '/HOSTNAME/d' /etc/sysconfig/network
echo "HOSTNAME=${hn}" >>/etc/sysconfig/network
cp -rf /etc/hosts /etc/hosts.bak
echo -e "$IP $hn" >>/etc/hosts

#7.锁定暂时无用的用户
for i in adm lp sync shutdown halt news uucp operator games gopher ftp
do
usermod -L $i
done

#8.关闭无用的服务
for i in nfs postfix ypbind portmap smb netfs lpd snmpd named squid xinetd apmd autofs cups isdn nfslock pcmcia sendmail
do
chkconfig --level 2345 $i off
done

#9.清除系统Banner
cp /etc/issue /etc/issue.bak
cp /etc/issue.net /etc/issue.bak
echo "" > /etc/issue
echo "" > /etc/issue.net

#10.设置用户最大进程数量
sed -i 's/1024/102400/' /etc/security/limits.d/90-nproc.conf
ulimit -u 102400

cat >> /etc/security/limits.conf << EOF
root             soft    nproc           16384
root             hard    nproc           16384
trade            soft    nproc           16384
trade            hard    nproc           16384

*           soft   nofile       65536
*           hard   nofile       65536
*           soft   nproc        10240
*           hard   nproc        10240
EOF

#11.关闭Ctrl-Alt-Del
sed -i 's#exec /sbin/shutdown -r now#\#exec /sbin/shutdown -r now#' /etc/init/control-alt-delete.conf

#12.sshd服务优化
sed -i 's%#PermitRootLogin yes%PermitRootLogin no%' /etc/ssh/sshd_config
sed -i 's/^GSSAPIAuthentication yes$/GSSAPIAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
sed -i 's/#Port 22/Port 2200/' /etc/ssh/sshd_config

#13添加程序运行用户trade
groupadd trade
useradd -g trade trade
echo "${tpasswd}" | passwd --stdin trade

#14.锁定重要文件以及去除特定目录的执行权限
chattr +i /etc/passwd /etc/shadow /etc/group /etc/gshadow
chmod -R 700 /etc/rc.d/init.d/*
chmod 644 /var/log/wtmp /var/run/utmp

#15.输错5次密码 账号被锁定5分钟
sed -i '4a auth        required      pam_tally2.so deny=5 unlock_time=300' /etc/pam.d/system-auth

#16.历史命令记录功能
if [ ! -e record.txt ]
   then
   echo "Can't find record.txt"
fi
dir=`pwd`
cat $dir/record.txt >>/etc/profile
source /etc/profile

#17.内核优化
yes | cp -rf  /etc/sysctl.conf /etc/sysctl.conf.bak
cat >> /etc/sysctl.conf << EOF
 net.ipv4.ip_forward = 0                          
 net.ipv4.conf.default.rp_filter = 1               
 net.ipv4.conf.default.accept_source_route = 0    
 kernel.sysrq = 0                                  
 kernel.core_uses_pid = 1
 net.ipv4.tcp_syncookies = 1
 kernel.msgmnb = 65536
 kernel.msgmax = 65536
 kernel.shmmax = 68719476736
 kernel.shmall = 4294967296
 net.ipv4.tcp_max_tw_buckets = 6000
 net.ipv4.tcp_sack = 1
 net.ipv4.tcp_window_scaling = 1
 net.ipv4.tcp_rmem = 4096 87380 4194304
 net.ipv4.tcp_wmem = 4096 16384 4194304
 net.core.wmem_default = 8388608
 net.core.rmem_default = 8388608
 net.core.rmem_max = 16777216
 net.core.wmem_max = 16777216
 net.core.netdev_max_backlog = 262144
 net.core.somaxconn = 262144
 net.ipv4.tcp_max_orphans = 3276800
 net.ipv4.tcp_max_syn_backlog = 262144
 net.ipv4.tcp_timestamps = 0
 net.ipv4.tcp_synack_retries = 1
 net.ipv4.tcp_syn_retries = 1
 net.ipv4.tcp_tw_recycle = 1
 net.ipv4.tcp_tw_reuse = 1
 net.ipv4.tcp_mem = 94500000 915000000 927000000
 net.ipv4.tcp_fin_timeout = 1
 net.ipv4.tcp_keepalive_time = 1200
 net.ipv4.ip_local_port_range = 1024 65535
EOF

sysctl -p

#.reboot system
echo "system init end, reboot system afte  5s"
sleep 5

reboot

