! $Id: grav_z.f90,v 1.45 2003-10-18 20:43:34 brandenb Exp $

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxilliary variables added by this module
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
!***************************************************************

module Gravity

!  Vertical gravity (for convection in a slab or a full star)
!  (The full star geometry is currently in grav_r, but in may well
!  be possible to migrate it in here.)

  use cparam

  implicit none

  interface potential
    module procedure potential_global
    module procedure potential_penc
  endinterface

!  zref is the height where rho=rho0 and cs2=cs20.
!  For a single polytrope, zinfty (calculated in the
!  density module) is the height where rho=cs2=0.

  integer :: ngrav=10
  real :: z1=0.,z2=1.,zref=0.,gravz=-1.,zinfty,zgrav=impossible,nu_epicycle=1.
  real :: lnrho_bot,lnrho_top,ss_bot,ss_top
  real :: grav_const=1.
  real :: g0
  logical :: lgravzd=.true.
  character (len=labellen) :: grav_profile='const'

!  The gravity potential must always be negative. However, in an plane
!  atmosphere with constant gravity, the potential goes to zero at
!  some position which is referred to as "zinfty".

!  For initlnrho='piecew-poly', z1 and z2 are the interfaces between the
!  three layers of different polytropic exponent:
!
!      z
!      ^
!      |  m = m2 (top layer)
!      |
!  z2  +
!      |
!      |  m = m0 (unstable [main] layer)
!      |
!  z1  +
!      |
!      |  m = m1 (stable bottom layer)
!      |
!
  namelist /grav_init_pars/ &
       z1,z2,zref,gravz,nu_epicycle,grav_profile,zgrav, &
       lnrho_bot,lnrho_top,ss_bot,ss_top,lgravzd

!  It would be rather unusual to change the profile during the
!  run, but "adjusting" the profile slighly may be quite useful.

  namelist /grav_run_pars/ &
       zref,gravz,nu_epicycle,grav_profile,zgrav, &
       lnrho_bot,lnrho_top,ss_bot,ss_top,lgravzd

  ! other variables (needs to be consistent with reset list below)
  integer :: i_curlggrms=0,i_curlggmax=0,i_divggrms=0,i_divggmax=0

  contains

!***********************************************************************
    subroutine register_gravity()
!
!  initialise gravity flags
!
!  9-jan-02/wolf: coded
!
      use Cdata
      use Mpicomm
      use Sub
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_gravity: called twice')
      first = .false.
!
!  identify version number (generated automatically by CVS)
!
      if (lroot) call cvs_id( &
           "$Id: grav_z.f90,v 1.45 2003-10-18 20:43:34 brandenb Exp $")
!
      lgrav = .true.
      lgravz = .true.
      lgravr = .false.
!
    endsubroutine register_gravity
!***********************************************************************
    subroutine initialize_gravity()
!
!  Set up some variables for gravity; do nothing in grav_z
!  16-jul-02/wolf: coded
!  22-nov-02/tony: renamed from setup_grav
!
    endsubroutine initialize_gravity
!***********************************************************************
    subroutine init_gg(f,xx,yy,zz)
!
!  initialise gravity; called from start.f90
!  9-jan-02/wolf: coded
!  24-nov-2002: renamed from init_grav to stay consistent
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
!  add duu/dt according to gravity
!  (do we need f here?/AB)
!
!  9-jan-02/wolf: coded
! 28-jun-02/axel: added 'linear' gravity profile
! 28-jul-02/axel: added 'const_zero' gravity profile
!  1-jun-03/axel: dust velocity added
!
      use Cdata
      use Sub
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (nx,3) :: uu
      real, dimension (nx) :: rho1
      real :: nu_epicycle2
!
      intent(in)  :: f
      if (headtt) print*,'duu_dt_grav: lgravzd=', lgravzd
!
!  different gravity profiles
!
      if (grav_profile=='const') then
        if (headtt) print*,'duu_dt_grav: constant gravz=',gravz
        if(lhydro) &
            df(l1:l2,m,n,iuz) =df(l1:l2,m,n,iuz) +gravz
        if(ldustvelocity .and. lgravzd) &
            df(l1:l2,m,n,iudz)=df(l1:l2,m,n,iudz)+gravz
!
!  linear gravity profile (for accretion discs)
!
      elseif (grav_profile=='const_zero') then
        if (headtt) print*,'duu_dt_grav: const_zero gravz=',gravz
        if (zgrav==impossible.and.lroot) print*,'zgrav is not set!'
        if (z(n)<=zgrav) then
          if(lhydro) &
              df(l1:l2,m,n,iuz) =df(l1:l2,m,n,iuz) +gravz
          if(ldustvelocity .and. lgravzd) &
              df(l1:l2,m,n,iudz)=df(l1:l2,m,n,iudz)+gravz
        endif
!
!  linear gravity profile (for accretion discs)
!
      elseif (grav_profile=='linear') then
        !if (nu_epicycle/=-gravz) then
        !  if (lroot) print*,'Omega,nu_epicycle=',Omega,nu_epicycle
        !endif
        nu_epicycle2=nu_epicycle**2
        if(headtt) print*,'duu_dt_grav: linear grav, nu=',nu_epicycle
        if(lhydro) &
            df(l1:l2,m,n,iuz) =df(l1:l2,m,n,iuz) -nu_epicycle2*z(n)
        if(ldustvelocity .and. lgravzd) &
            df(l1:l2,m,n,iudz)=df(l1:l2,m,n,iudz)-nu_epicycle2*z(n)
