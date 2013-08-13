# This is for testing only.
# - It expects a Vagrant VM to already exist
# - The VM must be called "vmdeploytemplate". Example Vagrantfile:
#     Vagrant.actions[:start].delete(Vagrant::Action::VM::ShareFolders)
#     Vagrant::Config.run do |config|
#       config.vm.box = "precise64"
#       config.vm.define :vmdeploytemplate do |cfg|
#       end
#     end
# - This deployer class will attempt to start the VM, then bootstrap it with Puppet.
module VMDeploy::Jobs::Deployer
    class Vagrant < VMDeploy::Jobs::Job
        include VMDeploy::Jobs::Deployer::Shared

		def get_vm_state
			state = nil
			IO.popen('vagrant status') do |f|
				f.each_line do |l|
					if m = l.match(/^vmdeploytemplate.*(running|poweroff)$/)
						state = m[1]
						break
					end
				end
			end
			bailout "Can't seem to run/understand 'vagrant status'" if state.nil?
			bailout "Unknown status returned by 'vagrant status'" unless state == 'running' or state == 'poweroff'
			return (state == 'running') ? 'on' : 'off'
		end

		def get_ssh_params
			params = {}
			IO.popen('vagrant ssh-config') do |f|
				f.each_line do |l|
					l.sub!(/^ */,'')
					l.chomp!
					k,v = l.split(/ +/,2)
					params[k] = v
				end
			end
			params
		end

        def perform
            log.info get_message_by_key('start') + ' -- ' + options.to_json
            progress_state_key('start')
            progress_state_key('pool_vm_get')
			vm_state = get_vm_state
            log.info "VM is #{vm_state}"
			if vm_state == 'off'
				log.info 'Attempting to power VM up'
				IO.popen('vagrant up') { |f| f.readlines }
				vm_state = get_vm_state
				bailout "VM isn't on" unless vm_state == 'on'
				log.info "VM is #{vm_state}"
			end
			log.info "Obtaining SSH parameters"
			ssh_params = get_ssh_params
			log.info ssh_params.inspect
            progress_state_key('pool_vm_bootstrap')
            log.info "Bootstrapping"
            bs = VMDeploy::Bootstrap.new( uuid,
                :user => ssh_params['User'],
                :host => ssh_params['HostName'],
                :port => ssh_params['Port'],
                :key  => ssh_params['IdentityFile']
            )
            bs.puppet_conditional_install_precise
            bs.apply! :interface => 'eth0',
                      :ip => '10.0.2.15',
                      :netmask => '255.255.255.0',
                      :gateway => '10.0.2.2',
                      :hostname => 'bootbox',
                      :domainname => 'vagrant.lan',
                      :dnsservers => ['8.8.8.8', '8.8.4.4'],
                      :searchdomains => ['vagrant.lan','whatever.com']
            log.info "Done!"
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
