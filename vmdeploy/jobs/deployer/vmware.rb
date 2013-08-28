require 'vmdeploy/vmomi'

module VMDeploy::Jobs::Deployer
    class VMware < VMDeploy::Jobs::Job
        include VMDeploy::Jobs::Deployer::Shared

        # DRY what?
        def perform
            log.info get_message_by_key('start') + ' -- ' + options.to_json
            progress_state_key('start')
            fail "VM params do not validate" unless VMDeploy::DeployerParams.new(options).valid?

            vmomi = VMDeploy::VMOMI.new host:       VMDeploy[:vcenter_cfg][:host],
                                        user:       VMDeploy[:vcenter_cfg][:user],
                                        password:   VMDeploy[:vcenter_cfg][:password],
                                        insecure:   VMDeploy[:vcenter_cfg][:insecure],
                                        datacenter: VMDeploy[:vcenter_cfg][:dcname]

            log.info get_message_by_key('viserver_connect')
            log.info 'Connecting to the vCenter server'
            vmomi.connect

            log.info get_message_by_key('vm_check_existence')
            progress_state_key('vm_check_existence')
            fail "A VM by this name already exists" if vmomi.find_vm_by_name(options['vmname'])

            log.info get_message_by_key('pool_vm_get')
            progress_state_key('pool_vm_get')
            pool_vms = vmomi.find_pool_templates(Regexp.new VMDeploy[:valid_pool_vmname])
            fail "No free pool servers are available" unless pool_vms.length > 0
            pool_vm = pool_vms.last
            pool_vm_name = pool_vm.name
            log.info "Deploying from \"#{pool_vm.name}\", #{pool_vms.length - 1} pool VM(s) left"

            log.info get_message_by_key('pool_vm_bootstrap')
            progress_state_key('pool_vm_bootstrap')
            fail "The chosen pool VM \"#{pool_vm.name}\" is not powered on, this is unexpected" if pool_vm.runtime.powerState != 'poweredOn'
            fail "\"#{pool_vm.guest.ipAddress}\" doesn't look like an IP address" unless
                /\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/.match(pool_vm.guest.ipAddress)
            log.info "Pool VM IP is #{pool_vm.guest.ipAddress}"
            bs_options = { :user => VMDeploy[:pool_vm_username],
                           :host => pool_vm.guest.ipAddress }
            bs_options[:password] = VMDeploy[:pool_vm_password] if VMDeploy[:pool_vm_password]
            ip = VMDeploy::Models::Ip.allocate! options['vmnetwork'], options['vmname'], pool_vm.summary.config.instanceUuid
            log.info "Allocated #{ip.address} on VLAN \"#{ip.vlan.name}\" (VLAN group \"#{options['vmnetwork']}\")"
            bs = VMDeploy::Bootstrap.new uuid, bs_options
            bs.puppet_conditional_install_precise
            vlan_config = VMDeploy[:vlan_groups][options['vmnetwork'].to_sym][ip.vlan.name.to_sym]
            bs.apply! :interface           => VMDeploy[:pool_vm_bootstrap_interface],
                      :ip                  => ip.address,
                      :netmask             => vlan_config[:netmask],
                      :gateway             => vlan_config[:gateway],
                      :hostname            => options['vmname'],
                      :domainname          => vlan_config[:domainname],
                      :dnsservers          => vlan_config[:dnsservers],
                      :searchdomains       => vlan_config[:searchdomains]

            log.info get_message_by_key('vm_shutdown')
            progress_state_key('vm_shutdown')
            vmomi.poweroff_vm pool_vm

            log.info get_message_by_key('pool_vm_tweak_hardware')
            progress_state_key('pool_vm_tweak_hardware')
            vmomi.reconfig_vm pool_vm,
                              :vmname         => options['vmname'],
                              :vnicname       => VMDeploy[:pool_vm_vnic_name],
                              :vlanname       => ip.vlan.name,
                              :vmramsize      => options['vmramsize'],
                              :vmnumberofcpus => options['vmnumberofcpus']

            log.info get_message_by_key('vm_start')
            progress_state_key('vm_start')
            vmomi.poweron_vm pool_vm

            log.info get_message_by_key('vm_wait_poweron')
            progress_state_key('vm_wait_poweron')
            vmomi.wait_for_guest_ip pool_vm
            log.info "VMware tools report IP: #{pool_vm.guest.ipAddress}"
            fail "Allocated IP and current VM IP don't match (#{ip.address}/#{pool_vm.guest.ipAddress})" unless ip.address == pool_vm.guest.ipAddress

            log.info get_message_by_key('vm_check_bootstrap_successful')
            progress_state_key('vm_check_bootstrap_successful')
            bs_options[:host] = ip.address
            bs = VMDeploy::Bootstrap.new uuid, bs_options
            bootstrapped = bs.bootstrap_success?
            fail 'Bootstrap seemingly failed' unless bootstrapped
            log.info 'Bootstrap OK'

            log.info get_message_by_key('notify_owner')
            progress_state_key('notify_owner')
            VMDeploy::Email::Mailer.send VMDeploy[:mailer_from],
                                         [options['owner'], options['creator'], VMDeploy[:support_email]],
                                         "\"#{options['vmname']}\" has been deployed",
                                         VMDeploy::Email::Success.render(:params => options,
                                                                         :ip => ip.address)

            log.info get_message_by_key('pool_vm_replace')
            progress_state_key('pool_vm_replace')
            job_id = VMDeploy::Jobs::Cloner.create :dst_vm_name => pool_vm_name
            log.info "Pool VM replace job id: #{job_id}"

            log.info get_message_by_key('done')
            progress_state_key('done')
        rescue Exception => e
            if e.is_a? DataMapper::SaveFailureError
                message = "#{e.message} (#{e.resource.errors.inspect})"
            else 
                message = e.message
            end
            log.error message
            VMDeploy::Email::Mailer.send VMDeploy[:mailer_from],
                                         [options['owner'], options['creator'], VMDeploy[:support_email]],
                                         "Error while deploying \"#{options['vmname']}\"",
                                         VMDeploy::Email::Failure.render(:params => options,
                                                                         :message => message,
                                                                         :support_email => VMDeploy[:support_email])
            raise
        end
        
        def name
            "#{options['vmname']}/#{options['owner']}"
        end
    end
end
