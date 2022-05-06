#!/bin/bash

num=$1
pre="amber14sb.ff/forcefield.itp"
post="/work/LSC/ryuhei/software/gmxgpu-2019.6_serial/share/gromacs/top/amber14sb.ff/forcefield.itp"

sed -e "s%${pre}%${post}%g" ./${num}.top > ./${num}_fixed.top
