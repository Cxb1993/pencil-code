! $Id: chiral.f90,v 1.3 2004-05-31 15:43:02 brandenb Exp $

!  This modules solves two reactive scalar advection equations
!  This is used for modeling the spatial evolution of left and
!  right handed aminoacids.

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! MVAR CONTRIBUTION 2
! MAUX CONTRIBUTION 0
!
!***************************************************************

module Chiral

  use Cparam
  use Cdata

  implicit none

  character (len=labellen) :: initXX_chiral='zero',initYY_chiral='zero'

  ! input parameters
  real :: amplXX_chiral=.1, widthXX_chiral=.5
  real :: amplYY_chiral=.1, widthYY_chiral=.5
  real :: kx_XX_chiral=1.,ky_XX_chiral=1.,kz_XX_chiral=1.,radiusXX_chiral=0.
  real :: kx_YY_chiral=1.,ky_YY_chiral=1.,kz_YY_chiral=1.,radiusYY_chiral=0.
  real :: xposXX_chiral=0.,yposXX_chiral=0.,zposXX_chiral=0.
  real :: xposYY_chiral=0.,yposYY_chiral=0.,zposYY_chiral=0.

  namelist /chiral_init_pars/ &
       initXX_chiral,amplXX_chiral,kx_XX_chiral,ky_XX_chiral,kz_XX_chiral, &
       initYY_chiral,amplYY_chiral,kx_YY_chiral,ky_YY_chiral,kz_YY_chiral, &
       radiusXX_chiral,widthXX_chiral, &
       radiusYY_chiral,widthYY_chiral, &
       xposXX_chiral,yposXX_chiral,zposXX_chiral, &
       xposYY_chiral,yposYY_chiral,zposYY_chiral

  ! run parameters
  real :: chiral_diff=0., chiral_crossinhibition=1.,chiral_fidelity=1.

  namelist /chiral_run_pars/ &
       chiral_diff,chiral_crossinhibition,chiral_fidelity

  ! other variables (needs to be consistent with reset list below)
  integer :: i_XX_chiralmax=0, i_XX_chiralm=0
  integer :: i_YY_chiralmax=0, i_YY_chiralm=0
  integer :: i_QQm_chiral=0, i_QQ21m_chiral=0, i_QQ21QQm_chiral=0

  contains

!***********************************************************************
    subroutine register_chiral()
!
!  Initialise variables which should know that we solve for passive
!  scalar: iXX_chiral and iYY_chiral; increase nvar accordingly
!
!  28-may-04/axel: adapted from pscalar
!
      use Cdata
      use Mpicomm
      use Sub
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_chiral called twice')
      first = .false.
!
      lchiral = .true.
      iXX_chiral = nvar+1       ! index to access XX_chiral
      iYY_chiral = nvar+2       ! index to access YY_chiral
      nvar = nvar+2             ! added 1 variable
!
      if ((ip<=8) .and. lroot) then
        print*, 'Register_XX_chiral:  nvar = ', nvar
        print*, 'iXX_chiral = ', iXX_chiral
      endif
!
!  Put variable names in array
!
      varname(iXX_chiral) = 'XX_chiral'
      varname(iYY_chiral) = 'YY_chiral'
!
!  identify version number
!
      if (lroot) call cvs_id( &
           "$Id: chiral.f90,v 1.3 2004-05-31 15:43:02 brandenb Exp $")
!
      if (nvar > mvar) then
        if (lroot) write(0,*) 'nvar = ', nvar, ', mvar = ', mvar
        call stop_it('Register_chiral: nvar > mvar')
      endif
!
    endsubroutine register_chiral
!***********************************************************************
    subroutine initialize_chiral(f)
!
!  Perform any necessary post-parameter read initialization
!  Dummy routine
!
!  28-may-04/axel: adapted from pscalar
!
      real, dimension (mx,my,mz,mvar+maux) :: f
! 
!  set to zero and then call the same initial condition
!  that was used in start.csh
!   
      if(ip==0) print*,'f=',f
    endsubroutine initialize_chiral
