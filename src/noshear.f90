! $Id: noshear.f90,v 1.12 2006-08-23 16:53:32 mee Exp $

!  This modules deals with all aspects of shear; if no
!  shear are invoked, a corresponding replacement dummy
!  routine is used instead which absorbs all the calls to the
!  shear relevant subroutines listed in here.

module Shear

  use Sub
  use Cdata
  use Messages

  implicit none

  include 'shear.h'

  !namelist /shear_init_pars/ dummy
  !namelist /shear_run_pars/ dummy

  contains

!***********************************************************************
    subroutine register_shear()
!
!  Initialise variables
!
!  2-july-02/nils: coded
!
      use Mpicomm
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_shear called twice')
      first = .false.
!
      lshear = .false.
!
!  identify version number
!
      if (lroot) call cvs_id( &
           "$Id: noshear.f90,v 1.12 2006-08-23 16:53:32 mee Exp $")
!
    endsubroutine register_shear
!***********************************************************************
    subroutine initialize_shear()
!
!  21-nov-02/tony: coded
!  17-jul-04/axel: Sshear=0 is needed for forcing_hel to work correctly.
!
      Sshear=0.
!
    endsubroutine initialize_shear
!***********************************************************************
    subroutine read_shear_init_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
                                                                                                   
      if (present(iostat) .and. (NO_WARN)) print*,iostat
      if (NO_WARN) print*,unit
                                                                                                   
    endsubroutine read_shear_init_pars
!***********************************************************************
    subroutine write_shear_init_pars(unit)
      integer, intent(in) :: unit
                                                                                                   
      if (NO_WARN) print*,unit
                                                                                                   
    endsubroutine write_shear_init_pars
!***********************************************************************
    subroutine read_shear_run_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
                                                                                                   
      if (present(iostat) .and. (NO_WARN)) print*,iostat
      if (NO_WARN) print*,unit
                                                                                                   
    endsubroutine read_shear_run_pars
!***********************************************************************
    subroutine write_shear_run_pars(unit)
      integer, intent(in) :: unit
                                                                                                   
      if (NO_WARN) print*,unit
    endsubroutine write_shear_run_pars
!***********************************************************************
    subroutine shearing(f,df)
!
!  Calculates the actuall shear terms
!
!  2-july-02/nils: coded
!
      use Cparam
      use Deriv
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
!
      if(NO_WARN) print*,f,df !(to keep compiler quiet)
    endsubroutine shearing
!***********************************************************************
    subroutine advance_shear(dt_shear)
!
!  Dummy routine: deltay remains unchanged
!
! 18-aug-02/axel: incorporated from nompicomm.f90
!
      use Cdata
!
      real :: dt_shear
!
!  print identifier
!
      if (headtt.or.ldebug) print*,'advance_shear: deltay=const=',deltay
!
      if (NO_WARN) print*, dt_shear
!
    endsubroutine advance_shear
!***********************************************************************
    subroutine rprint_shear(lreset,lwrite)
!
!  dummy routine
!
!  02-jul-04/tobi: coded
!
      logical :: lreset
      logical, optional :: lwrite

      if (present(lwrite)) then
        if (NO_WARN) print*,lreset
      endif

    endsubroutine rprint_shear
!***********************************************************************
  endmodule Shear
