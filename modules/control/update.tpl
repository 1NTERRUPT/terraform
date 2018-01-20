#!/bin/sh

sudo apt-get update
sudo apt-get install git ansible awscli -y 
sudo apt-get install ntp
sudo service ntp stop
sudo ntpd -gq
sudo service ntp start
touch /tmp/signal
