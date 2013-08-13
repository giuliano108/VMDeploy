$LOAD_PATH.unshift File.expand_path('..', File.dirname(__FILE__))
require 'vmdeploycommon'

include VMDeploy::Loggr
log_setup(File.join(VMDeploy::LogDir,'vmdeploy.log'),'testbootstrap.rb','uuid')

bs = VMDeploy::Bootstrap.new( 'uuid',
	:user => 'vagrant',
	:host => '127.0.0.1',
	:port => '2222',
	:key => '/Users/giuliano/.vagrant.d/insecure_private_key'
)

bs.puppet_conditional_install_precise
bs.apply! :interface => 'eth0',
          :ip => '10.0.2.15',
          :netmask => '255.255.255.0',
          :gateway => '10.0.2.2',
          :hostname => 'bootbox',
          :domainname => 'vagrant.lan',
          :dnsservers => ['8.8.8.8', '8.8.4.4'],
          :searchdomains => ['vagrant.lan','whatever.com']
