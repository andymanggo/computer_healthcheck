#!/bin/bash
############ ******** Script Introduction  ********* ###############
#
# Brief: This script is for check cpu load
# Use command line like: $PATH/cpuload_check.sh -o 10 -w 50 -c 90
# See the arg mean for use -h command
#
####################################################################

# Health check plugin and temp file path
# pre-config
CPU_INFO=/proc/stat

# Use of each cpu core
USE_CPUS=/boot/grub/grub.cfg

# creat temp file to save cpu info
START_INFO=`mktemp start_cpuinfo_temp.XXXXX`
END_INFO=`mktemp end_cpuinfo_temp.XXXXX`

ERROR_INFO="parameter format error,please entery a digit!"

# cpu info get interval arg
interval=1

OK_VALUE=15
WAR_VALUE=30
CRI_VALUE=60
# config end

# If value not given, use default value.
cpu_ok=$OK_VALUE
cpu_warning=$WAR_VALUE
cpu_critical=$CRI_VALUE


temp=`getopt -o o:w:c:h -l ok:,warning:,critical:,help  -- "$@"`
if [ $? != 0 ] ; then echo "terminating..." >&2 ; exit 1 ; fi

eval set -- "$temp"

# help info for args
help_info()
{
    echo "***** This is help info *****"
    echo  -e "\t-h --help     is help info"
    echo  -e "\t-o --ok       is the cpu ok threshold value"
    echo  -e "\t-w --warning  is the cpu warning threshold value"
    echo  -e "\t-c --critical is the cpu critical value"

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
                    cpu_ok=$2
                    shift 2 ;;
            esac ;;

        -w|--warning)
            case "$2" in
                [a-zA-Z]*) 
                    echo "Option 'w' or 'warning', ${ERROR_INFO}";
                    exit 1 ;;
                [0-9]*)
                    cpu_warning=$2
                    shift 2 ;;
            esac ;;

        -c|--critical)
            case "$2" in
                [a-zA-Z]*) 
                    echo "Option 'c' or 'critical', ${ERROR_INFO}";
                    exit 1 ;;
                [0-9]*)
                    cpu_critical=$2
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
#       CPU load check      #
#############################

cpu_num=`cat ${CPU_INFO} | grep cpu[0-9] -c`
cpu_load=()
sting_load=()
use_cpu=()
special_core=()


# function Get_Percore_cpuload: Average_load and per-core cpu load
# @parameter in:arg1,interval; arg2,cpu_num
Get_Percore_cpuload()
{
    interval_arg=$1
    num=$2

    #get proc/stat info
    echo "$(cat ${CPU_INFO} | grep "cpu" | awk '{print $2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "$10" "$11}')" >> "${START_INFO}"
    sleep ${interval_arg}
    echo "$(cat ${CPU_INFO} | grep "cpu" | awk '{print $2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "$10" "$11}')" >> "${END_INFO}"

    #loop for get average and per-core load
    for((i=1;i<=(${num} + 1);i++));
    do
        index=`expr ${i} - 1`
        #start info
        start_core=$(sed -n "${i}p" ${START_INFO} | awk '{print $1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "$10 }')
        start_core_usage[${index}]=$(echo ${start_core} | awk '{printf "%.f",$1+$2+$3+$5+$6+$7}')
        start_core_total[${index}]=$(echo ${start_core} | awk '{printf "%.f",$1+$2+$3+$4+$5+$6+$7+$8+$9+$10}')

        #end_info
        end_core=$(sed -n "${i}p" ${END_INFO} | awk '{print $1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "$10 }')
        end_core_usage[${index}]=$(echo ${end_core} | awk '{printf "%.f",$1+$2+$3+$5+$6+$7}')
        end_core_total[${index}]=$(echo ${end_core} | awk '{printf "%.f",$1+$2+$3+$4+$5+$6+$7+$8+$9+$10}')

        #calculate usage and total
        usage=`expr ${end_core_usage[${index}]} - ${start_core_usage[${index}]}`
        total=`expr ${end_core_total[${index}]} - ${start_core_total[${index}]}`
        #calculate cpu_load
        usage_normal=`expr ${usage} \* 100`
        cpu_load[${index}]=`echo "scale=2;${usage_normal}/${total}" | bc | awk '{printf "%.2f", $0}'`
    done
    echo ${cpu_load[*]}
}

