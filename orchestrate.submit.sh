#!/bin/bash

# Fancy colors in the command line
LRED='\033[1;31m'
LGREEN='\033[1;32m'
LBLUE='\033[1;34m'
LCYAN='\033[1;36m'
NC='\033[0m' # No Color

HERE=$(pwd)

#=$3

for i in "$@"
do
case $i in
    -c=*|--cpus=*)
    CPUS_PER_TASK="${i#*=}"
    if [ $CPUS_PER_TASK = "" ]; then 
    	CPUS_PER_TASK=""
    else
    	CPUS_PER_TASK=--cpus-per-task=$(echo $CPUS_PER_TASK)
    fi
    shift
    ;;
    -k=*|--memcpu=*) # k for KB
    MEM_PER_CPU="${i#*=}"
    if [ $MEM_PER_CPU = "" ]; then
        MEM_PER_CPU=""
    else
        MEM_PER_CPU=--mem-per-cpu=$(echo $MEM_PER_CPU)
    fi
    shift
    ;;
    -n=*|--nodelist=*)
    NODELIST="${i#*=}"
    # TODO if nodelist is empty, do not specifyat all
    if [ $NODELIST = "" ]; then
    	NODELIST=""
    else
        NODELIST=--nodelist=$(echo $NODELIST)
    fi
    shift
    ;;
    # resources can either be /shared/ or /single/
    -s=*|--shared=*)
    RESOURCES="${i#*=}" 
    if [ $RESOURCES = "on" ]; then
        # Resource sharing is enabled. That means, multiple tasks ob this array job 
        # will be deployed simultaneously at the same node. We specify the following:
        
        RESOURCES_CMD="--oversubscribe"
    else
        RESOURCES_CMD="--exclusive"
    fi
    shift # past argument=value
    ;;
    -r=*|--repetitions=*)
    REPETITIONS="${i#*=}" 
    shift
    ;;
    -m=*|--profiling=*) # m for measurements...
    PROFILING="${i#*=}"
    shift
    ;;
    -j=*|--jobname=*)
    JOB_NAME="${i#*=}"
    shift
    ;;
    -t=*|--tasklist=*)
    TASKS="${i#*=}"
    shift
    ;;
    -p=*|--partition=*)
    PARTITION="${i#*=}"
    shift
    ;;
    -a=*|--setup=*)
    SETUP_SCRIPT="${i#*=}"
    chmod +x $SETUP_SCRIPT
    shift
    ;;
    -z=*|--teardown=*)
    TEARDOWN_SCRIPT="${i#*=}"
    chmod +x $TEARDOWN_SCRIPT
    shift
    ;;
    *)
    # unknown option
    ;;
esac
done


NTASKS=$(wc -l < "$TASKS")

mkdir -p output_logs
mkdir -p error_logs
mkdir -p results

echo -e "\nSubmitting array job ${LBLUE}«$JOB_NAME»${NC} with ${LBLUE}${NTASKS} tasks${NC} to partition(s) ${LBLUE}$PARTITION${NC}."

if [ $RESOURCES = "on" ]; then
    echo -e " - Resource sharing is ${LGREEN}$RESOURCES${NC} (on: use for compute jobs only; off: use for profiling jobs)"
else
    echo -e " - Resource sharing is ${LRED}$RESOURCES${NC} (on: use for compute jobs only; off: use for profiling jobs)"
fi

echo -e " - Number of repetitions per task is ${LBLUE}$REPETITIONS${NC}."

if [ $PROFILING = "on" ]; then
    echo -e " - Profiling with /usr/bin/time is ${LGREEN}$PROFILING${NC} (on: write measurements to home folder; off: don't do it)\n"
else
    echo -e " - Profiling with /usr/bin/time is ${LRED}$PROFILING${NC} (on: write measurements to home folder; off: don't do it)\n"
fi

sbatch $RESOURCES_CMD $MEM_PER_CPU $CPUS_PER_TASK --array=1-$NTASKS --partition=$PARTITION --job-name="${JOB_NAME}" task.sh $TASKS --profiling=$PROFILING --repetitions=$REPETITIONS --shared=$RESOURCES  --teardown=$TEARDOWN_SCRIPT --setup=$SETUP_SCRIPT
echo -e ""
