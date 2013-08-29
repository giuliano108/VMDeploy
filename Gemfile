source 'https://rubygems.org'
gem 'sinatra', '>= 1.0'
gem 'dm-sqlite-adapter'
gem 'rake'
gem 'haml'
gem 'json'
gem 'bson_ext'
# This is because I need findByInventoryPath .
# It should be available on the official vmware repo soon.
gem 'rbvmomi', :git => 'https://github.com/giuliano108/rbvmomi.git'
gem 'rb-readline'
gem 'ffi'
gem 'omniauth'
gem 'omniauth-openid'
gem 'sinatra-flash'
gem 'pony'
gem 'data_mapper'
gem 'resque'
gem 'foreman'
gem 'thin'
gem 'resque-status'
gem 'resque-concurrent-restriction'
gem 'activemodel'
gem 'nsconfig', :git => 'git://github.com/giuliano108/nsconfig.git', :tag => 'v0.1.0'
gem 'rye'
gem 'activesupport', '<4.0.0'
gem 'capistrano'
gem 'rvm-capistrano'
gem 'pry'

group :production do
    gem 'dm-mysql-adapter'
end

group :development do
    gem 'sinatra-reloader'
    gem 'pry-nav'
    gem 'dm-sqlite-adapter'
end
