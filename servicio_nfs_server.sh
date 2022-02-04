#!/bin/sh
# TIPOS DE RETORNO:
#20-> Fallo de sintaxis en el fichero de configuracion adicional
#30-> Fallo de configuracion incompleta en el fichero de configuracion adicional
#40-> El directorio no esta vacio
# sh que realiza el servicio servidor BackUp


#set -x

RETORNO=0

FICHERO_ADICIONAL=$1 #cogemos el fichero adicional 
IP=$2 #cogemos la ip

echo "Comprobamos que el fichero de configuracion sea correcto sintacticamente"

LINEAS=`cat $FICHERO_ADICIONAL | wc -l`

if [ $LINEAS -eq 0 ]
then
	echo "Fichero conf vacío"
	RETORNO=20
	exit $RETORNO

fi

CONTADOR=1

echo "Comprobamos que existan los directorios" 

while [ $LINEAS -ne 0 ]
do
	DIRECTORIO=`cat $FICHERO_ADICIONAL | head -n $CONTADOR | tail -n 1`
	AUX=`echo $DIRECTORIO | cut -d " " -f2`
	if [ "$AUX" != "$DIRECTORIO" ]
	then
		echo "Error en el fichero de configuracion, en cada linea debe haber solo un valor. La línea errónea es: $DIRECTORIO"
		RETORNO=20
		exit $RETORNO
	fi
	if [ ! -d "$DIRECTORIO" ]
	then
		echo -e "El directorio local no existe y debe existir\n"
		RETORNO=40
		exit $RETORNO
	fi
	ARRAY_DIRECTORIOS+=("$DIRECTORIO")
	let CONTADOR=CONTADOR+1
	let LINEAS=LINEAS-1
done

echo "El fichero de configuracion es correcto y existen todos los directorios"

apt-get -y install nfs-kernel-server

#systemctl start rpcbind nfs-server
#RETORNO=$?
#if [ $RETORNO -ne 0 ]
#then
#	echo "Error al Iniciar el servicio del servidor NFS"
#	exit $RETORNO
#else
#	echo "Iniciado el servicio del servidor NFS "
#fi
#systemctl enable rpcbind nfs-server
#RETORNO=$?
#
#if [ $RETORNO -ne 0 ]
#then
#	echo "Error al habilitarlo para el inicio del sistema"
#	exit $RETORNO
#else
#	echo "Habilitado para el inicio del sistema"
#fi

DOMINIO=`cat /etc/idmapd.conf | grep Domain`




UNO=`echo $IP | cut -d "." -f1`
DOS=`echo $IP | cut -d "." -f2`
TRES=`echo $IP | cut -d "." -f3`
RED=`echo "$UNO"."$DOS"."$TRES".0/24`

sed -i "i/$DOMINIO/$RED/g" /etc/idmapd.conf

echo "Configuramos los recursos compartidos editando el archivo /etc/exports"
for DIRECTORIO in "${ARRAY_DIRECTORIOS[@]}"
do
	sed -i -e "\$a$DIRECTORIO $RED(rw,sync)"  /etc/exports #aniadimos al final del fichero fstab el nuevo montaje 
	RETORNO=$?
	if [ $RETORNO -ne 0 ]
	then
		echo "Error al editar fichero /etc/exports"
		exit $RETORNO
	fi
done

echo "Una vez añadidos al fichero exports, hacemos efectivos esos cambios"
exportfs -ra
RETORNO=$?
if [ $RETORNO -ne 0 ]
then
	echo "Error al realizar exportfs"
	exit $RETORNO
fi

echo "Todo ha salido correctamente y ya están exportados los directorios"

exit $RETORNO
