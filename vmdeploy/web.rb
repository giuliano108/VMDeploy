require 'sinatra/base'
require 'sinatra/flash'
require 'resque/server'
require 'resque/status_server'
require 'openid/store/filesystem'
require 'omniauth'
require 'omniauth-openid'
require 'active_model'

module VMDeploy::Web
    $0 = self.name
    VMDeploy::dm_setup

    class App < Sinatra::Base

        configure :production, :development do
            register Sinatra::Flash
            enable :logging
            set :root, VMDeploy::SinatraRoot
            set :views, File.join(VMDeploy::SinatraRoot,'views')
            use Rack::Session::Cookie
            set :session_secret, "nothingtoseehere" 
            use OmniAuth::Builder do
                provider :open_id, store: OpenID::Store::Filesystem.new('/tmp'), :name => 'google', :identifier => 'https://www.google.com/accounts/o8/id'
            end
        end

        configure :development do
            require 'sinatra/reloader'
            register Sinatra::Reloader
        end

        helpers do
            def authorized?
                session[:authenticated]
            end

            def protected
                unless authorized?
                    flash[:warning] = 'The page cannot be viewed without first logging in...'
                    redirect '/'
                end
                authorized?
            end

            def protected!
                throw(:halt, [401, "Not authorized\n"]) unless authorized?
            end

            def current_user
                return nil unless authorized?
                session[:username]
            end

            def partial( page, variables={} )
                haml page.to_sym, {layout:false}, variables
            end

            def buildvmform_vmname_value
                coming_from_build = session[:old_path_info] && (session[:old_path_info] == '/build')
                if coming_from_build && @dparams.errors.messages[:vmname]
                    params[:vmname] || ''
                else
                    ''
                end
            end

            def buildvmform_control_group(param)
                coming_from_build = session[:old_path_info] && (session[:old_path_info] == '/build')
                haml_tag :div, :class => ('control-group' + ((coming_from_build && @dparams.errors.messages[param]) ? ' error' : '')) do
                    yield
                end
            end

            def buildvmform_show_validation_error(param)
                coming_from_build = session[:old_path_info] && (session[:old_path_info] == '/build')
                if coming_from_build && @dparams.errors.messages[param] 
                    haml_tag 'span.help-inline', @dparams.errors.messages[param].first
                end
            end
        end
        
        # authentication callback
        [:get, :post].each do |method|
            send method, '/auth/:provider/callback' do
                session[:username] = request.env['omniauth.auth']['info']['email']
                if VMDeploy[:allowed_users_regexps].any? {|re| Regexp.new(re).match(session[:username])}
                    session[:authenticated] = true
                    flash[:notice] = 'Login successful'
                    redirect '/' 
                else
                    session[:authenticated] = false
                    flash[:error] = "You don't have permission to log in, sorry..."
                    redirect '/' 
                end
            end
        end

        get '/logout' do
            session[:authenticated] = false
            session.clear
            flash[:notice] = "You've been successfully logged out"
            redirect '/'
        end

        get '/auth/failure' do
            session[:authenticated] = false
            flash[:error] = "Authentication failed (#{params[:message]})"
            redirect '/'
        end

        # root page
        get '/' do
            if session.include? :old_build_params
                params.merge! JSON.parse(session[:old_build_params])
                session.delete :old_build_params
            end
            @dparams = VMDeploy::DeployerParams.new params
            @dparams.valid? # we don't really care about the result
            haml :root
        end

        post '/build' do
            protected
            @dparams = VMDeploy::DeployerParams.new params
            if @dparams.valid?
                job_id = VMDeploy::Jobs::Deployer::Fake.create(@dparams.to_hash)
                if job_id
                    flash[:notice] = "Your VM is being built. Progress info is available <a href=\"/resque/statuses/#{job_id}\" target=\"_blank\">here</a>."
                else
                    flash[:error] = "<strong>Couldn't submit a deploy job</strong>"
                end
            else
                flash[:error] = '<strong>One or more errors occurred</strong>'
            end
            session[:old_build_params] = params.to_json
            redirect '/'
        end

        ['/', '/build'].each do |path|
            after path do
                session[:old_path_info] = request.path_info
            end 
        end
    end
end
