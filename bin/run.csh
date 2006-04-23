#!/bin/csh
# CVS: $Id: run.csh,v 1.84 2006-04-23 17:41:11 theine Exp $

#                       run.csh
#                      ---------
#   Run src/run.x (timestepping for src/run.x).
#   Run parameters are set in run.in.
#
# Run this script with csh:
#PBS -S /bin/csh
#PBS -r n
#$ -S /bin/csh
#@$-s /bin/csh
#
# Work in submit directory (SGE):
#$ -cwd

# Work in submit directory (PBS):
if ($?PBS_O_WORKDIR) then
  cd $PBS_O_WORKDIR
endif

# Work in submit directory (SUPER-UX's nqs):
if ($?QSUB_WORKDIR) then
  cd $QSUB_WORKDIR
endif

# Work in submit directory (IBM Loadleveler):
if ($?LOADL_STEP_INITDIR) then
  cd $LOADL_STEP_INITDIR
endif

# ====================================================================== #
# Starting points when rerunning in new directory.
# This needs to come *before* "source getconf.csh", because
#  (i) it checks for LOCK file, and
# (ii) it sets $datadir/directory_snap
newdir:

# Common setup for start.csh, run.csh, start_run.csh:
# Determine whether this is MPI, how many CPUS etc.
source getconf.csh

#
#  If necessary, distribute var.dat from the server to the various nodes
#
if ($local_disc) then
  if ($one_local_disc) then	# one common local disc
    foreach node ($nodelist)
      foreach d (`cd $datadir; ls -d proc* allprocs`)
        $SCP $datadir/$d/var.dat ${node}:$SCRATCH_DIR/$d/
        if ($lparticles) $SCP $datadir/$d/pvar.dat ${node}:$SCRATCH_DIR/$d/
        $SCP $datadir/$d/timeavg.dat ${node}:$SCRATCH_DIR/$d/
      end
      if (-e $datadir/allprocs/dxyz.dat) $SCP $datadir/allprocs/dxyz.dat ${node}:$SCRATCH_DIR/allprocs
    end
  else # one local disc per MPI process (Horseshoe, etc);
       # still doesn't cover Copson
    set i = -1
    foreach node ($nodelist)
      set i=`expr $i + 1`
      echo "i = $i"
      set j = 0
      while ($j != $nprocpernode)
        set k = `expr $nprocpernode \* $i + $j`
        if ($?notserial_procN) set k = `expr $i + $nnodes \* $j`
        $SCP $datadir/proc$k/var.dat ${node}:$SCRATCH_DIR/proc$k/
        if ($lparticles) then
          $SCP $datadir/proc$k/pvar.dat ${node}:$SCRATCH_DIR/proc$k/
        endif
        echo "$SCP $datadir/proc$k/var.dat ${node}:$SCRATCH_DIR/proc$k/"
        if (-e $datadir/proc$k/timeavg.dat) then
          $SCP $datadir/proc$k/timeavg.dat ${node}:$SCRATCH_DIR/proc$k/
        endif
        set j=`expr $j + 1`
      end
      if (-e $datadir/allprocs/dxyz.dat) then
        $SCP $datadir/allprocs/dxyz.dat ${node}:$SCRATCH_DIR/allprocs/      
      endif
    end
  endif
endif

# ---------------------------------------------------------------------- #
rerun:

# Clean up control and data files
# NB. Don't remove NEWDIR it may have been put there on purpose so as
#     to catch a crash and run something else instead.
rm -f STOP RELOAD RERUN fort.20

# On machines with local scratch directory, initialize automatic
# background copying of snapshots back to the data directory.
# Also, if necessary copy executable to $SCRATCH_DIR of master node
# and start top command on all procs.
if ($local_disc) then
  echo "Use local scratch disk"
  $copysnapshots -v >&! copy-snapshots.log &
endif
# Copy output from `top' on run host to a file we can read from login server
if ($remote_top) then
  remote-top >&! remote-top.log &
endif
if ($local_binary) then
  echo "ls src/run.x $SCRATCH_DIR before copying:"
  ls -lt src/run.x $SCRATCH_DIR
  cp src/run.x $SCRATCH_DIR
  echo "ls src/run.x $SCRATCH_DIR after copying:"
  ls -lt src/run.x $SCRATCH_DIR
endif

# Write $PBS_JOBID to file (important when run is migrated within the same job)
if ($?PBS_JOBID) then
  echo $PBS_JOBID "  RUN STARTED on "$PBS_O_QUEUE `date` >> $datadir/jobid.dat
endif

