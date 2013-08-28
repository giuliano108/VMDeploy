require 'rye'
require 'erb'
require 'tempfile'

module VMDeploy
    class Bootstrap
        include VMDeploy::Loggr

        def initialize(uuid,ssh_params={})
            raise ArgumentError.new('Argument is not a Hash') unless ssh_params.is_a? Hash
            ssh_params = {:user => nil, :host => nil, :port => 22, :key => nil, :password => nil}.merge(ssh_params)
            raise ArgumentError.new(':host cannot be nil') unless ssh_params[:host]
            host = ssh_params.delete :host
            key = ssh_params.delete(:key)
            ssh_params[:keys] = [key] if key
            ssh_params[:paranoid] = Net::SSH::Verifiers::Null.new # avoid known_hosts key checking
            @box = Rye::Box.new(host, ssh_params);
            log_setup(File.join(VMDeploy::LogDir,'vmdeploy.log'),self.class.to_s,uuid.to_s)
            log.info "Connecting to #{host}"
        end
        
        def puppet_get_version
            begin
                ret = @box.sudo 'puppet', '--version'
                return ret.to_s.chomp if ret.exit_status == 0
                return 'unknown'
            rescue Rye::Err => e
                return nil if e.message.match /puppet: command not found/
            end
        end
       
        # Install puppet if it's not already there
        def puppet_conditional_install_precise
            fail("Invalid hostname ('#{@box.hostname}' doesn't match /#{VMDeploy[:valid_pool_hostname]}/), refusing to try and install Puppet") unless @box.hostname.to_s.match(VMDeploy[:valid_pool_hostname])
            @puppet_version = puppet_get_version
            if @puppet_version.nil?
                log.info 'Puppet is not installed - installing it'

                ret = @box.sudo 'wget', '--no-verbose', 'http://apt.puppetlabs.com/puppetlabs-release-precise.deb'
                log.info '"puppet-release" repo package downloaded'

                ret = @box.sudo 'dpkg', '-i', 'puppetlabs-release-precise.deb'
                log.info '"puppet-release" repo package installed'

                ret = @box.sudo 'apt-get', 'update', '-q'
                ret = @box.sudo 'apt-get', 'install', '-y', '-q', 'puppet'
                @puppet_version = puppet_get_version
                fail('"apt-get install puppet" doesn\'t seem to have installed Puppet') if @puppet_version.nil?
                fail('unknown Puppet version') if @puppet_version == 'unknown'
                log.info "Installed Puppet version #{@puppet_version}"
            else
                log.info "Puppet already installed - version #{@puppet_version}"
            end
            @puppet_version
        rescue Exception => e
            log.error e.message
            raise
        end

        def sudo_upload_file file, destdir, mask, chown
            basename = File.basename file
            via = "/tmp/" + Dir::Tmpname.make_tmpname(basename, nil)
            dest = File.join(destdir,basename)
            log.info "Uploading #{file} to #{destdir} via #{via}"
            @box.file_upload file, via
            @box.sudo 'mv', via, dest
            @box.sudo 'chmod', mask, dest
            @box.sudo 'chown', chown, dest
        end

        def sudo_upload_template file, destdir, mask, chown, params, strip_suffix=nil
            basename = File.basename file
            via = "/tmp/" + Dir::Tmpname.make_tmpname(basename, nil)
            dest = File.join(destdir, strip_suffix ? File.basename(basename,strip_suffix) : basename)
            log.info "Uploading template #{file} to #{destdir} via #{via} - params: #{params.inspect}"
            @box.file_write via, ERB.new(File.read(file),nil,'-').result(binding)
            @box.sudo 'mv', via, dest
            @box.sudo 'chmod', mask, dest
            @box.sudo 'chown', chown, dest
        end
       
        # Upload the puppet bootstrap archive, unpack and apply it
        # Try hard not to mess with an existing puppet install
        def apply! params={}
            fail('Invalid hostname, refusing to apply') unless @box.hostname.to_s.match(VMDeploy[:valid_pool_hostname])
            params = {:interface => nil,
                      :ip => nil,
                      :netmask => nil,
                      :gateway => nil,
                      :hostname => nil,
                      :domainname => nil,
                      :dnsservers => [],
                      :searchdomains => []}.merge(params)
            [:interface, :ip, :netmask, :gateway, :hostname, :domainname].each do |p| 
                raise ArgumentError.new(":#{p} cannot be nil") unless params[p]
            end
            [:dnsservers,:searchdomains].each do |p|
                raise ArgumentError.new(":#{p} must be a non-empty Array") unless (params[p].is_a?(Array) && !params[p].empty?)
            end
            sudo_upload_file File.join(VMDeploy[:puppet_scripts_subdir],'puppet-it-unpack.sh'), '/root', '755', 'root:root'
            sudo_upload_file File.join(VMDeploy[:puppet_pkg_subdir],'puppet-it-vmdeploy.tar.gz'), '/root', '755', 'root:root'
            log.info "Unpacking puppet boostrap archive with /root/puppet-it-unpack.sh"
            @box.sudo 'sh', '/root/puppet-it-unpack.sh', 'vmdeploy'
            sudo_upload_file File.join(VMDeploy[:puppet_scripts_subdir],'puppet-it-enc.sh'), '/etc/puppet-it', '755', 'root:root'
            sudo_upload_file File.join(VMDeploy[:puppet_scripts_subdir],'puppet-it-apply.sh'), '/etc/puppet-it', '755', 'root:root'
            sudo_upload_template File.join(VMDeploy[:puppet_scripts_subdir],'declared_classes.yaml.erb'), '/etc/puppet-it', '755', 'root:root', params, '.erb'
            log.info "Running puppet apply with /etc/puppet-it/puppet-it-apply.sh"
            @box.sudo 'sh', '/etc/puppet-it/puppet-it-apply.sh'
        rescue Exception => e
            log.error e.message
            raise
        end

        def bootstrap_success? params={}
            raise ArgumentError.new('Argument is not a Hash') unless params.is_a? Hash
            params = {:maxtime => 300, :delay => 10}.merge(params)
            start_time = Time.now.to_f
            connected = false
            bootstrapped  = false
            while (Time.now.to_f - start_time) < params[:maxtime]
                begin
                    # Assume bootstrap is ok if this file exists and we were able to connect to the box
                    @box.ls('/etc/puppet-it/declared_classes.yaml')
                    connected    = true
                    bootstrapped = true
                    break
                rescue Errno::ETIMEDOUT, Errno::EPERM, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH
                    sleep params[:delay]
                    puts 'sleeping'
                rescue Rye::Err
                    connected    = true
                    bootstrapped = false
                    break
                end
            end
            fail "Can't SSH into the VM" unless connected
            bootstrapped
        end
    end
end
