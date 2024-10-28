systemctl stop NetworkManager.service
systemctl stop firewalld.service
# Asignamos las IPs de las interfaces del router de las dos subredes de Dorayaki
# orgnoconf
ifconfig enp0s3 192.168.2.1 netmask 255.255.255.0 up
# pppr2rc
ifconfig enp0s8 192.168.34.253 netmask 255.255.255.252 up

# Activar encaminamiento de paquetes
# Se puede sustituir añadiendo la linea de configuración al fichero /etc/sysctl.conf
sysctl -w net.ipv4.conf.all.forwarding=1
sysctl -p

# Añadir a RC como router por defecto
route add default gw 192.168.34.254

# SNAT para todas las conexiones entrantes de OrgNoConf
iptables -t nat -A POSTROUTING -o enp0s8 -j SNAT --to 192.168.34.253

# Los routers no deben aparecer en los traceroute.
iptables -A OUTPUT -p icmp --icmp-type time-exceeded -j DROP