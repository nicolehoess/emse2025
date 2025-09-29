#! /bin/sh

project=$1
cores=$2

exec 3>&1 1>>>(tee "../log/${project}_benchmark.log") 2>&1

echo "Start:" `date -u`
start=`date +%s`

# Start codeface analysis
codeface -j $cores run \
         -c $HOME/codeface/codeface.conf \
         -p $HOME/codeface/conf/${project}_benchmark.conf \
         $HOME/res $HOME/git-repos &> /dev/fd/3 & # &>/dev/null &
codeface=$!

# # Monitor resource consumption
# collectl -i1:1 -sZ --procfilt P$! --procopts mct -P --sep 9 \
#          -f ../log/${project}_benchmark &>/dev/null &
# collectl=$!

printf 'Codeface running with PID %d...\n' $codeface
wait ${codeface}
# sudo kill ${collectl}

echo "End:" `date -u`
end=`date +%s`
d=$(($end-$start))
printf 'Time elapsed: %dd:%dh:%dm:%ds (%ds)\n' $((d/86400)) \
        $((d%86400/3600)) $((d%3600/60)) $((d%60)) $d
