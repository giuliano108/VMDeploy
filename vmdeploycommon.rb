require 'vmdeploy/preinit'
VMDeploy::preconfig File.dirname(__FILE__)
VMDeploy::SinatraRoot = File.dirname(__FILE__)
VMDeploy::LogDir = File.join(File.dirname(__FILE__),'log')
VMDeploy::ApplicationTitle = 'VMDeploy'
require 'vmdeploy/postinit'
