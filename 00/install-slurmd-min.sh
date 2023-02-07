#!/bin/bash
set -x
set -e
#needed on ubuntu2004
apt update
# apt install -y build-essential pkg-config libcurl4-openssl-dev libdbus-1-dev
#rm /usr/local/cuda
#ln -s /usr/local/cuda-11.7 /usr/local/cuda
#Todo find what's this file: 888-slurm.sh
#cp /admin/hosts/888-slurm.sh /etc/profile.d/

# needed on DLAMI BaseMeta
apt-get  -q -o DPkg::Lock::Timeout=240 install -y munge libmunge-dev hwloc libhwloc-dev numactl iftop \
  libmunge-dev liblz4-dev libfreeipmi-dev  libipmimonitoring-dev  libyaml-dev \
  libpmix-dev librrd-dev bzip2 libjson-c-dev libhttp-parser-dev
#we should probably get this from s3 and not hit their web servers
adduser --quiet --system --group --uid 401 --no-create-home --home /nonexistent slurm || true
#todo check slurm user
SLURM_VER="slurm-22.05.5.tar.bz2"
SLURM_URL=https://download.schedmd.com/slurm/${SLURM_VER}
TEMP_DIR="/tmp/slurm_tmp"
rm -rf  ${TEMP_DIR}
mkdir -p ${TEMP_DIR}
pushd ${TEMP_DIR}
curl -s ${SLURM_URL} | tar -jx --strip-components=1 && ./configure -q --prefix=/opt/slurm && make -s -j 64 && make -s install
#tar -jx --strip-components=1 -f /admin/slurm/${SLURM_VER} && ./configure -q --prefix=/opt/slurm && make -s -j 64 && make -s install
#echo "CgroupMountpoint=/sys/fs/cgroup" |sudo tee /opt/slurm/etc/cgroup.conf
popd
mkdir -p /var/lib/slurm/slurmd
mkdir -p /var/lib/slurm/checkpoint
mkdir -p /var/spool/slurmd
chown -R slurm:slurm /var/lib/slurm /var/spool/slurmd
rm -rf ${TEMP_DIR}
ln -s /admin/slurm/etc  /opt/slurm/etc
#cp /opt/slurm/etc/munge.key /etc/munge/
systemctl restart munge.service
cp /usr/lib/systemd/system/slurmd.service /etc/systemd/system/

