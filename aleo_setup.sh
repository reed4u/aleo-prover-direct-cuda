#!/bin/bash
APPROOT=$(dirname $(readlink -e $0))

# If you want to run as another user, please modify \$UID to be owned by this user
if [[ "$UID" -ne '0' ]]; then
  echo "Error: You must run this script as root!"; exit 1
fi

uninstall_package() {
  systemctl stop aleo
  systemctl disable aleo
  rm -f /etc/systemd/system/aleo.service
  rm -rf $APPROOT/start_aleo.sh
  rm -rf $APPROOT/stop_aleo.sh
  rm -rf $APPROOT/aleowrapper
  rm -rf $APPROOT/prover.log
}

while getopts "u" opt; do
  case "$opt" in
    u) echo "Uninstall aleo package..."
       uninstall_package
       echo "Done."
       exit 0
       ;;
    *) echo "Unknown option: \$opt"
       exit 1
       ;;
  esac
done

if [ ! -f $APPROOT/config.cfg ]; then
    echo -e "$APPROOT/config.cfg not found'\n"
    exit 1
fi
source $APPROOT/config.cfg

if [[ "$POOL" == "xxx.xxx.xxx.xxx:xxxx" || "$POOL" == "" ]]; then
    echo -e "Please edit the '$APPROOT/config.cfg'\n"
    exit 1
fi

if [[ ! -f $APPROOT/aleo-prover-cuda ]]; then
    echo -e "aleo-prover-cuda not found\n"
    exit 1
fi
chmod +x $APPROOT/aleo-prover-cuda

cat << EOF > /etc/systemd/system/aleo.service
[Unit]
Description=Aleo Service
Documentation=https://www.secureweb3.com/
After=network-online.target
Wants=network-online.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=+$APPROOT/aleowrapper
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF

cat << SUPER-EOF > $APPROOT/aleowrapper
#!/bin/bash
set -o pipefail

source $APPROOT/config.cfg

if [[ "\$POOL" == "xxx.xxx.xxx.xxx:xxxx" || "\$POOL" == "" ]]; then
    echo -e "Please edit the '$APPROOT/config.cfg'\n"
    exit 1
fi

LOG_PATH="$APPROOT/prover.log"
APP_PATH="$APPROOT/aleo-prover-cuda"

cpu_cores=\$(lscpu | grep '^CPU(s):' | awk '{print \$2}')
cpu_affinity=(\$(nvidia-smi topo -m 2>/dev/null | awk -F'\t+| {2,}' '{for (i=1;i<=NF;i++) if(\$i ~ /CPU Affinity/) col=i; if (NR != 1 && \$0 ~ /^GPU/) print \$col}'))
gpu_num=\${#cpu_affinity[*]}

cat << EOF >> \$LOG_PATH
=============================================================================
Account name    : \$ACCOUNT_NAME
Pool            : \$POOL
Number of gpus  : \$gpu_num
Number of cores : \$cpu_cores
=============================================================================
EOF

if [[ \$gpu_num -eq 0 ]]; then
    \$APP_PATH -t 7 -j \$(( cpu_cores / 7 )) -p "\$POOL" >> \$LOG_PATH 2>&1
elif [[ \$gpu_num -eq 1 ]]; then
    \$APP_PATH -g 0 -p "\$POOL" >> \$LOG_PATH 2>&1
else
    physical_cores=\$(( cpu_cores / 2 ))
    append=\$(( physical_cores % gpu_num ))
    span=\$(( physical_cores / gpu_num ))

    for gpu_seq in \$(seq 0 \$((gpu_num-1))); do
        cpu_list="\$((gpu_seq*span))-\$(((gpu_seq+1) * span - 1)),\$((gpu_seq * span + physical_cores))-\$(((gpu_seq+1) * span + physical_cores - 1))"
        if [[ \$append -gt 0 ]]; then
            cpu_list+=",\$((physical_cores - append)),\$((cpu_cores - append))"
            append=\$((append - 1))
        fi

        if [ \$gpu_seq -eq \$((gpu_num-1)) ]; then
            taskset -c \$cpu_list \$APP_PATH -g \$gpu_seq -p "\$POOL" >> \$LOG_PATH 2>&1
        else
            taskset -c \$cpu_list \$APP_PATH -g \$gpu_seq -p "\$POOL" >> \$LOG_PATH 2>&1 &
        fi
    done
fi
SUPER-EOF
chmod +x $APPROOT/aleowrapper

cat << EOF > $APPROOT/start_aleo.sh
#!/bin/bash
sudo systemctl start aleo
EOF
chmod +x $APPROOT/start_aleo.sh

cat << EOF > $APPROOT/stop_aleo.sh
#!/bin/bash
sudo systemctl stop aleo
EOF
chmod +x $APPROOT/stop_aleo.sh

systemctl enable aleo
systemctl start aleo
