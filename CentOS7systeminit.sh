#!/bin/bash
#v1 CentOS7内网服务器初始化脚本
#date 20171116
#version 2.0
#v2 修改默认阿里云源，修改用户的密码变量为gjs2017

log=/tmp/systeminit.log
gjspasswd=password

#1、添加gjs用户，并赋权
id gjs  >&/dev/null  
if [ $? -eq 0 ]
   then
   echo "user gjs exist" >>$log
   else
   groupadd gjs
   useradd -g gjs gjs
   echo "${gjspasswd}" | passwd --stdin gjs >>$log
   echo "gjs     ALL=(ALL)     ALL" >> /etc/sudoers
fi

#2.修改主机名
printf "Please enter current serve Hostname:"
read hn
echo "current Hostname is ${hn}"
IP=`ip addr |grep -w inet |grep -v '127.0.0.1' |awk '{print $2}' |cut -d/  -f 1`
echo "curenet ip is ${IP}"
sed -i '/'$IP'/d' /etc/hosts
echo -e "$IP $hn" >>/etc/hosts


#3、新建目录并修改权限
mkdir -p /opt/gjs/
chown -R gjs:gjs /opt/gjs

 
#4.锁定暂时无用的用户
for i in adm lp sync shutdown halt  uucp operator games gopher ftp
do
usermod -L $i
done

#6.关闭无用的服务
for i in postfix 
do
systemctl disable $i
done

#5.时间同步
yes | cp -a /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
rpm -q ntpdate
if [ $? -eq 0 ] ;then
   echo "ntpdate is installed" >>$log
   else
   yum -y install ntpdate >>$log
fi
cat >> /var/spool/cron/root <<EOF
* */6 * * * /usr/sbin/ntpdate -u ntp1.aliyun.com  > /dev/null 2>&1
EOF
systemctl restart crond

#6.安装lsof软件包
rpm -q lsof
if [ $? -eq 0 ]
   then 
   echo "lsof is installled" >>$log
   else
   yum -y install lsof >>$log
fi

#7.修改用户最大进程数
sed -i 's/4096/10240/' /etc/security/limits.d/20-nproc.conf
ulimit -u 10240

cat >> /etc/security/limits.conf << EOF
root             soft    nproc           10240
root             hard    nproc           10240
gjs              soft    nproc           10240
gjs              hard    nproc           10240
EOF


#8.内核优化参数
cat >> /etc/sysctl.d/99-sysctl.conf  << EOF

net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_fin_timeout = 30

net.ipv4.tcp_syn_retries= 2
net.ipv4.tcp_keepalive_time= 1200
net.ipv4.tcp_orphan_retries= 3
net.ipv4.tcp_keepalive_probes= 5
net.core.netdev_max_backlog= 3000

EOF

sysctl -p >>$log

#9.修改为阿里云yum源和添加epel源
rpm -q wget
if [ $? -eq 0 ] ;then
   echo "wget is installed" >>$log
   else
   yum -y install wget >>$log
fi
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
echo "####Downloading Centos.repo####"
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
echo "####Downloading epel.repo####"
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo






