! $Id$
!
!  Module to handle variables whose state should persist between executions of
!  run.x, e.g. the random number seeds and some other forcing state information.
!
!  25-Apr-2005/tony: Implemented initial try at backwards compatible
!                    additions to var.dat files.
!
!  The idea is to use integer block and record type tags to store arbitrary
!  extra information in the var files along with the actual field information.
!
!  The integers representing the various block/record types are defined in a
!  separate file, record_types.inc.  These numbers MUST remain unique and MUST
!  not be altered, though adding new types is acceptable (else old var.dat
!  files may become unreadable).
!
module Persist
!
  use Cdata
!
  implicit none
!
  private
!
  public :: input_persistent, output_persistent
!
  include 'record_types.h'
!
  contains
!***********************************************************************
    subroutine input_persistent(lun)
!
!  Read auxiliary information from snapshot file.
!  lun should be set to the same lun as that of the snapshot.
!
!  26-may-03/axel: adapted from output_vect
!   6-apr-08/axel: added input_persistent_magnetic
!
      use Interstellar, only: input_persistent_interstellar
      use Forcing, only: input_persistent_forcing
      use Magnetic, only: input_persistent_magnetic
      use Hydro, only: input_persistent_hydro
!
      integer :: lun
      integer :: id, dummy,ierr
      logical :: done =.false.
!
      if ((ip<=8).and.lroot) print*,'input_persistent: '
!
      read(lun,end=1000) id
      if (id/=id_block_PERSISTENT) then
        if ((ip<=8).and.lroot) &
            print*,'input_persistent: No persistent data to read'
        return
      endif
!
dataloop: do
        read(lun,iostat=ierr,end=1000) id
        done=.false.
        if (id==id_block_PERSISTENT) then
          exit dataloop
        endif
        if (ierr<0) exit dataloop
        if (.not.done) call input_persistent_general(id,lun,done)
        if (.not.done) call input_persistent_interstellar(id,lun,done)
        if (.not.done) call input_persistent_forcing(id,lun,done)
        if (.not.done) call input_persistent_magnetic(id,lun,done)
        if (.not.done) call input_persistent_hydro(id,lun,done)
        if (.not.done) read(lun,end=1000) dummy
      enddo dataloop
!
      if ((ip<=8).and.lroot) print*,'input_persistent: DONE'
      return
1000  if ((ip<=8).and.lroot) print*,'input_persistent: EOF termination'
!
    endsubroutine input_persistent
!***********************************************************************
    subroutine output_persistent(lun_output)
!
!  Write auxiliary information into snapshot file.
!  lun should be set to the same lun as that of the snapshot
!
!  26-may-03/axel: adapted from output_vect
!   6-apr-08/axel: added output_persistent_magnetic
!   5-nov-11/MR: IOSTAT handling added
!  16-nov-11/MR: calls adapted
!
      use Interstellar, only: output_persistent_interstellar
      use Forcing, only: output_persistent_forcing
      use Magnetic, only: output_persistent_magnetic
      use Hydro, only: output_persistent_hydro
      use Messages, only: outlog
!
      integer :: lun_output
!
      integer :: iostat
!
      if ((ip<=8).and.lroot) print*,'output_persistent: '
!
      write(lun_output,iostat=IOSTAT) id_block_PERSISTENT
      if (outlog(iostat,'write id_block_PERSISTENT')) return
!
      if (output_persistent_general(lun_output)) return
      if (output_persistent_interstellar(lun_output)) return
      if (output_persistent_forcing(lun_output)) return
      if (output_persistent_magnetic(lun_output)) return
      if (output_persistent_hydro(lun_output)) return
!
      write(lun_output,iostat=IOSTAT) id_block_PERSISTENT
      if (outlog(iostat,'write id_block_PERSISTENT')) return
!
    endsubroutine output_persistent
!***********************************************************************
    subroutine input_persistent_general(id,lun,done)
!
!  Reads seed from a snapshot.
!
      use Cdata, only: seed,nseed
      use General, only: random_seed_wrapper
!
      integer :: id,lun
      logical :: done
!
      call random_seed_wrapper(GET=seed)
      if (id==id_record_RANDOM_SEEDS) then
        read (lun) seed(1:nseed)
        call random_seed_wrapper(PUT=seed)
        done=.true.
      endif
!
    endsubroutine input_persistent_general
!***********************************************************************
    logical function output_persistent_general(lun)
!
!  Writes seed to a snapshot.
!
      use Cdata, only: seed,nseed
      use Messages, only: outlog
      use General, only: random_seed_wrapper
!
      integer :: lun
!
      integer :: iostat
!
      output_persistent_general = .true.
!
      call random_seed_wrapper(GET=seed)
      write (lun,IOSTAT=iostat) id_record_RANDOM_SEEDS
      if (outlog(iostat,'write id_record_RANDOM_SEEDS')) return
!
      write (lun,IOSTAT=iostat) seed(1:nseed)
      if (outlog(iostat,'write seed')) return
!
      output_persistent_general = .false.
!
    endfunction output_persistent_general
!***********************************************************************
endmodule Persist
