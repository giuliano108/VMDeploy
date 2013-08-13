module VMDeploy::Jobs::Deployer
    class Fake < VMDeploy::Jobs::Job
        include VMDeploy::Jobs::Deployer::Shared

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
