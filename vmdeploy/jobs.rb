require 'resque'
require 'resque-status'

module VMDeploy::Jobs
end
module VMDeploy::Jobs::Deployer
end

require 'vmdeploy/jobs/deployer/shared'
require 'vmdeploy/jobs/deployer/fake'
require 'vmdeploy/jobs/deployer/vmware'
require 'vmdeploy/jobs/deployer/vagrant' if VMDeploy[:environment] == 'development'
