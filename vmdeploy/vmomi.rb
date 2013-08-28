require 'rbvmomi'

module VMDeploy
    class VMOMI
        @connect_params = nil
        @dc_name        = nil
        @vim            = nil
        @vc             = nil

        def initialize params
            raise ArgumentError.new('Argument is not a Hash') unless params.is_a? Hash
            @connect_params = {:host => nil, :user => nil, :password => nil, :insecure => false, :datacenter => nil}.merge params
            raise ArgumentError.new(':host, :user, :password and :datacenter cannot be nil') unless @connect_params[:host] && @connect_params[:user] && @connect_params[:password] && @connect_params[:datacenter]

            @dc_name = @connect_params.delete :datacenter
        end

        def connect
            @vim = RbVmomi::VIM.connect(@connect_params) or fail('cannot connect to VCenter')
            @dc  = @vim.serviceInstance.find_datacenter(@dc_name) or fail 'datacenter not found'
        end

        def close
            @vim.close
        end

        def find_vms_by_name(term) 
            if term.is_a? String
                matcher = lambda {|term,value| term == value}
            elsif term.is_a? Regexp
                matcher = lambda {|term,value| term.match(value)}
            else
                raise ArgumentError.new "\"term\" must be a String or a Regexp"
            end
            filterSpec = RbVmomi::VIM.PropertyFilterSpec(
                :objectSet => [
                    :obj => @dc.vmFolder,
                    :skip => true,
                    :selectSet => [
                        RbVmomi::VIM.TraversalSpec(
                            :name => 'VisitFolders',
                            :type => 'Folder',
                            :path => 'childEntity',
                            :skip => false,
                            :selectSet => [
                                RbVmomi::VIM.SelectionSpec(:name => 'VisitFolders')
                            ]
                        )
                    ]
                ],
                :propSet => [{ :type => 'VirtualMachine', :pathSet => ['name','summary.config.instanceUuid'] }]
            )
            data = @vim.propertyCollector.RetrieveProperties(:specSet => [filterSpec])
            return [] if data.nil?
            data.find_all {|d| d.props[:propSet].find {|p| p.name == 'name' && matcher.call(term,p.val)}}.map {|r| r.obj}
        end

        def find_vm_by_name(term)
            vm = find_vms_by_name(term)
            fail "More than one VM returned, use find_vms_by_name instead" if vm.length > 1
            return vm.first
        end

        def find_pool_templates(term)
            fail "\"term\" must be a Regexp" unless term.is_a? Regexp
            # All the templates/pool servers must be in this folder
            # Subfolders won't be searched
            pool_folder = @dc.vmFolder.findByInventoryPath(VMDeploy[:pool_folder])
            fail "can't find \"#{VMDeploy[:pool_folder]}\" folder" if pool_folder.nil?
            filterSpec = RbVmomi::VIM.PropertyFilterSpec(
                :objectSet => [
                    :obj => pool_folder,
                    :skip => true,
                    :selectSet => [
                        RbVmomi::VIM.TraversalSpec(
                            :name => 'VisitFolders',
                            :type => 'Folder',
                            :path => 'childEntity',
                            :skip => false
                        )
                    ]
                ],
                :propSet => [{ :type => 'VirtualMachine', :pathSet => %w(name runtime.powerState guest.ipAddress) }]
            )
            data = @vim.propertyCollector.RetrieveProperties(:specSet => [filterSpec])
            return [] if data.nil?
            vms = data.find_all {|d| d.props[:propSet].find {|p| p.name == 'name' && term.match(p.val)}}.map {|r| r.obj}
            #FIXME: vms.find_all {|vm| vm.customValue.find {|p| p.key == 2}.value == 'pool'} # 2 is "Creator" 
        end

        def clone src_vm, dst_folder_name, dst_vm_name
            raise ArgumentError.new('src_vm is not a VirtualMachine') unless src_vm.is_a? RbVmomi::VIM::VirtualMachine
            raise ArgumentError.new('dst_folder_name and dst_vm_name must be strings') unless dst_folder_name.is_a?(String) && dst_vm_name.is_a?(String)
            raise ArgumentError.new('Must supply a block for progress notification') unless block_given?

            dst_folder = @dc.vmFolder.findByInventoryPath(dst_folder_name)
            fail "can't find \"#{dst_folder_name}\" folder" if dst_folder.nil?
            dst_vm = src_vm.CloneVM_Task(:folder => dst_folder,
                                         :name => dst_vm_name,
                                         :spec => {
                                           :location => {
                                           },
                                           :template => false,
                                           :powerOn => true,
                                         }).wait_for_progress do |percent|
                                            yield percent
                                         end
        end


        def vmotion src_vm_path, dst_ds_path
            raise ArgumentError.new('src_vm_path is not a String') unless src_vm_path.is_a? String
            raise ArgumentError.new('dst_ds_path is not a String') unless dst_ds_path.is_a? String
            raise ArgumentError.new('Must supply a block for progress notification') unless block_given?

            src_vm = @dc.vmFolder.findByInventoryPath(src_vm_path)
            fail "can't find \"#{src_vm_path}\"" if src_vm.nil?
            fail "\"#{src_vm_path}\"" unless src_vm.is_a? RbVmomi::VIM::VirtualMachine
            dst_ds = @dc.vmFolder.findByInventoryPath(dst_ds_path)
            fail "can't find \"#{dst_ds_path}\"" if dst_ds.nil?
            fail "\"#{dst_ds_path}\"" unless dst_ds.is_a? RbVmomi::VIM::Datastore
            src_vm.RelocateVM_Task(:spec => {
                                     :datastore => dst_ds
                                   }).wait_for_progress do |percent|
                                      yield percent
                                   end
        end

        def poweron_vm vm
            power_vm 'on', vm
        end

        def poweroff_vm vm
            power_vm 'off', vm
        end

        def power_vm state, vm
            raise ArgumentError.new('vm is not a VirtualMachine') unless vm.is_a? RbVmomi::VIM::VirtualMachine
            raise ArgumentError.new("state can be either 'on' or 'off'") unless state == 'on' || state == 'off'
            state = state.to_s.capitalize
            result = vm._call(:"Power#{state}VM_Task").wait_for_completion
        end

        def reconfig_vm vm, params={}
            raise ArgumentError.new('vm is not a VirtualMachine') unless vm.is_a? RbVmomi::VIM::VirtualMachine
            raise ArgumentError.new('Argument is not a Hash') unless params.is_a? Hash
            params = {:vmname => nil, :vnicname => nil, :vlanname => nil, :vmramsize => nil, :vmnumberofcpus => nil}.merge(params)
            raise ArgumentError.new('All parameters must be supplied') unless params.all?

            new_net     = vm.runtime.host.network.find {|n| n.name == params[:vlanname]}
            fail "VLAN #{vlan_name} doens't exist on the host where the VM is" unless new_net
            nic         = vm.config.hardware.device.find {|d| d.is_a?(RbVmomi::VIM::VirtualEthernetCard) && d.deviceInfo.label == params[:vnicname]}
            nic.backing = nic.backing.dup.tap {|bi| bi.deviceName = new_net.name; bi.network = new_net}
            result = vm.ReconfigVM_Task( :spec => {
                :name => params[:vmname],
                :numCPUs => params[:vmnumberofcpus],
                :memoryMB => VMDeploy::human_byte_size_to_mib(params[:vmramsize]),
                :deviceChange => [
                    {
                        :operation => :edit,
                        :device => nic
                    }
                ]
            }).wait_for_completion
        end

        # Wait until VMware tools report an IP address on the machine
        def wait_for_guest_ip vm, params={}
            raise ArgumentError.new('vm is not a VirtualMachine') unless vm.is_a? RbVmomi::VIM::VirtualMachine
            raise ArgumentError.new('Argument is not a Hash') unless params.is_a? Hash
            params = {:maxtime => 300, :delay => 10}.merge(params)
            start_time = Time.now.to_f
            ip = nil
            while (Time.now.to_f - start_time) < params[:maxtime]
                if vm.guest.guestState == 'running' && vm.guest.ipAddress != ''
                    ip = vm.guest.ipAddress
                    break
                end
                sleep params[:delay]
            end
            raise "Timeout while wait_for_guest_ip" unless ip
            ip
        end

        def move_vm_into_folder vm, dst_folder_name
            raise ArgumentError.new('vm is not a VirtualMachine') unless vm.is_a? RbVmomi::VIM::VirtualMachine
            raise ArgumentError.new('dst_folder_name is not a String') unless dst_folder_name.is_a? String

            dst_folder = @dc.vmFolder.findByInventoryPath(dst_folder_name)
            fail "can't find \"#{dst_folder_name}\" folder" if dst_folder.nil?
            result = dst_folder.MoveIntoFolder_Task(:list => [vm]).wait_for_completion
        end

        private :power_vm
    end
end
