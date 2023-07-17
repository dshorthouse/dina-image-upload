#! /bin/bash

if [[ $1 == *"--"* ]]; then
    v="${1/--/}"
    declare $v="$2"
fi

source ~/miniconda3/etc/profile.d/conda.sh
conda activate dina

cd ~/dina-image-upload
line=$SGE_TASK_ID
output=`./upload_assets_worker.rb --paths_list_file $paths_list_file --line $line`

echo "$output" | tee -a upload_assets_output.csv  >/dev/null
