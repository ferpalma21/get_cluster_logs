#!/bin/bash
# Autor: David Lladro 2017
# Dependences: sshpass

readonly PROGNAME=$(basename $0)
readonly PROGDIR=$(readlink -m $(dirname $0))
readonly ARGS="$@"
readonly NUM_ARGS="$#"

CFLAG=false
DFLAG=false
LFLAG=false
GFLAG=false
VFLAG=false
XFLAG=false

usage() {
    cat <<- EOF

    usage: $PROGNAME -c configfile options
    
    Este script descarga logs de los clusters y unifica los ficheros en funcion de su timestamp. 

    OPTIONS:
       -c --config              fichero de configuracion. (Obligatorio)
       -d --destination         destino de los ficheros (Obligatorio)
       -l --list                lista los sistemas de los que se pueden descargar los logs.
       -g --get                 se indica que logs queremos obtener separados por comas (Obligatorio)
       -v --verbose             Verbose. 
       -x --debug               debug
       -h --help                muestra este mensaje.

    
    Ejemplos:
       Run:
       $PROGNAME -c /root/get_cluster_logs.cfg -d /root/Descargas/ -g all
       $PROGNAME -c /root/get_cluster_logs.cfg -d /root/Descargas/ -g webA,webB
       $PROGNAME -c /root/get_cluster_logs.cfg -l
EOF

}

function log () {
    if [[ "$VFLAG" = true ]]; then
        echo "$@"
    fi
}

function log_error () {
	echo "[ERROR] - $@" >&2
}


cmdline() {
    local arg=
    for arg
    do
        local delim=""
        case "$arg" in
            #translate --gnu-long-options to -g (short options)
            --config)         args="${args}-c ";;
            --list)           args="${args}-l ";;
            --get)            args="${args}-g ";;
            --destination)    args="${args}-d ";;
            --help)           args="${args}-h ";;
            --verbose)        args="${args}-v ";;
            --debug)          args="${args}-x ";;
            #pass through anything else
            *) [[ "${arg:0:1}" == "-" ]] || delim="\""
                args="${args}${delim}${arg}${delim} ";;
        esac
    done

    #Reset the positional parameters to the short options
    eval set -- $args

    while getopts "d:c:g:lvhx" OPTION
    do
         case $OPTION in
         v)
             VFLAG=true
             ;;
         h)
             usage
             exit 0
             ;;
	 d)
             DFLAG=true
	     DESTINATION="$OPTARG"
	     ;;
         x)
	     XFLAG=true
	     ;;
         c)
	     CONFIG_FILE="$OPTARG"
	     CFLAG=true
             ;;
         g)
	     GFLAG=true
             GET_FILES="$OPTARG"
             ;;
         l)
             LFLAG=true
	     ;;
        esac
    done


    if ! $CFLAG 
    then
        log_error "La opcion -c o --config es obligatoria"
	exit 1
    fi

    if  [ ! -f $CONFIG_FILE ];
    then
	log_error "El fichero de configuración no existe"
	exit 1
    fi

    log "Cargando fichero de configuracion en $CONFIG_FILE"
    source "$CONFIG_FILE"

    if  $LFLAG 
    then
        list_servers
	exit 1
    fi

    if ! $DFLAG 
    then
        log_error "La opcion -d o --destination path es obligatoria"
	exit 1
    fi

    if [ ! -d "$DESTINATION" ]; 
    then
	log_error "El directorio de destino no existe."
	exit 1
    fi

    if  $XFLAG 
    then
        set -x
    fi


}

get_files (){

    if [ $GET_FILES = "all" ]; 
    then
	array=("${SISTEMAS[@]}") 
    else
        OIFS=$IFS
        IFS=', ' read -r -a array <<< "$GET_FILES"
        IFS=$OIFS
    fi
    
    read -p "Usuario: " usuario 
    read -s -p "Password: " SSHPASS
    eval "export SSHPASS='""$SSHPASS""'"


    for i in "${array[@]}"
    do
	echo
	echo "Descargando logs de $i..."
	echo
	sistema=${i}_sist
	logs=${i}_logs
	paths=${i}_path
    	sistemas=$sistema[@]
	rutas=$paths[@]
	ficheros=$logs[@]
	
	if [ ! -d $DESTINATION/$i ]; then
	mkdir $DESTINATION/$i
	fi


	#Descargamos los logs
	for sist in ${!sistemas}
	do
	    for ruta in ${!rutas}
	    do
	        for fich in ${!ficheros}
	        do  
		    expansion=$(echo "$fich*")
		    fich_antiguos=$(sshpass -e ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$usuario@$sist" ls $ruta/$expansion 2>/dev/null)
		    for arch in $fich_antiguos;
		    do
			archivo=$(echo $arch | awk -F"/" {'print $(NF)'})
		        echo "Descargando el fichero $i/$sist@$ruta/$archivo"		    
	                sshpass -e scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$usuario@$sist:$ruta/$archivo" "$DESTINATION/$i/$sist@$archivo" 
		    done
	        done
	    done
	done
    done
    
 
    eval "export SSHPASS='""""'"


}

fusion_files (){


    for i in "${array[@]}"
    do
    	logs=${i}_logs
        ficheros=$logs[@]

	#Fusionamos los logs en un fichero
	for fich in $(ls "$DESTINATION/$i/" | awk -F"@" {'print $2'} | sort | uniq)
       	do 
		expansion=$(echo "$DESTINATION/$i/*$fich")
		echo "Fusionando el fichero $fich de diferentes servidores"
		sort -S 50% -t ' ' -k 5.9,5.12n -k 5.5,5.7M -k 5.2,5.3n -k 5.14,5.21n -m $expansion -o "$DESTINATION/$i/$fich"
	done

	for fich in ${!ficheros}
	do
		#
		expansion=$(echo "$DESTINATION/$i/$fich*")
		echo "Fusionando el fichero $fich de diferentes dias"
		sort -S 50% -t ' ' -k 5.9,5.12n -k 5.5,5.7M -k 5.2,5.3n -k 5.14,5.21n -m $expansion -o "$DESTINATION/$i/sorted-$fich"
		expansion2=$(echo "$DESTINATION/$i/$fich*")
		rm $expansion2
		mv "$DESTINATION/$i/sorted-$fich" "$DESTINATION/$i/$fich"
	done
    done

}



list_servers (){

    for i in "${SISTEMAS[@]}"
    do
        echo -n "$i "
    done
    echo
}

main() {

    if [[ $NUM_ARGS -eq 0 ]] ;
    then
	usage
	exit 0
    fi
    cmdline $ARGS
    get_files
    fusion_files

}

main
