#!/bin/bash
# TIPOS DE RETORNO:
#20-> Fallo de sintaxis en el fichero de configuracion adicional
#30-> Fallo de configuracion incompleta en el fichero de configuracion adicional
# sh que realiza el servicio cliente NIS


#set -x

RETORNO=0

FICHERO_ADICIONAL=$1 #cogemos el fichero adicional 

echo "Accedemos al escritorio donde hemos copiado el fichero de configuracion"

#como hemos copiado el fichero de configuracion en Escritorio accedemos a el
#cd /home/ubuntu/Escritorio

echo "Comprobamos que el fichero de configuracion sea correcto sintacticamente"

LINEAS=`cat $FICHERO_ADICIONAL | wc -l`
DOMINIO_NIS=`cat $FICHERO_ADICIONAL | head -n 1`
IP=`cat $FICHERO_ADICIONAL | head -n 2 | tail -n 1`
VALOR=`cat $FICHERO_ADICIONAL | head -n 1 | wc -w`
VALOR2=`cat $FICHERO_ADICIONAL | head -n 2 | tail -n 1 | wc -w`
echo "Valor 1: $VALOR y valor 2: $VALOR2"
#Detectamos si el fichero de configuración solo tiene una línea
	if [ $LINEAS -ne 2 ]
	then
		echo -e "Error por configuración incompleta, el fichero de configuración del servicio nis debe contener al menos 2 lineas y su contenido debe ser:\n\tnombre-del-dominio-nis\n\tservidor-nis-al-que-se-desea-conectar\n\t" 
		RETORNO=30
		exit $RETORNO
	fi
#Detectamos si el fichero de configuración solo tiene un valor
	if [ $VALOR -ne 1 ]
	then
		echo -e "Error por configuración incompleta, el servicio nis debe contener un unico valor en la primera linea.\n\t" 
		RETORNO=30
		exit $RETORNO
	fi

	if [ $VALOR2 -ne 1 ]
	then
		echo -e "Error por configuración incompleta, el servicio nis debe contener un unico valor en la segunda linea.\n\t" 
		RETORNO=30
		exit $RETORNO
	fi
#Detectamos si el valor de la segunda linea tiene el correcto formato
if [[ $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
then
	OIFS=$IFS
  	IFS='.'
	ip=($IP)
	IFS=$OIFS
	[[ ${ip[0]} -le 255 && ${ip[1]} -le 255  && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
	stat=$?
	if [ $stat -ne 0 ]
	then
		echo -e "Error de sintaxis en el fichero de configuracion del servicio nis, la ip no es valida\n" 
		RETORNO=20
		exit $RETORNO
	fi
	else
		echo -e "Error de sintaxis en el fichero de configuracion del servicio nis, la ip no es valida\n" 
		RETORNO=20
		exit $RETORNO
fi

#Instalamos el servicio NIS
mount --bind /bin/true /usr/sbin/invoke-rc.d
DEBIAN_FRONTEND=noninteractive apt-get -yq install nis
RETORNO=$?
	if [ $RETORNO -ne 0 ]
	then
		echo -e "Error al ejecutar el mandato apt-get install nis\n"
		RETORNO=40
		exit $RETORNO
	fi
		
umount /usr/sbin/invoke-rc.d
#Fin de instalación del servicio NIS

#Ponemos el nombre del dominio en /etc/defaultdomain 
echo $DOMINIO_NIS > /etc/defaultdomain
echo "domain $DOMINIO_NIS server $IP" >> /etc/yp.conf
#####################
#Modificacion del fichero /etc/nsswitch.conf

sed -i -e 's/passwd:         files systemd/passwd:         compat systemd nis/' /etc/nsswitch.conf
	if [ $RETORNO -ne 0 ]
	then
		echo -e "Error al ejecutar el mandato sed para modificar la línea passwd:         files systemd\n"
		RETORNO=40
		exit $RETORNO
	fi
#####################
#Rearrancamos el servicio NIS

systemctl restart nis 
RETORNO=$?
	if [ $RETORNO -ne 0 ]
	then
		echo -e "Error al ejecutar el mandato ypinit -m\n"
		RETORNO=40
		exit $RETORNO
	fi
exit $RETORNO

