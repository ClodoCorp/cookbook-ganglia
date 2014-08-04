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

  template "/etc/init.d/ganglia-monitor" do
    source "init.gmond.erb"
    mode  "0755"
    variables( :cluster_name => "",
               :instance_name => "ganglia-monitor" )
  end

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

# Normalize udp_send_channels
udp_send_channel = node[:ganglia][:udp_send_channel].map do |udpsch|
  # Fill it with default values
  temp_udpsch = {
    'mcast_join' => node[:ganglia][:gmond][:mcast_join],
    'ttl' => node[:ganglia][:gmond][:ttl],
    'port' => node[:ganglia][:gmond][:port]
  }
  # Merge with node attributes
  temp_udpsch.merge!(udpsch)

  if temp_udpsch.has_key?(:host) || temp_udpsch.has_key?('host')
    # Remove multicast options when using unicast
    temp_udpsch.delete('mcast_join')
    temp_udpsch.delete('mcast_if') if temp_udpsch['mcast_if']
  end
  temp_udpsch
end

if udp_send_channel.empty?
  udp_send_channel = [{:mcast_join => node[:ganglia][:gmond][:mcast_join],
                       :port => node[:ganglia][:gmond][:port],
                       :ttl => node[:ganglia][:gmond][:ttl]
                      }]
end

# Normalize udp_recv_channels
udp_recv_channel = node[:ganglia][:udp_recv_channel].map do |udprch|
  # Fill it with default values
  temp_udprch = {
    "port" => node[:ganglia][:gmond][:port]
  }
  # Merge with node attributes
  temp_udprch.merge!(udprch)
  temp_udprch
end

if udp_recv_channel.empty?
  udp_recv_channel = [{:mcast_join => node[:ganglia][:gmond][:mcast_join],
                       :bind => node[:ganglia][:gmond][:mcast_join],
                       :port => node[:ganglia][:gmond][:port]
                      }]
end

# Normalize tcp_accept_channels
tcp_accept_channel = node[:ganglia][:tcp_accept_channel].map do |tcpach|
  # Fill it with default values
  temp_tcpach = {
    "port" => node[:ganglia][:gmond][:port]
  }
  # Merge with node attributes
  temp_tcpach.merge!(tcpach)
  temp_tcpach
end

if tcp_accept_channel.empty?
  tcp_accept_channel = [{"port" => node[:ganglia][:gmond][:port]
                      }]
end

template "/etc/ganglia/gmond.conf" do
  source "gmond.conf.erb"
  variables( :udp_send_channel => udp_send_channel,
             :udp_recv_channel => udp_recv_channel,
             :tcp_accept_channel => tcp_accept_channel
            )
  notifies :restart, "service[ganglia-monitor]", :delayed
end

service "ganglia-monitor" do
  pattern "gmond"
  supports :restart => true
  action [ :enable, :start ]
end
