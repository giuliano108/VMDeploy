require 'nsconfig'

module VMDeploy
    extend NSConfig

    def self.preconfig base_path
        VMDeploy.config_path = File.join(base_path,'config')
        if VMDeploy.get_environment == 'development'
            VMDeploy[:datamapper_parameters] = File.join(base_path,VMDeploy[:datamapper_parameters])
        end
    end

    def self.dm_setup
        require 'data_mapper'
        require VMDeploy[:datamapper_require]
        DataMapper.setup(:default, "#{VMDeploy[:datamapper_adapter]}://#{VMDeploy[:datamapper_parameters]}")
        DataMapper::Model.raise_on_save_failure = true
        require 'vmdeploy/models'
    end
end
