! $Id: nocosmicrayflux.f90,v 1.6 2006-11-30 09:03:35 dobler Exp $
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lcosmicrayflux = .false.
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
!
!***************************************************************

module Cosmicrayflux

  use Cparam
  use Messages

  implicit none

  include 'cosmicrayflux.h'

  contains

!***********************************************************************
    subroutine register_cosmicrayflux()
!
      use Cdata
      use Mpicomm
      use Sub
!
      logical, save :: first=.true.
!

      if (.not. first) call stop_it('register_cosmicrayflux called twice')
      first = .false.

      if (lroot) call cvs_id( &
           "$Id: nocosmicrayflux.f90,v 1.6 2006-11-30 09:03:35 dobler Exp $")

    endsubroutine register_cosmicrayflux
!***********************************************************************
    subroutine initialize_cosmicrayflux(f)
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      if (NO_WARN) print*,'f=',f
!
    endsubroutine initialize_cosmicrayflux
!***************************************:********************************
    subroutine read_cosmicrayflux_init_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat) .and. (NO_WARN)) print*,iostat
      if (NO_WARN) print*,unit

    endsubroutine read_cosmicrayflux_init_pars
!***********************************************************************
    subroutine write_cosmicrayflux_init_pars(unit)
!
      integer, intent(in) :: unit
!
      if (NO_WARN) print*,unit
!
    endsubroutine write_cosmicrayflux_init_pars
!***********************************************************************
    subroutine read_cosmicrayflux_run_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (present(iostat) .and. (NO_WARN)) print*,iostat
!
      if (NO_WARN) print*,unit
!
    endsubroutine read_cosmicrayflux_run_pars
!***********************************************************************
    subroutine write_cosmicrayflux_run_pars(unit)
!
      integer, intent(in) :: unit
!
      if (NO_WARN) print*,unit
!
    endsubroutine write_cosmicrayflux_run_pars
!***********************************************************************
    subroutine init_fcr(f,xx,yy,zz)
!
      use Cdata
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz)      :: xx,yy,zz
!
      if (NO_WARN) print*,f,xx,yy,zz !(prevent compiler warnings)
!
    endsubroutine init_fcr
!***********************************************************************
    subroutine pencil_criteria_cosmicrayflux()
!
!   All pencils that the CosmicrayFlux module depends on are specified here.
!
    endsubroutine pencil_criteria_cosmicrayflux
!***********************************************************************
    subroutine pencil_interdep_cosmicrayflux(lpencil_in)
!
      logical, dimension (npencils) :: lpencil_in
!
      if (NO_WARN) print*, lpencil_in !(keep compiler quiet)
!
    endsubroutine pencil_interdep_cosmicrayflux
!***********************************************************************
    subroutine calc_pencils_cosmicrayflux(f,p)
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      intent(in) :: f,p
!
      if (NO_WARN) print*, f, p !(keep compiler quiet)
!
    endsubroutine calc_pencils_cosmicrayflux
!***********************************************************************
    subroutine dfcr_dt(f,df,p)
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      intent(in) :: f,df,p
!
      if (NO_WARN) print*,f,df,p
!
    endsubroutine dfcr_dt
!***********************************************************************
    subroutine rprint_cosmicrayflux(lreset,lwrite)
!
      use Sub
!
      logical :: lreset,lwr
      logical, optional :: lwrite
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
!  reset everything in case of reset
!  (this needs to be consistent with what is defined above!)
!
      if (lreset) then
!
      endif
!
      if (lwr) then
!        write(3,*) 'i_lnccmz=',idiag_lnccmz
      endif
!
    endsubroutine rprint_cosmicrayflux
!***********************************************************************

endmodule Cosmicrayflux
