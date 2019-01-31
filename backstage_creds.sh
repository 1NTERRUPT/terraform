#!/bin/bash

echo "Run this script for the first time set up of the Treasure Hunt."
echo
echo "This will make the directory for and then copy your AWS config file."
echo "*** Please be sure to copy a config file that ONLY contains credentials"
echo "for the Treasure Hunt and no other profiles or credentials***"
echo
echo "Please enter the name of your config file:"
read file
echo
echo "Please enter your key file name including the .pem extension:"
read key
echo "Creating the remote ~/.aws directory..."
ssh -i ~/.ssh/$key ubuntu@backstage.events.1nterrupt.com mkdir .aws
echo
echo "Copying your local config file to the remote ~/.aws directory..."
scp -i ~/.ssh/$key ~/.aws/$file ubuntu@backstage.events.1nterrupt.com:.aws/config
echo
echo "Making the ssh connection..."
ssh -i ~/.ssh/$key ubuntu@backstage.events.1nterrupt.com
