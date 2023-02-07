#prepare /etc/hosts
#setup /ect/hostname (temporary)
#mount /admin/slurm/etc

mkdir -p /admin/slurm/etc
wget https://raw.githubusercontent.com/jagwar/slurm-conf/main/00/custom-scripts-and-configs/test/slurm.conf /admin/slurm/etc
#todo DNS

cat >/etc/hosts <<EOF
headnode 10.52.17.10
p4de1 10.52.17.11
p4de2 10.52.17.12
EOF

headnode 10.52.17.10
p4de1 10.52.17.11
p4de2 10.52.17.12
