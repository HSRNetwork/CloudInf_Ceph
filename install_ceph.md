# How to set up a minimal Ceph cluster
The following steps are needed in order to set up a ceph cluster build on top of 3 nodes. Please take care of the comments and change the configuration based on your own setup.

**Note:** For simplicity of this lab use the user `root` to run all commands listed below!

## Prerequisites
These prerequisites are based on http://docs.ceph.com/docs/master/start/quick-start-preflight/#debian-ubuntu.

### Ceph-Nodes
The following commands must be applied on each Ceph node:
```bash
apt install ntp openssh-server python -y
useradd -d /home/bob -m bob
# Change the password!
echo "bob:<your_password>" | chpasswd
echo "bob ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/bob
chmod 0440 /etc/sudoers.d/bob
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
service ssh restart
# Change private IPs
cat <<EOF >> /etc/hosts
10.135.48.69 node1
10.135.52.210 node2
10.135.14.117 node3
EOF
```

### Ceph-Deploy
The following commands must be applied on the Ceph deploy node:
```bash
wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
echo deb https://download.ceph.com/debian-mimic/ $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/ceph.list
apt update && apt install ceph-deploy -y
# Choose the default SSH key location and set NO password!
ssh-keygen -b 4096 -t rsa
# Add the private IP of the three nodes in the following variable:
CLUSTER_NODES="10.135.48.69 10.135.52.210 10.135.14.117"
# Enter the password of bob three times:
for NODE in $CLUSTER_NODES
do
  ssh-keyscan $NODE >> ~/.ssh/known_hosts
  # When requested, enter the user PW
  ssh-copy-id bob@$NODE
done
```

## Installing Ceph
This setup is based on http://docs.ceph.com/docs/master/start/quick-ceph-deploy.

### Ceph-Deploy
The following commands must be applied on the Ceph deploy node:
```bash
# Change private IPs
cat <<EOF >> /etc/hosts
10.135.48.69 node1
10.135.52.210 node2
10.135.14.117 node3
EOF
mkdir /root/ceph
cd /root/ceph
ceph-deploy --username bob new node1
# Change the mon_host private IP to the public one
sed -i 's/mon_host = .*/mon_host = 165.227.133.37/g' ceph.conf
# Change IP ranges to your IP ranges
cat <<EOF >> ceph.conf
public network = 165.227.133.37/20,159.89.103.115/20,167.99.134.192/20
cluster network = 10.135.0.0/16
EOF
ceph-deploy --username bob install node1 node2 node3
ceph-deploy --username bob mon create-initial
ceph-deploy --username bob admin node1 node2 node3
ceph-deploy --username bob mgr create node1
# Ensure to chose the right disk and it's currently unmounted!
ceph-deploy --username bob osd create --data /dev/sda node1
ceph-deploy --username bob osd create --data /dev/sda node2
ceph-deploy --username bob osd create --data /dev/sda node3
ceph-deploy --username bob mds create node1
# Note: rgw = RADOS Gateway ~= S3 object store hosted on ceph
ceph-deploy --username bob rgw create node1
ssh bob@node1 sudo ceph health
ssh bob@node1 sudo ceph -s
ssh bob@node1 sudo ceph osd tree
```

## Testing the Object Store (RADOS)
Create service user login in order to access the S3 API. On node1:
```bash
radosgw-admin user create --uid="svc_user_01" --display-name="Service User 01"
# Important: Note down the generated key array. E.g.:
#
# "keys": [
#        {
#            "user": "svc_user_01",
#            "access_key": "M0...",
#            "secret_key": "c7..."
#        }
#    ],
#
```

Now to see how the object store can be accessed via API follow the steps shown down here. `s3cmd` is a command line tool which allows it to access any Amazon S3 compatible API.

On the ceph-deploy node:
```bash
# On ceph-deploy node:
apt-get install s3cmd -y
# Change the access_key and secret_key to your own values:
API_ACCESS_KEY=M0...
API_SECRET_KEY=c7...
s3cmd --access_key=$API_ACCESS_KEY --secret_key=$API_SECRET_KEY --host=165.227.133.37:7480 --no-check-certificate --no-ssl mb s3://cloudinf_bucket
echo "CloudInf Testing File" > testing_file.txt
s3cmd --access_key=$API_ACCESS_KEY --secret_key=$API_SECRET_KEY --host=165.227.133.37:7480 --no-check-certificate --no-ssl put testing_file.txt s3://cloudinf_bucket/
s3cmd --access_key=$API_ACCESS_KEY --secret_key=$API_SECRET_KEY --host=165.227.133.37:7480 --no-check-certificate --no-ssl ls s3://cloudinf_bucket
# Switch directory in order to show the download of the testing file:
cd /tmp
s3cmd --access_key=$API_ACCESS_KEY --secret_key=$API_SECRET_KEY --host=165.227.133.37:7480 --no-check-certificate --no-ssl get s3://cloudinf_bucket/testing_file.txt
```

