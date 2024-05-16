#!/bin/sh
#script by Abi Darwish

rm -rf $0

#Cleanup from previous beta installation
rm -rf /etc/arca/restart_wan
sed -i '/^.*pgrep -f restart_wan/d;/^$/d' /usr/lib/rooter/connect/create_connect.sh
sed -i '/^.*pgrep -f \/etc\/arca\/restart_wan/d;/^$/d' /usr/lib/rooter/connect/create_connect.sh
sed -i '/if \[ -e \/etc\/arca\/restart_wan \].*$/,/fi/d' /usr/lib/rooter/connect/create_connect.sh

if [ ! -e /etc/arca ]; then
        mkdir -p /etc/arca
fi

if [ ! -e /usr/lib/rooter/connect/create_connect.sh.bak ]; then
        cp /usr/lib/rooter/connect/create_connect.sh /usr/lib/rooter/connect/create_connect.sh.bak
fi

#Initialize
sed -i '/^.*pgrep -f change_ip/d;/^$/d' /usr/lib/rooter/connect/create_connect.sh
sed -i '/^.*pgrep -f \/etc\/arca\/change_ip/d;/^$/d' /usr/lib/rooter/connect/create_connect.sh
sed -i '/#!\/bin\/sh/a\\nkill -9 \$\(pgrep -f change_ip)' /usr/lib/rooter/connect/create_connect.sh
sed -i '/#!\/bin\/sh/a\\nkill -9 \$\(pgrep -f \/etc\/arca\/change_ip)' /usr/lib/rooter/connect/create_connect.sh
sed -i '/if \[ -e \/etc\/arca\/change_ip \].*$/,/fi/d' /usr/lib/rooter/connect/create_connect.sh
>/etc/arca/counter

if [ ! -e /usr/lib/rooter/connect/conmon.sh.bak ]; then
        cp /usr/lib/rooter/connect/conmon.sh /usr/lib/rooter/connect/conmon.sh.bak
fi

echo -e "#!/bin/sh
#script by Abi Darwish

if [ -e /etc/arca/change_ip ]; then
        /etc/arca/change_ip &
fi" >/usr/lib/rooter/connect/conmon.sh

cat << 'EOF' >/etc/arca/change_ip
#!/bin/sh
#script by Abi Darwish

[ $(pgrep -f /etc/arca/change_ip | wc -l) -gt 2 ] && exit 0

QMIChangeWANIP() {
        ifup wan1
}

MBIMChangeWANIP() {
        /usr/lib/rooter/gcom/gcom-locked /dev/ttyUSB2 run-at.gcom 1 AT+CFUN=0 >/dev/null 2>&1 && /usr/lib/rooter/gcom/gcom-locked /dev/ttyUSB2 run-at.gcom 1 AT+CFUN=1 /dev/null 2>&1 && ifup wan1
}

log() {
        modlog "$@"
}

log "Start RC script"

n=0
>/tmp/wan_status
>/etc/arca/counter
while true; do
        if [ $(curl -I -s -o /dev/null -w "%{http_code}" --max-time 5 https://www.youtube.com) -eq 200 ] && [ $(curl -I -s -o /dev/null -w "%{http_code}" --max-time 5 https://fast.com) -eq 200 ]; then
                echo -e "$(date) \t Internet is fine" | tee -a /tmp/wan_status
                >/etc/arca/counter
        else
                log "RC: Modem disconnected"
                if [ $(uci get modem.modem1.proto) -eq 2 ]; then
                        QMIChangeWANIP
                        log "RC: QMI Protocol restarted"
                else
                        MBIMChangeWANIP
                        log "RC: MBIM Protocol restarted"
                fi
                sleep 20
                WAN_IP=$(curl --max-time 10 -s ip.sb)
                if [ ! -z ${WAN_IP} ]; then
                        log "RC: WAN IP changed to ${WAN_IP}"
                        >/etc/arca/counter
                else
                        n=$(( $n + 1 ))
                        echo "$n" >/etc/arca/counter
                        if [ $(cat /etc/arca/counter) -eq 2 ]; then
                                n=$(( $n + 1 ))
                                echo "$n" >/etc/arca/counter
                                sleep 2
                                log "RC: Modem restarted"
                                reboot
                        elif [ $(cat /etc/arca/counter) -ge 3 ]; then
                                log "RC: Modem disconnected. Check your SIM card"
                                exit 1
                        fi
                fi
        fi
        sleep 20
done
EOF

#Kill previous beta RC Script daemon
if [ ! -z $(pgrep -f /etc/arca/restart_wan) ]; then
        kill -9 $(pgrep -f /etc/arca/restart_wan)
fi

#Kill currently running RC Script daemon
if [ ! -z $(pgrep -f /etc/arca/change_ip) ]; then
        kill -9 $(pgrep -f /etc/arca/change_ip)
fi

chmod 755 /etc/arca/change_ip
/etc/arca/change_ip &
echo "Done. You can close this terminal now"
exit 0
