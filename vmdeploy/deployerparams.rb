require 'active_model'

module VMDeploy
	class DeployerParams
		include ActiveModel::Validations
		include ActiveModel::Conversion
		extend ActiveModel::Naming

		attr_accessor :vmname, :owner, :creator, :vmramsize, :vmnumberofcpus,
			          :vmnetwork, :rubyversion, :department    

		validates_presence_of :vmname, :owner, :creator, :vmramsize, :vmnumberofcpus,
						      :vmnetwork, :rubyversion, :department    

		validates :vmname, :format => {:with => /^[a-z\d\-]+$/i, :message => 'contains invalid characters'}, :length => {:minimum => 3, :message => 'is too short'}
		validates :owner,  :format => {:with => /^[-a-z0-9_+\.]+\@([-a-z0-9]+\.)+[a-z0-9]{2,4}$/i, :message => 'doesn\'t look like a valid email address'}
		validates :creator,  :format => {:with => /^[-a-z0-9_+\.]+\@([-a-z0-9]+\.)+[a-z0-9]{2,4}$/i, :message => 'doesn\'t look like a valid email address'}
		validates :vmramsize, :inclusion => {:in => VMDeploy[:deployer_params][:ram_sizes], :message => 'is invalid'}
		validates :vmnumberofcpus, :inclusion => {:in => VMDeploy[:deployer_params][:number_of_cpus], :message => 'is invalid'}
		validates :vmnetwork, :inclusion => {:in => VMDeploy[:deployer_params][:networks], :message => 'is invalid'}
		validates :rubyversion, :inclusion => {:in => VMDeploy[:deployer_params][:ruby_versions], :message => 'is invalid'}
		validates :department, :inclusion => {:in => VMDeploy[:deployer_params][:departments], :message => 'is invalid'}

		def initialize(params=nil)
			params.each do |name, value|
				send("#{name}=", value)
			end unless params.nil?
		end

		def persisted?
			false
		end

        # Resque Status expects a Hash
        def to_hash
            Hash[(instance_variables - [:@validation_context, :@errors]).map {|v| [v.to_s[1..-1],instance_variable_get(v)]}]
        end
	end
end
