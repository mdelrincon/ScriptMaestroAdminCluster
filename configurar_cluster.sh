#!/bin/bash
# TIPOS DE RETORNO:
#					10-> Fichero configuracion no existe 
#					20-> Fallo de sintaxis en el fichero de configuracion adicional
#					99-> Fallo de que no exista algun parametro pasado necesario 

#set -x

RETORNO=0

iniciar(){
	FICHERO_A_COPIAR=$1
	MAQUINA_REMOTA=$2
	SERVICIO=$3
	echo "El servicio que se quiere realizar es el servicio $SERVICIO."
	echo "Copiamos el fichero de configuracion en la maquina destino."
	scp $FICHERO_A_COPIAR root@$MAQUINA_REMOTA:$FICHERO_A_COPIAR
	RETORNO_FUNCION=$?
	if [ $RETORNO_FUNCION -ne 0 ]
	then
		echo "No se ha podido copiar el fichero $FICHERO_A_COPIAR en la maquina $MAQUINA_REMOTA."
		RETORNO_FUNCION=99
		exit $RETORNO_FUNCION
	fi
	echo "Una vez copiado el fichero de configuracion, ejecutamos el servicio $SERVICIO."
	if [ "$SERVICIO" = "nfs_server" ]
	then
		#Si el servicio es nfs_server le pasamos la ip como parametro para que la añada al fichero /etc/exports
		echo entra
		ssh -x root@$MAQUINA_REMOTA "bash -s" -- < servicio_$SERVICIO.sh "$FICHERO_A_COPIAR" "$MAQUINA_REMOTA"
		RETORNO_FUNCION=$?
	else	
		ssh -x root@$MAQUINA_REMOTA "bash -s" -- < servicio_$SERVICIO.sh "$FICHERO_A_COPIAR" 
		RETORNO_FUNCION=$?
	fi
	echo "Tras terminar el servicio $SERVICIO, borramos el fichero de configuracion que hemos copiado"
	ssh root@$MAQUINA_REMOTA rm $FICHERO_A_COPIAR
	return $RETORNO_FUNCION
}


echo "Iniciamos el script configurar_cluster.sh"
echo "Primero comprobamos que se haya pasado el fichero de configuracion"

if [ $# = 1 ]
then
	FICHERO_CONFIGURACION=$1 export FICHERO_CONFIGURACION
	echo "Fichero de configuracion pasado por parametro"
	
else
	RETORNO=20
	echo "ERROR $RETORNO: N.de parametros incorrectos en llamada a configurar_cluster.sh"
fi

echo "Procedemos a leerlo"

if [ ! -s $FICHERO_CONFIGURACION ]
then
	echo "El fichero de configuracion  no existe o no contiene datos"
	exit 10
fi


LINEAS=`cat $FICHERO_CONFIGURACION | wc -l`
CONTADOR=1

if [ $RETORNO -eq 0 ]
then
	while  [ $LINEAS -ne 0 ] && [ $RETORNO -eq 0 ]
	do
		LINEA=`cat $FICHERO_CONFIGURACION | head -n $CONTADOR | tail -n 1`
		PRIMER_CARACTER=`echo $LINEA | cut -c1`
		let CONTADOR=CONTADOR+1
		let LINEAS=LINEAS-1
		echo $LINEA
		if [ "$LINEA" = '' ] || [ "$PRIMER_CARACTER" = '#' ]
		then 
			continue
		else
			MAQUINA_DESTINO=`echo $LINEA | cut -d" " -f1`
			SERVICIO=`echo $LINEA | cut -d" " -f2`
			FICHERO_ADICIONAL=`echo $LINEA | cut -d" " -f3` export FICHERO_ADICIONAL		
			#comprobamos que hayan pasado bien los parametros 
			if [ "$MAQUINA_DESTINO" = "" ] || [ "$SERVICIO" = "" ] || [ "$FICHERO_ADICIONAL" = "" ] || [ "$SERVICIO" = "$FICHERO_ADICIONAL" ]
			then
				echo "Linea del fichero de configuracion: $MAQUINA_DESTINO $SERVICIO $FICHERO_ADICIONAL"
				echo "Error de sintaxis en el fichero de configuracion: debe ser maquina-destino nombre-del-servicio fichero-de-perfil-de-servicio" 
				RETORNO=99
				exit $RETORNO
			else	
				#comprueba servicios
				##inicio servicio mount 
				if [ "$SERVICIO" = "mount" ] || [ "$SERVICIO" = "raid" ] || [ "$SERVICIO"="lvm" ] || ["$SERVICIO"="backup_server"] || ["$SERVICIO"="backup_client"] || ["$SERVICIO"="nis_client"] || ["$SERVICIO"="nis_server"] || ["$SERVICIO"="nfs_client"] || ["$SERVICIO"="nfs_server"]
				then
					iniciar $FICHERO_ADICIONAL $MAQUINA_DESTINO $SERVICIO
					RETORNO=$?
				else
					echo "No existe el servicio "$SERVICIO
					RETORNO=99
				fi #fin comprobacion de servicios 	
			fi #mira si se han pasado bien los parametros en el fichero de configuracion 
		fi #mira si estan vacias o son comentarios
	done 
fi

exit $RETORNO
