$LOAD_PATH.unshift File.expand_path('..', File.dirname(__FILE__))
require 'vmdeploycommon'
VMDeploy::dm_setup
require 'ipaddr'

fail "Refusing to run anywhere other than in development" unless VMDeploy[:environment] == 'development'

netname  = 'Internal'
net  = IPAddr.new('192.168.123.0/24')
from = net | IPAddr.new('0.0.0.10')
to   = net | IPAddr.new('0.0.0.20')

(from..to).each do |ip|
	ip = ip.to_s
	attributes = {
		:address => ip,
		:network => netname,
		:address => ip,
		:taken   => false
	}
	begin
		VMDeploy::Models::IP.first_or_create(attributes).save
	rescue DataMapper::SaveFailureError => e
		puts e.resource.errors.inspect
	end
end

