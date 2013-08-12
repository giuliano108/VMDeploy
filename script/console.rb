$LOAD_PATH.unshift File.expand_path('..', File.dirname(__FILE__))
require 'vmdeploycommon'
VMDeploy::dm_setup

require 'pry'
binding.pry
