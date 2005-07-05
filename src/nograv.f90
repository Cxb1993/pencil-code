! $Id: nograv.f90,v 1.43 2005-07-05 16:21:42 mee Exp $

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
! PENCILS PROVIDED gg
!
!***************************************************************

module Gravity

!
!  Dummy model: no gravity
!

  use Cparam
  use Messages

  implicit none

  include 'gravity.h'

  interface potential
    module procedure potential_global
    module procedure potential_penc
    module procedure potential_point
  endinterface

  real, dimension(nx) :: gravx_pencil=0.,gravy_pencil=0.,gravz_pencil=0.
  real :: z1,z2,zref,zgrav,gravz,zinfty,nu_epicycle=1.
  real :: lnrho_bot,lnrho_top,ss_bot,ss_top
  real :: grav_const=1.
  real :: g0=0.,r0_pot=0.,kx_gg=1.,ky_gg=1.,kz_gg=1.
  integer :: n_pot=10
  character (len=labellen) :: grav_profile='const'  !(used by Density)
  logical :: lnumerical_equilibrium=.false.

  !namelist /grav_init_pars/ dummy
  !namelist /grav_run_pars/  dummy

  ! other variables (needs to be consistent with reset list below)
  integer :: idiag_curlggrms=0,idiag_curlggmax=0,idiag_divggrms=0
  integer :: idiag_divggmax=0

  contains

!***********************************************************************
    subroutine register_gravity()
!
!  initialise gravity flags
!
!  9-jan-02/wolf: coded
! 28-mar-02/axel: adapted from grav_z
!
      use Cdata
      use Mpicomm
      use Sub
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_grav called twice')
      first = .false.
!
!  identify version number (generated automatically by CVS)
!
      if (lroot) call cvs_id( &
           "$Id: nograv.f90,v 1.43 2005-07-05 16:21:42 mee Exp $")
!
      lgrav = .false.
      lgravz = .false.
      lgravr = .false.
!
    endsubroutine register_gravity
!***********************************************************************
    subroutine initialize_gravity()
!
!  Set up some variables for gravity; do nothing in nograv
!  16-jul-02/wolf: coded
!  22-nov-02/tony: renamed from setup_grav
!
    endsubroutine initialize_gravity
!***********************************************************************
    subroutine read_gravity_init_pars(unit,iostat)
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (present(iostat) .and. (NO_WARN)) print*,iostat 
!
      if (NO_WARN) print*,unit 
!
    endsubroutine read_gravity_init_pars
!***********************************************************************
    subroutine write_gravity_init_pars(unit)
!    
      integer, intent(in) :: unit
!
      if (NO_WARN) print*,unit
!
    endsubroutine write_gravity_init_pars
!***********************************************************************
    subroutine read_gravity_run_pars(unit,iostat)
!    
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (present(iostat) .and. (NO_WARN)) print*,iostat 
!
      if (NO_WARN) print*,unit 
!
    endsubroutine read_gravity_run_pars
!***********************************************************************
    subroutine write_gravity_run_pars(unit)
!    
      integer, intent(in) :: unit
!      
      if (NO_WARN) print*,unit
!
    endsubroutine write_gravity_run_pars
!***********************************************************************
    subroutine init_gg(f,xx,yy,zz)
!
!  initialise gravity; called from start.f90
!   9-jan-02/wolf: coded
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz) :: xx,yy,zz
!
! Not doing anything (this might change if we decide to store gg)
!
      if (NO_WARN) print*,f,xx,yy,zz !(keep compiler quiet)
!        
    endsubroutine init_gg
!***********************************************************************
    subroutine pencil_criteria_gravity()
! 
!  All pencils that the Gravity module depends on are specified here.
! 
!  20-11-04/anders: coded
!
!
    endsubroutine pencil_criteria_gravity
!***********************************************************************
    subroutine pencil_interdep_gravity(lpencil_in)
