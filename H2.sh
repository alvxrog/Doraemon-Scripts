systemctl stop NetworkManager.service
systemctl stop firewalld.service

# Asignamos a la interfaz su direccion IP
ifconfig enp0s3 192.168.0.7 netmask 255.255.255.0 up
# Añadimos a R1 como router por defecto
route add default gw 192.168.0.1
resolvectl dns enp0s3 8.8.8.8