# Run run.x
date
echo "$mpirun $mpirunops $npops $mpirunops2 $run_x $x_ops"
echo $mpirun $mpirunops $npops $mpirunops2 $run_x $x_ops >! run_command.log
time $mpirun $mpirunops $npops $mpirunops2 $run_x $x_ops
set run_status=$status		# save for exit
date

# Write $PBS_JOBID to file (important when run is migrated within the same job)
if ($?PBS_JOBID) then
  echo $PBS_JOBID " RUN FINISHED on "$PBS_O_QUEUE `date` >> $datadir/jobid.dat
endif

# look for RERUN file 
# With this method one can only reload a new executable.
# One cannot change directory, nor are the var.dat files returned to server.
# See the NEWDIR method below for more options.
if (-e "RERUN") then 
  rm -f RERUN
  echo
  echo "======================================================================="
  echo "Rerunning in the *same* directory; current run status: $run_status"
  echo "We are *still* in: " `pwd`
  echo "======================================================================="
  echo
  goto rerun
endif  
# ---------------------------------------------------------------------- #

# On machines with local scratch disc, copy var.dat back to the data
# directory
if ($local_disc) then
  echo "Copying all var.dat, VAR*, TIMEAVG*, dxyz.dat, timeavg.dat and crash. dat back from local scratch disks"
  $copysnapshots -v var.dat     >&! copy-snapshots2.log
  if ($lparticles) $copysnapshots -v pvar.dat >>& copy-snapshots2.log
  $copysnapshots -v -1          >>& copy-snapshots2.log
  $copysnapshots -v dxyz.dat    >>& copy-snapshots2.log
  $copysnapshots -v timeavg.dat >>& copy-snapshots2.log
  $copysnapshots -v crash.dat   >>& copy-snapshots2.log
  echo "done, will now killall copy-snapshots"
  # killall copy-snapshots   # Linux-specific
  set pids=`ps -U $USER -o pid,command | grep -E 'remote-top|copy-snapshots' | sed 's/^ *//' | cut -d ' ' -f 1`
  echo "Shutting down processes ${pids}:"
  foreach p ($pids)  # need to do in a loop, and check for existence, since
                     # some systems (Hitachi) abort this script when trying
                     # to kill non-existent processes
    echo "  pid $p"
    if ( `ps -p $p | fgrep -c $p` ) kill -KILL $p
  end

  if ($remove_scratch_root) then
    rm -rf $SCRATCH_DIR/*
    rm -rf $SCRATCH_DIR
  endif
endif
echo "Done"

# look for NEWDIR file 
# if NEWDIR contains a directory name, then continue run in that directory
if (-e "NEWDIR") then 
  if (-s "NEWDIR") then
    # Remove LOCK file before going to other directory
    if (-e "LOCK") rm -f LOCK
    set olddir=$cwd
    cd `cat NEWDIR`
    rm $olddir/NEWDIR
    (echo "stopped run:"; date; echo "new run directory:"; echo $cwd; echo "")\
       >> $olddir/$datadir/directory_change.log
    (date; echo "original run script is in:"; echo $olddir; echo "")\
       >> $datadir/directory_change.log
    echo
    echo "====================================================================="
    echo "Rerunning in new directory; current run status: $run_status"
    echo "We are now in: " `pwd`
    echo "====================================================================="
    echo
    goto newdir
  else
    rm -f NEWDIR
    if (-e "LOCK") rm -f LOCK
    echo
    echo "====================================================================="
    echo "Rerunning in the *same* directory; current run status: $run_status"
    echo "We are *still* in: " `pwd`
    echo "====================================================================="
    echo
    echo "Rerunning; current run status: $run_status"
    goto newdir
  endif
endif  
# ====================================================================== #

# Shut down lam if we have started it
if ($booted_lam) lamhalt

# remove LOCK file
if (-e "LOCK") rm -f LOCK

exit $run_status		# propagate status of mpirun

# cut & paste for job submission on the mhd machine
# bsub -n  4 -q 4cpu12h -o run.`timestr` -e run.`timestr` run.csh
# bsub -n  8 -q 8cpu12h mpijob dmpirun src/run.x
# bsub -n 16 -q 16cpu8h mpijob dmpirun src/run.x
# bsub -n  8 -q 8cpu12h -o run.log -w 'exit(123456)' mpijob dmpirun src/run.x

# qsub -l ncpus=64,mem=32gb,walltime=500:00:00 -W group_list=UK07001 -q UK07001 run.csh
# qsub -l nodes=4:ppn=1,mem=500mb,cput=24:00:00 -q p-long run.csh
# qsub -l ncpus=16,mem=1gb,cput=400:00:00 -q parallel run.csh
# qsub -l nodes=128,walltime=10:00:00 -q workq run.csh
# eval `env-setup lam`; qsub -v PATH -pe lam 8 -j y -o run.log run.csh
