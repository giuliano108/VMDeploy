$LOAD_PATH.unshift File.dirname(__FILE__)
$stdout.sync = true

require 'vmdeploycommon'
require 'vmdeploy/web'

run Rack::URLMap.new \
  "/"       => VMDeploy::Web::App,
  "/resque" => Resque::Server.new
