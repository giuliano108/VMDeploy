- capify
- Deployer jobs should first of all check if a VM by that name alread exists.
  I don't think they can do that by simply querying vCenter
- resque/status_server might need some (monkey)patching. Too many params screw the layout up... 
- VMDeploy::Exceptions module
- log the "creator" somewhere! (it might be different than the "owner")
