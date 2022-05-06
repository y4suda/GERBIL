#!/bin/bash
if [ -z "$1" ]
then
   echo ""
   echo " This script control GERBIL ( G-factor-based external bias limiter)"
   ESC=$(printf '\033')
   echo "${ESC}[31m :Usage ./$( basename $0 ) thresh_ini thresh_delta b_min b_max candi total_calculation_time(ns) ${ESC}[m"
   echo " Thresh_ini usually set V_avg provided by 10 ns conventional MD."
   echo ""
   exit
fi

thresh_ini=$1       #initial values of thresh (the average of 100 ns conventional MD)
thresh_delta=$2     #how strong boost per cycle
b_min=$3            #the values of b min (default value = 0.1)
b_max=$4            #the values of b max (default value = 1.0)
CANDI=$5            #the number of candidates (default value = 5)
t_total=$6        #the total calcualtion time (defaul value = 1000 ns)
t_sim=$(($t_total/$CANDI)) #(default value = 200)
b_delta=`echo "scale=2; ($b_max-$b_min)/($CANDI-1)" | bc`

echo " Total calculation time is $t_total and num of candi is $CANDI"
echo " Therefore, each cycle calcurate $t_sim ns ($(($t_sim/10)) cycle * 10 ns)"

echo " thresh_ini = ${thresh_ini}, b_min = ${b_min} , b_max = ${b_max}"

for candi in $(seq 1 $CANDI) ; do
       B=`echo "scale=2; ($b_min+$b_delta*($candi-1))" | bc`
       echo " candi$candi : The value of b is $B"
       nohup ./run_candi.sh $thresh_ini $thresh_delta $B $candi $t_sim > out_$candi.log +&
       echo "./run_candi.sh $thresh_ini $thresh_delta $B $candi $t_sim"
done