# function: judge core's use, special use or not
# @parameter out: core's use status
Special_use_core()
{
    # get isolcpus string from path "USE_CPUS"
    special_use=$(awk '{if(match($0,".*isolcpus=([^; ]*)",a))print a[1]}' ${USE_CPUS} | sed -e"s/[^0-9]//g")

    # init array use_cpu
    for((i=0;i<${cpu_num};i++));
    do
        use_cpu[${i}]=0
    done

    # write special_use core to use_cpu array
    len=${#special_use}
    for((k=0;k<${len};k++));
    do
        m=`expr ${k} + 1`
        special_core[${k}]=$(echo ${special_use} | cut -b ${m})
        use_cpu[${special_core[${k}]}]=1
    done
    echo ${use_cpu[*]}
}

# function : split joint load to string
# @parameter in: cpu_load
# @parameter out: load string
Split_Load_To_String()
{
    #input parameter
    local load=($1)

    # loop split
    for((i=1;i<=${cpu_num};i++));
    do
        num=`expr ${i} - 1`
        sting_load[${num}]="cpu$[${num}],Load:"${load[i]}"%;"
    done
    echo ${sting_load[*]}
}

# function Check_Status: check cpu status and print to file
# @parameter in:arg1,cpu_load; arg2,threshold value
CPU_load_status()
{
    #count of status
    OK_count=0
    WARNING_count=0
    CRITICAL_count=0
    SPECIAL_use_count=0
    UNKNOW_count=0

    #input parameter
    local load=($1)
    local use=($2)
    threshold_value_ok=$3
    threshold_value_warning=$4
    threshold_value_critical=$5
    overview_str=""
    each_core_str=""

    # per-core status check and print to log
    for((i=0;i<=${cpu_num};i++))
    {
        # average load
        if [[ ${i} -eq 0 ]]; then
        {
            each_core_str="CPU_AverageLoad:${load[$i]}\n"
            overview_str="${overview_str}${each_core_str}"
        }
        # each core's load
        else
        {
            core_num=`expr ${i} - 1`
            if [[ "$(echo "${load[$i]} <= ${threshold_value_ok}" | bc)" -eq 1 ]]; then
            {
                let OK_count+=1
                each_core_str="CPU${core_num}:OK;Load:${load[$i]}\n"
                overview_str="${overview_str}${each_core_str}"
            }
            elif [[ "$(echo "${load[$i]} > ${threshold_value_ok}" | bc)" -eq 1 ]] && [[ "$(echo "${load[$i]} <= ${threshold_value_warning}" | bc)" -eq 1 ]]; then
            {
                let WARNING_count+=1
                each_core_str="CPU${core_num}:WARNING;Load:${load[$i]}\n"
                overview_str="${overview_str}${each_core_str}"
            }
            elif [[ "$(echo "${load[$i]} > ${threshold_value_warning}" | bc)" -eq 1 ]] && [[ "$(echo "${load[$i]} <= ${threshold_value_critical}" | bc)" -eq 1 ]] && [[ ${use[${core_num}]} -eq 0 ]]; then
            {
                let CRITICAL_count+=1
                each_core_str="CPU${core_num}:CRITICAL;Load:${load[$i]}\n"
                overview_str="${overview_str}${each_core_str}"
            }
            elif [[ ${use[${core_num}]} -eq 1 ]]; then
            {
                let SPECIAL_use_count+=1
                each_core_str="CPU${core_num}:SPECIAL_USE!;Load:${load[$i]}\n"
                overview_str="${overview_str}${each_core_str}"
            }
            else
            {
                let UNKNOW_count+=1
                each_core_str="CPU${core_num}:UNKNOW;Load:${load[$i]}\n"
                overview_str="${overview_str}${each_core_str}"
            }
            fi
        }
        fi
    }
    
    each_core_str="Core_Overview:OK_Core:${OK_count}; WARNING_Core:${WARNING_count}; CRITICAL_Core:${CRITICAL_count}; SPECIAL_USE_Core:${SPECIAL_use_count}; UNKNOW_Core:${UNKNOW_count}"
    overview_str="${overview_str}${each_core_str}"

    # judge output status and print to log
    rest_core=`expr ${cpu_num} - ${SPECIAL_use_count}`
    if [[ "${OK_count}" -eq "${rest_core}" ]]; then
    {
        echo "OK: CPU usage under limit! $(Split_Load_To_String "${load[*]}")"
        echo -e $overview_str
        return 0
    }
    elif [[ "${WARNING_count}" -gt 0 ]]; then
    {
        echo "WARNING: CPU unhealth, has ${WARNING_count} warning core! $(Split_Load_To_String "${load[*]}")"
        echo -e $overview_str
        return 1
    }
    elif [[ "${CRITICAL_count}" -gt 0 ]]; then
    {
        echo "CRITICAL: CPU unhealth, has ${CRITICAL_count} critical core!! $(Split_Load_To_String "${load[*]}")"
        echo -e $overview_str
        return 2
    }
    else
    {
        echo "UNKNOWN: CPU status is UNKNOWN, please check!!"
        echo -e $overview_str
        return 3
    }
    fi

}

#remove temp files
Rm_temp_file()
{
    if [ -a ${START_INFO} ]; then
        rm ${START_INFO}
    fi

    if [ -a ${END_INFO} ]; then
        rm ${END_INFO}
    fi
}

#############################
#      CPU load check       #
#############################

# step1 get_cpu_load
rate=(`Get_Percore_cpuload ${interval} ${cpu_num}`)

# step2 get use of core
core_use=(`Special_use_core`)

# step3 check_status
CPU_load_info=$(CPU_load_status "${rate[*]}" "${core_use[*]}" ${cpu_ok} ${cpu_warning} ${cpu_critical})
# get return value
ret=$?

# step4
echo "${CPU_load_info}" >&1

# remove temp file
Rm_temp_file


exit $ret

