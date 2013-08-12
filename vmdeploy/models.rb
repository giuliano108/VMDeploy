require 'data_mapper'
module VMDeploy::Models
	class IP
		include DataMapper::Resource  
		property :id, Serial
		property :network, String, :required => true
		property :address, String, :required => true, :unique => true
		property :taken, Boolean, :index => true
		property :taken_by_vm, String
		property :taken_by_jobid, String
		property :taken_on, String
	end
	DataMapper.auto_upgrade!
end
