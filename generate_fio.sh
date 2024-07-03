mkdir -p fio-jobs

# Create fio_generic_sequential.ini
cat << EOF > fio-jobs/fio_generic_sequential.ini
[global]
direct=1
ioengine=libaio
size=10G
runtime=300
group_reporting

[job1]
rw=read
bs=128k
numjobs=4

[job2]
rw=write
bs=128k
numjobs=4
EOF

# Create fio_generic_random.ini
cat << EOF > fio-jobs/fio_generic_random.ini
[global]
direct=1
ioengine=libaio
size=10G
runtime=300
group_reporting

[job1]
rw=randread
bs=4k
numjobs=4

[job2]
rw=randwrite
bs=4k
numjobs=4
EOF

# Create fio_vm_volumes.ini
cat << EOF > fio-jobs/fio_vm_volumes.ini
[global]
direct=1
ioengine=libaio
size=50G
runtime=600
group_reporting

[job1]
rw=randrw
bs=4k
numjobs=8
EOF

# Create fio_data.ini
cat << EOF > fio-jobs/fio_data.ini
[global]
direct=1
ioengine=libaio
size=200G
runtime=1200
group_reporting

[job1]
rw=write
bs=1M
numjobs=1
EOF

# Create fio_database.ini
cat << EOF > fio-jobs/fio_database.ini
[global]
direct=1
ioengine=libaio
size=100G
runtime=600
group_reporting

[job1]
rw=randread
bs=4k
numjobs=16

[job2]
rw=randwrite
bs=4k
numjobs=16
EOF
