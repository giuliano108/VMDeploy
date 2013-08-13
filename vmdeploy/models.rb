require 'data_mapper'
module VMDeploy::Models
    class Vlan
		include DataMapper::Resource  
        property :id, Serial
        property :name, String, :required => true, :unique => true

        has n, :ips
    end

    class Vm
		include DataMapper::Resource  
        property :id, Serial
        property :name, String, :required => true, :unique => true
        property :uuid, String, :required => true, :unique => true

        has n, :ips
    end

	class Ip
		include DataMapper::Resource  
		property :id, Serial
		property :address, String, :required => true, :unique => true
        belongs_to :vlan
        belongs_to :vm, :required => false

        # Obtain a free IP from the given vlan_group and associate it with vm_name
        def self.allocate! vlan_group, vm_name, uuid
            vlan_group = vlan_group.to_sym
            fail("Unknown VLAN group \"#{vlan_group}\"") unless VMDeploy[:vlan_groups][vlan_group]
            vlans = VMDeploy[:vlan_groups][vlan_group].keys
            ip    = VMDeploy::Models::Ip.first(:vlan => vlans.map{|v| {:name => v}}, :vm => nil)
            fail("No more free IPs on the \"#{vlan_group}\" VLAN group") unless ip
            vm    = VMDeploy::Models::Vm.first_or_create(:name => vm_name, :uuid => uuid)
            ip.update(:vm => vm)
            ip
        end
	end
	DataMapper.auto_upgrade!
end
