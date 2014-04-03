case node[:platform_family]
when "debian"
  package "gmetad"
when "rhel", "fedora"
  include_recipe "ganglia::source"
  execute "copy gmetad init script" do
    command "cp " +
      "/usr/src/ganglia-#{node[:ganglia][:version]}/gmetad/gmetad.init " +
      "/etc/init.d/gmetad"
    not_if "test -f /etc/init.d/gmetad"
  end

  link "/usr/sbin/gmetad" do
    to "/usr/local/sbin/gmetad"
  end

end

directory "/var/lib/ganglia/rrds" do
  owner "nobody"
  recursive true
end

template "/etc/ganglia/gmetad.conf" do
  source "gmetad.conf.erb"
  variables( {:grid_name => node[:ganglia][:grid_name],
              :clusters => node[:ganglia][:clusters],
              :riemann => node[:ganglia][:riemann]})
  notifies :restart, "service[gmetad]"
end

if node[:recipes].include? "iptables"
  include_recipe "ganglia::iptables"
end

service "gmetad" do
  supports :restart => true
  action [ :enable, :start ]
end