!
!  gravity profile from K. Ferriere, ApJ 497, 759, 1998, eq (34)
!   at solar radius.  (for interstellar runs)
!
      elseif (grav_profile=='Ferriere') then
!  nb: 331.5 is conversion factor: 10^-9 cm/s^2 -> kpc/Gyr^2)  (/= 321.1 ?!?)
!AB: These numbers should be inserted in the appropriate unuts.
!AB: As it is now, it can never make much sense.
        if(lhydro) &
            df(l1:l2,m,n,iuz) = df(l1:l2,m,n,iuz) & 
            -331.5*(4.4*z(n)/sqrt(z(n)**2+(0.2)**2) + 1.7*z(n))
        if(ldustvelocity .and. lgravzd) &
            df(l1:l2,m,n,iudz) = df(l1:l2,m,n,iudz) & 
            -331.5*(4.4*z(n)/sqrt(z(n)**2+(0.2)**2) + 1.7*z(n))
      else
        if(lroot) print*,'duu_dt_grav: no gravity profile given'
      endif
!
      if(ip==0) print*,f,uu,rho1 !(keep compiler quiet)
    endsubroutine duu_dt_grav
!***********************************************************************
    subroutine potential_global(xx,yy,zz,pot,pot0)
!
!  gravity potential
!  16-jul-02/wolf: coded
!
      use Cdata, only: mx,my,mz
      use Mpicomm
!
      real, dimension (mx,my,mz) :: xx,yy,zz, pot
      real, optional :: pot0
!
      call stop_it("potential_global: not implemented for grav_z")
!
      if(ip==0) print*,xx(1,1,1)+yy(1,1,1)+zz(1,1,1), &
           pot(1,1,1),pot0  !(keep compiler quiet)
!
    endsubroutine potential_global
!***********************************************************************
    subroutine potential_penc(xmn,ymn,zmn,pot,pot0,grav,rmn)
!
!  calculates gravity potential and gravitational acceleration
!  on a pencil.
!
!  21-jan-02/wolf: coded
!   8-jul-02/axel: activated and used for initial conditions
!
      use Cdata, only: nx,lroot
!
      real, dimension (nx) :: xmn,pot,r
      real :: ymn,zmn,nu_epicycle2
      real, optional :: pot0
      real, optional, dimension (nx) :: rmn
      real, optional, dimension (nx,3) :: grav
      logical, save :: first=.true.
!
      intent(in) :: xmn,ymn,zmn,rmn
      intent(out) :: pot,grav
!
!  identifier
!
      if (lroot.and.first) print*,'potential_penc: zinfty=',zinfty
!
!  different profiles, calculate also gz=-dpot/dz
!  remember, gravz=-1 (at least negative) for z pointing upwards.
!
      select case(grav_profile)
      case('const')
        pot=-gravz*(zmn-zinfty)
        if (present(pot0)) pot0 = gravz*zinfty !(potential at z=0)
        if (present(grav)) then
          grav(:,1:2)=0.
          grav(:,3)=gravz
        endif
!
!  gravity is set to zero above z=zgrav
!
      case('const_zero')
        if(zgrav==impossible.and.lroot) print*,'potential_penc: zgrav is not set!'
        if(zmn<=zgrav) then
          pot=-gravz*(zmn-zinfty)
          if (present(grav)) then
            grav(:,1:2)=0.
            grav(:,3)=gravz
          endif
        else
          pot=-gravz*(zgrav-zinfty)
          if (present(grav)) grav=0.
        endif
        if (present(pot0)) then !(potential at z=0)
          if(zgrav==impossible.and.lroot) print*,'potential_penc: zgrav is not set!'
          if(0.<=zgrav) then
            pot0 = gravz*zinfty
          else
            pot0 =-gravz*(zgrav-zinfty)
          endif
        endif
!
!  gravity increases linearly with height (for accretion discs)
!
        case('linear')
          nu_epicycle2=nu_epicycle**2
          pot=.5*nu_epicycle2*(zmn**2-zinfty**2)
          if (present(pot0)) pot0=-.5*nu_epicycle2*zinfty**2 !(potential at z=0)
          if (present(grav)) then
            grav=0.
            if(zmn<=zgrav) grav(:,3)=-nu_epicycle2*zmn
          endif
!
!  gravity profile from K. Ferriere, ApJ 497, 759, 1998, eq (34)
!
        case('Ferriere')
          pot=331.5*(4.4*(sqrt(zmn**2+0.2**2)-0.2)+1.7*zmn**2/2.)
          if (present(pot0)) pot0=331.5*(4.4*(sqrt(0.2**2)-0.2))
          if (present(grav)) then
            grav=0.
            if(zmn<=zgrav) grav(:,3)= &
              -331.5*(4.4*zmn/sqrt(zmn**2+(0.2)**2) + 1.7*zmn)
          endif
!
!  radial profile; not currently implemented
!
        case('radial')
          if (present(rmn)) then
            r=rmn
          else
            r=sqrt(xmn**2+ymn**2+zmn**2)
          endif
          !(not implemented yet; just laying out the idea)
          pot=.5*gravz*r**2/(1.+r**4)
          if (present(pot0)) pot0 = 0. ! potential at z=0
          if (present(grav)) then
            grav(:,1:3)=0.
          endif
      case default
        print*,'potential_penc: no default profile'
        stop
      endselect
      first=.false.
!
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
