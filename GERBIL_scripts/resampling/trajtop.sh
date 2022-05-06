#!/bin/bash

name="model"
candi=$1
HOMEDIR=$(pwd)

for c in $(seq 1 $candi) ; do

cd candi_${c}
gmx_mpi trjconv -f em.gro -s em.gro -o em_nowater.gro << eof0
1
eof0
cd $HOMEDIR

done

