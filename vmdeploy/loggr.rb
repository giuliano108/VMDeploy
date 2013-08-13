require 'logger'
module VMDeploy::Loggr
    def log_setup(filename,classname,id)
        @logger = Logger.new(filename, File::WRONLY | File::APPEND)
        @logger.formatter = proc do |severity, datetime, progname, msg|
            "#{datetime.strftime("%Y-%m-%dT%H:%M:%S.") << "%06d" % datetime.usec} #{classname} [#{id}] #{severity} #{msg}\n"
        end
    end

    def log
        @logger
    end
end
