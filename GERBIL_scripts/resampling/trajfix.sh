#!/bin/bash

name="model"
candi=$1
res_num=500
HOMEDIR=$(pwd)

for c in $(seq 1 $candi) ; do

cd candi_${c}
cat << eof0 > ./trajfix.txt
parm   ./${name}.prmtop
trajin ./run_cluster.dcd 1 last 1
unwrap :1-$res_num
center :1-$res_num@CA mass origin
autoimage
strip :SOL,NA
trajout ./cluser_noPBC.xtc
go
eof0
cpptraj -i trajfix.txt
cd $HOMEDIR

done

