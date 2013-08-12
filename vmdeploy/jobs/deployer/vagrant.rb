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
    class Vagrant
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
			log.info "Obatainig SSH parameters"
			ssh_params = get_ssh_params
			log.info ssh_params.inspect
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
