install
text
reboot
skipx
url --url http://mirror.switch.ch/ftp/mirror/centos/6.4/os/x86_64/
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
/usr/sbin/ntpdate -sub 0.ch.pool.ntp.org
chkconfig ntpd on

cat <<-EOD > /etc/yum.repos.d/swisstxt.repo
[swisstxt]
name=SWISS TXT Yum Repostory
baseurl=http://yum.swisstxt.ch/centos.6.x86_64.swisstxt
enabled=1
gpgcheck=0
priority=1
EOD

rpm -Uvh http://mirror.switch.ch/ftp/mirror/epel/6/i386/epel-release-6-8.noarch.rpm
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

# Enable API publci key support for Cloudstack 
# see http://cloudstack.apache.org/docs/en-US/Apache_CloudStack/4.0.2/html/Installation_Guide/using-sshkeys.html
cat <<-EOD > /etc/init.d/cloud-set-guest-sshkey.in
# chkconfig: 345 98 02
# description: SSH Public Keys Download Client

# Modify this line to specify the user (default is root)
user=root

# Add your DHCP lease folders here
DHCP_FOLDERS="/var/lib/dhclient/* /var/lib/dhcp3/*"
keys_received=0
file_count=0

for DHCP_FILE in $DHCP_FOLDERS
do
	if [ -f $DHCP_FILE ]
	then
		file_count=$((file_count+1))
		SSHKEY_SERVER_IP=$(grep dhcp-server-identifier $DHCP_FILE | tail -1 | awk '{print $NF}' | tr -d '\;')

		if [ -n $SSHKEY_SERVER_IP ]
		then
			logger -t "cloud" "Sending request to ssh key server at $SSHKEY_SERVER_IP"

			publickey=$(wget -t 3 -T 20 -O - http://$SSHKEY_SERVER_IP/latest/public-keys 2>/dev/null)

			if [ $? -eq 0 ]
			then
				logger -t "cloud" "Got response from server at $SSHKEY_SERVER_IP"
				keys_received=1
				break
			fi
		else
			logger -t "cloud" "Could not find ssh key server IP in $DHCP_FILE"
		fi
	fi
done

# did we find the keys anywhere?
if [ "$keys_received" == "0" ]
then
    logger -t "cloud" "Failed to get ssh keys from any server"
    exit 1
fi

# set ssh public key
homedir=$(grep ^$user /etc/passwd|awk -F ":" '{print $6}')
sshdir=$homedir/.ssh
authorized=$sshdir/authorized_keys

if [ ! -e $sshdir ]
then
    mkdir $sshdir
fi

if [ ! -e $authorized ]
then
    touch $authorized
fi

cat $authorized|grep -v "$publickey" > $authorized
echo "$publickey" >> $authorized

exit 0
EOD
chmod +x /etc/init.d/cloud-set-guest-sshkey.in
chkconfig --add cloud-set-guest-sshkey.in

/bin/touch /etc/puppet/namespaceauth.conf
test -n "$puppetmaster" && puppet agent --test

exit 0
