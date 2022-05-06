#!/bin/bash

name=$1
WDIR=$(pwd)

##########
# Define .conf file
##########

echo "Make .conf file for Production MD."

gmx_mpi trjconv -f $WDIR/npt.gro -s $WDIR/npt.gro -o $WDIR/${name}.pdb << EOF
0
EOF

X=$(sed -n 4,1p $WDIR/${name}.pdb | awk '{print $2 }')
Y=$(sed -n 4,1p $WDIR/${name}.pdb | awk '{print $3 }')
Z=$(sed -n 4,1p $WDIR/${name}.pdb | awk '{print $4 }')

cat << eof1 > $WDIR/run_cluster.conf
temperature         300
amber               yes
coordinates         $WDIR/${name}.pdb
parmfile            $WDIR/model.prmtop
numsteps            2500000
restartfreq         25000     ;# 50000 steps = every 100 ps (0.1 ns)
dcdfreq             2500
xstFreq             25000
outputEnergies      100     ;# 100 steps = every 0.2 ps
outputTiming        1000
exclude             scaled1-4
1-4scaling          1.0
switching           on
cutoff              12. ;# may use smaller, maybe 10., with PME
switchdist          10. ;# cutoff - 2.
pairlistdist        14. ;# cutoff + 2.
stepspercycle       10  
timestep            2.0  ;# 2fs/step
rigidBonds          all  ;# needed for 2fs steps
nonbondedFreq       1    ;# nonbonded forces every step
fullElectFrequency  2    ;# PME only every other step
# Constant Temperature Control
langevin            on            ;# langevin dynamics
langevinDamping     1.            ;# damping coefficient of 1/ps
langevinTemp        300           ;# random noise at this level
langevinHydrogen    no            ;# don't couple bath to hydrogens
cellBasisVector1    ${X} 0.0 0.0
cellBasisVector2    0.0 ${Y} 0.0
cellBasisVector3    0.0 0.0 ${Z}
cellOrigin          0.0 0.0 0.0 
seed                $RANDOM
wrapWater             on              ;# wrap water to central cell
wrapAll               on              ;# wrap other molecules too
wrapNearest           off             ;# use for non-rectangular cells
useGroupPressure      yes             ;# needed for rigid bonds
useFlexibleCell       no              ;# no for water box, yes for membrane
useConstantArea       no              ;# no for water box, maybe for membraneangevinTemp         300
PME                  yes
PMEGridSpacing       1.0
langevinPiston        on
langevinPistonTarget  1.01325        ;# pressure in bar -> 1 atm
langevinPistonPeriod  100.           ;# oscillation period around 100 fs
langevinPistonDecay   50.            ;# oscillation decay time of 50 fs
langevinPistonTemp    300            ;# coupled to heat bath
outputname            $WDIR/run_cluster.out
DCDfile               $WDIR/run_cluster.dcd
eof1
