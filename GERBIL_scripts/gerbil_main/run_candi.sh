#!/bin/bash

if [ -z "$1" ]
then
   echo ""
   echo " This is the main script of GERBIL ( G-factor-based external bias limiter )"
   echo ""
   exit
fi

#write the informations of system before calculation
res_num=271
name=model
atoms=58105 #(total number of system including water)

#Set run control variables################
RUNID="$(cat /dev/urandom | base64 | tr -dc "A-Z" | fold -w 5 | head -n 1)"
HOMEDIR=$(pwd)
GMX_MPI=/work/LSC/ryuhei/software/gmxgpu-2019.6/bin/gmx_mpi
OMP_NUM_THREADS=24
OMP=24
thresh_ini=$1
thresh_delta=$2
b=`echo "scale=3; $3*$atoms" | bc`
candi=$4            
t_total=$5       
gfactor_thresh=`echo "scale=3; -0.6 " | bc`            
mkdir ./candi$candi
cd    ./candi$candi
WDIR=$(pwd)

#SET CALCULATION TIME ####################
calc_time=10
step=`echo "scale=0; $calc_time*500000"| bc`
step=`printf "%.0f" $step`
CYCLE=`echo "scale=0; $(($t_total/$calc_time))" | bc`
echo $CYCLE

#PROGTAM MAIN ############################# 

for curr_cycle in $(seq 1 $CYCLE) ; do
    mkdir $WDIR/cyc${curr_cycle}
    cd $WDIR/cyc${curr_cycle}
 
    if [ $curr_cycle -eq 1 ] ; then
    	curr_thresh=$thresh_ini 

    elif [ -f $WDIR/cyc$(($curr_cycle-1))/continue.txt ];then
          cat $WDIR/cyc$(($curr_cycle-1))/thresh.txt > $WDIR/cyc${curr_cycle}/continue.txt
	  curr_thresh=$( cat $WDIR/cyc$(($curr_cycle-1))/continue.txt)
    else
	safety_cycle=$(($curr_cycle-1))
	curr_thresh=$(($( cat ../cyc$(($safety_cycle))/thresh.txt)+$thresh_delta))
	while [[  -f $WDIR/cyc$safety_cycle/break.txt ]];do
		safety_cycle=$(($safety_cycle-1))
		curr_thresh=$( cat ../cyc$(($safety_cycle))/thresh.txt)
 		if [ $safety_cycle -lt 1 ];then
			curr_thresh=$thresh_ini
			break
		fi
	done
    fi

cat << eof1 > $WDIR/cyc${curr_cycle}/thresh.txt
$curr_thresh
eof1

X=$(sed -n 1,1p $HOMEDIR/input/${name}.pdb | awk '{print $2 }')
Y=$(sed -n 1,1p $HOMEDIR/input/${name}.pdb | awk '{print $3 }')
Z=$(sed -n 1,1p $HOMEDIR/input/${name}.pdb | awk '{print $4 }')

echo $X,$Y,$Z

cat << eof0 > $WDIR/cyc${curr_cycle}/amd.conf
temperature         300
amber               yes
coordinates         $HOMEDIR/input/${name}.pdb
parmfile            $HOMEDIR/input/${name}.prmtop
numsteps            $step
restartfreq         50000     ;# 50000 steps = every 100 ps (0.1 ns)
dcdfreq             50000
xstFreq             50000
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
useConstantArea       no     	      ;# no for water box, maybe for membraneangevinTemp         300
PME                  yes
PMEGridSpacing       1.0
langevinPiston        on
langevinPistonTarget  1.01325        ;# pressure in bar -> 1 atm
langevinPistonPeriod  100.           ;# oscillation period around 100 fs
langevinPistonDecay   50.            ;# oscillation decay time of 50 fs
langevinPistonTemp    300	     ;# coupled to heat bath
outputname            ./amd.out
DCDfile               ./amd.dcd
accelMD              on
accelMDdihe          off
accelMDE             $curr_thresh
accelMDalpha         $b
eof0

  cat << eof0 > ./qsub.sh
#!/bin/bash
#------- qsub option -----------
#PBS -A LSC
#PBS -q gpu
#PBS -N APEX_CANDI${candi}_CYC${curr_cycle}
#PBS -l elapstim_req=03:30:00
#PBS -v OMP_NUM_THREADS=24
#------- Program execution -----------
cd $WDIR/cyc${curr_cycle}
/work/LSC/y4su_da/software/NAMD_3.0alpha7_Linux-x86_64-netlrts-smp-CUDA/namd3 +auto-provision +devicesperreplica 0,1,2,3 amd.conf > ./amd.log
eof0
   #Start Calculation (aMD)
   qsub qsub.sh
   sleep 60

    #Waiting the trajectory
    while [[ $(qstat -l | grep "APEX_CANDI${candi}_CYC${curr_cycle}" | wc -l) -gt 0 ]] ; do
      sleep 60
    done
    echo "All candicates are ready."

   if [ ! -f $WDIR/cyc${curr_cycle}/amd.dcd ];then
	cat $WDIR/cyc$(($curr_cycle-1))/thresh.txt > $WDIR/cyc${curr_cycle}/continue.txt
   fi 
   #Calculate RMSD and noPBC
   cd $WDIR/cyc${curr_cycle}
   $HOMEDIR/trajfix.sh ${name} ${candi} ${curr_cycle} ${res_num} ${HOMEDIR}

   #Convert XTC to PDB and Calcurate G-factor
   mkdir ./gfactor_check
   cd ./gfactor_check
   for timestep in $(seq 0 99);do
	$GMX_MPI trjconv -f $WDIR/cyc${curr_cycle}/amd_noPBC.xtc -s $HOMEDIR/input/em.gro -o ${timestep}.pdb -dump ${timestep} << eof0
	1
eof0
	/work/LSC/ryuhei/software/PROCHECK/procheck/procheck.scr ${timestep}.pdb 2.0   
	cat ${timestep}.sum | grep  G-factors |  awk '{print $4}' > Gfactor_${timestep}.txt
	rm ./${timestep}.*
   	rm *.ps
   done

   #Calcurate G-factor Average
   cat Gfactor_*.txt > Gfactor_all.txt
   cat Gfactor_all.txt | awk '{m+=$1} END{print m/NR;}' > Gfactor_avg.txt 

   #Check G-factor 
   Gfactor_avg=`echo "scale=3; $(cat Gfactor_avg.txt) " | bc`
   if [ $(echo "$Gfactor_avg < $gfactor_thresh" | bc) == 1 ];then
	echo $curr_cycle > $WDIR/cyc${curr_cycle}/break.txt
   fi

done
echo "GERBIL has done."
