%{?scl:%scl_package rubygem-%{gem_name}}
%{!?scl:%global pkg_name %{name}}

%global homedir /usr/share/openstack-foreman-installer

Name:	%{?scl_prefix}openstack-foreman-installer	
Version:	0.0.2
Release:	1%{?dist}
Summary:	Installer & Configuration tool for OpenStack

Group:		Applications/System
License:	GPLv2
URL:		https://github.com/jsomara/astapor
Source0: http://file.rdu.redhat.com:~/jomara/openstack-foreman-installer.tar.gz	

Requires: %{?scl_prefix}ruby-puppet
Requires:	packstack-modules-puppet
Requires: %{?scl_prefix}ruby
Requires: foreman >= 1.1
Requires: %{?scl_prefix}rubygem-foreman_openstack_simplify
# Requires: foreman-mysql >= 1.1
# Requires: foreman-installer >= 2.0
Requires: mysql-server

%description
Tools for configuring The Foreman for provisioning & configuration of
OpenStack.

%prep
%setup -q

%build

%install
install -d -m 0755 %{buildroot}%{homedir}
install -d -m 0755 %{buildroot}%{homedir}/bin
install -m 0755 bin/foreman-setup.rb %{buildroot}%{homedir}/bin
install -m 0755 bin/foreman_server.sh %{buildroot}%{homedir}/bin
install -m 0644 bin/foreman-params.json %{buildroot}%{homedir}/bin
install -d -m 0755 %{buildroot}%{homedir}/puppet/modules
cp -Rp puppet/* %{buildroot}%{homedir}/puppet/modules/
install -d -m 0755 %{buildroot}%{homedir}/config
install -m 0644 config/broker-ruby %{buildroot}%{homedir}/config
install -m 0644 config/database.yml %{buildroot}%{homedir}/config
install -m 0644 config/foreman-nightlies.repo %{buildroot}%{homedir}/config
install -m 0644 config/ruby193-passenger.conf %{buildroot}%{homedir}/config

%files
%{homedir}/
%{homedir}/bin/
%{homedir}/bin/foreman-setup.rb
%{homedir}/bin/foreman_server.sh
%{homedir}/bin/foreman-params.json
%{homedir}/puppet/
%{homedir}/puppet/*
%{homedir}/config/
%{homedir}/config/broker-ruby
%{homedir}/config/database.yml
%{homedir}/config/foreman-nightlies.repo
%{homedir}/config/ruby193-passenger.conf

%changelog
* Tue May 21 2013 Jordan OMara <jomara@redhat.com> 0.0.2-1
- new package built with tito

* Mon May 20 2013 Jordan OMara <jomara@redhat.com> 0.0.1-1
- initial packaging
