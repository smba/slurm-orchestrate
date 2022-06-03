#!/bin/bash

# Pipe output and error log straight to /tmp
#SBATCH --output=/tmp/slurm_out.txt
#SBATCH --error=/tmp/slurm_err.txt

# TODO: turn off performance measurements
# TODO: either do oversubscribe or exclusive

TASKLIST=$1

RESULTS=/tmp/measurements.csv

for i in "$@"
do
case $i in

    -r=*|--repetitions=*)
    REPETITIONS="${i#*=}"
    shift
    ;;
    -p=*|--profiling=*)
    PROFILING="${i#*=}"
    shift
    ;;
    -s=*|--shared=*)
    SHARED="${i#*=}"
    shift
    ;;
    -a=*|--setup=*)
    SETUP_SCRIPT="${i#*=}"
    #cp -rf $SETUP_SCRIPT /tmp/setup_script.sh
    #chmod +x /tmp/setup_script.sh
    shift
    ;;
    -z=*|--teardown=*)
    TEARDOWN_SCRIPT="${i#*=}"
    #cp -rf $TEARDOWN_SCRIPT /tmp/teardown_script.sh
    #chmod +x /tmp/teardown_script.sh
    shift
    ;;
    *)
    # unknown option
    ;;
esac
done

# Parse i-th line from the task list
TASK_COMMAND=$(sed "${SLURM_ARRAY_TASK_ID}q;d" $TASKLIST)

# Write CSV header to $RESULTS
if [ $PROFILING = "on" ]; then
    echo "time,kernel-time,user-time,max-resident-set-size,avg-resident-set-size,avg-mem-use" >> $RESULTS
else
    :
fi

for i in `seq 1 $REPETITIONS`; do

   # run setup script
   bash $SETUP_SCRIPT

   if [ $PROFILING = "on" ]; then
       (~/slurm/tools/performance/time --format "%e,%S,%U,%M,%t,%K" --append --output="${RESULTS}" $TASK_COMMAND)
   else
       ($TASK_COMMAND)
   fi

   # run teardown script
   bash $TEARDOWN_SCRIPT

done

# Compress log files
xz -q -3 /tmp/slurm_out.txt
xz -q -3 /tmp/slurm_err.txt

# Move error logs to ~/slurm/tools/performance ...
mv /tmp/slurm_out.txt.xz "/u/$USER/slurm/tools/performance/output_logs/${SLURM_JOB_NAME}_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.txt.xz"
mv /tmp/slurm_err.txt.xz "/u/$USER/slurm/tools/performance/error_logs/${SLURM_JOB_NAME}_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.txt.xz"

# Move CSV to ~/slurm/performance/results/
if [ $PROFILING = "on" ]; then
    mv $RESULTS "/u/${USER}/slurm/tools/performance/results/${SLURM_JOB_NAME}_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.csv"
else
    :
fi

# Run tear-down script to clean up any system specific things
bash /tmp/teardown_script.sh

# Clean /tmp -- IMPORTANT (srsly) : only do this when the node is not shared  - this ma interfere with a) your jobs or b) other people's job on shared nodes...
if [ $SHARED = "on" ]; then
    rm -rf /tmp
else
    :
fi

#  Nuke the task in case it won't terminate
scancel "${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
