#!/bin/bash

HOMEDIR=$(pwd)
NUM_OF_CANDIDATES=$1
OMP=24

cat << eof0 > ./qsub.sh
#!/bin/bash
#------- qsub option -----------
#PBS -A LSC
#PBS -q gpu
#PBS -N CLUSTER_candi\${PBS_SUBREQNO}
#PBS -l elapstim_req=05:00:00
#PBS -v OMP_NUM_THREADS=${OMP}
#------- Program execution -----------
cd ${HOMEDIR}
mkdir candi_\${PBS_SUBREQNO}
cd candi_\${PBS_SUBREQNO}
/work/LSC/ryuhei/software/gmxgpu-2019.6_serial/bin/gmx pdb2gmx -f ${HOMEDIR}/structure/\${PBS_SUBREQNO}_nowater.pdb -o ./\${PBS_SUBREQNO}.gro -water tip3p -ff amber14sb -p ./\${PBS_SUBREQNO}.top -ignh
/work/LSC/ryuhei/software/gmxgpu-2019.6_serial/bin/gmx editconf -f ./\${PBS_SUBREQNO}.gro -o ./\${PBS_SUBREQNO}_nebox.gro -c -d 1.5 -bt cubic
/work/LSC/ryuhei/software/gmxgpu-2019.6_serial/bin/gmx solvate -cp ./\${PBS_SUBREQNO}_nebox.gro -cs ./spc216.gro -o ./\${PBS_SUBREQNO}_solv.gro -p ./\${PBS_SUBREQNO}.top
/work/LSC/ryuhei/software/gmxgpu-2019.6_serial/bin/gmx grompp -maxwarn 1 -f ${HOMEDIR}/ions.mdp -c ./\${PBS_SUBREQNO}_solv.gro -p ./\${PBS_SUBREQNO}.top -o ./ions.tpr
/work/LSC/ryuhei/software/gmxgpu-2019.6_serial/bin/gmx genion -s ./ions.tpr -o ./\${PBS_SUBREQNO}_solv_ions.gro -p ./\${PBS_SUBREQNO}.top -pname NA -np 0 -nname CL -nn 0 -neutral << EOF
13
EOF
/work/LSC/ryuhei/software/gmxgpu-2019.6_serial/bin/gmx grompp -f ${HOMEDIR}/min.mdp -c ./\${PBS_SUBREQNO}_solv_ions.gro -p ./\${PBS_SUBREQNO}.top -o ./em.tpr 
/work/LSC/ryuhei/software/gmxgpu-2019.6/bin/gmx_mpi mdrun -v -deffnm ./em
/work/LSC/ryuhei/software/gmxgpu-2019.6_serial/bin/gmx grompp -maxwarn 1 -f ${HOMEDIR}/nvt.mdp -c ./em.gro -p ./\${PBS_SUBREQNO}.top -o nvt.tpr -r ./em.gro
/work/LSC/ryuhei/software/gmxgpu-2019.6/bin/gmx_mpi mdrun -deffnm nvt -ntomp ${OMP} -v -cpo nvt.cpt
/work/LSC/ryuhei/software/gmxgpu-2019.6_serial/bin/gmx grompp -f ${HOMEDIR}/npt.mdp -c nvt.gro -t nvt.cpt -p \${PBS_SUBREQNO}.top -o npt.tpr -r nvt.gro
/work/LSC/ryuhei/software/gmxgpu-2019.6/bin/gmx_mpi mdrun -deffnm npt -ntomp ${OMP} -v -cpo npt.cpt
$HOMEDIR/replace.sh \${PBS_SUBREQNO}
conda activate base
python $HOMEDIR/convert.py \${PBS_SUBREQNO}
$HOMEDIR/make_conf.sh \${PBS_SUBREQNO}
/work/LSC/y4su_da/software/NAMD_3.0alpha7_Linux-x86_64-netlrts-smp-CUDA/namd3 +auto-provision +devicesperreplica 0,1,2,3 run_cluster.conf > ./run_cluster.log
eof0
  qsub -t 1-${NUM_OF_CANDIDATES} qsub.sh
