#!/bin/bash
############ ******** Script Introduction  ********* ####################
#
# Brief: This script is for check top ten use cpu resource process
# Use command line like: $PATH/top_ten_processload_check.sh -t 10
# See the arg mean for use -h command
#
#########################################################################

THRESHOLD_VALUE=10
threshold_value=$THRESHOLD_VALUE

TOPTEN_INFO=`mktemp TopTenProcessInfo_temp.XXXXX`
ERROR_INFO="parameter format error,please entery a digit!"

temp=`getopt -o t:h -l threshold:,help -- "$@"`   
if [ $? != 0 ] ; then echo "terminating..." >&2 ; exit 1 ; fi

eval set -- "$temp"

# help info for args
help_info()
{
    echo "***** This is help info *****"
    echo -e "\t-h --help      is help info"
    echo -e "\t-t --threshold is the process load check threshold value"

    exit -1
}

# loop for command line arg
while true; do
    case "$1" in
        -t|--threshold)
            case "$2" in
                [a-zA-Z]*)
                    echo "Option 't' or 'threshold', ${ERROR_INFO}";
                    exit 1 ;;
                [0-9]*)
                    threshold_value=$2
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

#############################
#    Process load check     #
#############################

# Get TOP 10 use cpu load Process

# *** function start ***
# get Process Info
Process_load_status()
{
    Threshold_Value=$1
    k=1
    warning_count=0
    each_process_info_str=""
    process_info_str=""
    
    # get top ten process ID,process name,process cpu load
    process_topten_info=$(ps -aux | sort -k3nr | head -10 | awk '{print $2,$11,$3}')
    echo "${process_topten_info}" >> "$TOPTEN_INFO"

    # get process cpu load
    processLoad=$(sed -n "${k}p" ${TOPTEN_INFO} | awk '{print $3}')
    
    # judge Process load and Threshold_Value
    while [ "$k" -le 10 ]
    do
        judge=$(awk -v num1=${processLoad} -v num2=${Threshold_Value} 'BEGIN{print(num1>num2)? 1 : 0}')
        processInfo=$(sed -n "${k}p" ${TOPTEN_INFO})
        
        if [ ${judge} -eq 1 ]; then
            each_process_info_str="Process Warning: ${processInfo} uses more than ${Threshold_Value}%!!!\n"
            process_info_str="${process_info_str}${each_process_info_str}"
            let warning_count+=1
        else
        {
            each_process_info_str="Process OK: ${processInfo}.\n"
            process_info_str="${process_info_str}${each_process_info_str}"
        }
        fi
        
        k=$(($k+1))
        processLoad=$(sed -n "${k}p" ${TOPTEN_INFO} | awk '{print $3}')  
    done
     
    if [ ${warning_count} -eq 0 ]; then
    {
        echo "OK: Processes are all healthy!"
        echo -e $process_info_str
        return 0
    }
    elif [ ${warning_count} -ge 1 ] && [ ${warning_count} -le 6 ]; then
    {
        echo "WARNING: Have ${warning_count} processes unhealthy!"
        echo -e $process_info_str
        return 1
    }
    elif [ ${warning_count} -ge 7 ] && [ ${warning_count} -le 10 ]; then
    {
        echo "CRITICAL: Have ${warning_count} processes unhealthy!!"
        echo -e $process_info_str
        return 2
    }
    else
    {
        echo "UNKNOWN: please check!"
        echo -e $process_info_str
        return 3
    }
    fi

}
# *** function end ***

Rm_temp_file()
{
    if [ -a ${TOPTEN_INFO} ]; then
        rm ${TOPTEN_INFO}
    fi
}
#############################
#     Process load check    #
#############################

# step1 get Process_load and status info
Process_load_info=$(Process_load_status ${threshold_value})

Rm_temp_file

# get return value
ret=$?

# step2 echo to report file
echo "${Process_load_info}" >&1

exit $ret
