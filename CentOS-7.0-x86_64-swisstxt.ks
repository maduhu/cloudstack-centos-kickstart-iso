install
text
reboot
skipx
url --url http://mirror.switch.ch/ftp/mirror/centos/7/os/x86_64/
lang en_US.UTF-8
firewall --service=ssh
keyboard sg-latin1
rootpw --iscrypted $1$esW0xSO9$5QojXX2ul5gHti70gLkwp0
authconfig --enableshadow --passalgo=sha512
timezone --utc Europe/Zurich
bootloader --location=mbr --append="nofb quiet splash=quiet"

network --device=eth0 --bootproto dhcp

zerombr
clearpart --all --initlabel
part /boot --fstype ext4 --size=512 --ondisk=sda --asprimary
part pv.00 --size=1 --grow --asprimary --ondisk=sda
volgroup system pv.00
logvol swap --vgname=system --size=2096 --name=swap --fstype=swap
logvol / --vgname=system --grow --size 2048 --maxsize=20480 --name=root --fstype=ext4


%packages
@core
@server-policy
yum-priorities
e4fsprogs
irqbalance
man-pages
mlocate
openssh-clients
redhat-lsb-core
vim-enhanced
wget


%post
exec < /dev/tty3 > /dev/tty3
/usr/bin/chvt 3
/usr/sbin/ntpdate -sub ch.pool.ntp.org
chkconfig ntpd on

rpm -Uvh http://mirror.switch.ch/ftp/mirror/epel/beta/7/x86_64/epel-release-7-0.2.noarch.rpm
yum -t -y -e 0 upgrade
yum -t -y -e 0 install puppet

# find first usable puppetmaster
puppetmaster="`getent ahosts puppet`" || 
for site in bie zrh; do
  for nr in `seq -f %02.0f 0 9`; do
    puppetmaster="`getent ahosts puppet-${site}-${nr}`" && break 2
  done
done
puppetmaster="`echo $puppetmaster | awk '{print $3}'`"

cat <<-EOD > /etc/puppet/puppet.conf
[main]
    confdir = /etc/puppet
    vardir = /var/lib/puppet
    logdir = /var/log/puppet
    rundir = /var/run/puppet
    pluginsync = true

[agent]
    classfile = \$vardir/classes.txt
    localconfig = \$vardir/localconfig
    ssldir = \$vardir/ssl
    logdest = /var/log/puppet/puppet.log
    environment = production
    server = $puppetmaster
    report = true
EOD

# Enable API public key support for Cloudstack 
# see http://cloudstack.apache.org/docs/en-US/Apache_CloudStack/4.0.2/html/Installation_Guide/using-sshkeys.html
wget -O /etc/init.d/cloud-set-guest-sshkey.in "http://downloads.sourceforge.net/project/cloudstack/SSH%20Key%20Gen%20Script/cloud-set-guest-sshkey.in?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fcloudstack%2Ffiles%2FSSH%2520Key%2520Gen%2520Script%2F&ts=1331225219&use_mirror=iweb"
chmod +x /etc/init.d/cloud-set-guest-sshkey.in
chkconfig --add cloud-set-guest-sshkey.in

/bin/touch /etc/puppet/namespaceauth.conf
test -n "$puppetmaster" && puppet agent --test

exit 0
