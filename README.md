# get_cluster_logs
Get logs from all machines within a cluster, it orders and fusion them


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
