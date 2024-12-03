# Interfaz conectada a enp0s3
# TODO: cambiar la IP asignada al reestructurar la topología
ifconfig enp0s3 192.168.0.5 netmask 255.255.255.0 up

sysctl -w net.ipv4.conf.all.forwarding=1
# R1 como router por defecto
route add default gw 192.168.0.1

resolvectl dns enp0s3 8.8.8.8