#! /bin/sh

project=$1
cores=$2

exec 3>&1 1>>>(tee "/home/codeface/codeface/log/${project}_conway.log") 2>&1

echo "Start:" `date -u`
start=`date +%s`

# Start codeface analysis
codeface -j $cores conway \
         -c /home/codeface/codeface/codeface.conf \
         -p /home/codeface/codeface/conf/${project}.conf \
         /home/codeface/res /home/codeface/git-repos /home/codeface/titan &> /dev/fd/3 &
codeface=$!

printf 'Analysing %s with Codeface using PID %d...\n' $project $codeface
wait ${codeface}

echo "End:" `date -u`
end=`date +%s`
d=$(($end-$start))
printf 'Time elapsed: %dd:%dh:%dm:%ds (%ds)\n' $((d/86400)) \
        $((d%86400/3600)) $((d%3600/60)) $((d%60)) $d
