#
# Cookbook Name:: ganglia
# Recipe:: default
#
# Copyright 2011, Heavy Water Software Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
require "ipaddr"
case node[:platform_family]
when "debian"
  package "ganglia-monitor"
when "rhel","fedora"
  include_recipe "ganglia::source"

  execute "copy ganglia-monitor init script" do
    command "cp " +
      "/usr/src/ganglia-#{node[:ganglia][:version]}/gmond/gmond.init " +
      "/etc/init.d/ganglia-monitor"
    not_if "test -f /etc/init.d/ganglia-monitor"
  end

  user "ganglia"
end

directory "/etc/ganglia"

local_addresses = Array.new()
node[:network][:interfaces].each_value do |iface|
  iface.addresses.each_key do |addr|
    local_addresses.push(addr)
  end
end

node[:ganglia][:clusters].each do |cluster|

  bind_addr = Hash.new()
  cluster[:collector].each do |addr|
    if node[:ganglia][:clusters_options][:check_ip_exist] == false or local_addresses.include?(addr)
      ipaddr = IPAddr.new addr
      if ipaddr.ipv4?
        bind_addr[addr] = "inet4"
      elsif ipaddr.ipv6?
        bind_addr[addr] = "inet6"
      end
    end
  end

  service "gmond-#{cluster[:name]}"

  template "/etc/ganglia/gmond-#{cluster[:name]}.conf" do
    source "cluster.gmond.conf.erb"
    variables( :cluster_name => cluster[:name],
               :bind_addr =>  bind_addr,
               :grid_name => node[:ganglia][:grid_name]
              )
    notifies :restart, "service[gmond-#{cluster[:name]}]", :delayed
  end

  template "/etc/init.d/gmond-#{cluster[:name]}" do
    source "init.gmond.erb"
    mode  "0755"
    variables( :cluster_name => cluster[:name],
               :instance_name => "gmond-#{cluster[:name]}" )
  end

  service  "gmond-#{cluster[:name]}" do
    action [:enable, :start]
  end

end
