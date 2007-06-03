! $Id: pscalar_nolog.f90,v 1.58 2007-06-03 10:03:02 ajohan Exp $

!  This modules solves the passive scalar advection equation
!  Solves for c, not lnc.

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! MVAR CONTRIBUTION 1
! MAUX CONTRIBUTION 0
!
! PENCILS PROVIDED cc,cc1,gcc,ugcc,gcc2,gcc1,del2cc,hcc
! PENCILS PROVIDED del6cc,g5cc,g5ccglnrho
!
!***************************************************************

module Pscalar

  use Cparam
  use Cdata
  use Messages

  implicit none

  include 'pscalar.h'

  ! keep old name for backward compatibility
  character (len=labellen) :: initlncc='impossible', initlncc2='impossible'

  character (len=labellen) :: initcc='zero', initcc2='zero'
  character (len=40) :: tensor_pscalar_file
  logical :: nopscalar=.false.,reinitalize_cc=.false.
  logical :: reinitalize_lncc=.false.

  ! keep old name for backward compatibility
  real :: ampllncc=impossible, widthlncc=impossible, lncc_min
  real :: ampllncc2=impossible,radius_lncc=impossible
  real :: kx_lncc=impossible,ky_lncc=impossible,kz_lncc=impossible
  real :: epsilon_lncc=impossible

  ! input parameters
  real :: amplcc=.1, widthcc=.5, cc_min=0.
  real :: amplcc2=0.,kx_cc=1.,ky_cc=1.,kz_cc=1.,radius_cc=0.
  real :: epsilon_cc=0., cc_const=1.
  real, dimension(3) :: gradC0=(/0.,0.,0./)

  namelist /pscalar_init_pars/ &
       initcc,initcc2,amplcc,amplcc2,kx_cc,ky_cc,kz_cc, &
       radius_cc,epsilon_cc,widthcc,cc_min,cc_const, &
       ! keep old names
       initlncc,initlncc2,ampllncc,ampllncc2,kx_lncc,ky_lncc,kz_lncc, &
       radius_lncc,epsilon_lncc,widthlncc

  ! run parameters
  real :: pscalar_diff=0., tensor_pscalar_diff=0., soret_diff=0.
  real :: pscalar_diff_hyper3=0.0, rhoccm=0., cc2m=0., gcc2m=0.
  real :: pscalar_sink=0., Rpscalar_sink=0.5
  logical :: lpscalar_sink

  namelist /pscalar_run_pars/ &
       pscalar_diff,nopscalar,tensor_pscalar_diff,gradC0,soret_diff, &
       pscalar_diff_hyper3,reinitalize_lncc,reinitalize_cc, &
       lpscalar_sink,pscalar_sink,Rpscalar_sink

  ! other variables (needs to be consistent with reset list below)
  integer :: idiag_rhoccm=0,idiag_ccmax=0,idiag_ccmin=0.,idiag_ccm=0
  integer :: idiag_Qrhoccm=0,idiag_Qpsclm=0,idiag_mcct=0
  integer :: idiag_ccmz=0,idiag_gcc5m=0,idiag_gcc10m=0
  integer :: idiag_ucm=0,idiag_uudcm=0,idiag_Cz2m=0,idiag_Cz4m=0,idiag_Crmsm=0
  integer :: idiag_uxcm=0,idiag_uycm=0,idiag_uzcm=0
  integer :: idiag_cc1m=0,idiag_cc2m=0,idiag_cc3m=0,idiag_cc4m=0,idiag_cc5m=0
  integer :: idiag_cc6m=0,idiag_cc7m=0,idiag_cc8m=0,idiag_cc9m=0,idiag_cc10m=0
  integer :: idiag_gcc1m=0,idiag_gcc2m=0,idiag_gcc3m=0,idiag_gcc4m=0
  integer :: idiag_gcc6m=0,idiag_gcc7m=0,idiag_gcc8m=0,idiag_gcc9m=0

  contains

!***********************************************************************
    subroutine register_pscalar()
!
!  Initialise variables which should know that we solve for passive
!  scalar: icc; increase nvar accordingly
!
!  6-jul-02/axel: coded
!
      use Cdata
      use Mpicomm
      use Sub
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_cc called twice')
      first = .false.
!
      lpscalar = .true.
      lpscalar_nolog = .true.
      ilncc = 0                 ! needed for idl
      icc = nvar+1              ! index to access cc
      nvar = nvar+1             ! added 1 variable
!
      if ((ip<=8) .and. lroot) then
        print*, 'Register_cc:  nvar = ', nvar
        print*, 'icc = ', icc
      endif
!
!  Put variable names in array
!
      varname(icc) = 'cc'
