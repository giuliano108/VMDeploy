redis:                redis-server > /dev/null
web:                  bundle exec rackup -s thin -p 8080
workers_deployer:     bundle exec rake resque:workers --trace QUEUE=deployer COUNT=4
workers_cloner:       bundle exec rake resque:workers --trace QUEUE=cloner COUNT=4
