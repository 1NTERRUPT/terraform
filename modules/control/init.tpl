#!/bin/sh
sudo apt-add-repository ppa:ansible/ansible -y
sudo apt-get update
sudo apt-get install git ansible awscli python-minimal python-pip -y
touch /tmp/signal