!
!  identify version number
!
      if (lroot) call cvs_id( &
           "$Id: pscalar_nolog.f90,v 1.58 2007-06-03 10:03:02 ajohan Exp $")
!
      if (nvar > mvar) then
        if (lroot) write(0,*) 'nvar = ', nvar, ', mvar = ', mvar
        call stop_it('Register_cc: nvar > mvar')
      endif
!
    endsubroutine register_pscalar
!***********************************************************************
    subroutine initialize_pscalar(f)
!
!  Perform any necessary post-parameter read initialization
!  Since the passive scalar is often used for diagnostic purposes
!  one may want to reinitialize it to its initial distribution.
!
!  24-nov-02/tony: coded
!  20-may-03/axel: reinitalize_cc added
!
      real, dimension (mx,my,mz,mfarray) :: f
!
!  set to zero and then call the same initial condition
!  that was used in start.csh
!
      if (reinitalize_cc) then
        f(:,:,:,icc)=0.
        call init_lncc_simple(f)
      endif
!
    endsubroutine initialize_pscalar
!***********************************************************************
    subroutine init_lncc_simple(f)
!
!  initialise passive scalar field; called from start.f90
!
!   6-jul-2001/axel: coded
!
      use Cdata
      use Mpicomm
      use Density
      use Sub
      use Initcond
!
      real, dimension (mx,my,mz,mfarray) :: f
!
!  identify module
!
      if (lroot) print*,'init_lncc_simple; initcc=',initcc
!
      ! for the time being, keep old name for backward compatibility
      if (initlncc/='impossible') initcc=initlncc
      if (initlncc2/='impossible') initcc2=initlncc2
      if (ampllncc/=impossible) amplcc=ampllncc
      if (ampllncc2/=impossible) amplcc2=ampllncc2
      if (kx_lncc/=impossible) kx_cc=kx_lncc
      if (ky_lncc/=impossible) ky_cc=ky_lncc
      if (kz_lncc/=impossible) kz_cc=kz_lncc
      if (radius_lncc/=impossible) radius_cc=radius_lncc
      if (epsilon_lncc/=impossible) epsilon_cc=epsilon_lncc
      if (widthlncc/=impossible) widthcc=widthlncc
!
      select case(initcc)
        case('zero'); f(:,:,:,icc)=0.
        case('constant'); f(:,:,:,icc)=cc_const
        case('hat-x'); call hat(amplcc,f,icc,widthcc,kx=kx_cc)
        case('hat-y'); call hat(amplcc,f,icc,widthcc,ky=ky_cc)
        case('hat-z'); call hat(amplcc,f,icc,widthcc,kz=kz_cc)
        case('gaussian-x'); call gaussian(amplcc,f,icc,kx=kx_cc)
        case('gaussian-y'); call gaussian(amplcc,f,icc,ky=ky_cc)
        case('gaussian-z'); call gaussian(amplcc,f,icc,kz=kz_cc)
        case('parabola-x'); call parabola(amplcc,f,icc,kx=kx_cc)
        case('parabola-y'); call parabola(amplcc,f,icc,ky=ky_cc)
        case('parabola-z'); call parabola(amplcc,f,icc,kz=kz_cc)
        case('gaussian-noise'); call gaunoise(amplcc,f,icc,icc)
        case('wave-x'); call wave(amplcc,f,icc,kx=kx_cc)
        case('wave-y'); call wave(amplcc,f,icc,ky=ky_cc)
        case('wave-z'); call wave(amplcc,f,icc,kz=kz_cc)
        case('propto-ux'); call wave_uu(amplcc,f,icc,kx=kx_cc)
        case('propto-uy'); call wave_uu(amplcc,f,icc,ky=ky_cc)
        case('propto-uz'); call wave_uu(amplcc,f,icc,kz=kz_cc)
        case('cosx_cosy_cosz'); call cosx_cosy_cosz(amplcc,f,icc,kx_cc,ky_cc,kz_cc)
        case default; call stop_it('init_lncc: bad initcc='//trim(initcc))
      endselect
!
!  superimpose something else
!
      select case(initcc2)
        case('wave-x'); call wave(amplcc2,f,icc,ky=5.)
      endselect
!
!  add floor value if cc_min is set
!
      if (cc_min/=0.) then
        if (lroot) print*,'set floor value for cc; cc_min=',cc_min
        f(:,:,:,icc)=max(cc_min,f(:,:,:,icc))
      endif
!
    endsubroutine init_lncc_simple
!***********************************************************************
    subroutine init_lncc(f,xx,yy,zz)
!
!  initialise passive scalar field; called from start.f90
!
!   6-jul-2001/axel: coded
!
      use Cdata
      use Mpicomm
      use Density
      use Sub
      use Initcond
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz)      :: xx,yy,zz,prof
!
      ! for the time being, keep old name for backward compatibility
      if (initlncc/='impossible') initcc=initlncc
      if (initlncc2/='impossible') initcc2=initlncc2
      if (ampllncc/=impossible) amplcc=ampllncc
      if (ampllncc2/=impossible) amplcc2=ampllncc2
      if (kx_lncc/=impossible) kx_cc=kx_lncc
      if (ky_lncc/=impossible) ky_cc=ky_lncc
      if (kz_lncc/=impossible) kz_cc=kz_lncc
      if (radius_lncc/=impossible) radius_cc=radius_lncc
      if (epsilon_lncc/=impossible) epsilon_cc=epsilon_lncc
      if (widthlncc/=impossible) widthcc=widthlncc
