#!/bin/bash
############################################################
# Before using this script, complete the following steps:
#   - Install doctl (see https://www.digitalocean.com/community/tutorials/how-to-use-doctl-the-official-digitalocean-command-line-client)
#   - Add SSH key to your digitalocean account
#   - Generate API token and set up doctl by using "doctl auth init"
############################################################

### Configuration
# docctl
SSH_KEY=`doctl compute ssh-key list --format FingerPrint --no-header`
# Droplet
OS_IMAGE="ubuntu-16-04-x64"
REGION="fra1"
DROPLET_SIZE="512mb"
VOLUME_SIZE="10gb"
# Ceph
DEPLOY_NODE="ceph-deploy"
CEPH_NODES="node1 node2 node3"

############################################################
# Do not change anything below here unless you know
# exactly what you are doing!
############################################################

# Create droplets
echo "Starting to create droplets..."
doctl compute droplet create $DEPLOY_NODE \
  --size $DROPLET_SIZE \
  --image $OS_IMAGE \
  --region $REGION \
  --ssh-keys $SSH_KEY \
  --enable-private-networking > /dev/null 2>&1
echo "Created $DEPLOY_NODE droplet"
for DROPLET_NAME in $CEPH_NODES
do
  VOLUME=`doctl compute volume create $DROPLET_NAME-vol01 \
    --region $REGION \
    --size $VOLUME_SIZE \
    --format ID --no-header`
  doctl compute droplet create $DROPLET_NAME \
    --size $DROPLET_SIZE \
    --image $OS_IMAGE \
    --region $REGION \
    --ssh-keys $SSH_KEY \
    --enable-private-networking \
    --volumes $VOLUME
  echo "Created $DROPLET_NAME droplet"
done

# Print out all created droplets
echo "The following droplets were created:"
doctl compute droplet ls \
  --format ID,Name,PublicIPv4,PrivateIPv4,Memory,VCPUs,Disk,Image,Status,Volumes

# Setup finished message
echo "Basic setup finished. Now continue with with the Ceph setup. See http://docs.ceph.com/docs/master/start/quick-ceph-deploy/ for further instructions."
