#!/bin/sh
# TIPOS DE RETORNO:
#20-> Fallo de sintaxis en el fichero de configuracion adicional
# sh que realiza el servicio mount


#set -x

RETORNO=0

FICHERO_ADICIONAL=$1 #cogemos el fichero adicional 

#leemos las lineas que nos interesan e ignoramos los comentarios y las lineas vacias 
LINEAS=`cat $FICHERO_ADICIONAL | wc -l`
CONTADOR=1

while [ $LINEAS -ne 0 ]
do
	LINEA=`cat $FICHERO_ADICIONAL | head -n $CONTADOR | tail -n 1`
	PRIMER_CARACTER=`echo $LINEA | cut -c1`
	let CONTADOR=CONTADOR+1
	let LINEAS=LINEAS-1
	if [ "$LINEA" = '' ] || [ "$PRIMER_CARACTER" = '#' ]
	then 
		continue
	else
		if [ "$DISPOSITIVO" = "" ]
		then
			DISPOSITIVO="$LINEA"
		elif [ "$PUNTO_MONTAJE" = "" ]
		then
			PUNTO_MONTAJE="$LINEA"
		else
			echo "Error de sintaxis en el fichero de configuracion del servicio mount: hay mas de dos lineas"
			RETORNO=20
			exit $RETORNO
		fi
	fi
	
done

echo "Comprobamos que el fichero de configuracion es correcto"

AUX=`echo $DISPOSITIVO | grep \ `
AUX2=`echo $PUNTO_MONTAJE | grep  \ `


if [ "$DISPOSITIVO" = "" ] || [ "$PUNTO_MONTAJE" = "" ] || [ "$AUX" != "" ] || [ "$AUX2" != "" ]
then
	echo -e "error de sintaxis en el fichero de configuracion del servicio mount: debe ser /nombre_dispositivo \n /punto_de_montaje" 
	RETORNO=20
fi

##if [ $LINEAS -ne 2 ]
##then
##	echo -e "error de sintaxis en el fichero de configuracion del servicio mount: debe ser /nombre_dispositivo \n /punto_de_montaje" 
##	RETORNO=20
##fi

if [ $RETORNO -eq 0 ]
then
	#Si el fichero de configuracion de mount esta bien 
	#DISPOSITIVO=`cat $FICHERO_ADICIONAL | head -n 1`
	#PUNTO_MONTAJE=`cat $FICHERO_ADICIONAL | tail -n 1`

	echo "Una vez hemos visto que el fichero de configuracion esta bien, comprobamos que el directorio existe."
	#vemos si el directorio existe
	if [ ! -d $PUNTO_MONTAJE ]
	then
		echo "Como no existe, creamos el directorio."
		mkdir $PUNTO_MONTAJE
		RETORNO=$?
		if [ $RETORNO -eq 0 ]
		then
			echo "El directorio $PUNTO_MONTAJE se ha creado correctamente"
		else
			echo "El directorio $PUNTO_MONTAJE no se ha podido crear correctamente"
		fi
		#si existe hay que comprobar que este vacio 
	else
		echo "Como existe, comprobamos que este vacio."
		if [ "$(ls $PUNTO_MONTAJE)" != "" ]
		then
			echo "Error, el directorio del punto de montaje no esta vacio: "$PUNTO_MONTAJE 
		RETORNO=99
		else
			echo "El directorio esta correctamente vacio "
		fi
	fi

	if [ $RETORNO -eq 0 ]
	then
		#si se ha creado bien el directorio 
		#comprobamos que exista el dispositivo
		echo "Ahora comprobaremos que el dispositivo $DISPOSITIVO existe"
		NOMBRE_DISPOSITIVO=`echo $DISPOSITIVO | cut -d "/" -f3`
		EXISTE=`lsblk | grep $NOMBRE_DISPOSITIVO`
		if [ "$EXISTE" = '' ]
		then
			echo "error no existe el dispositivo: "$DISPOSITIVO 
			RETORNO=99
			#Tras todas las comprobaciones, nos disponemos a realizar el servicio
		else
			echo "Como $DISPOSITIVO existe, lo montamos en $PUNTO_MONTAJE"
			#montamos el dispositivo en el punto de montaje
			mount $DISPOSITIVO $PUNTO_MONTAJE
			RETORNO=$?
			#miramos si se ha montado correctamente 
			if [ $RETORNO -eq 0 ]
			then
				echo "Como se ha montado correctamente, ahora editamos el archivo fstab para iniciar siempre este montado"
				#tras montarlo hay que editar el archivo fstab para que al iniciar siempre este montado
				VARIABLE_UID=`blkid | grep $DISPOSITIVO | cut -d" " -f2` #aqui obtenemos el UID del dispositivo creado 
				echo "Aniadimos al final del fichero fstab el nuevo montaje poniendo al final la linea:"
				echo -e "\t $VARIABLE_UID $PUNTO_MONTAJE auto defaults 1 1"
				sed -i -e "\$a$VARIABLE_UID $PUNTO_MONTAJE auto defaults 1 1" /etc/fstab #aniadimos al final del fichero fstab el nuevo montaje 
				RETORNO=$?
				if [ $RETORNO -eq 0 ]
				then
					echo "se ha montado correctamente el dispositivo "$DISPOSITIVO" en "$PUNTO_MONTAJE" " 
				else
					echo "error, no se ha podido escribir en el fichero /etc/fstab la linea correspondiente " 
				fi
			else
				echo "error, el dispositivo: "$DISPOSITIVO" no se ha montado correctamente en el punto de montaje: "$PUNTO_MONTAJE 
				RETORNO=99
			fi
		fi
	fi
fi

exit $RETORNO