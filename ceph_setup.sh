#!/bin/bash

banner()
{
  echo "+------------------------------------------+"
  printf "| %-40s |\n" "`date`"
  echo "|                                          |"
  printf "|`tput bold` %-40s `tput sgr0`|\n" "$@"
  echo "+------------------------------------------+"
}

declare -a nodes

banner "Starting the job"

banner "Type in the IP addresses of the nodes"
read -p "Deploy Node IP: " vardeploynodeip
read -p "Amount of Nodes: " node_amount
for (( i=1; i<=$node_amount; i++ ))
do
   read -p "Set Node $i ip address: " temp_ip
   nodes[$i]=$temp_ip
done

banner "Check IP Addresses"
# check deploy node reachability
((count1 = 10))
while [[ $count -ne 0 ]] ; do
    ping -c 1 $vardeploynodeip
    rc=$?
    if [[ $rc -eq 0 ]] ; then
        ((count1 = 1))
    fi
    ((count1 = count1 - 1))
done

if [[ $rc -eq 0 ]] ; then
    echo "Host is Reachable."
else
    echo "Timeout."
fi
# Check minion reachability
for j in "${nodes[@]}"
do
  ((count = 10))
  while [[ $count -ne 0 ]] ; do
      ping -c 1 $j
      rc=$?
      if [[ $rc -eq 0 ]] ; then
          ((count = 1))
      fi
      ((count = count - 1))
  done

  if [[ $rc -eq 0 ]] ; then
      echo "Host is Reachable."
  else
      echo "Timeout."
  fi
done

banner "Install dependencies on nodes"
read -p "Passwort for User bob: " varbobpw
for z in "${minion_ips[@]}"
do
  banner "Node - $z"
	ssh root@$z apt update
  ssh root@$z apt install ntp openssh-server python -y
  ssh root@$z useradd -d /home/bob -m bob
  ssh root@$z echo "bob:$varbobpw" | chpasswd
  ssh root@$z echo "bob ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/bob
  ssh root@$z chmod 0440 /etc/sudoers.d/bob
  ssh root@$z sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
  ssh root@$z service ssh restart
  # TODO: cat EOF hosts file
done

banner "Install dependencies on deploy node"
ssh root@$vardeploynodeip wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
ssh root@$vardeploynodeip wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
ssh root@$vardeploynodeip wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
ssh root@$vardeploynodeip wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
ssh root@$vardeploynodeip wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
ssh root@$vardeploynodeip wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
