#!/bin/bash
# TIPOS DE RETORNO:
#20-> Fallo de sintaxis en el fichero de configuracion adicional
#30-> Fallo de configuracion incompleta en el fichero de configuracion adicional
#40-> El directorio no esta vacio
# sh que realiza el servicio servidor BackUp


#set -x

RETORNO=0

FICHERO_ADICIONAL=$1 #cogemos el fichero adicional 

#como hemos copiado el fichero de configuracion en Escritorio accedemos a el
#cd /home/ubuntu/Escritorio

echo "Comprobamos que el fichero de configuracion sea correcto sintacticamente"

LINEAS=`cat $FICHERO_ADICIONAL | wc -l`
DIRECTORIO=`cat $FICHERO_ADICIONAL | head -n 1`
VALOR=`cat $FICHERO_ADICIONAL | wc -w`

#Detectamos si el fichero de configuración solo tiene una linea
	if [ $LINEAS -ne 1 ]
	then
		echo -e "Error por configuración incompleta, el fichero de configuración del servicio servidor backup debe contener una linea y su contenido debe ser:\n\tdirectorio-donde-se-realiza-el-backup\n\t" 
		RETORNO=30
		exit $RETORNO
	fi
#Detectamos si el fichero de configuración solo tiene un valor
	if [ $VALOR -ne 1 ]
	then
		echo -e "Error por configuración incompleta, el servicio servidor backup debe contener un unico valor.\n\t" 
		RETORNO=30
		exit $RETORNO
	fi

echo "Comprobamos que exista el directorio"
	
#Comprobamos si existe el directorio o no
	if [ -d "$DIRECTORIO" ]
	then
		if [ "$(ls $DIRECTORIO)" ]
		then
			echo -e "Error por configuración incompleta, el servicio backup debe recibir un directorio vacio.\n\t" 
			RETORNO=40
			exit $RETORNO
		fi
	else
		echo "Si no existe lo creamos"
   		mkdir $DIRECTORIO
		RETORNO=$?
		if [ $RETORNO -ne 0 ]
		then
			echo "Error al crear el directorio"
			exit $RETORNO
		else
			echo "Todo se realizó correctamente."
		fi
	fi

exit $RETORNO






