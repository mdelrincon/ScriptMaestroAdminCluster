#!/bin/sh
# TIPOS DE RETORNO:
#20-> Fallo de sintaxis en el fichero de configuracion adicional
#30-> Fallo de configuracion incompleta en el fichero de configuracion adicional
#40-> Fallo en un mandato
# sh que realiza el servicio mount


#set -x

RETORNO=0

FICHERO_ADICIONAL=$1 #cogemos el fichero adicional 

echo "Accedemos al escritorio donde hemos copiado el fichero de configuracion"

#como hemos copiado el fichero de configuracion en Escritorio accedemos a el
#cd /home/ubuntu/Escritorio

echo "Comprobamos que el fichero de configuracion sea correcto sintacticamente"

LINEAS=`cat $FICHERO_ADICIONAL | wc -l`
DOMINIO_NIS=`cat $FICHERO_ADICIONAL | head -n 1`
VALOR=`cat $FICHERO_ADICIONAL | wc -w`

#Detectamos si el fichero de configuración solo tiene una línea
	if [ $LINEAS -ne 1 ]
	then
		echo -e "Error por configuración incompleta,el fichero de configuración del servicio nis debe contener una linea y su contenido debe ser:\n\tnombre-del-dominio-nis\n\t" 
		RETORNO=30
		exit $RETORNO
	fi
#Detectamos si el fichero de configuración solo tiene un valor
	if [ $VALOR -ne 1 ]
	then
		echo -e "Error por configuración incompleta, el servicio nis debe contener un unico valor.\n\t" 
		RETORNO=30
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

#Ponemos el nombre del dominio en /etc/defaultdomain y definimos el nodo como maestro
echo $DOMINIO_NIS > /etc/defaultdomain
sed -i -e 's/NISSERVER=false/NISSERVER=master/' /etc/default/nis
RETORNO=$?
	if [ $RETORNO -ne 0 ]
	then
		echo -e "Error al ejecutar el mandato sed para modificar la línea NISSERVER=false\n"
		RETORNO=40
		exit $RETORNO
	fi
echo "domain $DOMINIO_NIS server `hostname` " >> /etc/yp.conf
###############
#Modificacion del fichero /var/yp/Makefile
sed -i -e 's/MERGE_PASSWD=false/MERGE_PASSWD=true/' /var/yp/Makefile
RETORNO=$?
	if [ $RETORNO -ne 0 ]
	then
		echo -e "Error al ejecutar el mandato sed para modificar la línea MERGE_PASSWD=false\n"
		RETORNO=40
		exit $RETORNO
	fi
sed -i -e 's/MERGE_GROUP=false/MERGE_GROUP=true/' /var/yp/Makefile
RETORNO=$?
	if [ $RETORNO -ne 0 ]
	then
		echo -e "Error al ejecutar el mandato sed para modificar la línea MERGE_GROUP=false\n"
		RETORNO=40
		exit $RETORNO
	fi
###############
#Rearrancamos el servicio NIS
systemctl restart nis &
ID=$!
RETORNO=$?
	if [ $RETORNO -ne 0 ]
	then
		echo -e "Error al ejecutar el mandato systemctl restart nis &\n"
		RETORNO=40
		exit $RETORNO
	fi
sleep 1
/usr/lib/yp/ypinit -m < /dev/null			
RETORNO=$?
	if [ $RETORNO -ne 0 ]
	then
		echo -e "Error al ejecutar el mandato ypinit -m\n"
		RETORNO=40
		exit $RETORNO
	fi
wait $ID
exit $RETORNO




