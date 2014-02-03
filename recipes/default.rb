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

service "jboss-as" do
  action [:stop, :disable]
end

file "/etc/init.d/jboss-as" do
  action :delete
end

directory "/etc/jboss-as" do
  action :delete
  recursive true
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

# Install the server via a gem so we can reuse our existing rbenv JRuby system
# install. This also allows us to upgrade the version of JRuby prior to a new,
# official TorqueBox package being released (useful when JRuby security updates
# are released, but TorqueBox takes a while to update).
rbenv_gem "torquebox-server" do
  rbenv_version node[:torquebox][:rbenv_version]
  version node[:torquebox][:version]
  notifies :run, "rbenv_script[setup-torquebox-gem-install]", :immediately
  notifies :restart, "service[torquebox]"
end

# Symlink the current torquebox gem directory into a predictable system-wide
# location.
rbenv_script "setup-torquebox-gem-install" do
  if(File.symlink?(node[:torquebox][:dir]))
    action :nothing
  else
    action :run
  end

  rbenv_version node[:torquebox][:rbenv_version]
  code <<-EOS
    eval `torquebox env`
    chown -R #{node[:torquebox][:user]} $TORQUEBOX_HOME
    rm -rf #{node[:torquebox][:dir]}
    ln -s $TORQUEBOX_HOME #{node[:torquebox][:dir]}
  EOS
end

# Move the jboss "deployments" directory outside the gem so it will persist
# across JRuby and TorqueBox upgrades.
directory "#{node[:torquebox][:conf_dir]}/deployments" do
  recursive true
  owner node[:torquebox][:user]
  group(node[:common_writable_group] || "root")
  mode "0775"
  action :create
end

directory "#{node[:torquebox][:dir]}/jboss/standalone/deployments" do
  action :delete
  recursive true
  only_if { ::File.directory?("#{node[:torquebox][:dir]}/jboss/standalone/deployments") && !::File.symlink?("#{node[:torquebox][:dir]}/jboss/standalone/deployments") }
end

link "#{node[:torquebox][:dir]}/jboss/standalone/deployments" do
  to "#{node[:torquebox][:conf_dir]}/deployments"
end

# Move the jboss "log" directory outside the gem so it's easier to find and
# will persist across upgrades.
directory node[:torquebox][:log_dir] do
  recursive true
  owner node[:torquebox][:user]
  group "root"
  mode "0755"
  action :create
end

directory "#{node[:torquebox][:dir]}/jboss/standalone/log" do
  action :delete
  only_if { ::File.directory?("#{node[:torquebox][:dir]}/jboss/standalone/log") && !::File.symlink?("#{node[:torquebox][:dir]}/jboss/standalone/log") }
end

link "#{node[:torquebox][:dir]}/jboss/standalone/log" do
  to node[:torquebox][:log_dir]
end

if(node[:torquebox][:clustered])
  template "#{node[:torquebox][:dir]}/jboss/standalone/configuration/standalone-ha.xml" do
    source "standalone-ha.xml.erb"
    mode "0644"
    user node[:torquebox][:user]
    group "root"
    notifies :restart, "service[torquebox]"
  end
else
  template "#{node[:torquebox][:dir]}/jboss/standalone/configuration/standalone.xml" do
    source "standalone.xml.erb"
    mode "0644"
    user node[:torquebox][:user]
    group "root"
    notifies :restart, "service[torquebox]"
  end
end

template "#{node[:torquebox][:conf_dir]}/jboss-as.conf" do
  source "jboss-as.conf.erb"
  mode "0644"
  user "root"
  group "root"
  variables({ :options => node[:torquebox] })
  notifies :restart, "service[torquebox]"
end

template "/etc/init.d/torquebox" do
  source "jboss-as-standalone.sh.erb"
  mode "0755"
  user "root"
  group "root"
  notifies :restart, "service[torquebox]"
end

service "torquebox" do
  supports :restart => true, :status => true, :reload => true
  action [:enable, :start]
end
