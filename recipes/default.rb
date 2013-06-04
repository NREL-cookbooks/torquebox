#
# Cookbook Name:: torquebox
# Recipe:: default
#
# Copyright 2013, NREL
#
# All rights reserved - Do Not Redistribute
#

include_recipe "java"
include_recipe "rbenv::system"

node.set_unless[:torquebox][:bind_ip] = node[:ipaddress]

hostsfile_entry node[:torquebox][:bind_ip] do
  hostname "local-torquebox-ip"
  action :create
end

if(node[:torquebox][:clustered] && !node[:torquebox][:multicast])
  if Chef::Config[:solo]
    abort("Torquebox clustering without multicast requires chef search. Chef Solo does not support search.")
  end

  if(!node[:torquebox][:cluster_name])
    abort("Torquebox clustering without multicast requires the 'cluster_name' attribute to be set.")
  end

  peer_nodes = search(:node, "torquebox_clustered:true AND \
    torquebox_cluster_name:#{node[:torquebox][:cluster_name]} AND \
    chef_environment:#{node.chef_environment}")

  node.set[:torquebox][:peers] = peer_nodes.map { |peer| peer[:ipaddress] }
  node.set[:torquebox][:peers].delete(node[:ipaddress])
end

user node[:torquebox][:user] do
  system true
  shell "/bin/false"
  home node[:torquebox][:dir]
end

# Setup the deployments directory outside of the torquebox installation
# directory so that on upgrades the apps are persisted.
directory "#{node[:torquebox][:dir]}/deployments" do
  recursive true
  owner node[:torquebox][:user]
  group(node[:common_writable_group] || "root")
  mode "0775"
  action :create
end

directory node[:torquebox][:log_dir] do
  recursive true
  owner node[:torquebox][:user]
  group "root"
  mode "0755"
  action :create
end

# Install the server via a gem so we can reuse our existing rbenv JRuby system
# install. This also allows us to upgrade the version of JRuby prior to a new,
# official TorqueBox package being released (useful when JRuby security updates
# are released, but TorqueBox takes a while to update).
rbenv_gem "torquebox-server" do
  if node[:torquebox][:rbenv_version]
    rbenv_version node[:torquebox][:rbenv_version]
  end

  version node[:torquebox][:version]

  # The big torquebox-server gem isn't available at rubygems.org:
  # http://torquebox.org/news/2013/05/07/torquebox-2-3-1-released/
  source "http://torquebox.org/rubygems"

  notifies :run, "rbenv_script[setup-torquebox-gem-install]", :immediately
  notifies :restart, "service[jboss-as]"
end

# Make a few tweaks to the gem-based installation.
rbenv_script "setup-torquebox-gem-install" do
  if File.exists?("#{node[:torquebox][:dir]}/home")
    action :nothing
  else
    action :run
  end

  if node[:torquebox][:rbenv_version]
    rbenv_version node[:torquebox][:rbenv_version]
  end

  code <<-EOS
    eval `torquebox env`

    # Ensure the gem files are owned by the torquebox user (since it writes so
    # various directories inside the gem).
    chown -R #{node[:torquebox][:user]} $TORQUEBOX_HOME

    # Move the jboss "deployments" directory outside the gem so it will persist
    # across JRuby and TorqueBox upgrades.
    mv $JBOSS_HOME/standalone/deployments/README.txt #{node[:torquebox][:dir]}/deployments/
    rm -rf $JBOSS_HOME/standalone/deployments
    ln -s #{node[:torquebox][:dir]}/deployments $JBOSS_HOME/standalone/deployments

    # Move the jboss "log" directory outside the gem so it's easier to find and
    # will persist across upgrades.
    rm -rf $JBOSS_HOME/standalone/log
    ln -s #{node[:torquebox][:log_dir]} $JBOSS_HOME/standalone/log

    # Symlink the gem directory into a predictable system-wide location.
    rm -f #{node[:torquebox][:dir]}/home
    ln -s $TORQUEBOX_HOME #{node[:torquebox][:dir]}/home
  EOS
end

if(node[:torquebox][:clustered])
  template "#{node[:torquebox][:dir]}/home/jboss/standalone/configuration/standalone-ha.xml" do
    source "standalone-ha.xml.erb"
    mode "0644"
    user node[:torquebox][:user]
    group "root"
    notifies :restart, "service[jboss-as]"
  end
end

directory "/etc/jboss-as" do
  recursive true
  mode "0755"
  user "root"
  group "root"
end

template "/etc/jboss-as/jboss-as.conf" do
  source "jboss-as.conf.erb"
  mode "0644"
  user "root"
  group "root"
  variables({ :options => node[:torquebox] })
  notifies :restart, "service[jboss-as]"
end

cookbook_file "/etc/init.d/jboss-as" do
  source "jboss-as-standalone.sh"
  mode "0755"
  user "root"
  group "root"
  notifies :restart, "service[jboss-as]"
end

service "jboss-as" do
  supports :restart => true, :status => true, :reload => true
  action [:enable, :start]
end