!***********************************************************************
    subroutine init_chiral(f,xx,yy,zz)
!
!  initialise passive scalar field; called from start.f90
!
!  28-may-04/axel: adapted from pscalar
!
      use Cdata
      use Mpicomm
      use Density
      use Sub
      use Initcond
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz)      :: xx,yy,zz,prof
!
!  check first for initXX_chiral
!
      select case(initXX_chiral)
        case('zero'); f(:,:,:,iXX_chiral)=0.
        case('const'); f(:,:,:,iXX_chiral)=amplXX_chiral
        case('blob'); call blob(amplXX_chiral,f,iXX_chiral,radiusXX_chiral,xposXX_chiral,yposXX_chiral,zposXX_chiral)
        case('hat-x'); call hat(amplXX_chiral,f,iXX_chiral,widthXX_chiral,kx=kx_XX_chiral)
        case('hat-y'); call hat(amplXX_chiral,f,iXX_chiral,widthXX_chiral,ky=ky_XX_chiral)
        case('hat-z'); call hat(amplXX_chiral,f,iXX_chiral,widthXX_chiral,kz=kz_XX_chiral)
        case('gaussian-x'); call gaussian(amplXX_chiral,f,iXX_chiral,kx=kx_XX_chiral)
        case('gaussian-y'); call gaussian(amplXX_chiral,f,iXX_chiral,ky=ky_XX_chiral)
        case('gaussian-z'); call gaussian(amplXX_chiral,f,iXX_chiral,kz=kz_XX_chiral)
        case('positive-noise'); call posnoise(amplXX_chiral,f,iXX_chiral)
        case('wave-x'); call wave(amplXX_chiral,f,iXX_chiral,kx=kx_XX_chiral)
        case('wave-y'); call wave(amplXX_chiral,f,iXX_chiral,ky=ky_XX_chiral)
        case('wave-z'); call wave(amplXX_chiral,f,iXX_chiral,kz=kz_XX_chiral)
        case('cosx_cosy_cosz'); call cosx_cosy_cosz(amplXX_chiral,f,iXX_chiral,kx_XX_chiral,ky_XX_chiral,kz_XX_chiral)
        case default; call stop_it('init_chiral: bad init_chiral='//trim(initXX_chiral))
      endselect
!
!  check next for initYY_chiral
!
      select case(initYY_chiral)
        case('zero'); f(:,:,:,iYY_chiral)=0.
        case('const'); f(:,:,:,iYY_chiral)=amplYY_chiral
        case('blob'); call blob(amplYY_chiral,f,iYY_chiral,radiusYY_chiral,xposYY_chiral,yposYY_chiral,zposYY_chiral)
        case('hat-x'); call hat(amplYY_chiral,f,iYY_chiral,widthYY_chiral,kx=kx_YY_chiral)
        case('hat-y'); call hat(amplYY_chiral,f,iYY_chiral,widthYY_chiral,ky=ky_YY_chiral)
        case('hat-z'); call hat(amplYY_chiral,f,iYY_chiral,widthYY_chiral,kz=kz_YY_chiral)
        case('gaussian-x'); call gaussian(amplYY_chiral,f,iYY_chiral,kx=kx_YY_chiral)
        case('gaussian-y'); call gaussian(amplYY_chiral,f,iYY_chiral,ky=ky_YY_chiral)
        case('gaussian-z'); call gaussian(amplYY_chiral,f,iYY_chiral,kz=kz_YY_chiral)
        case('positive-noise'); call posnoise(amplYY_chiral,f,iYY_chiral)
        case('wave-x'); call wave(amplYY_chiral,f,iYY_chiral,kx=kx_YY_chiral)
        case('wave-y'); call wave(amplYY_chiral,f,iYY_chiral,ky=ky_YY_chiral)
        case('wave-z'); call wave(amplYY_chiral,f,iYY_chiral,kz=kz_YY_chiral)
        case('cosx_cosy_cosz'); call cosx_cosy_cosz(amplYY_chiral,f,iYY_chiral,kx_YY_chiral,ky_YY_chiral,kz_YY_chiral)
        case default; call stop_it('init_chiral: bad init_chiral='//trim(initYY_chiral))
      endselect
!
      if(ip==0) print*,xx,yy,zz !(prevent compiler warnings)
    endsubroutine init_chiral
!***********************************************************************
    subroutine dXY_chiral_dt(f,df,uu)
!
!  passive scalar evolution
!  calculate chirality equations in reduced form; see q-bio/0401036
!
!  28-may-04/axel: adapted from pscalar
!
      use Sub
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (nx,3) :: uu,gXX_chiral,gYY_chiral
      real, dimension (nx) :: XX_chiral,ugXX_chiral,del2XX_chiral,dXX_chiral
      real, dimension (nx) :: YY_chiral,ugYY_chiral,del2YY_chiral,dYY_chiral
      real, dimension (nx) :: RRXX_chiral,XX2_chiral
      real, dimension (nx) :: RRYY_chiral,YY2_chiral
      real, dimension (nx) :: RR21_chiral
      real, dimension (nx) :: QQ_chiral,QQ21_chiral,QQ21QQ_chiral
      real :: pp,qq
      integer :: j
!
      intent(in)  :: f,uu
      intent(out) :: df
!
!  identify module and boundary conditions
!
      if (headtt.or.ldebug) print*,'SOLVE dXY_dt'
      if (headtt) call identify_bcs('XX_chiral',iXX_chiral)
      if (headtt) call identify_bcs('YY_chiral',iYY_chiral)
!
!  gradient of passive scalar
!
      call grad(f,iXX_chiral,gXX_chiral)
      call grad(f,iYY_chiral,gYY_chiral)
      call dot_mn(uu,gXX_chiral,ugXX_chiral)
      call dot_mn(uu,gYY_chiral,ugYY_chiral)
!
!  advection term
!
      if(lhydro) df(l1:l2,m,n,iXX_chiral)=df(l1:l2,m,n,iXX_chiral)-ugXX_chiral
      if(lhydro) df(l1:l2,m,n,iYY_chiral)=df(l1:l2,m,n,iYY_chiral)-ugYY_chiral
!
!  diffusion term
!
      call del2(f,iXX_chiral,del2XX_chiral)
      call del2(f,iYY_chiral,del2YY_chiral)
      df(l1:l2,m,n,iXX_chiral)=df(l1:l2,m,n,iXX_chiral)+chiral_diff*del2XX_chiral
      df(l1:l2,m,n,iYY_chiral)=df(l1:l2,m,n,iYY_chiral)+chiral_diff*del2YY_chiral
!
!  reaction terms
!  X^2/Rtilde^2 - X*R
!  Y^2/Rtilde^2 - Y*R
!
!  for finite crossinhibition (=kI/kS) and finite fidelity (=f) we have
!  R --> RX=X+Y*kI/kS, R --> RY=Y+X*kI/kS, and
!  X2tilde=X^2/2RX, Y2tilde=Y^2/2RY.
!
      XX_chiral=f(l1:l2,m,n,iXX_chiral)
      YY_chiral=f(l1:l2,m,n,iYY_chiral)
      RRXX_chiral=XX_chiral+YY_chiral*chiral_crossinhibition
      RRYY_chiral=YY_chiral+XX_chiral*chiral_crossinhibition
!
!  abbreviations for quadratic quantities
!
      XX2_chiral=.5*XX_chiral**2/RRXX_chiral
      YY2_chiral=.5*YY_chiral**2/RRYY_chiral
      RR21_chiral=1./(XX2_chiral+YY2_chiral)
!
!  fidelity factor
!
      pp=.5*(1.+chiral_fidelity)
      qq=.5*(1.-chiral_fidelity)
!
!  final reaction equation
!
      dXX_chiral=(pp*XX2_chiral+qq*YY2_chiral)*RR21_chiral-XX_chiral*RRXX_chiral
      dYY_chiral=(pp*YY2_chiral+qq*XX2_chiral)*RR21_chiral-YY_chiral*RRYY_chiral
      df(l1:l2,m,n,iXX_chiral)=df(l1:l2,m,n,iXX_chiral)+dXX_chiral
      df(l1:l2,m,n,iYY_chiral)=df(l1:l2,m,n,iYY_chiral)+dYY_chiral
!
!  For the timestep calculation, need maximum diffusion
!
        if (lfirst.and.ldt) then
          call max_for_dt(chiral_diff,maxdiffus)
        endif
!
!  diagnostics
!
!  output for double and triple correlators (assume z-gradient of cc)
!  <u_k u_j d_j c> = <u_k c uu.gradXX_chiral>
!
      if (ldiagnos) then
        if (i_XX_chiralmax/=0) call max_mn_name(XX_chiral,i_XX_chiralmax)
        if (i_YY_chiralmax/=0) call max_mn_name(YY_chiral,i_YY_chiralmax)
        if (i_XX_chiralm/=0) call sum_mn_name(XX_chiral,i_XX_chiralm)
        if (i_YY_chiralm/=0) call sum_mn_name(YY_chiral,i_YY_chiralm)
!
!  extra diagnostics
!
        QQ_chiral=XX_chiral-YY_chiral
        QQ21_chiral=1.-QQ_chiral**2
        QQ21QQ_chiral=(1.-QQ_chiral**2)/(1.+QQ_chiral**2)*QQ_chiral
        if (i_QQm_chiral/=0) call sum_mn_name(QQ_chiral,i_QQm_chiral)
        if (i_QQ21m_chiral/=0) call sum_mn_name(QQ21_chiral,i_QQ21m_chiral)
        if (i_QQ21QQm_chiral/=0) call sum_mn_name(QQ21QQ_chiral,i_QQ21QQm_chiral)
      endif
!
    endsubroutine dXY_chiral_dt
!***********************************************************************
    subroutine rprint_chiral(lreset,lwrite)
!
!  reads and registers print parameters relevant for magnetic fields
!
!  28-may-04/axel: adapted from pscalar
!
      use Sub
!
      integer :: iname,inamez
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
        i_XX_chiralmax=0; i_XX_chiralm=0
        i_YY_chiralmax=0; i_YY_chiralm=0
        i_QQm_chiral=0; i_QQ21m_chiral=0; i_QQ21QQm_chiral=0
      endif
!
!  check for those quantities that we want to evaluate online
!
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'XXm',i_XX_chiralm)
        call parse_name(iname,cname(iname),cform(iname),'YYm',i_YY_chiralm)
        call parse_name(iname,cname(iname),cform(iname),'XXmax',i_XX_chiralmax)
        call parse_name(iname,cname(iname),cform(iname),'YYmax',i_YY_chiralmax)
        call parse_name(iname,cname(iname),cform(iname),'QQm',i_QQm_chiral)
        call parse_name(iname,cname(iname),cform(iname),'QQ21m',i_QQ21m_chiral)
        call parse_name(iname,cname(iname),cform(iname),'QQ21QQm',i_QQ21QQm_chiral)
      enddo
!
!  write column where which magnetic variable is stored
!
      if (lwr) then
        write(3,*) 'i_XX_chiralm=',i_XX_chiralm
        write(3,*) 'i_YY_chiralm=',i_YY_chiralm
        write(3,*) 'i_XX_chiralmax=',i_XX_chiralmax
        write(3,*) 'i_YY_chiralmax=',i_YY_chiralmax
        write(3,*) 'i_QQm_chiral=',i_QQm_chiral
        write(3,*) 'i_QQ21m_chiral=',i_QQ21m_chiral
        write(3,*) 'i_QQ21QQm_chiral=',i_QQ21QQm_chiral
        write(3,*) 'iXX_chiral=',iXX_chiral
        write(3,*) 'iYY_chiral=',iYY_chiral
      endif
!
    endsubroutine rprint_chiral
!***********************************************************************

endmodule Chiral

