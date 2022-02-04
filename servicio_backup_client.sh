#!/bin/bash
# TIPOS DE RETORNO:
#20-> Fallo de sintaxis en el fichero de configuracion adicional
#30-> Fallo de configuracion incompleta en el fichero de configuracion adicional
#40-> El directorio no existe
# sh que realiza el servicio cliente BackUp


#set -x

RETORNO=0

FICHERO_ADICIONAL=$1 #cogemos el fichero adicional 

#como hemos copiado el fichero de configuracion en Escritorio accedemos a el
#cd /home/ubuntu/Escritorio

echo "Comprobamos que el fichero de configuracion sea correcto sintacticamente"

LINEAS=`cat $FICHERO_ADICIONAL | wc -l`
DIRECTORIO_LOCAL=`cat $FICHERO_ADICIONAL | head -n 1`
DIRECCION=`cat $FICHERO_ADICIONAL | head -n 2 | tail -n 1`
DIRECTORIO_REMOTO=`cat $FICHERO_ADICIONAL | head -n 3 | tail -n 1`
HORAS=`cat $FICHERO_ADICIONAL | tail -n 1`
VALOR=`cat $FICHERO_ADICIONAL | head -n 1 | wc -w`
VALOR2=`cat $FICHERO_ADICIONAL | head -n 2 | tail -n 1 | wc -w`
VALOR3=`cat $FICHERO_ADICIONAL | head -n 3 | tail -n 1 | wc -w`
VALOR4=`cat $FICHERO_ADICIONAL | tail -n 1 | wc -w`

#Detectamos si el fichero de configuración solo tiene cuatros lineas
	if [ $LINEAS -ne 4 ]
	then
		echo -e "Error por configuración incompleta, el fichero de configuración del servicio cliente backup debe contener cuatro lineas y su contenido debe ser:\n\truta-del-directorio-del-que-se-desea-hacer-backup\n\tdirección-del-servidor-de-backup\n\truta-de-directorio-destino-del-backup\n\tperiodicidad-del-backup-en-horas\n\t" 
		RETORNO=30
		exit $RETORNO
	fi
#Detectamos si el fichero de configuración solo tiene un valor para cada una de sus lineas
	if [ $VALOR -ne 1 ]
	then
		echo -e "Error por configuración incompleta, el servicio cliente backup debe contener un unico valor en la primera linea.\n\t" 
		RETORNO=30
		exit $RETORNO
	fi
	if [ $VALOR2 -ne 1 ]
	then
		echo -e "Error por configuración incompleta, el servicio cliente backup debe contener un unico valor en la segunda linea.\n\t" 
		RETORNO=30
		exit $RETORNO
	fi
	if [ $VALOR3 -ne 1 ]
	then
		echo -e "Error por configuración incompleta, el servicio cliente backup debe contener un unico valor en la tercera linea.\n\t" 
		RETORNO=30
		exit $RETORNO
	fi
	if [ $VALOR4 -ne 1 ]
	then
		echo -e "Error por configuración incompleta, el servicio cliente backup debe contener un unico valor en la cuarta linea.\n\t" 
		RETORNO=30
		exit $RETORNO
	fi
	
echo "Comprobamos que exista el directorio local"

#Comprobamos si existe el directorio local o no
	if [ -d "$DIRECTORIO_LOCAL" ]
	then
		echo -e "El directorio local existe\n"
	else
		echo -e "El directorio local no existe y debe existir\n"
		RETORNO=40
		exit $RETORNO
	fi
	
#Detectamos si el valor de la segunda linea tiene el correcto formato
if [[ $DIRECCION =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
then
	OIFS=$IFS
  	IFS='.'
	ip=($DIRECCION)
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

echo "La ip tiene formato correcto, ahora vemos si existe el directorio remoto"



echo "ESTO ES DIRECCION=$DIRECCION y esto $DIRECTORIO_REMOTO"
#Comprobamos que el direcorio remoto exista

#ssh root@$DIRECCION test -d $DIRECTORIO_REMOTO
#ssh-keygen -R $DIRECCION



ssh root@$DIRECCION test -d $DIRECTORIO_REMOTO < /dev/null


DEVOLUCION=$?
if [ $DEVOLUCION -eq 0 ]
then
	echo -e "El directorio remoto existe\n"
else
	echo -e "El directorio remoto no existe y debe existir\n"
	RETORNO=40
	exit $RETORNO
fi
	
echo "Y por nultimo vemos si el valor de la ultima linea del fichero de configuracion es correcto"
	
#Comprobamos si el valor de la ultima linea es un numero entre el 1 y 23
	if [[ "$HORAS" =~ ^[0-9]+$ ]] && [ "$HORAS" -ge 1 ] && [ "$HORAS" -le 23 ]
	then
		echo -e "Las horas expresadas son correctas\n"
	else
		echo -e "Error de sintaxis en el fichero de configuracion del servicio cliente backup, las horas o no son un numero o no esta en el intervalo de 1 y 23\n" 
		RETORNO=20
		exit $RETORNO
	fi
echo "Ejecutamos rsync"
	
#Tras las comprobaciones del fichero de configuracion, llamamos a rsync
#* $HORAS * * * root rsync --recursive $DIRECTORIO_LOCAL root@$DIRECCION:$DIRECTORIO_REMOTO
echo "Aniadimos al fichero crontab la ejecucion recursiva"
sed -i -e "\$a 0 */$HORAS * * * root rsync --recursive $DIRECTORIO_LOCAL root@$DIRECCION:$DIRECTORIO_REMOTO" /etc/crontab
RETORNO=$?

if [ $RETORNO -ne 0 ]
then
	echo "Error al aniadir al fichero /etc/crontab"
	exit $RETORNO
else
	echo "Todo se realizó correctamente."
fi



exit $RETORNO