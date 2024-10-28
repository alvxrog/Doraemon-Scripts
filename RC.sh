systemctl stop NetworkManager.service
systemctl stop firewalld.service
# Añadimos la configuración de las interfaces
# RC-R1 (dorayakih, dorayakis)
ifconfig enp0s3 192.168.33.254 netmask 255.255.255.252 up
# RC-R2 (orgnoconf)
ifconfig enp0s8 192.168.34.254 netmask 255.255.255.252 up
# RC-R3 (externos)
ifconfig enp0s9 192.168.35.254 netmask 255.255.255.252 up

# Definir entrada de tabla de rutas
# dorayakih -> 192.168.33.253
#route add -net 192.168.1.0 netmask 255.255.255.0 gw 192.168.33.253

# dorayakis -> 192.168.33.253
#route add -net 192.168.0.0 netmask 255.255.255.0 gw 192.168.33.253

# orgnoconf -> 192.168.34.253
#route add -net 192.168.2.0 netmask 255.255.255.0 gw 192.168.34.253

# externos -> 192.168.35.253
#route add -net 192.168.3.0 netmask 255.255.255.0 gw 192.168.35.253

# Activar encaminamiento de paquetes
# Los PCRouters ya tienen activada esta opción al añadir la configuración en el fichero /etc/sysctl.conf
sysctl -w net.ipv4.conf.all.forwarding=1
sysctl -p

# Limpiar tablas iptables
iptables -F

# Activar natting inverso para poder recibir respuestas de internet por la interfaz de NAT de VBOX
iptables -t nat -A POSTROUTING -o enp0s10 -j MASQUERADE

# Los routers no deben aparecer en los traceroute.
iptables -A OUTPUT -p icmp --icmp-type time-exceeded -j DROP