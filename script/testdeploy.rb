$LOAD_PATH.unshift File.expand_path('..', File.dirname(__FILE__))
require 'json'
require 'vmdeploycommon'

params = JSON.parse <<EOJ
{"vmname":"gtest",
"owner":"giuliano@108.bz",
"vmramsize":"512MB",
"vmnumberofcpus":"1",
"vmnetwork":"Internal",
"rubyversion":"ruby1.9=2:1.9.2p290",
"department":"IT"}
EOJ

job_id = VMDeploy::Jobs::Deployer::VMware.create(params)
puts "Created job: #{job_id}"
