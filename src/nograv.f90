! $Id: nograv.f90,v 1.30 2003-10-18 20:43:34 brandenb Exp $

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxilliary variables added by this module
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
!***************************************************************

module Gravity

!
!  Dummy model: no gravity
!

  use Cparam

  implicit none

  interface potential
    module procedure potential_global
    module procedure potential_penc
  endinterface

  real :: z1,z2,zref,zgrav,gravz,zinfty,nu_epicycle=1.
  real :: lnrho_bot,lnrho_top,ss_bot,ss_top
  real :: grav_const=1.
  real :: g0
  character (len=labellen) :: grav_profile='const'  !(used by Density)

  integer :: dummy              ! We cannot define empty namelists
  namelist /grav_init_pars/ dummy
  namelist /grav_run_pars/  dummy

  ! other variables (needs to be consistent with reset list below)
  integer :: i_curlggrms=0,i_curlggmax=0,i_divggrms=0,i_divggmax=0

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
           "$Id: nograv.f90,v 1.30 2003-10-18 20:43:34 brandenb Exp $")
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
      if(ip==0) print*,f,xx,yy,zz !(keep compiler quiet)
    endsubroutine init_gg
!***********************************************************************
    subroutine duu_dt_grav(f,df,uu,rho1)
!
!  add nothing to duu/dt
!
! 28-mar-02/axel: adapted from grav_z
!
      use Cdata
!      use Mpicomm
      use Sub
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (nx,3) :: uu
      real, dimension (nx) :: rho1
!
      if(ip==0) print*,f,df,uu,rho1  !(keep compiler quiet)
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
      if (lroot) print*,'potential: should not have been called'
      pot = 0.
      pot0 = 0.
!
      if(ip==0) print*,xx(1,1,1),yy(1,1,1),zz(1,1,1)
    endsubroutine potential_global
!***********************************************************************
    subroutine potential_penc(xmn,ymn,zmn,pot,pot0,grav,rmn)
!
!  gravity potential
!  28-mar-02/axel: adapted from grav_z
!
      use Cdata, only: nx,lroot
!
      real, dimension (nx) :: xmn,pot
      real :: ymn,zmn
      real, optional :: pot0
      real, optional, dimension (nx) :: rmn
      real, optional, dimension (nx,3) :: grav
!
      if (lroot) print*,'potential: should not have been called'
      pot = 0.
      pot0 = 0.
!
      if(ip==0) print*,xmn,ymn,zmn,rmn,grav
    endsubroutine potential_penc
!***********************************************************************
    subroutine rprint_gravity(lreset)
!
!  reads and registers print parameters relevant for gravity advance
!  dummy routine
!
!  26-apr-03/axel: coded
!
      use Cdata
!
      logical :: lreset
!
!  write column, i_XYZ, where our variable XYZ is stored
!  idl needs this even if everything is zero
!
      write(3,*) 'i_curlggrms=',i_curlggrms
      write(3,*) 'i_curlggmax=',i_curlggmax
      write(3,*) 'i_divggrms=',i_divggrms
      write(3,*) 'i_divggmax=',i_divggmax
      write(3,*) 'igg=',igg
      write(3,*) 'igx=',igx
      write(3,*) 'igy=',igy
      write(3,*) 'igz=',igz
!
      if(ip==0) print*,lreset  !(to keep compiler quiet)
    endsubroutine rprint_gravity
!***********************************************************************

endmodule Gravity
