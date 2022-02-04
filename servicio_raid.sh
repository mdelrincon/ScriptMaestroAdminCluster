#!/bin/sh
# TIPOS DE RETORNO:
#           20-> Fallo de sintaxis en el fichero de configuracion adicional
#           30 -> Nivel de raid no correcto
#           40 -> Dispositivo para usar no existente
#           50 -> Nivel de raid y dispositivos no cuadran
# sh que realiza el servicio mount

##set -x

RETORNO=0

FICHERO_ADICIONAL=$1 #cogemos el fichero adicional 


echo "Comprobamos que el fichero de configuracion sea correcto sintacticamente"


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
		if [ "$NOMBRE_RAID" = "" ]
		then
			NOMBRE_RAID="$LINEA"
		elif [ "$NIVEL_RAID" = "" ]
		then
			NIVEL_RAID="$LINEA"
		elif [ "$DISPOSITIVOS_USADOS" = "" ]
		then
			DISPOSITIVOS_USADOS="$LINEA"
		else
			echo -e "error de sintaxis en el fichero de configuracion del servicio raid, debe tener solo 3 lineas "
			RETORNO=20
			exit $RETORNO
		fi
	fi
	
done

AUX=`echo $NOMBRE_RAID | grep \ `
AUX2=`echo $NIVEL_RAID | grep  \ `


if [ "$NOMBRE_RAID" = "" ] || [ "$NIVEL_RAID" = "" ] || [ "$DISPOSITIVOS_USADOS" = "" ] || [ "$AUX" != "" ] || [ "$AUX2" != "" ]
then
	echo -e "error de sintaxis en el fichero de configuracion del servicio raid debe ser:\nnombre_nuevo_dispositivo_raid\n nivel_de_raid\n dispositivo-1 [dispositivo-2 ...]" 
	RETORNO=20
	exit $RETORNO
	
fi

##if [ $LINEAS -ne 3 ]
##then
##	echo -e "Error de sintaxis en el fichero de configuracion del servicio raid debe ser:\nnombre_nuevo_dispositivo_raid\n nivel_de_raid\n dispositivo-1 [dispositivo-2 ...]" 
##	RETORNO=20
##	exit $RETORNO
##fi
##
##NOMBRE_RAID=`cat $FICHERO_ADICIONAL | head -n 1`
##NIVEL_RAID=`cat $FICHERO_ADICIONAL | head -n 2 | tail -n 1`
##DISPOSITIVOS_USADOS=`cat $FICHERO_ADICIONAL | head -n 3 | tail -n 1`


echo "Comprobamos que todos los dispositivos existen"

echo $DISPOSITIVOS_USADOS | tr -s '[:blank:]' '\n' > dispositivos_columna.txt


while read DISPOSITIVO
do
	NOMBRE_DISPOSITIVO=`echo $DISPOSITIVO | cut -d "/" -f3`
	EXISTE=`lsblk | grep $NOMBRE_DISPOSITIVO`
	if [ "$EXISTE" = '' ]
	then
		echo "Error no existe el dispositivo: "$DISPOSITIVO 
		RETORNO=40
		rm dispositivos_columna.txt
		exit $RETORNO
	fi
	SALIDA=`lsblk -o MOUNTPOINT $DISPOSITIVO | grep -v MOUNTPOINT`
	
	if [ "$SALIDA" != "" ]
	then
		echo "El dispositivo $DISPOSITIVO ya contiene un sistema de ficheros."
		RETORNO=50
		rm dispositivos_columna.txt
		exit $RETORNO
	fi
done < dispositivos_columna.txt

echo "Todos los dispositivos existen y no contienen ningun sistema de ficheros."

echo "Ahora comprobaremos que el nivel de Raid y la lista de los dispositivos asociada a ese nivel es correcta"

NUMERO_DISPOSITIVOS=`cat dispositivos_columna.txt | wc -l`