!
      select case(initcc)
        case('zero'); f(:,:,:,icc)=0.
        case('constant'); f(:,:,:,icc)=cc_const
        case('hat-x'); call hat(amplcc,f,icc,widthcc,kx=kx_cc)
        case('hat-y'); call hat(amplcc,f,icc,widthcc,ky=ky_cc)
        case('hat-z'); call hat(amplcc,f,icc,widthcc,kz=kz_cc)
        case('gaussian-x'); call gaussian(amplcc,f,icc,kx=kx_cc)
        case('gaussian-y'); call gaussian(amplcc,f,icc,ky=ky_cc)
        case('gaussian-z'); call gaussian(amplcc,f,icc,kz=kz_cc)
        case('parabola-x'); call parabola(amplcc,f,icc,kx=kx_cc)
        case('parabola-y'); call parabola(amplcc,f,icc,ky=ky_cc)
        case('parabola-z'); call parabola(amplcc,f,icc,kz=kz_cc)
        case('gaussian-noise'); call gaunoise(amplcc,f,icc,icc)
        case('wave-x'); call wave(amplcc,f,icc,kx=kx_cc)
        case('wave-y'); call wave(amplcc,f,icc,ky=ky_cc)
        case('wave-z'); call wave(amplcc,f,icc,kz=kz_cc)
        case('propto-ux'); call wave_uu(amplcc,f,icc,kx=kx_cc)
        case('propto-uy'); call wave_uu(amplcc,f,icc,ky=ky_cc)
        case('propto-uz'); call wave_uu(amplcc,f,icc,kz=kz_cc)
        case('cosx_cosy_cosz'); call cosx_cosy_cosz(amplcc,f,icc,kx_cc,ky_cc,kz_cc)
        case('sound-wave'); f(:,:,:,icc)=-amplcc*cos(kx_cc*xx)
        case('tang-discont-z')
           print*,'init_lncc: widthcc=',widthcc
        prof=.5*(1.+tanh(zz/widthcc))
        f(:,:,:,icc)=-1.+2.*prof
        case('hor-tube'); call htube2(amplcc,f,icc,icc,xx,yy,zz,radius_cc,epsilon_cc)
        case('jump'); call jump(f,icc,cc_const,0.,widthcc,'z')
        case default; call stop_it('init_lncc: bad initcc='//trim(initcc))
      endselect

!
!  superimpose something else
!
      select case(initcc2)
        case('wave-x'); call wave(amplcc2,f,icc,ky=5.)
      endselect
!
!  add floor value if cc_min is set
!
      if (cc_min/=0.) then
        if (lroot) print*,'set floor value for cc; cc_min=',cc_min
        f(:,:,:,icc)=max(cc_min,f(:,:,:,icc))
      endif
!
      if (NO_WARN) print*,xx,yy,zz !(prevent compiler warnings)
    endsubroutine init_lncc
!***********************************************************************
    subroutine pencil_criteria_pscalar()
!
!  All pencils that the Pscalar module depends on are specified here.
!
!  20-11-04/anders: coded
!
      integer :: i
!
      if (.not. nopscalar) lpenc_requested(i_ugcc)=.true.
      if (lpscalar_sink) lpenc_requested(i_rho1)=.true.
      if (pscalar_diff/=0.) then
        lpenc_requested(i_gcc)=.true.
        lpenc_requested(i_glnrho)=.true.
      endif
      if (soret_diff/=0.) then
        lpenc_requested(i_cc)=.true.
        lpenc_requested(i_TT)=.true.
        lpenc_requested(i_glnTT)=.true.
        lpenc_requested(i_del2lnTT)=.true.
      endif
      do i=1,3
        if (gradC0(i)/=0.) lpenc_requested(i_uu)=.true.
      enddo
      if (pscalar_diff/=0.) lpenc_requested(i_del2cc)=.true.
      if (tensor_pscalar_diff/=0.) lpenc_requested(i_hcc)=.true.
      if (pscalar_diff_hyper3/=0.0) then
        lpenc_requested(i_del6cc)=.true.
        lpenc_requested(i_g5ccglnrho)=.true.
      endif
!
      lpenc_diagnos(i_cc)=.true.
      if (idiag_rhoccm/=0 .or. idiag_Cz2m/=0 .or. idiag_Cz4m/=0 .or. &
          idiag_Qrhoccm/=0 .or. idiag_Qpsclm/=0) &
          lpenc_diagnos(i_rho)=.true.
      if (idiag_ucm/=0 .or. idiag_uudcm/=0 .or. idiag_uxcm/=0 .or. &
          idiag_uycm/=0 .or. idiag_uzcm/=0 ) lpenc_diagnos(i_uu)=.true.
      if (idiag_uudcm/=0) lpenc_diagnos(i_ugcc)=.true.
      if (idiag_cc1m/=0 .or. idiag_cc2m/=0 .or. idiag_cc3m/=0 .or. &
          idiag_cc4m/=0 .or. idiag_cc5m/=0 .or. idiag_cc6m/=0 .or. &
          idiag_cc7m/=0 .or. idiag_cc8m/=0 .or. idiag_cc9m/=0 .or. &
          idiag_cc10m/=0) lpenc_diagnos(i_cc1)=.true.
      if (idiag_gcc1m/=0 .or. idiag_gcc2m/=0 .or. idiag_gcc3m/=0 .or. &
          idiag_gcc4m/=0 .or. idiag_gcc5m/=0 .or. idiag_gcc6m/=0 .or. &
          idiag_gcc7m/=0 .or. idiag_gcc8m/=0 .or. idiag_gcc9m/=0 .or. &
          idiag_gcc10m/=0) lpenc_diagnos(i_gcc1)=.true.
!
    endsubroutine pencil_criteria_pscalar
!***********************************************************************
    subroutine pencil_interdep_pscalar(lpencil_in)
!
!  Interdependency among pencils provided by the Pscalar module
!  is specified here.
!
!  20-11-04/anders: coded
!
      logical, dimension(npencils) :: lpencil_in
!
      if (lpencil_in(i_cc1)) lpencil_in(i_cc)=.true.
      if (lpencil_in(i_ugcc)) then
        lpencil_in(i_uu)=.true.
        lpencil_in(i_gcc)=.true.
      endif
      if (lpencil_in(i_g5ccglnrho)) then
        lpencil_in(i_g5cc)=.true.
        lpencil_in(i_glnrho)=.true.
      endif
      if (lpencil_in(i_gcc2)) lpencil_in(i_gcc)=.true.
      if (lpencil_in(i_gcc1)) lpencil_in(i_gcc2)=.true.
      if (tensor_pscalar_diff/=0.) lpencil_in(i_gcc)=.true.
!
    endsubroutine pencil_interdep_pscalar
!**********************************************************************
    subroutine calc_pencils_pscalar(f,p)
!
!  Calculate pscalar Pencils.
!  Most basic pencils should come first, as others may depend on them.
!
!  20-11-04/anders: coded
!
      use Cdata
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      intent(in) :: f
      intent(inout) :: p
! cc
      if (lpencil(i_cc)) p%cc=f(l1:l2,m,n,icc)
! cc1
      if (lpencil(i_cc1)) p%cc1=1/p%cc
! gcc
      if (lpencil(i_gcc)) call grad(f,icc,p%gcc)
! ugcc
      if (lpencil(i_ugcc)) call dot_mn(p%uu,p%gcc,p%ugcc)
! gcc2
      if (lpencil(i_gcc2)) call dot2_mn(p%gcc,p%gcc2)
! gcc1
      if (lpencil(i_gcc1)) p%gcc1=sqrt(p%gcc2)
! del2cc
      if (lpencil(i_del2cc)) call del2(f,icc,p%del2cc)
! hcc
      if (lpencil(i_hcc)) call g2ij(f,icc,p%hcc)
! del6cc
      if (lpencil(i_del6cc)) call del6(f,icc,p%del6cc)
! g5cc
      if (lpencil(i_g5cc)) call grad5(f,icc,p%g5cc)
! g5cc
      if (lpencil(i_g5ccglnrho)) then
        call dot_mn(p%g5cc,p%glnrho,p%g5ccglnrho)
      endif
!
    endsubroutine calc_pencils_pscalar
!***********************************************************************
    subroutine dlncc_dt(f,df,p)
!
!  passive scalar evolution
!  calculate dc/dt=-uu.gcc + pscalar_diff*[del2cc + glnrho.gcc]
!
!  20-may-03/axel: coded
!
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      real, dimension (nx) :: diff_op,diff_op2,bump
      integer :: j
!
      intent(in)  :: f
      intent(out) :: df
!
!  identify module and boundary conditions
!
      if (nopscalar) then
        if (headtt.or.ldebug) print*,'not SOLVED: dlncc_dt'
      else
        if (headtt.or.ldebug) print*,'SOLVE dlncc_dt'
      endif
      if (headtt) call identify_bcs('cc',icc)
!
!  gradient of passive scalar
!  allow for possibility to turn off passive scalar
!  without changing file size and recompiling everything.
!
      if (.not. nopscalar) then ! i.e. if (pscalar)
!
!  passive scalar equation
!
        df(l1:l2,m,n,icc) = df(l1:l2,m,n,icc) - p%ugcc
!
!  passive scalar sink
!
        if (lpscalar_sink) then
!          if (lagrangian) then
!            call interp(rsink,usink,ir,iuu,f)
!            rsink=rsink+usink*dt
!          else
!            rsink=0.
!          endif
          bump=pscalar_sink* &
          exp(-.5*(x(l1:l2)**2+y(m)**2+z(n)**2)/Rpscalar_sink**2)
!          exp(-.5*((x(l1:l2)-rsink(0))**2+(y(m)-rsink(1))**2+(z(n)-rsink(2))**2)/Rpscalar_sink**2)
          df(l1:l2,m,n,icc)=df(l1:l2,m,n,icc)-bump*f(l1:l2,m,n,icc)
        endif
!
!  diffusion operator
!
        if (pscalar_diff/=0.) then
          if (headtt) print*,'dlncc_dt: pscalar_diff=',pscalar_diff
          call dot_mn(p%glnrho,p%gcc,diff_op)
          diff_op=diff_op+p%del2cc
          df(l1:l2,m,n,icc) = df(l1:l2,m,n,icc) + pscalar_diff*diff_op
        endif
!
!  hyperdiffusion operator
!
        if (pscalar_diff_hyper3/=0.) then
          if (headtt) &
              print*,'dlncc_dt: pscalar_diff_hyper3=', pscalar_diff_hyper3
          df(l1:l2,m,n,icc) = df(l1:l2,m,n,icc) + &
              pscalar_diff_hyper3*(p%del6cc+p%g5ccglnrho)
        endif
!
!  Soret diffusion
!
        if (soret_diff/=0.) then
          if (headtt) print*,'dlncc_dt: soret_diff=',soret_diff
          call dot2_mn(p%glnTT,diff_op2)
          diff_op2=p%cc*(1.-p%cc)*p%TT*(diff_op2+p%del2lnTT)
          df(l1:l2,m,n,icc) = df(l1:l2,m,n,icc) + soret_diff*diff_op2
        endif
!
!  add diffusion of imposed constant gradient of c
!  restrict ourselves (for the time being) to z-gradient only
!  makes sense really only for periodic boundary conditions
!
        do j=1,3
          if (gradC0(j)/=0.) then
            df(l1:l2,m,n,icc) = df(l1:l2,m,n,icc) - gradC0(j)*p%uu(:,j)
          endif
        enddo
!
!  tensor diffusion (but keep the isotropic one)
!
        if (tensor_pscalar_diff/=0.) &
            call tensor_diff(f,df,p,tensor_pscalar_diff)
!
!  For the timestep calculation, need maximum diffusion
!
        if (lfirst.and.ldt) then
          diffus_pscalar=max(diffus_pscalar,pscalar_diff*dxyz_2)
          diffus_pscalar=max(diffus_pscalar,tensor_pscalar_diff*dxyz_2)
        endif
!
      endif
!
!  diagnostics
!
!  output for double and triple correlators (assume z-gradient of cc)
!  <u_k u_j d_j c> = <u_k c uu.gradcc>
!
      if (ldiagnos) then
        if (idiag_Qpsclm/=0)  call sum_mn_name(bump,idiag_Qpsclm)
        if (idiag_Qrhoccm/=0) call sum_mn_name(bump*p%rho*p%cc,idiag_Qrhoccm)
        if (idiag_mcct/=0)    call integrate_mn_name(p%rho*p%cc,idiag_mcct)
        if (idiag_rhoccm/=0)  call sum_mn_name(p%rho*p%cc,idiag_rhoccm)
        if (idiag_ccmax/=0)   call max_mn_name(p%cc,idiag_ccmax)
        if (idiag_ccmin/=0)   call max_mn_name(-p%cc,idiag_ccmin,lneg=.true.)
        if (idiag_uxcm/=0)    call sum_mn_name(p%uu(:,1)*p%cc,idiag_uxcm)
        if (idiag_uycm/=0)    call sum_mn_name(p%uu(:,2)*p%cc,idiag_uycm)
        if (idiag_uzcm/=0)    call sum_mn_name(p%uu(:,3)*p%cc,idiag_uzcm)
        if (idiag_ucm/=0)     call sum_mn_name(p%uu(:,3)*p%cc,idiag_ucm)
        if (idiag_uudcm/=0)   call sum_mn_name(p%uu(:,3)*p%ugcc,idiag_uudcm)
        if (idiag_Cz2m/=0)    call sum_mn_name(p%rho*p%cc*z(n)**2,idiag_Cz2m)
        if (idiag_Cz4m/=0)    call sum_mn_name(p%rho*p%cc*z(n)**4,idiag_Cz4m)
        if (idiag_Crmsm/=0) &
            call sum_mn_name((p%rho*p%cc)**2,idiag_Crmsm,lsqrt=.true.)
        if (idiag_cc1m/=0)    call sum_mn_name(p%cc1   ,idiag_cc1m)
        if (idiag_cc2m/=0)    call sum_mn_name(p%cc1**2,idiag_cc2m)
        if (idiag_cc3m/=0)    call sum_mn_name(p%cc1**3,idiag_cc3m)
        if (idiag_cc4m/=0)    call sum_mn_name(p%cc1**4,idiag_cc4m)
        if (idiag_cc5m/=0)    call sum_mn_name(p%cc1**5,idiag_cc5m)
        if (idiag_cc6m/=0)    call sum_mn_name(p%cc1**6,idiag_cc6m)
        if (idiag_cc7m/=0)    call sum_mn_name(p%cc1**7,idiag_cc7m)
        if (idiag_cc8m/=0)    call sum_mn_name(p%cc1**8,idiag_cc8m)
        if (idiag_cc9m/=0)    call sum_mn_name(p%cc1**9,idiag_cc9m)
        if (idiag_cc10m/=0)   call sum_mn_name(p%cc1**10,idiag_cc10m)
        if (idiag_gcc1m/=0)   call sum_mn_name(p%gcc1   ,idiag_gcc1m)
        if (idiag_gcc2m/=0)   call sum_mn_name(p%gcc1**2,idiag_gcc2m)
        if (idiag_gcc3m/=0)   call sum_mn_name(p%gcc1**3,idiag_gcc3m)
        if (idiag_gcc4m/=0)   call sum_mn_name(p%gcc1**4,idiag_gcc4m)
        if (idiag_gcc5m/=0)   call sum_mn_name(p%gcc1**5,idiag_gcc5m)
        if (idiag_gcc6m/=0)   call sum_mn_name(p%gcc1**6,idiag_gcc6m)
        if (idiag_gcc7m/=0)   call sum_mn_name(p%gcc1**7,idiag_gcc7m)
        if (idiag_gcc8m/=0)   call sum_mn_name(p%gcc1**8,idiag_gcc8m)
        if (idiag_gcc9m/=0)   call sum_mn_name(p%gcc1**9,idiag_gcc9m)
        if (idiag_gcc10m/=0)  call sum_mn_name(p%gcc1**10,idiag_gcc10m)
      endif
!
      if (l1ddiagnos) then
        if (idiag_ccmz/=0)    call xysum_mn_name_z(p%cc,idiag_ccmz)
      endif
!
    endsubroutine dlncc_dt
!***********************************************************************
    subroutine read_pscalar_init_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) then
        read(unit,NML=pscalar_init_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=pscalar_init_pars,ERR=99)
      endif


