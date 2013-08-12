module VMDeploy::Jobs::Deployer
    module Shared
        States = [
            { :key => 'start',                         :message => 'Deployment started'},
            { :key => 'viserver_connect',              :message => 'Connecting to the vCenter server'},
            { :key => 'vm_check_existence',            :message => 'Checking if the chosen VM name already exists on vCenter'},
            { :key => 'pool_vm_get',                   :message => 'Getting hold of a free pool VM'},
            { :key => 'pool_vm_bootstrap',             :message => 'Bootstrapping OS'},
            { :key => 'vm_shutdown',                   :message => 'Shutting VM down'},
            { :key => 'pool_vm_tweak_hardware',        :message => 'Changing VM hardware/network properties'},
            { :key => 'vm_start',                      :message => 'Starting up VM'},
            { :key => 'vm_wait_poweron',               :message => 'Waiting until the VM is on'},
            { :key => 'vm_check_bootstrap_successful', :message => 'Checking if Bootstrap succeeded'},
            { :key => 'notify_owner',                  :message => 'Deploy looks ok, notifying the Owner'},
            { :key => 'vm_vmotion',                    :message => 'Moving VM to production datastore'},
            { :key => 'viserver_disconnect',           :message => 'Disconnecting from the vCenter server'},
            { :key => 'done',                          :message => 'Deployment finished'}
        ]
        StatesK2I = Hash[States.each_with_index.map {|s,i| [s[:key],i]}]

        def get_message_by_key(key)
            States[StatesK2I[key]][:message]
        end

        def progress_state_index(i)
            at((Float(i)*100/States.length).round, 100, States[i][:message])
        end

        def progress_state_key(key)
            progress_state_index(StatesK2I[key])
        end
    end
end
