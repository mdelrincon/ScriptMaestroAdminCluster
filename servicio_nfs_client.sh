#!/bin/sh
# TIPOS DE RETORNO:
#20-> Fallo de sintaxis en el fichero de configuracion adicional
#30-> Fallo de configuracion incompleta en el fichero de configuracion adicional
#40-> El directorio no esta vacio
# sh que realiza el servicio servidor BackUp


#set -x

RETORNO=0

FICHERO_ADICIONAL=$1 #cogemos el fichero adicional 

apt-get install nfs-common -y

echo "Comprobamos que el fichero de configuracion sea correcto sintacticamente"

LINEAS=`cat $FICHERO_ADICIONAL | wc -l`

if [ $LINEAS -eq 0 ]
then
	echo "Fichero conf vacío"
	RETORNO=20
	exit $RETORNO

fi

CONTADOR=1

while [ $LINEAS -ne 0 ]
do
	LINEA=`cat $FICHERO_ADICIONAL | head -n $CONTADOR | tail -n 1`
	AUX=`echo $LINEA | cut -d " " -f4`
	AUX2=`echo $LINEA | cut -d " " -f3`
	AUX3=`echo $LINEA | cut -d " " -f2`
	if [ "$AUX" != "" ] || [ "$AUX2" = "" ] || [ "$AUX3" = "" ] 
	then
		echo "Error en el fichero de configuracion, en cada linea debe haber solo tres valores. La línea errónea es: $LINEA"
		RETORNO=20
		exit $RETORNO
	fi
	if [ -d "$AUX2" ]
	then
		
		CONTENIDO="$(ls $AUX2)"
   		if [ "$CONTENIDO" != "" ]
		then
			echo -e "Error por configuración incompleta, directorio $AUX2 no vacio." 
			RETORNO=40
			exit $RETORNO
		fi
	else
		mkdir $AUX2
	fi
	ARRAY_LINEAS+=("$LINEA")
	let CONTADOR=CONTADOR+1
	let LINEAS=LINEAS-1
done

echo "Realizamos el montaje y añadimos a fstab para que se mantenga"

for LINEA in "${ARRAY_LINEAS[@]}"
do
	#mount -t nfs servidor:dir_exportado punto_de_montaje
	#ip-servidor ruta-de-directorio-remoto punto-de montaje
	IP_SERVIDOR=`echo $LINEA | cut -d " " -f1`
	DIRECTORIO_EXPORTADO=`echo $LINEA | cut -d " " -f2`
	PUNTO_MONTAJE=`echo $LINEA | cut -d " " -f3`
	mount -t nfs $IP_SERVIDOR:$DIRECTORIO_EXPORTADO $PUNTO_MONTAJE
	RETORNO=$?
	if [ $RETORNO -ne 0 ]
	then
		echo "Error al realizar montaje: echo $LINEA"
		exit $RETORNO
	fi
	#servidor:dir_exportado punto_de_montaje nfs defaults
	sed -i -e "\$a$IP_SERVIDOR:$DIRECTORIO_EXPORTADO $PUNTO_MONTAJE nfs defaults"  /etc/fstab #aniadimos al final del fichero fstab el nuevo montaje 
	
done


exit $RETORNO