#!/bin/sh
sudo apt-add-repository ppa:ansible/ansible -y
sudo apt-add-repository ppa:brightbox/ruby-ng -y
sudo apt-get update
sudo unattended-upgrade
sudo apt-get install git ansible awscli python-minimal python-pip -y
touch /tmp/signal