## Ceph Filesystem
In order use the Ceph FS (FUSE) you need to create a pool and a filesystem. Mount the fs on the deploy-node to test the setup.

### Configuration on the Ceph cluster
On node1:
```bash
ceph osd pool create cephfs_data 64
ceph osd pool create cephfs_metadata 64
ceph fs new mydata cephfs_metadata cephfs_data
ceph-authtool -C /etc/ceph/ceph.client.bob.keyring
# Not not use the following weak permissions for productive usage!
ceph-authtool -C /etc/ceph/ceph.client.bob.keyring -n client.bob --cap osd 'allow rwx' --cap mon 'allow rwx' --cap mds 'allow rw' --gen-key
ceph auth add client.bob -i /etc/ceph/ceph.client.bob.keyring
chmod 644 /etc/ceph/ceph.client.bob.keyring
```
See http://docs.ceph.com/docs/master/rados/operations/user-management/ for more informations.

Show pools and filesystem:
```bash
root@node1:~# ceph fs ls
name: mydata, metadata pool: cephfs_metadata, data pools: [cephfs_data ]
root@node1:~# ceph -s
  cluster:
    id:     289127f7-36bc-4d6e-879c-7866ff7bfc4d
    health: HEALTH_WARN
            application not enabled on 1 pool(s)

  services:
    mon: 1 daemons, quorum node1
    mgr: node1(active)
    mds: mydata-1/1/1 up  {0=node1=up:active}
    osd: 3 osds: 3 up, 3 in
    rgw: 1 daemon active

  data:
    pools:   9 pools, 248 pgs
    objects: 249  objects, 4.2 KiB
    usage:   3.0 GiB used, 24 GiB / 27 GiB avail
    pgs:     248 active+clean
root@node1:~# ceph fs status mydata
mydata - 0 clients
======
+------+--------+-------+---------------+-------+-------+
| Rank | State  |  MDS  |    Activity   |  dns  |  inos |
+------+--------+-------+---------------+-------+-------+
|  0   | active | node1 | Reqs:    0 /s |   10  |   13  |
+------+--------+-------+---------------+-------+-------+
+-----------------+----------+-------+-------+
|       Pool      |   type   |  used | avail |
+-----------------+----------+-------+-------+
| cephfs_metadata | metadata | 2286  | 7720M |
|   cephfs_data   |   data   |    0  | 7720M |
+-----------------+----------+-------+-------+
+-------------+
| Standby MDS |
+-------------+
+-------------+
MDS version: ceph version 13.2.2 (02899bfda814146b021136e9d8e80eba494e1126) mimic (stable)
```
See http://docs.ceph.com/docs/master/cephfs/createfs/ for more informations.

### Ceph mount
```bash
apt-get install ceph-common -y
mkdir /root/mydata
mkdir /etc/ceph
# Change to the public monitor node IP
scp bob@165.227.133.37:/etc/ceph/ceph.conf /etc/ceph/ceph.conf
scp bob@165.227.133.37:/etc/ceph/ceph.client.bob.keyring /etc/ceph/ceph.client.bob.keyring
# Add bob's key from /etc/ceph/ceph.client.bob.keyring:
cat <<EOF >> /etc/ceph/ceph_bob.secret
AQCc.....
EOF
mount -t ceph 165.227.133.37:6789:/ /root/mydata -o name=bob,secretfile=/etc/ceph/ceph_bob.secret
```

Check the ceph mount:
```bash
root@ceph-deploy:~# mount | grep ceph
165.227.133.37:6789:/ on /root/mydata type ceph (rw,relatime,name=bob,secret=<hidden>,acl,wsize=16777216)
root@ceph-deploy:~# stat -f /root/mydata/
  File: "/root/mydata/"
    ID: 915f0daf23b1c7c9 Namelen: 255     Type: ceph
Block size: 4194304    Fundamental block size: 4194304
Blocks: Total: 1930       Free: 1930       Available: 1930
Inodes: Total: 0          Free: -1
root@ceph-deploy:~# touch /root/mydata/test.txt
```

See http://docs.ceph.com/docs/master/cephfs/fuse/ for more informations.
