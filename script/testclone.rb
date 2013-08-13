$LOAD_PATH.unshift File.expand_path('..', File.dirname(__FILE__))
require 'json'
require 'vmdeploycommon'

params = JSON.parse <<EOJ
{"dst_vm_name":"pool1"}
EOJ

job_id = VMDeploy::Jobs::Cloner.create(params)
puts "Created job: #{job_id}"