!
!  Interdependency among pencils from the Gravity module is specified here.
!
!  20-11-04/anders: coded
!
      logical, dimension(npencils) :: lpencil_in
!
      if (NO_WARN) print*, lpencil_in !(keep compiler quiet)
!
    endsubroutine pencil_interdep_gravity
!***********************************************************************
    subroutine calc_pencils_gravity(f,p)
!
!  Calculate Gravity pencils.
!  Most basic pencils should come first, as others may depend on them.
!
!  12-nov-04/anders: coded
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      type (pencil_case) :: p
!      
      intent(in) :: f
      intent(inout) :: p
!
      if (lpencil(i_gg)) p%gg=0.
!
      if (NO_WARN) print*, f !(keep compiler quiet)
!
    endsubroutine calc_pencils_gravity
!***********************************************************************
    subroutine duu_dt_grav(f,df,p)
!
!  add nothing to duu/dt
!
! 28-mar-02/axel: adapted from grav_z
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      if (NO_WARN) print*,f,df,p  !(keep compiler quiet)
!        
    endsubroutine duu_dt_grav
!***********************************************************************
    subroutine potential_global(xx,yy,zz,pot,pot0)
!
!  gravity potential
!  28-mar-02/axel: adapted from grav_z
!
      use Cdata, only: mx,my,mz,lroot
!
      real, dimension (mx,my,mz) :: xx,yy,zz,pot
      real, optional :: pot0
!
      if (lroot) print*,'potential: note, GRAV=nograv is not OK'
      pot = 0.
      pot0 = 0.
!
      if (NO_WARN) print*,xx(1,1,1),yy(1,1,1),zz(1,1,1)
!
    endsubroutine potential_global
!***********************************************************************
    subroutine potential_penc(xmn,ymn,zmn,pot,pot0,grav,rmn)
!
!  gravity potential
!  28-mar-02/axel: adapted from grav_z
!
      use Cdata, only: nx,lroot
!
      real, dimension (nx) :: pot
      real, optional :: ymn,zmn,pot0
      real, optional, dimension (nx) :: xmn,rmn
      real, optional, dimension (nx,3) :: grav
!
      if (lroot) print*,'potential: note, GRAV=nograv is not OK'
      pot = 0.
      pot0 = 0.
!
      if (NO_WARN) print*,xmn,ymn,zmn,rmn,grav
!
    endsubroutine potential_penc
!***********************************************************************
    subroutine potential_point(x,y,z,r, pot,pot0, grav)
!
!  Gravity potential in one point
!
!  20-dec-03/wolf: coded
!
      use Mpicomm, only: stop_it
!
      real :: pot
      real, optional :: x,y,z,r
      real, optional :: pot0,grav
!
      call stop_it("nograv: potential_point not implemented")
!
      if (NO_WARN) print*,x,y,z,r,pot,pot0,grav     !(to keep compiler quiet)
!
    endsubroutine potential_point
!***********************************************************************
    subroutine rprint_gravity(lreset,lwrite)
!
!  reads and registers print parameters relevant for gravity advance
!  dummy routine
!
!  26-apr-03/axel: coded
!
      use Cdata
!
      logical :: lreset,lwr
      logical, optional :: lwrite
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
!  write column, idiag_XYZ, where our variable XYZ is stored
!  idl needs this even if everything is zero
!
      if (lwr) then
        write(3,*) 'i_curlggrms=',idiag_curlggrms
        write(3,*) 'i_curlggmax=',idiag_curlggmax
        write(3,*) 'i_divggrms=',idiag_divggrms
        write(3,*) 'i_divggmax=',idiag_divggmax
        write(3,*) 'igg=',igg
        write(3,*) 'igx=',igx
        write(3,*) 'igy=',igy
        write(3,*) 'igz=',igz
      endif
!
      if (NO_WARN) print*,lreset  !(to keep compiler quiet)
!        
    endsubroutine rprint_gravity
!***********************************************************************

endmodule Gravity