case $NIVEL_RAID in
	
	0)  echo "Se trata de un nivel de Raid 0, por lo que debe haber al menos dos dispositivos"
		if [ $NUMERO_DISPOSITIVOS -lt 2 ]
		then
			echo "Hay menos de dos dispositivos para el nivel de Raid 0, por lo que es incorrecto."
			RETORNO=60
			rm dispositivos_columna.txt
			exit $RETORNO
		fi
		;;
	
	1)  echo "Se trata de un nivel de Raid 1, es decir, un espejo, por lo que debe haber dos dispositivos "
		
		if [ $NUMERO_DISPOSITIVOS -lt 2 ]
		then
			echo "Hay menos de dos dispositivos para el nivel de Raid 1, por lo que es incorrecto."
			RETORNO=60
			rm dispositivos_columna.txt
			exit $RETORNO
		fi
		;;
	
	4)	echo "Se trata de un nivel de Raid 4, por lo que hay un disco de paridad. Se necesitan por lo tanto 3 discos minimo"
		
		if [ $NUMERO_DISPOSITIVOS -lt 3 ]
		then
			echo "Hay menos de tres dispositivos para el nivel de Raid 4, por lo que es incorrecto."
			RETORNO=60
			rm dispositivos_columna.txt
			exit $RETORNO
		fi
		;;
	5) echo "Se trata de un nivel de Raid 5, por lo que hay una paridad distribuida en los discos. Se necesitan por lo tanto 3 discos minimo"
		
		if [ $NUMERO_DISPOSITIVOS -lt 3 ]
		then
			echo "Hay menos de tres dispositivos para el nivel de Raid 4, por lo que es incorrecto."
			RETORNO=60
			rm dispositivos_columna.txt
			exit $RETORNO
		fi
		;;
	
	6) echo "Se trata de un nivel de Raid 6, por lo que hay una paridad distribuida en los discos. Se necesitan por lo tanto 3 discos minimo"
		
		if [ $NUMERO_DISPOSITIVOS -lt 4 ]
		then
			echo "Hay menos de tres dispositivos para el nivel de Raid 4, por lo que es incorrecto."
			RETORNO=60
			rm dispositivos_columna.txt
			exit $RETORNO
		fi
		;;
	
	10) echo "Se trata de un nivel de Raid 10, por lo que se trata de una combinacion de Raid 0 y 1. Se neceistan por lo tanto 4 discos minimo"
		if [ $NUMERO_DISPOSITIVOS -lt 4 ]
		then
			echo "Hay menos de cuatro dispositivos para el nivel de Raid 10, por lo que es incorrecto."
			RETORNO=60
			rm dispositivos_columna.txt
			exit $RETORNO
		fi
		;;
	
	*) echo "El nivel de RAID: $NIVEL_RAID no es correcto"
		RETORNO=30
		rm dispositivos_columna.txt
		exit $RETORNO
		;;
esac	

echo "El nivel de Raid, los dispositivos y el numero de dispositivos existen y son correctos."

echo "Instalamos el mandato mdadm en caso de que no lo tenga la maquina"

apt-get install mdadm -y
RETORNO=$?
sleep 4

if [ $RETORNO -eq 0 ]
then

	echo "Nos disponemos a crear el raid con nombre $NOMBRE_RAID de nivel $NIVEL_RAID con $NUMERO_DISPOSITIVOS dispositivos: $DISPOSITIVOS_USADOS"
	rm dispositivos_columna.txt

else
	echo "Ha fallado la instalacion del mandato mdadm"
	rm dispositivos_columna.txt
	exit $RETORNO
fi



mdadm --create --verbose $NOMBRE_RAID --run --level=$NIVEL_RAID --raid-devices=$NUMERO_DISPOSITIVOS $DISPOSITIVOS_USADOS
RETORNO=$?

if [ $RETORNO -eq 0 ]
then
	echo "El raid se ha creado correctamente."
	echo "Una vez creado correctamente, hay que aniadirlo al fichero mdadm.conf para que persista al volver a encender la maquina"
	mdadm --detail --scan | tee -a /etc/mdadm/mdadm.conf
	RETORNO=$?
	if [ $RETORNO -eq 0 ]
	then
		echo "Se ha aniadido correctamente al fichero mdadm.conf por lo tanto ya estaria realizado el servicio correctamente"
	else
		echo "No se ha podido aniadir al fichero mdadm.conf el nuevo arraid creado."
	fi
else
	echo "Ha fallado la creacion del Raid"
	exit $RETORNO
fi

#Falta escribir en el fichero conf de raids para que sea permanente

exit $RETORNO
