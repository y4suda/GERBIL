#!/bin/bash

FIRST=1
LAST=200
curre="./resampling/initial_structures"

for num in $(seq $FIRST $LAST) ; do
gmx_mpi trjconv -f $curre/${num}.gro -s $curre/${num}.gro -o $curre/${num}_nowater.pdb <<eof0
1
eof0
done
