! $Id: noviscosity.f90 13053 2010-01-22 18:43:47Z sven.bingert $
!
!  This modules implements viscous heating and diffusion terms
!  here for cases 1) nu constant, 2) mu = rho.nu 3) constant and
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lviscosity = .false.
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
! PENCILS PROVIDED gshock(3); shock; visc_heat
!
!***************************************************************
module Viscosity
!
  use Cdata
  use Sub, only: keep_compiler_quiet
!
  implicit none
!
  include 'viscosity.h'
!
  logical :: lvisc_first=.false.
!
  contains
!***********************************************************************
    subroutine register_viscosity()
!
!  19-nov-02/tony: coded
!
      use Messages, only: svn_id
!
!  Identify version number.
!
      if (lroot) call svn_id( &
           "$Id: noviscosity.f90 13053 2010-01-22 18:43:47Z sven.bingert $")
!
    endsubroutine register_viscosity
!***********************************************************************
    subroutine initialize_viscosity(lstarting)
!
      logical, intent(in) :: lstarting
!
      call keep_compiler_quiet(lstarting)
!
    endsubroutine initialize_viscosity
!***********************************************************************
    subroutine read_viscosity_init_pars(unit,iostat)
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      call keep_compiler_quiet(unit)
      if (present(iostat)) call keep_compiler_quiet(iostat)
!
    endsubroutine read_viscosity_init_pars
!***********************************************************************
    subroutine write_viscosity_init_pars(unit)
!
      integer, intent(in) :: unit
!
      call keep_compiler_quiet(unit)
!
    endsubroutine write_viscosity_init_pars
!***********************************************************************
    subroutine read_viscosity_run_pars(unit,iostat)
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      call keep_compiler_quiet(unit)
      if (present(iostat)) call keep_compiler_quiet(iostat)
!
    endsubroutine read_viscosity_run_pars
!***********************************************************************
    subroutine write_viscosity_run_pars(unit)
!
      integer, intent(in) :: unit
!
      call keep_compiler_quiet(unit)
!
    endsubroutine write_viscosity_run_pars
!*******************************************************************
    subroutine rprint_viscosity(lreset,lwrite)
!
      logical :: lreset
      logical, optional :: lwrite
!
      call keep_compiler_quiet(lreset)
      call keep_compiler_quiet(present(lwrite))
!
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
      logical, dimension (npencils) :: lpencil_in
!
      call keep_compiler_quiet(lpencil_in)
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
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      intent(in) :: f
      intent(inout) :: p
!
!  define shock, gshock, visc_heat
!
      if (lpencil(i_shock)) p%shock=0.0
      if (lpencil(i_gshock)) p%gshock=0.0
      if (lpencil(i_visc_heat)) p%visc_heat=0.0
!
      call keep_compiler_quiet(f)
!
    endsubroutine calc_pencils_viscosity
!***********************************************************************
    subroutine calc_viscosity(f)
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine calc_viscosity
!***********************************************************************
    subroutine calc_viscous_heat(f,df,p,Hmax)
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar)    :: df
      type (pencil_case) :: p
!
      real, dimension (nx) :: Hmax
!
      intent(in) :: df,p,Hmax
!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
      call keep_compiler_quiet(Hmax)
!
    endsubroutine calc_viscous_heat
!***********************************************************************
    subroutine calc_viscous_force(df,p)
!
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      intent (in) :: df,p
!
      call keep_compiler_quiet(df)
      call keep_compiler_quiet(p)
!
    endsubroutine calc_viscous_force
!***********************************************************************
    subroutine calc_visc_heat_ppd(df,p)
!
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
      intent (in) :: df,p
!
      call keep_compiler_quiet(df)
      call keep_compiler_quiet(p)
!
    endsubroutine calc_visc_heat_ppd
!***********************************************************************
    subroutine getnu(nu_)
!
      real,intent(out) :: nu_
!
      nu_=0.0
!
      call keep_compiler_quiet(nu_)
!
    endsubroutine getnu
!***********************************************************************
endmodule Viscosity
