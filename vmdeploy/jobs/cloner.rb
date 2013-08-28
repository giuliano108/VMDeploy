module VMDeploy::Jobs
    class Cloner < Job
        extend Resque::Plugins::ConcurrentRestriction 
        concurrent VMDeploy[:concurrent_cloners]

        def progress_state percent, message
            at(percent.round, 100, message)
        end

        def perform
            log.info 'Start' + ' -- ' + options.to_json
            progress_state 0, 'Start'
            fail "Missing 'dst_vm_name' parameter" unless options['dst_vm_name'] && !options['dst_vm_name'].empty?

            vmomi = VMDeploy::VMOMI.new host:       VMDeploy[:vcenter_cfg][:host],
                                        user:       VMDeploy[:vcenter_cfg][:user],
                                        password:   VMDeploy[:vcenter_cfg][:password],
                                        insecure:   VMDeploy[:vcenter_cfg][:insecure],
                                        datacenter: VMDeploy[:vcenter_cfg][:dcname]

            log.info 'Connecting to the vCenter server'
            vmomi.connect

            master_template_vm = vmomi.find_vm_by_name VMDeploy[:master_template_vmname]
            fail "Cannot find the master template VM (#{VMDeploy[:master_template_vmname]})" unless master_template_vm
            log.info 'Cloning...'
            result = vmomi.clone master_template_vm, VMDeploy[:pool_folder], options['dst_vm_name'] do |p|
                progress_state(p, "Cloning: #{p}%") if p
            end
            progress_state(100, "Clone complete") if result
            log.info 'done'
        rescue Exception => e
            log.error e.message
            raise
        end

        def name
            "#{VMDeploy[:master_template_vmname]}/#{options['dst_vm_name']}"
        end
    end
end
