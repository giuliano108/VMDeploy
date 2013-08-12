# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.actions[:start].delete(Vagrant::Action::VM::ShareFolders)
Vagrant::Config.run do |config|
  config.vm.box = "precise64"
  config.vm.define :vmdeploytemplate do |cfg|
  end
end