99    return
    endsubroutine read_pscalar_init_pars
!***********************************************************************
    subroutine write_pscalar_init_pars(unit)
      integer, intent(in) :: unit

      write(unit,NML=pscalar_init_pars)

    endsubroutine write_pscalar_init_pars
!***********************************************************************
    subroutine read_pscalar_run_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) then
        read(unit,NML=pscalar_run_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=pscalar_run_pars,ERR=99)
      endif


99    return
    endsubroutine read_pscalar_run_pars
!***********************************************************************
    subroutine write_pscalar_run_pars(unit)
      integer, intent(in) :: unit

      write(unit,NML=pscalar_run_pars)

    endsubroutine write_pscalar_run_pars
!***********************************************************************
    subroutine rprint_pscalar(lreset,lwrite)
!
!  reads and registers print parameters relevant for passive scalar
!
!   6-jul-02/axel: coded
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
        idiag_rhoccm=0; idiag_ccmax=0; idiag_ccmin=0.; idiag_ccm=0
        idiag_Qrhoccm=0; idiag_Qpsclm=0; idiag_mcct=0
        idiag_ccmz=0;
        idiag_ucm=0; idiag_uudcm=0; idiag_Cz2m=0; idiag_Cz4m=0; idiag_Crmsm=0
        idiag_uxcm=0; idiag_uycm=0; idiag_uzcm=0
        idiag_cc1m=0; idiag_cc2m=0; idiag_cc3m=0; idiag_cc4m=0; idiag_cc5m=0
        idiag_cc6m=0; idiag_cc7m=0; idiag_cc8m=0; idiag_cc9m=0; idiag_cc10m=0
        idiag_gcc1m=0; idiag_gcc2m=0; idiag_gcc3m=0; idiag_gcc4m=0
        idiag_gcc5m=0; idiag_gcc6m=0; idiag_gcc7m=0; idiag_gcc8m=0
        idiag_gcc9m=0; idiag_gcc10m=0
      endif
