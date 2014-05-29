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


node[:ganglia][:cluster_collectors].each do |cluster|

  bind_addr = Array.new()
  cluster[:collector].each do |addr|
    if local_addresses.include?(addr)
      bind_addr.push(addr)
    end
  end
  
  template "/etc/ganglia/gmond-#{cluster[:name]}.conf" do
    source "cluster.gmond.conf.erb"
    variables( :cluster_name => cluster[:name],
               :bind_addr =>  bind_addr,
               :grid_name => node[:ganglia][:grid_name]
              )
    notifies :restart, "service[gmond-#{cluster[:name]}]"
  end

  runit_service "gmond-#{cluster[:name]}" do
    run_template_name "gmond"
    log_template_name "gmond"
    options({
              :cluster_name => cluster[:name],
              :gmond_binary => "/usr/sbin/gmond"
            })
  end

end
