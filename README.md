# VMDeploy

Spin up VMware Virtual Machines from a simple web page.

No Windows required.

## Deployment process

- A _master template_ VM (`master_template_vmname`) exists on the VCenter.

- The template has got a certain number of clones (`valid_pool_vmname`). They are all up and running within the same VCenter folder (`pool_folder`), and constitute the _pool_ of ready-to-be-deployed VMs. Template and pool VMs are identical except for the dynamic IP they receive via DHCP.

- When a User wants to spin up a new machine, a _pool VM_ gets selected.

- The pool VM is then _bootstrapped_ by:
  - Installing Puppet (from the official repo, only if it doesn't already exist).
  - Dropping a Puppet manifests tarball on it, along with a couple of scripts (to _unpack_ and _apply_ the config) and a `declared_classes.yaml` file. In a nutshell: this is a _masterless_ Puppet setup where everything is stored in `/etc/puppet-it` (to avoid messing with other Puppet related stuff that might end up on the VM), and the classes to declare come from an [external node classifier](http://docs.puppetlabs.com/guides/external_nodes.html) script that takes the yaml file as input.
  - The Puppet config is applied. All it does at this stage is configuring the final IP address on the box, hostname, DNS servers and other network parameters.

- The pool VM is shut down, its harware parameters are changed according to the User's choices (RAM, CPU, VLAN, ...), then it's powered back on. It's also moved to a specific VCenter folder (`destination_folder`).

- If bootstrap was successful, a notification email is sent to the User (actually, to the configured _owner_ , to the _requestor_ and to `support_email`).

- Two more background jobs are created:
  - A _cloner_, to replace the ex pool VM (that just became a "real" server) with a fresh copy of the master template.
  - A _mover_ that relocates - using Storage VMotion - the deployed VM to its final datastore (`destination_datastore`). This last step is necessary because, as far as I know, it's the only automatable way to rename a VM's on disk folder/files. Note that for this to work, starting from vSphere 5, you have to enable `provisioning.relocate.enableRename` on the vCenter Server. Check [this KB article](http://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=2008877) for details.

## The app

- 100% Ruby (with a dash of Puppet), tested on Linux and Mac OS.

- Simple Web UI built on Sinatra.

- Relies on Google (Apps) for user authentication (`allowed_users_regexps`).

- Submits jobs to Resque, and uses `resque-status` for progress feedback.

- Uses Capistrano for production deployment.

- New VMs need free IP addresses. Those are stored in a DB (see `models.rb`).  
The User selects a VLAN group and the code tries to find a free IP on any of the VLANs that belong to the group. A candidate IP gets allocated and linked to a VM DB model.
VLAN groups (along with network range, netmask, gateway, ...) are defined in the yaml config file.  

## Misc

You can use `scripts/console.rb` to interact with the DB or to create Jobs.

```
$ RACK_ENV=production bundle exec ruby script/console.rb
```

You'll be dropped in a `pry` session:

```
[1] pry(main)> m = VMDeploy::Models
=> VMDeploy::Models
[2] pry(main)> m::Ip.first
=> #<VMDeploy::Models::Ip @id=1 @address="10.41.40.123" @vlan_id=1 @vm_id=6>
[3] pry(main)> m::Ip.first.vm
=> #<VMDeploy::Models::Vm @id=6 @name="gtest" @uuid="50315057-83da-e4d3-1139-dbbe36c3c5d5">
```

Say you want to "unlink" 10.41.40.123 from the VM it's been assigned to (thus freeing up the IP):

```
[4] pry(main)> m::Ip.first(:address => '10.41.40.123').update(:vm => nil)
=> true
```

And you also want to remove the VM that used to own that IP, maybe because it's been deleted on the VCenter:

```
[5] pry(main)> m::Vm.first(:name => 'gtest').destroy
=> true
```

Another easy thing to do with `script/console.rb` is submitting a Job. Here I'm creating a new master template clone called `pool4`.

```
[6] pry(main)> VMDeploy::Jobs::Cloner.create({'dst_vm_name'=>'pool4'})
=> "d79b0f8e638a77d15050bb8506f654f3"
```