!
!  check for those quantities that we want to evaluate online
!
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'Qpsclm',idiag_Qpsclm)
        call parse_name(iname,cname(iname),cform(iname),'Qrhoccm',idiag_Qrhoccm)
        call parse_name(iname,cname(iname),cform(iname),'rhoccm',idiag_rhoccm)
        call parse_name(iname,cname(iname),cform(iname),'mcct',idiag_mcct)
        call parse_name(iname,cname(iname),cform(iname),'ccmax',idiag_ccmax)
        call parse_name(iname,cname(iname),cform(iname),'ccmin',idiag_ccmin)
        call parse_name(iname,cname(iname),cform(iname),'ccm',idiag_ccm)
        call parse_name(iname,cname(iname),cform(iname),'ucm',idiag_ucm)
        call parse_name(iname,cname(iname),cform(iname),'uxcm',idiag_uxcm)
        call parse_name(iname,cname(iname),cform(iname),'uycm',idiag_uycm)
        call parse_name(iname,cname(iname),cform(iname),'uzcm',idiag_uzcm)
        call parse_name(iname,cname(iname),cform(iname),'uudcm',idiag_uudcm)
        call parse_name(iname,cname(iname),cform(iname),'Cz2m',idiag_Cz2m)
        call parse_name(iname,cname(iname),cform(iname),'Cz4m',idiag_Cz4m)
        call parse_name(iname,cname(iname),cform(iname),'Crmsm',idiag_Crmsm)
        call parse_name(iname,cname(iname),cform(iname),'cc1m',idiag_cc1m)
        call parse_name(iname,cname(iname),cform(iname),'cc2m',idiag_cc2m)
        call parse_name(iname,cname(iname),cform(iname),'cc3m',idiag_cc3m)
        call parse_name(iname,cname(iname),cform(iname),'cc4m',idiag_cc4m)
        call parse_name(iname,cname(iname),cform(iname),'cc5m',idiag_cc5m)
        call parse_name(iname,cname(iname),cform(iname),'cc6m',idiag_cc6m)
        call parse_name(iname,cname(iname),cform(iname),'cc7m',idiag_cc7m)
        call parse_name(iname,cname(iname),cform(iname),'cc8m',idiag_cc8m)
        call parse_name(iname,cname(iname),cform(iname),'cc9m',idiag_cc9m)
        call parse_name(iname,cname(iname),cform(iname),'cc10m',idiag_cc10m)
        call parse_name(iname,cname(iname),cform(iname),'gcc1m',idiag_gcc1m)
        call parse_name(iname,cname(iname),cform(iname),'gcc2m',idiag_gcc2m)
        call parse_name(iname,cname(iname),cform(iname),'gcc3m',idiag_gcc3m)
        call parse_name(iname,cname(iname),cform(iname),'gcc4m',idiag_gcc4m)
        call parse_name(iname,cname(iname),cform(iname),'gcc5m',idiag_gcc5m)
        call parse_name(iname,cname(iname),cform(iname),'gcc6m',idiag_gcc6m)
        call parse_name(iname,cname(iname),cform(iname),'gcc7m',idiag_gcc7m)
        call parse_name(iname,cname(iname),cform(iname),'gcc8m',idiag_gcc8m)
        call parse_name(iname,cname(iname),cform(iname),'gcc9m',idiag_gcc9m)
        call parse_name(iname,cname(iname),cform(iname),'gcc10m',idiag_gcc10m)
      enddo
