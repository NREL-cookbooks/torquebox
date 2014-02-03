#
# Cookbook Name:: torquebox
# Recipe:: backstage
#
# Copyright 2013, NREL
#
# All rights reserved - Do Not Redistribute
#

include_recipe "torquebox"

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

password = nil
if(node[:torquebox][:clustered])
  peer_nodes = search(:node, "torquebox_clustered:true AND \
    torquebox_cluster_name:#{node[:torquebox][:cluster_name]} AND \
    chef_environment:#{node.chef_environment}")

  peer_nodes.each do |peer|
    if(peer[:torquebox][:backstage] && peer[:torquebox][:backstage][:password])
      password = peer[:torquebox][:backstage][:password]
      break
    end
  end
end

node.set_unless[:torquebox][:backstage][:password] = password || secure_password

rbenv_gem "torquebox-backstage" do
  rbenv_version node[:torquebox][:rbenv_version]
  version node[:torquebox][:backstage][:version]
  notifies :run, "rbenv_script[torquebox-backstage-deploy]", :immediately
end

rbenv_script "torquebox-backstage-deploy" do
  if(File.exists?("#{node[:torquebox][:conf_dir]}/deployments/torquebox-backstage-knob.yml"))
    action :nothing
  else
    action :run
  end

  rbenv_version node[:torquebox][:rbenv_version]
  code <<-EOS
    eval `torquebox env`
    export TORQUEBOX_HOME
    export JBOSS_HOME
    BACKSTAGE_HOME=`ruby -e 'print Gem::Specification.find_by_name("torquebox-backstage").gem_dir'`

    chown -R #{node[:torquebox][:user]} $BACKSTAGE_HOME
    backstage deploy --secure=#{node[:torquebox][:backstage][:username]}:#{node[:torquebox][:backstage][:password]}
  EOS
end
