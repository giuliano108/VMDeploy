$LOAD_PATH.unshift File.expand_path('..', File.dirname(__FILE__))
require 'json'
require 'vmdeploycommon'

params = JSON.parse <<EOJ
{"vmname":"gtest",
"owner":"giuliano.cioffi@forward.co.uk",
"vmramsize":"512MB",
"vmnumberofcpus":"1",
"vmnetwork":"Internal",
"rubyversion":"ruby1.9=2:1.9.2p290",
"department":"uSwitch"}
EOJ

job_id = VMDeploy::Jobs::Deployer::Vagrant.create(params)

puts "Created job: #{job_id}"
