module VMDeploy::Jobs
    class Mover < Job
        extend Resque::Plugins::ConcurrentRestriction 
        concurrent VMDeploy[:concurrent_movers]

        def progress_state percent, message
            at(percent.round, 100, message)
        end

        def perform
            log.info 'Start' + ' -- ' + options.to_json
            progress_state 0, 'Start'
            fail "Missing 'src_vm_path' parameter" unless options['src_vm_path'] && !options['src_vm_path'].empty?
            fail "Missing 'dst_ds_path' parameter" unless options['dst_ds_path'] && !options['dst_ds_path'].empty?

            vmomi = VMDeploy::VMOMI.new host:       VMDeploy[:vcenter_cfg][:host],
                                        user:       VMDeploy[:vcenter_cfg][:user],
                                        password:   VMDeploy[:vcenter_cfg][:password],
                                        insecure:   VMDeploy[:vcenter_cfg][:insecure],
                                        datacenter: VMDeploy[:vcenter_cfg][:dcname]

            log.info 'Connecting to the vCenter server'
            vmomi.connect

            log.info 'Moving...'
            result = vmomi.vmotion options['src_vm_path'], options['dst_ds_path'] do |p|
                progress_state(p, "Moving: #{p}%") if p
            end
            progress_state(100, "VMotion complete") if result
            log.info 'Disconnecting from the vCenter server'
            vmomi.close
            log.info 'done'
        rescue Exception => e
            log.error e.message
            raise
        end

        def name
            "#{options['src_vm_path'].split('/').last}/#{options['dst_ds_path'].split('/').last}"
        end
    end
end
