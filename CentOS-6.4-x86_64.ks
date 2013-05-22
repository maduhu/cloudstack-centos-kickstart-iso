install
text
reboot
skipx
url --url http://mirror.switch.ch/ftp/mirror/centos/6.4/os/x86_64/
lang en_US.UTF-8
firewall --service=ssh
keyboard sg-latin1
rootpw --iscrypted %DEFAULTPW%
authconfig --enableshadow --passalgo=sha512
timezone --utc Europe/Zurich
bootloader --location=mbr --append="nofb quiet splash=quiet"

network --bootproto dhcp

clearpart --all --initlabel
part /boot --fstype ext4 --size=512 --ondisk=sda --asprimary
part pv.00  --size=1 --grow --asprimary --ondisk=sda
logvol swap   --vgname=VolGroup   --size=4096     --name=swap     --fstype=swa
logvol /      --vgname=VolGropu   --size=20480    --name=system   --fstype=ext3


%packages
@core
@server-policy
rubygems
ruby-json
e4fsprogs
irqbalance
man-pages
mlocate
openssh-clients
redhat-lsb-core
vim-enhanced
wget

%post
/usr/bin/chvt 3
echo "updating system time"
/usr/sbin/ntpdate -sub 0.ch.pool.ntp.org
/usr/sbin/hwclock --systohc

su -c 'rpm -Uvh http://mirror.switch.ch/ftp/mirror/epel/6/i386/epel-release-6-8.noarch.rpm'
yum -t -y -e 0 upgrade
yum -t -y -e 0 install puppet

cat <<-EOD > /etc/puppet/puppet.conf
[main]
    confdir = /etc/puppet
    vardir = /var/lib/puppet
    logdir = /var/log/puppet
    rundir = /var/run/puppet
    pluginsync = true

[agent]
    classfile = $vardir/classes.txt
    localconfig = $vardir/localconfig
    ssldir = $vardir/ssl
    logdest = /var/log/puppet/puppet.log
    environment = production
    server = puppet
    report = true
EOD

/bin/touch /etc/puppet/namespaceauth.conf
puppet agent --test

exit 0
