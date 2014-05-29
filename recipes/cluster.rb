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

if Chef::Config['solo'] && !node['ganglia']['allow_solo_search']
  Chef::Log.warn('This recipe uses search. Chef Solo does not support search.')
  addresses = []
else
  addresses = search("network_interfaces__addresses:*")
end

node[:ganglia][:cluster_collectors].each do |cluster|

  bind_addr = Array.new()
  cluster[:collector].each do |addr|
    if addresses.include?(addr)
      bind_addr.push(addr)
    end
  end
  
  template "/etc/ganglia/gmond.conf" do
    source "gmond.conf.erb"
    variables( :udp_send_channel => udp_send_channel,
               :udp_recv_channel => udp_recv_channel,
               :tcp_accept_channel => tcp_accept_channel,
               :cluster => cluster[:name],
               :bind_addr =>  bind_addr,
               :grid => node[:ganglia]
              )
    notifies :restart, "gmond-#{cluster[:name]}"
  end

  service "gmond-#{cluster[:name]}" do
    pattern "gmond"
    supports :restart => true
    action [ :enable, :start ]
  end

end