!
!  check for those quantities for which we want xy-averages
!
      do inamez=1,nnamez
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'ccmz',idiag_ccmz)
      enddo
!
!  write column where which passive scalar variable is stored
!
      if (lwr) then
        write(3,*) 'i_Qpsclm=',idiag_Qpsclm
        write(3,*) 'i_Qrhoccm=',idiag_Qrhoccm
        write(3,*) 'i_rhoccm=',idiag_rhoccm
        write(3,*) 'i_mcct=',idiag_mcct
        write(3,*) 'i_ccmax=',idiag_ccmax
        write(3,*) 'i_ccmin=',idiag_ccmin
        write(3,*) 'i_ccm=',idiag_ccm
        write(3,*) 'i_ucm=',idiag_ucm
        write(3,*) 'i_uxcm=',idiag_uxcm
        write(3,*) 'i_uycm=',idiag_uycm
        write(3,*) 'i_uzcm=',idiag_uzcm
        write(3,*) 'i_uudcm=',idiag_uudcm
        write(3,*) 'i_ccmz=',idiag_ccmz
        write(3,*) 'i_Cz2m=',idiag_Cz2m
        write(3,*) 'i_Cz4m=',idiag_Cz4m
        write(3,*) 'i_Crmsm=',idiag_Crmsm
        write(3,*) 'i_cc1m=',idiag_cc1m
        write(3,*) 'i_cc2m=',idiag_cc2m
        write(3,*) 'i_cc3m=',idiag_cc3m
        write(3,*) 'i_cc4m=',idiag_cc4m
        write(3,*) 'i_cc5m=',idiag_cc5m
        write(3,*) 'i_cc6m=',idiag_cc6m
        write(3,*) 'i_cc7m=',idiag_cc7m
        write(3,*) 'i_cc8m=',idiag_cc8m
        write(3,*) 'i_cc9m=',idiag_cc9m
        write(3,*) 'i_cc10m=',idiag_cc10m
        write(3,*) 'i_gcc1m=',idiag_gcc1m
        write(3,*) 'i_gcc2m=',idiag_gcc2m
        write(3,*) 'i_gcc3m=',idiag_gcc3m
        write(3,*) 'i_gcc4m=',idiag_gcc4m
        write(3,*) 'i_gcc5m=',idiag_gcc5m
        write(3,*) 'i_gcc6m=',idiag_gcc6m
        write(3,*) 'i_gcc7m=',idiag_gcc7m
        write(3,*) 'i_gcc8m=',idiag_gcc8m
        write(3,*) 'i_gcc9m=',idiag_gcc9m
        write(3,*) 'i_gcc10m=',idiag_gcc10m
        write(3,*) 'ilncc=0'
        write(3,*) 'icc=',icc
      endif
