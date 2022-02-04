#!/bin/sh
# TIPOS DE RETORNO:
#           20-> Fallo de sintaxis en el fichero de configuracion adicional
#           30 -> Tamaño disponible insuficiente
#           40 -> Dispositivo para usar no existente 
# sh que realiza el servicio lvm

##
#set -x


RETORNO=0

FICHERO_ADICIONAL=$1 #cogemos el fichero adicional 



echo "Comprobamos que el fichero de configuracion sea correcto sintacticamente"

LINEAS=`cat $FICHERO_ADICIONAL | wc -l`


if [ $LINEAS -lt 3 ]
then
	echo -e "Error de sintaxis en el fichero de configuracion del servicio lvm debe contener al menos 3 lineas y su contenido debe ser:\n\tnombre-del-grupo-de-volúmenes\n\tlista-de-dispositivos-en-el-grupo\n\tnombre-del-primer-volumen tamaño-del-primer-volumen \n\tnombre-del-segundo-volumen tamaño-del-segundo-volumen ..." 
	RETORNO=20
	exit $RETORNO
fi

CONTADOR=1
INDICE=0
TOTAL_SIZE=0 #tamaño total del volumen logico 

while [ $LINEAS -ne 0 ]
do
	LINEA=`cat $FICHERO_ADICIONAL | head -n $CONTADOR | tail -n 1`
	PRIMER_CARACTER=`echo $LINEA | cut -c1`
	if [ "$LINEA" = '' ] || [ "$PRIMER_CARACTER" = '#' ]
	then 
		let LINEAS=LINEAS-1
		let CONTADOR=CONTADOR+1
		continue
	elif [ "$NOMBRE_VOLUMEN" = "" ]
	then
		NOMBRE_VOLUMEN="$LINEA"
	elif [ "$LISTA_DISPOSITIVOS" = "" ]
	then
		LISTA_DISPOSITIVOS="$LINEA"	
	else
		VOLUMEN=`cat $FICHERO_ADICIONAL | head -n $CONTADOR | tail -n 1`
		ARRAY_VOLUMENES+=("$VOLUMEN")
		PREFIJO_M=`echo $VOLUMEN | grep M`
		PREFIJO_MIN=`echo $VOLUMEN | grep m`
		if [ "$PREFIJO_M" != "" ]
		then
			SUMA=`echo $VOLUMEN | cut -d" " -f2 | cut -d"M" -f1`
			#let SUMA=MEGA/1000
		elif [ "$PREFIJO_MIN" != "" ]
		then
			SUMA=`echo $VOLUMEN | cut -d" " -f2 | cut -d"m" -f1`
			#let SUMA=MEGA/1000
		else
			#Se multiplica por 10^3 para conseguir MEGAS
			GIGA=`echo $VOLUMEN | cut -d" " -f2 | cut -d"G" -f1`
			let SUMA=GIGA*1000
		fi
		let TOTAL_SIZE=TOTAL_SIZE+SUMA
	fi
	let CONTADOR=CONTADOR+1
	let LINEAS=LINEAS-1
done


AUX_1=`echo $NOMBRE_VOLUMEN | grep \ `

if [ "$AUX_1" != "" ] || [ "$NOMBRE_VOLUMEN" = "" ] || [ "$LISTA_DISPOSITIVOS" = "" ]  || [ $TOTAL_SIZE = "" ]
then
	echo "Error de sintaxis fichero de configuracion"
	RETORNO=20
	exit $RETORNO
fi

let NUMERO_VOLUMENES=LINEAS-2

apt-get install lvm2 -y

echo "Comprobamos que todos los dispositivos existen"

echo $LISTA_DISPOSITIVOS | tr -s '[:blank:]' '\n' > dispositivos_columna.txt #esta linea lo que hace es poner a columnas la fila de los dispositivos 


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


echo "Una vez hemos comprobado que existen y estan disponibles,inicializamos los volumenes fisicos"
pvcreate $LISTA_DISPOSITIVOS
RETORNO=$?

if [ $RETORNO -ne 0 ]
then
	echo "Error al inicializar los volumenes fisicos con los dispositivos $LISTA_DISPOSITIVOS"
	exit $RETORNO	
fi

echo "Creamos el grupo con ellos"

vgcreate $NOMBRE_VOLUMEN $LISTA_DISPOSITIVOS
RETORNO=$?

if [ $RETORNO -ne 0 ]
then
	echo "Error al crear el grupo $NOMBRE_VOLUMEN con los dispositivos $LISTA_DISPOSITIVOS"
	exit $RETORNO	
fi

echo "Se ha creado con exito el volumen, ahora comprobaremos que el tamaño del volumen es suficiente para el tamaño del volumen logico total"


#Comprobamos si la particion esta en giga o en mega 
PREFIJO_M=`vgs $NOMBRE_VOLUMEN -o vg_free | grep m`

if [ "$PREFIJO_M" = "" ]
then
	ESPACIO_VOLUMEN_AUX=`vgs $NOMBRE_VOLUMEN -o vg_free | grep -v VFree | cut -d"g" -f1`
	ESPACIO_VOLUMEN=`echo $ESPACIO_VOLUMEN_AUX | sed "s/,/./g" | sed "s/<//g"`
	ESPACIO_VOLUMEN=`echo $ESPACIO_VOLUMEN | cut -d"." -f1`
	let ESPACIO_VOLUMEN=ESPACIO_VOLUMEN*1000
else
	ESPACIO_VOLUMEN_AUX=`vgs $NOMBRE_VOLUMEN -o vg_free | grep -v VFree | cut -d"m" -f1`
	ESPACIO_VOLUMEN=`echo $ESPACIO_VOLUMEN_AUX | sed "s/,/./g" | sed "s/<//g"`
fi


if [ 1 -eq "$(echo "${ESPACIO_VOLUMEN} < ${TOTAL_SIZE}" | bc)" ]
then  
    echo "El tamaño disponible ($ESPACIO_VOLUMEN ) en el grupo de dispositivos es insuficiente para el tamaño del volumen lógico total: $TOTAL_SIZE."
	RETORNO=30
	exit $RETORNO
fi




echo "El tamaño disponible es suficiente por lo que nos disponemos a crear el volumen logico."

for VOLUMEN in "${ARRAY_VOLUMENES[@]}"
do
	NOMBRE=`echo $VOLUMEN | cut -d" " -f1`
	SIZE=`echo $VOLUMEN | cut -d" " -f2`
	lvcreate -n $NOMBRE $NOMBRE_VOLUMEN -L $SIZE
	RETORNO=$?
	if [ $RETORNO -ne 0 ]
	then
		echo "No se ha podido crear el volumen logico: $NOMBRE"
		exit $RETORNO
	else
		echo "Se ha creado con exito el volumen logico: $NOMBRE"
		#El enunciado no plantea que se cree un sistema de ficheros en el volumen logico 
		#echo "Ahora creamos el sistema de ficheros en él"
		#mkfs.ext4 /dev/$NOMBRE_VOLUMEN/$NOMBRE
		#RETORNO=$?
		#if [ $RETORNO -ne 0 ]
		#then
		#	echo "No se ha podido crear el sistema de ficheros en el volumen $NOMBRE"
		#	exit $RETORNO
		#else
		#	echo "Se ha creado con éxito el sistema de ficheros en el volumen $NOMBRE"
		#fi
	fi
done

exit $RETORNO