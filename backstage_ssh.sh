#!/bin/bash
echo "So, you want to ssh to the backstage server? Enter your ssh key file name,"
echo "including its file extension, here:"
echo
read KEY_FILE
ssh -o IdentitiesOnly=yes -i ~/.ssh/$KEY_FILE ubuntu@backstage.events.1nterrupt.com

