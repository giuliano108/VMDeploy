$LOAD_PATH.unshift File.expand_path('..', File.dirname(__FILE__))
require 'vmdeploycommon'
VMDeploy::dm_setup
require 'ipaddr'

fail "Refusing to run anywhere other than in development" unless VMDeploy[:environment] == 'development'

begin
    # Every IP is assigned to this "fake" VM
    vm = VMDeploy::Models::Vm.first_or_create(:name => 'ipstealer', :uuid => 0)

    vlans = []
    networks = {}
    VMDeploy[:vlan_groups].
        values. # get rid of the vlan group name
        each do |h| # an hash for each vlan group
            h.each do |k,v| # a key for each vlan
                vlans << VMDeploy::Models::Vlan.first_or_create(:name => k)
                networks[k.to_s]={:net=>v[:network],:mask=>v[:netmask]}
            end
        end

    vlans.each do |vlan|
        net  = IPAddr.new("#{networks[vlan.name][:net]}/#{networks[vlan.name][:mask]}")
        #from = net | IPAddr.new('0.0.0.10')
        #to   = net | IPAddr.new('0.0.0.20')
        from = net.to_range.to_a[3]
        to   = net.to_range.to_a[-2]

        (from..to).each do |ip|
            ip = ip.to_s
            puts "#{vlan.name}/#{ip}"
            VMDeploy::Models::Ip.create(:address => ip, :vlan => vlan, :vm => vm)
        end
    end
rescue DataMapper::SaveFailureError => e
    puts e.resource.errors.inspect
end
