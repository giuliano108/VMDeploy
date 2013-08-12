module VMDeploy::Jobs::Deployer
    class Fake
        include VMDeploy::Loggr
        include VMDeploy::Jobs::Deployer::Shared
        include Resque::Plugins::Status
        @queue = :deployer

        def initialize(uuid, options={})
            super uuid, options
            log_setup(File.join(VMDeploy::LogDir,'deployer.log'),self.class.to_s,uuid.to_s)
        end

        def perform
            total = 30
            len = States.length
            States.each_index do |i|
                if States[i][:key] == 'start'
                    log.info States[i][:message] + ' -- ' + options.to_json
                else
                    log.info States[i][:message]
                end
                progress_state_index(i)
                sleep(Float(total)/len)
            end
        end
        
        def name
            "#{options['vmname']}/#{options['owner']}"
        end
    end
end
