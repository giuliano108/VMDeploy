$LOAD_PATH.unshift File.dirname(__FILE__)
require 'rake/packagetask'
require 'resque/tasks'
require 'vmdeploycommon'

VMDeploy::dm_setup

Rake::PackageTask.new('puppet-it', 'vmdeploy') do |pkg|
  pkg.need_tar_gz = true
  pkg.package_files.include("#{VMDeploy[:puppet_subdir]}/**/*")
end
