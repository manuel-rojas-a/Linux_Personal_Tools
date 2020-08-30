#!/bin/bash
#
# What is it?
#
# Script adapted from someplace forum duscussion about how to use skip adds list on linux, based on public adds sites list from mvps.org lists
#
# How it works?
#
# The scrips works first restores your backup etchosts files in /etc/hosts ; then download the current block add list, and convets the file format for linux use;  then, updates /etc/hosts file.  
#
# in order to create your first .etchosts backup 
#
# run:#  cat /etc/hosts > ~/.etchosts
#
# Is important that you  first create an /root/.etchosts backup for personal customizations of etc howts file, in order to don't loss all changes.
#
# PLEASE NOTE if you want to update your etc hosts files, go to /root/.etchost files and make your changes here. Changes on /etc/hots will be lost on script runs.
# finaly put a link for this script directy on /etc/cron.[daily, weekly, monthly] path as your preference.
#


# delete current etc hosts file
rm /etc/hosts

# add our custom sites from ~.etchosts file
cat ~/.etchosts > /etc/hosts

# use /tmp work directory 
cd /tmp
# Download sites repository 
wget http://winhelp2002.mvps.org/hosts.txt

# convert format to linux
dos2unix -n hosts.txt hosts.unix

# update etc hosts file
cat hosts.unix >> /etc/hosts
