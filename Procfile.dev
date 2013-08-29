redis:  redis-server > /dev/null
web:    bundle exec rackup -s thin -p 8080
resque: bundle exec rake resque:workers --trace QUEUE=vmdeploy COUNT=8
