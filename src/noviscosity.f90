! $Id: noviscosity.f90,v 1.9 2006-11-30 09:03:36 dobler Exp $

!  This modules implements viscous heating and diffusion terms
!  here for cases 1) nu constant, 2) mu = rho.nu 3) constant and

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lviscosity = .false.
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
! PENCILS PROVIDED gshock,shock
!
!***************************************************************

module Viscosity

  use Cdata
  use Messages

  implicit none

  include 'viscosity.h'

  logical :: lvisc_first=.false.

  real :: nu_mol
  ! input parameters
  !namelist /viscosity_init_pars/ dummy

  ! run parameters
  !namelist /viscosity_run_pars/ dummy

  ! Not implemented but needed for bodged implementation in hydro
  integer :: idiag_epsK=0
  character (len=labellen) :: ivisc='nu-const'

  contains

!***********************************************************************
    subroutine register_viscosity()
!
!  19-nov-02/tony: coded
!
      use Cdata
      use Mpicomm
      use Sub
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_viscosity called twice')
      first = .false.
!
      if ((ip<=8) .and. lroot) then
        print*, 'register_viscosity: NO VISCOSITY'
      endif
!
!  identify version number
!
      if (lroot) call cvs_id( &
           "$Id: noviscosity.f90,v 1.9 2006-11-30 09:03:36 dobler Exp $")

    endsubroutine register_viscosity
!***********************************************************************
    subroutine initialize_viscosity(lstarting)
!
!  02-apr-02/tony: coded
      logical, intent(in) :: lstarting

      if (NO_WARN) print*,lstarting
    endsubroutine initialize_viscosity
!***********************************************************************
    subroutine read_viscosity_init_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat).and.NO_WARN) print*,iostat
      if (NO_WARN) print*,unit

    endsubroutine read_viscosity_init_pars
!***********************************************************************
    subroutine write_viscosity_init_pars(unit)
      integer, intent(in) :: unit

      if (NO_WARN) print*,unit

    endsubroutine write_viscosity_init_pars
!***********************************************************************
    subroutine read_viscosity_run_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat).and.NO_WARN) print*,iostat
      if (NO_WARN) print*,unit

    endsubroutine read_viscosity_run_pars
!***********************************************************************
    subroutine write_viscosity_run_pars(unit)
      integer, intent(in) :: unit

      if (NO_WARN) print*,unit

    endsubroutine write_viscosity_run_pars
!*******************************************************************
    subroutine rprint_viscosity(lreset,lwrite)
!
!  Writes ishock to index.pro file
!
!  02-apr-03/tony: adapted from visc_const
!
      logical :: lreset
      logical, optional :: lwrite
!
      if(NO_WARN) print*,lreset,present(lwrite)  !(to keep compiler quiet)
    endsubroutine rprint_viscosity
!***********************************************************************
    subroutine pencil_criteria_viscosity()
!
!  All pencils that the Viscosity module depends on are specified here.
!
!  20-11-04/anders: coded
!
    endsubroutine pencil_criteria_viscosity
!***********************************************************************
    subroutine pencil_interdep_viscosity(lpencil_in)
!
!  Interdependency among pencils from the Viscosity module is specified here.
!
!  20-11-04/anders: coded
!
      use Cdata
!
      logical, dimension (npencils) :: lpencil_in
!
      if (NO_WARN) print*, lpencil_in !(keep compiler quiet)
!
    endsubroutine pencil_interdep_viscosity
!***********************************************************************
    subroutine calc_pencils_viscosity(f,p)
!
!  Calculate Viscosity pencils.
!  Most basic pencils should come first, as others may depend on them.
!
!  20-11-04/anders: coded
!
      use Cdata
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      intent(in) :: f
      intent(inout) :: p
! shock
      if (lpencil(i_shock)) p%shock=0.
! gshock
      if (lpencil(i_gshock)) p%gshock=0.
!
      if (NO_WARN) print*, f
!
    endsubroutine calc_pencils_viscosity
!!***********************************************************************
    subroutine calc_viscosity(f)
!
!
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      if(NO_WARN) print*,f  !(to keep compiler quiet)
!
    endsubroutine calc_viscosity
!!***********************************************************************
    subroutine calc_viscous_heat(df,p,Hmax)
!
!  calculate viscous heating term for right hand side of entropy equation
!
!  20-nov-02/tony: coded
!
      use Cdata

      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      real, dimension (nx) :: Hmax
!
      intent(in) :: df,p,Hmax
!
      if(NO_WARN) print*,df,p,Hmax  !(keep compiler quiet)
!
    endsubroutine calc_viscous_heat
!***********************************************************************
    subroutine calc_viscous_force(df,p)
!
!  calculate viscous heating term for right hand side of entropy equation
!
!  20-nov-02/tony: coded
!
      use Cdata

      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      intent (in) :: df,p
!
      if(NO_WARN) print*,df,p  !(keep compiler quiet)
!
    end subroutine calc_viscous_force
!***********************************************************************

endmodule Viscosity
