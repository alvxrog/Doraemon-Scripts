# Configuración manual IP para CP1
ifconfig enp0s3 192.168.1.140 netmask 255.255.255.128 up

# Añadimos a R1 como router por defecto
route add default gw 192.168.1.129