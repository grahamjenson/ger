# -*- mode: ruby -*-
# vi: set ft=ruby :

#### Vagrant File ####
#
# This file is used to define GER's infrastructure as docker containers
#
# Graham
#####################
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.define "db" do |v|
    v.vm.provider "docker" do |d|
      d.image = "paintedfox/postgresql"
      d.volumes = ["/var/docker/postgresql:/data"]
      d.ports = ["5432:5432"]
      d.env = {
        USER: "root",
        PASS: "abcdEF123456",
        DB: "root"
      }
      d.vagrant_vagrantfile = "./Vagrantfile.proxy"
    end
  end

end
