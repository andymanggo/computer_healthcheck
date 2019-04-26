#!/bin/bash
############ ******** Script Introduction  ********* ####################
#
# Brief: This script is for check memroy load
# Use command line like: $PATH/memoryload_check.sh -o 40 -w 60 -c 90
# See the arg mean for use -h command
#
#########################################################################

# Input value
OK_VALUE=50
WAR_VALUE=70
CRI_VALUE=80


# If value not given, use default value.
mem_ok=$OK_VALUE
mem_warning=$WAR_VALUE
mem_critical=$CRI_VALUE

ERROR_INFO="parameter format error,please entery a digit!"

temp=`getopt -o o:w:c:h -l ok:,warning:,critical:,help -- "$@"`
if [ $? != 0 ] ; then echo "terminating..." >&2 ; exit 1 ; fi

eval set -- "$temp"

# help info for args
help_info()
{
    echo "***** This is help info *****"
    echo -e "\t-h --help     is help info"
    echo -e "\t-o --ok       is the memory ok threshold value"
    echo -e "\t-w --warning  is the memory warning threshold value"
    echo -e "\t-c --critical is the memory critical value"

    exit -1
}

# loop for command line arg
while true; do
    case "$1" in
        -o|--ok)
            case "$2" in
                [a-zA-Z]*)
                    echo "Option 'o' or 'ok', ${ERROR_INFO}";
                    exit 1 ;;
                [0-9]*)
                    mem_ok=$2
                    shift 2 ;;
            esac ;;

        -w|--warning)
            case "$2" in
                [a-zA-Z]*)
                    echo "Option 'w' or 'warning', ${ERROR_INFO}";
                    exit 1 ;;
                [0-9]*)
                    mem_warning=$2
                shift 2 ;;
            esac ;;

        -c|--critical)
            case "$2" in
                [a-zA-Z]*)
                    echo "Option 'c' or 'critical', ${ERROR_INFO}";
                    exit 1 ;;
                [0-9]*)
                    mem_critical=$2
                shift 2 ;;
            esac ;;

        -h|--help)
            help_info; exit; shift ;;
        --)
            shift
            break
            ;;
        *)
            echo "internal error!"
            exit 1 ;;
    esac
done

# This function for VM Memory load check

#############################
#     Memory load check     #
#############################

Mem_load_status()
{
    threshold_value_ok=$1
    threshold_value_warning=$2
    threshold_value_critical=$3

    # Change file path to get file Mem_Load.py
    MEM=$(python -c 'import os,sys; path=os.getcwd();os.chdir(path); import Mem_Load; print Mem_Load.mem_load()')

    total=$(echo ${MEM} | awk '{print $1}' | sed -e"s/[^0-9]//g")
    usage=$(echo ${MEM} | awk '{print $2}' | awk -F. '{print $1}')
    load=$(echo ${MEM} | awk '{print $3}' | awk -F] '{print $1}')

    # change KB to MB
    usage=`expr ${usage} / 1024`
    total=`expr ${total} / 1024`
    load=`echo ${load} | awk '{printf "%.2f", $0}'`

    str="Memory total:${total} MB; Memory used:${usage} MB; Memory load:${load}%"

    # judge the status and echo
    if [[ "$(echo "${load} <= ${threshold_value_ok}" | bc)" -eq 1 ]]; then
    {
        echo -e "OK: Load:${load}%;Memory usage under limit!"
        echo -e $str
        return 0
    }
    elif [[ "$(echo "${load} > ${threshold_value_ok}" | bc)" -eq 1 ]] && [[ "$(echo "${load} <= ${threshold_value_warning}" | bc)" -eq 1 ]]; then
    {
        echo -e "WARNING: Load:${load}%;Memory usage over limit!"
        echo -e $str
        return 1
    }
    elif [[ "$(echo "${load} > ${threshold_value_warning}" | bc)" -eq 1 ]] && [[ "$(echo "${load} <= ${threshold_value_critical}" | bc)" -eq 1 ]]; then
    {
        echo -e "CRITICAL: Load:${load}%;Memory load is critical!!"
        echo -e $str
        return 2
    }
    else
    {
        echo -e "UNKNOW: Load:${load}%; Memory status unknown!"
        echo -e $str
        return 3
    }
    fi
}

#############################
#     Memory load check     #
#############################


# step1 get Mem_load and status info
Mem_load_info=$(Mem_load_status ${mem_ok} ${mem_warning} ${mem_critical})

# get return value
ret=$?

# step2 echo to report file
echo "${Mem_load_info}" >&1


exit $ret