!
    endsubroutine rprint_pscalar
!***********************************************************************
    subroutine calc_mpscalar
!
!  calculate mean magnetic field from xy- or z-averages
!
!  14-apr-03/axel: adaped from calc_mfield
!
      use Cdata
      use Sub
!
      logical,save :: first=.true.
      real :: ccm
!
!  Magnetic energy in horizontally averaged field
!  The bxmz and bymz must have been calculated,
!  so they are present on the root processor.
!
      if (idiag_ccm/=0) then
        if (idiag_ccmz==0) then
          if (first) print*
          if (first) print*,"NOTE: to get ccm, ccmz must also be set in xyaver"
          if (first) print*,"      We proceed, but you'll get ccm=0"
          ccm=0.
        else
          ccm=sqrt(sum(fnamez(:,:,idiag_ccmz)**2)/(nz*nprocz))
        endif
        call save_name(ccm,idiag_ccm)
      endif
!
    endsubroutine calc_mpscalar
!***********************************************************************
    subroutine tensor_diff(f,df,p,tensor_pscalar_diff)
!
!  reads file
!
!  11-jul-02/axel: coded
!
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
      real :: tensor_pscalar_diff
!
      real, save, dimension (nx,ny,nz,3) :: bunit,hhh
      real, dimension (nx) :: tmp,scr
      integer :: iy,iz,i,j
      logical, save :: first=.true.
!
!  read H and Bunit arrays and keep them in memory
!
      if (first) then
        open(1,file=trim(directory)//'/bunit.dat',form='unformatted')
        print*,'read bunit.dat with dimension: ',nx,ny,nz,3
        read(1) bunit,hhh
        close(1)
        print*,'read bunit.dat; bunit=',bunit
      endif
!
!  tmp = (Bunit.G)^2 + H.G + Bi*Bj*Gij
!  for details, see tex/mhd/thcond/tensor_der.tex
!
      call dot_mn(bunit,p%gcc,scr)
      call dot_mn(hhh,p%gcc,tmp)
      tmp=tmp+scr**2
!
!  dot with bi*bj
!
      iy=m-m1+1
      iz=n-n1+1
      do j=1,3
      do i=1,3
        tmp=tmp+bunit(:,iy,iz,i)*bunit(:,iy,iz,j)*p%hcc(:,i,j)
      enddo
      enddo
!
!  and add result to the dcc/dt equation
!
      df(l1:l2,m,n,icc)=df(l1:l2,m,n,icc)+tensor_pscalar_diff*tmp
!
      first=.false.
    endsubroutine tensor_diff
!***********************************************************************

endmodule Pscalar



