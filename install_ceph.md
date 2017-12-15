# How to set up a minimal Ceph cluster
The following steps are needed in order to set up a Ceph cluster build on top of 3 nodes. Please take care of the comments and change the configuration based on your own setup.

## Prerequisites
These prerequisites are based on http://docs.ceph.com/docs/master/start/quick-start-preflight/#debian-ubuntu.

### Ceph-Nodes
The following commands must be applied on each Ceph node:
```bash
apt install ntp openssh-server python -y
useradd -d /home/bob -m bob
# Change the password!
echo "bob:your_password_here" | chpasswd
echo "bob ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/bob
chmod 0440 /etc/sudoers.d/bob
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
service ssh restart
# Change private IPs
cat <<EOF >> /etc/hosts
10.135.57.73 node1
10.135.75.84 node2
10.135.76.14 node3
EOF
```

### Ceph-Deploy
The following commands must be applied on the Ceph deploy node:
```bash
wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
echo deb https://download.ceph.com/debian/ xenial main | sudo tee /etc/apt/sources.list.d/ceph.list
apt update && apt install ceph-deploy -y
# Choose the default SSH key location and set NO password!
ssh-keygen -b 4096 -t rsa
# Add the private IP of the three nodes in the following variable:
CLUSTER_NODES="10.135.57.73 10.135.75.84 10.135.76.14"
for NODE in $CLUSTER_NODES
do
  ssh-keyscan $NODE >> ~/.ssh/known_hosts
  # When requested, enter the user PW
  ssh-copy-id bob@$NODE
done
```

## Set up Ceph
This setup is based on http://docs.ceph.com/docs/master/start/quick-ceph-deploy/#starting-over.

### Ceph-Deploy
The following commands must be applied on the Ceph deploy node:
```bash
# Change private IPs
cat <<EOF >> /etc/hosts
10.135.57.73 node1
10.135.75.84 node2
10.135.76.14 node3
EOF
mkdir /root/ceph
cd /root/ceph
ceph-deploy --username bob new node1
# Change the mon_host private IP to the public one
sed -i 's/mon_host = .*/mon_host = 159.89.12.54/g' ceph.conf
# Change IP ranges to your IP ranges
cat <<EOF >> ceph.conf
public network = 159.89.0.1/20,46.101.128.1/18,165.227.160.1/20
cluster network = 10.135.0.0/16
EOF
ceph-deploy --username bob install node1 node2 node3
ceph-deploy --username bob mon create-initial
ceph-deploy --username bob admin node1 node2 node3
# Ensure to chose the right disk and it's currently unmounted!
ceph-deploy --username bob osd create node1:sda node2:sda node3:sda
ssh bob@node1 sudo ceph health
ssh bob@node1 sudo ceph -s
ssh bob@node1 sudo ceph osd tree
```
