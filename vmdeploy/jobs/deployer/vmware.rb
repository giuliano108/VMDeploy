require 'rbvmomi'

module VMDeploy::Jobs::Deployer
    class VMWare
        include VMDeploy::Loggr
        include VMDeploy::Jobs::Deployer::Shared
        include Resque::Plugins::Status
        @queue = :deployer

        def initialize(uuid, options={})
            super uuid, options
            log_setup(File.join(VMDeploy::LogDir,'deployer.log'),self.class.to_s,uuid.to_s)
        end

        def bailout(message)
            log.error message
            fail message
        end

        def find_vms_by_name(term) 
            if term.is_a? String
                matcher = lambda {|term,value| term == value}
            elsif term.is_a? Regexp
                matcher = lambda {|term,value| term.match(value)}
            else
                fail "\"term\" must be a String or a Regexp"
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
                :propSet => [{ :type => 'VirtualMachine', :pathSet => ['name'] }]
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

        # TODO: find_pool_templates relies on this patch to "lib/rbvmomi/vim/Folder.rb"
        #       I'll create a pull request for it
        # def findByInventoryPath path
        #   propSpecs = {
        #       :entity => self, :inventoryPath => path
        #   }
        #   x = _connection.searchIndex.FindByInventoryPath(propSpecs)
        # end
        def find_pool_templates(term)
            fail "\"term\" must be a Regexp" unless term.is_a? Regexp
            # All the templates/pool servers must be in a folder named "Pool"
            # Subfolders won't be searched
            pool_folder = @dc.vmFolder.findByInventoryPath('/Qube/vm/Pool')
            fail "can't find \"Pool\" folder" if pool_folder.nil?
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
            vms.find_all {|vm| vm.customValue.find {|p| p.key == 2}.value == 'pool'} # 2 is "Creator"
        end

        # DRY what?
        def perform
            log.info get_message_by_key('start') + ' -- ' + options.to_json
            progress_state_key('start')
            @vc_cfg = YAML.load_file(File.join(File.dirname(__FILE__),'..','..','..','config','vcenter.yml'))
            bailout "VM params do not validate" unless VMDeploy::DeployerParams.new(options).valid?

            log.info get_message_by_key('viserver_connect')
            progress_state_key('viserver_connect')
            @vim = RbVmomi::VIM.connect host:     VMDeploy[:vcenter_cfg][:host],
                                        user:     VMDeploy[:vcenter_cfg][:user],
                                        password: VMDeploy[:vcenter_cfg][:password],
                                        insecure: VMDeploy[:vcenter_cfg][:insecure]
            bailout "Can't connect to vCenter" unless @vim
            @dc  = @vim.serviceInstance.find_datacenter(VMDeploy[:vcenter_cfg][:dcname]) or bailout 'datacenter not found'

            log.info get_message_by_key('vm_check_existence')
            progress_state_key('vm_check_existence')
            bailout "A VM by this name already exists" if find_vm_by_name(options['vmname'])

            log.info get_message_by_key('pool_vm_get')
            progress_state_key('pool_vm_get')
            pool_vms = find_pool_templates(/^bbpool/) #TODO: this has to come from the Form
            bailout "No free pool servers are available" unless pool_vms.length > 0
            pool_vm = pool_vms.last
            log.info "Deploying from \"#{pool_vm.name}\", #{pool_vms.length - 1} pool VM(s) left"

            log.info get_message_by_key('pool_vm_bootstrap')
            progress_state_key('pool_vm_get')
            bailout "The chosen pool server is not powered on, this is unexpected" if pool_vm.runtime.powerState != 'poweredOn'
            bailout "\"#{pool_vm.guest.ipAddress}\" doesn't look like an IP address" unless
                /\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/.match(pool_vm.guest.ipAddress)
            log.info "Pool server IP is #{pool_vm.guest.ipAddress}"

            #TODO: check if the IP is on the Dev network
            
            log.info get_message_by_key('done')
            progress_state_key('done')
        rescue Exception => e
            log.error e.message
            raise
        end
        
        def name
            "#{options['vmname']}/#{options['owner']}"
        end
    end
end
