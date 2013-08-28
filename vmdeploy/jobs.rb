require 'resque'
require 'resque-status'
require 'resque-concurrent-restriction'

module VMDeploy::Jobs
    class Job
        include VMDeploy::Loggr
        include Resque::Plugins::Status
        def self.queue; :vmdeploy; end

        def initialize(uuid, options={})
            super uuid, options
            log_setup(File.join(VMDeploy::LogDir,'vmdeploy.log'),self.class.to_s,uuid.to_s)
        end
    end
end

require 'vmdeploy/jobs/deployer'
require 'vmdeploy/jobs/deployer/shared'
require 'vmdeploy/jobs/deployer/fake'
require 'vmdeploy/jobs/deployer/vmware'
require 'vmdeploy/jobs/deployer/vagrant' if VMDeploy[:environment] == 'development'
require 'vmdeploy/jobs/cloner'
require 'vmdeploy/jobs/mover'
