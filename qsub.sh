#! /bin/bash

source ~/miniconda3/bin/activate
conda activate dina

cd ~/dina-image-upload

while [ $# -gt 0 ]; do
   if [[ $1 == *"--"* ]]; then
        v="${1/--/}"
        declare $v="$2"
   fi
  shift
done

while IFS=",", read -r id directory
do
  if (( $id == $SGE_TASK_ID )); then
    output=`./worker.rb --directory "$directory"`
    if [[ "$output" == *"ERROR"* ]]; then
      echo "$output" | tee -a $error >/dev/null
    else
      echo "$output" | tee -a $log  >/dev/null
    fi
    break
  fi
done < $input
