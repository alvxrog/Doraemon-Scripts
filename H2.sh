# Asignamos a la interfaz su direccion IP
ifconfig enp0s3 192.168.2.2 netmask 255.255.255.0 up

# Añadimos a R1 como router por defecto
route add default gw 192.168.2.1