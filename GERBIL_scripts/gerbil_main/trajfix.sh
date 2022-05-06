#!/bin/bash

name=$1
candi=$2
cycle=$3
res_num=$4
HOMEDIR=$5

cat << eof0 > ./trajfix.txt
parm   $HOMEDIR/input/${name}.prmtop
trajin $HOMEDIR/candi${candi}/cyc${cycle}/amd.dcd 1 last 1
unwrap :1-$res_num
center :1-$res_num@CA mass origin
autoimage
trajout $HOMEDIR/candi${candi}/cyc${cycle}/amd_noPBC.xtc
rms first out $HOMEDIR/candi${candi}/cyc${cycle}/rmsd.dat @CA
go
eof0

cpptraj -i trajfix.txt

