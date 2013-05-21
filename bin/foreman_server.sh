#!/bin/bash

# PUPPETMASTER is the fqdn that needs to be resolvable by clients.
# Change if needed
if [ "x$PUPPETMASTER" = "x" ]; then
  # Set PuppetServer
  #export PUPPETMASTER=puppet.example.com
  export PUPPETMASTER=$(hostname --fqdn)
fi

if [ "x$FOREMAN_INSTALLER_DIR" = "x" ]; then
  FOREMAN_INSTALLER_DIR=$HOME/foreman-installer
fi

if [ ! -d $FOREMAN_INSTALLER_DIR ]; then
  echo "$FOREMAN_INSTALLER_DIR does not exist.  exiting"
  exit 1
fi

if [ ! -f foreman_server.sh ]; then
  echo "You must be in the same dir as foreman_server.sh when executing it"
  exit 1
fi

if [ ! -f /etc/redhat-release ] || \
    cat /etc/redhat-release | grep -v -q -P 'release 6.[456789]'; then
  echo "This installer is only supported on RHEL 6.4 or greater."
  exit 1
fi

# start with a subscribed RHEL6 box.  hint:
#    subscription-manager register
#    subscription-manager subscribe --auto

function install_pkgs {
  depends=$1
  install_list=""
  for dep in $depends; do
    if ! `rpm -q --quiet --nodigest $dep`; then
      install_list="$install_list $dep"
    fi
  done

  # Install the needed packages
  if [ "x$install_list" != "x" ]; then
    sudo yum install -y $install_list
  fi

  # Verify the dependencies did install
  fail_list=""
  for dep in $depends; do
    if ! `rpm -q --quiet --nodigest $dep`; then
      fail_list="$fail_list $dep"
    fi
  done

  # If anything failed verification, we tell the user and exit
  if [ "x$fail_list" != "x" ]; then
      echo "ABORTING:  FAILED TO INSTALL $fail_list"
      exit 1
  fi
}

install_pkgs "yum-utils yum-rhn-plugin"

rpm -Uvh http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
cp config/foreman-nightlies.repo /etc/yum.repos.d/
yum-config-manager --enable rhel-6-server-optional-rpms
yum clean all

# install dependent packages
install_pkgs "augeas ruby193-puppet git policycoreutils-python"

# enable ip forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf

# disable selinux in /etc/selinux/config
# TODO: selinux policy
setenforce 0

augtool -s set /files/etc/puppet/puppet.conf/agent/server $PUPPETMASTER

# Puppet Plugins
augtool -s set /files/etc/puppet/puppet.conf/main/pluginsync true

pushd $FOREMAN_INSTALLER_DIR
scl enable ruby193 "puppet apply --verbose -e '
  include puppet, puppet::server, passenger, foreman_proxy
  class { 'foreman':
    db_type => 'mysql',
  }
  ' --modulepath=./"
popd

sudo -u foreman scl enable ruby193 "cd /usr/share/foreman; RAILS_ENV=production rake db:migrate"

########### FIX PASSENGER ################# 
cp config/broker-ruby /usr/share/foreman
chmod 777 /usr/share/foreman/broker-ruby
cp config/ruby193-passenger.conf /etc/httpd/conf.d/ruby193-passenger.conf
rm /etc/httpd/conf.d/passenger.conf

###########################################

# turn on certificate autosigning
echo '*' >> /etc/puppet/autosign.conf

# install puppet modules
mkdir -p /etc/puppet/modules/production
cp -r puppet/* /etc/puppet/modules/production/
sudo -u foreman scl enable ruby193 "cd /usr/share/foreman; RAILS_ENV=production rake puppet:import:puppet_classes[batch]"

# Configure defaults, host groups, proxy, etc
pushd bin/

sed -i "s/foreman_hostname/$PUPPETMASTER/" foreman-params.json

export PASSWD_COUNT=$(cat foreman-params.json | grep changeme | wc -l)

for i in $(seq $PASSWD_COUNT)
do
  export PASSWD=$(scl enable ruby193 "ruby foreman-setup.rb password")
  sed -i "s/changeme/$PASSWD" foreman-params.json
done

scl enable ruby193 "ruby foreman-setup.rb proxy"
scl enable ruby193 "ruby foreman-setup.rb globals"
scl enable ruby193 "ruby foreman-setup.rb hostgroups"
popd
# write client-register-to-foreman script
# TODO don't hit yum unless packages are not installed
cat >/tmp/foreman_client.sh <<EOF

# start with a subscribed RHEL7 box
rpm -Uvh http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum-config-manager --enable rhel-6-server-optional-rpms
yum clean all

# install dependent packages
yum install -y http://yum.theforeman.org/releases/latest/el6/x86_64/rubygems-1.8.10-1.el6.noarch.rpm
yum install -y augeas ruby193-puppet

# Set PuppetServer
augtool -s set /files/etc/puppet/puppet.conf/agent/server $PUPPETMASTER

# Puppet Plugins
augtool -s set /files/etc/puppet/puppet.conf/main/pluginsync true

# check in to foreman
puppet agent --test
sleep 1
puppet agent --test

/etc/init.d/puppet start
EOF

echo "Foreman is installed and almost ready for setting up your OpenStack"
echo "First, you need to input a few parameters into foreman."
echo "Visit https://$(hostname)/common_parameters"
echo ""
echo "Then copy /tmp/foreman_client.sh to your openstack client nodes"
echo "Run that script and visit the HOSTS tab in foreman. Pick CONTROLLER"
echo "host group for your controller node and COMPUTE host group for the rest"
echo ""
echo "Once puppet runs on the machines, OpenStack is ready!"
