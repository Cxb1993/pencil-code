! $Id: magnetic.f90 14421 2010-07-23 23:55:02Z Bourdin.KIS $
!
!  This modules solves mean-field contributions to both the
!  induction and the momentum equations.
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lmagnetic_mf = .true.
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
! PENCILS PROVIDED mf_EMF(3); mf_EMFdotB; jxb_mf(3); jxbr_mf(3)
!
!***************************************************************
module Magnetic_meanfield
!
  use Cdata
  use Cparam
  use Messages, only: fatal_error,inevitably_fatal_error,warning,svn_id,timing
  use Sub, only: keep_compiler_quiet
!
  implicit none
!
  include 'magnetic/meanfield.h'
!
!  array for inputting alpha profile
!
  real, dimension (mx,my) :: alpha_input
!
! Parameters
!
  character (len=labellen) :: Omega_profile='nothing', alpha_profile='const'
  character (len=labellen) :: meanfield_etat_profile='const'
  character (len=labellen) :: meanfield_Beq_profile='const'
  character (len=labellen) :: EMF_profile='nothing', delta_profile='const'
!
! Input parameters
!
  real :: Omega_ampl=0.0
  real :: alpha_effect=0.0, alpha_quenching=0.0, delta_effect=0.0
  real :: meanfield_etat=0.0, meanfield_etat_height=1., meanfield_pumping=1.
  real :: meanfield_Beq=1.0, meanfield_Beq_height=0.
  real :: alpha_eps=0.0
  real :: alpha_equator=impossible, alpha_equator_gap=0.0, alpha_gap_step=0.0
  real :: alpha_cutoff_up=0.0, alpha_cutoff_down=0.0
  real :: meanfield_qs=1.0, meanfield_qp=1.0, meanfield_qe=1.0
  real :: meanfield_Bs=1.0, meanfield_Bp=1.0, meanfield_Be=1.0
  real :: meanfield_kf=1.0, meanfield_etaB=0.0
  real :: dummy=0.0
  logical :: lOmega_effect=.false.
  logical :: lmeanfield_noalpm=.false., lmeanfield_pumping=.false.
  logical :: lmeanfield_jxb=.false., lmeanfield_jxb_with_vA2=.false.
  logical, pointer :: lmeanfield_theory
!
  namelist /magnetic_mf_init_pars/ &
      dummy
!
! Run parameters
!
  real :: meanfield_molecular_eta=0.0
  real :: alpha_rmax=0.0, alpha_width=0.0
  real :: Omega_rmax=0.0, Omega_rwidth=0.0
  real, dimension(mz) :: etat_z
  real, dimension(mz,3) :: getat_z
  logical :: llarge_scale_velocity=.false.
  logical :: lEMF_profile=.false.
  logical :: lalpha_profile_total=.false.
  logical :: ldelta_profile=.false.
!
  namelist /magnetic_mf_run_pars/ &
      alpha_effect, alpha_quenching, &
      alpha_eps, lmeanfield_noalpm, alpha_profile, &
      ldelta_profile, delta_effect, delta_profile, &
      meanfield_etat, meanfield_etat_height, meanfield_etat_profile, &
      meanfield_Beq, meanfield_Beq_height, meanfield_Beq_profile, &
      lmeanfield_pumping, meanfield_pumping, &
      lmeanfield_jxb, lmeanfield_jxb_with_vA2, &
      meanfield_qs, meanfield_qp, meanfield_qe, meanfield_Beq, &
      meanfield_Bs, meanfield_Bp, meanfield_Be, meanfield_kf, &
      meanfield_etaB, alpha_equator, alpha_equator_gap, alpha_gap_step, &
      alpha_cutoff_up, alpha_cutoff_down, &
      lOmega_effect, Omega_profile, Omega_ampl, &
      llarge_scale_velocity, EMF_profile, lEMF_profile, &
      Omega_rmax,Omega_rwidth
!
! Diagnostic variables (need to be consistent with reset list below)
! 
  integer :: idiag_qsm=0        ! DIAG_DOC: $\left<q_p(\overline{B})\right>$
  integer :: idiag_qpm=0        ! DIAG_DOC: $\left<q_p(\overline{B})\right>$
  integer :: idiag_qem=0        ! DIAG_DOC: $\left<q_e(\overline{B})\right>$
  integer :: idiag_alpm=0       ! DIAG_DOC: $\left<\alpha\right>$
  integer :: idiag_etatm=0      ! DIAG_DOC: $\left<\eta_{\rm t}\right>$
  integer :: idiag_EMFmz1=0     ! DIAG_DOC: $\left<{\cal E}\right>_{xy}|_x$
  integer :: idiag_EMFmz2=0     ! DIAG_DOC: $\left<{\cal E}\right>_{xy}|_y$
  integer :: idiag_EMFmz3=0     ! DIAG_DOC: $\left<{\cal E}\right>_{xy}|_z$
  integer :: idiag_EMFdotBm=0   ! DIAG_DOC: $\left<{\cal E}\cdot\Bv \right>$
  integer :: idiag_EMFdotB_int=0! DIAG_DOC: $\int{\cal E}\cdot\Bv dV$
!
  contains
!***********************************************************************
    subroutine initialize_magnetic_mf(f,lstarting)
!
!  Perform any post-parameter-read initialization
!
!  24-nov-02/tony: dummy routine - nothing to do at present
!  20-may-03/axel: reinitialize_aa added
!
      use BorderProfiles, only: request_border_driving
      use FArrayManager
      use SharedVariables, only: put_shared_variable,get_shared_variable
      use EquationOfState, only: cs0
!
      real, dimension (mx,my,mz,mfarray) :: f
      logical :: lstarting
      integer :: i,ierr
!
!  check for alpha profile
!
      if (alpha_profile=='read') then
        print*,'read alpha profile'
        open(1,file='alpha_input.dat',form='unformatted')
        read(1) alpha_input
        close(1)
      endif
!
!  write profile (uncomment for debugging)
!
!     if (lroot) then
!       do n=n1,n2
!         print*,z(n),eta_z(n)
!       enddo
!     endif
!
!  if meanfield theory is invoked, we want to send meanfield_etat to
!  other subroutines
!
      call get_shared_variable('lmeanfield_theory',lmeanfield_theory,ierr)
      if (ierr/=0) call fatal_error("initialize_magnetic_mf: ", &
              "cannot get shared variable lmeanfield_theory")
      if (lmeanfield_theory) then
        call put_shared_variable('meanfield_etat',meanfield_etat,ierr)
      endif
!
!  Compute etat profile and share with other routines.
!  Here we also set the etat_z and getat_z profiles.
!
      if (meanfield_etat/=0.0) then
        select case (meanfield_etat_profile)
        case ('const')
          etat_z=meanfield_etat
          getat_z=0.
        case ('exp(z/H)')
          etat_z=meanfield_etat*exp(z/meanfield_etat_height)
          getat_z(:,1:2)=0.
          getat_z(:,3)=etat_z/meanfield_etat_height
        case default;
          call inevitably_fatal_error('initialize_magnetic', &
          'no such meanfield_etat_profile profile')
        endselect
!
!  share etat profile with viscosity module
!
        if (lviscosity) then
          call put_shared_variable('etat_z',etat_z,ierr)
          call put_shared_variable('getat_z',getat_z,ierr)
          print*,'ipz,z(n),etat_z(n),getat_z(n,3)'
          do n=n1,n2
            print*,ipz,z(n),etat_z(n),getat_z(n,3)
          enddo
          print*
        endif
      endif
!
      call keep_compiler_quiet(lstarting)
!
    endsubroutine initialize_magnetic_mf
!***********************************************************************
    subroutine pencil_criteria_magnetic_mf()
!
!   All pencils that the Magnetic mean-field module depends on are specified here.
!
!  28-jul-10/axel: adapted from magnetic
!
      use Mpicomm, only: stop_it
!
      lpenc_requested(i_bb)=.true.
!
      if (meanfield_etat/=0.0.or.ietat/=0) &
          lpenc_requested(i_del2a)=.true.
!
!  In mean-field theory, with variable etat, need divA for resistive gauge.
!
      if (meanfield_etat_profile/='const') then
        lpenc_requested(i_diva)=.true.
      endif
!
!  In spherical coordinates, we also need grad(divA)
!
      if (lspherical_coords) lpenc_requested(i_graddiva)=.true.
!
!  For mean-field modelling in momentum equation:
!
      if (lmeanfield_jxb) then
        lpenc_requested(i_b2)=.true.
        lpenc_requested(i_rho1)=.true.
        lpenc_requested(i_jxbr_mf)=.true.
        if (lmeanfield_jxb_with_vA2) lpenc_requested(i_va2)=.true.
      endif
!
!  Turbulent diffusivity
!
      if (meanfield_etat/=0.0 .or. ietat/=0 .or. &
          alpha_effect/=0.0 .or. delta_effect/=0.0) &
          lpenc_requested(i_mf_EMF)=.true.
      if (delta_effect/=0.0) lpenc_requested(i_oxJ)=.true.
!
      if (idiag_EMFdotBm/=0.or.idiag_EMFdotB_int/=0) lpenc_diagnos(i_mf_EMFdotB)=.true.
!
!  Check whether right variables are set for half-box calculations.
!
    endsubroutine pencil_criteria_magnetic_mf
!***********************************************************************
    subroutine pencil_interdep_magnetic_mf(lpencil_in)
!
!  Interdependency among pencils from the Magnetic module is specified here.
!
!  28-jul-10/axel: adapted from magnetic
!
      logical, dimension(npencils) :: lpencil_in
!
!  exa
!
      if (lpencil_in(i_exa)) then
        lpencil_in(i_aa)=.true.
        lpencil_in(i_mf_EMF)=.true.
      endif
!
!  mf_EMFdotB
!
      if (lpencil_in(i_mf_EMFdotB)) then
        lpencil_in(i_mf_EMF)=.true.
        lpencil_in(i_bb)=.true.
      endif
!
!  mf_EMFdotB
!
      if (lpencil_in(i_mf_EMF)) then
        if (lspherical_coords) then
          lpencil_in(i_jj)=.true.
          lpencil_in(i_graddivA)=.true.
        endif
        lpencil_in(i_b2)=.true.
!
        if (meanfield_etat/=0.0 .or. ietat/=0) then
!         if (lweyl_gauge) then
!           lpencil_in(i_jj)=.true.
!         else
            lpencil_in(i_del2a)=.true.
!         endif
        endif
      endif
!  
!  oxJ effect
!
        if (lpencil_in(i_oxJ)) lpencil_in(i_jj)=.true.
!
!  ??
!
!     if (lpencil_in(i_del2A)) then
!       if (lspherical_coords) then
!       endif
!     endif
!
!  Mean-field Lorentz force: jxb_mf
!
      if (lpencil_in(i_jxbr_mf)) lpencil_in(i_jxb_mf)=.true.
      if (lpencil_in(i_jxb_mf)) lpencil_in(i_jxb)=.true.
!
    endsubroutine pencil_interdep_magnetic_mf
!***********************************************************************
    subroutine calc_pencils_magnetic_mf(f,p)
!
!  Calculate Magnetic mean-field pencils.
!  Most basic pencils should come first, as others may depend on them.
!
!  28-jul-10/axel: adapted from magnetic
!
      use Sub
      use Diagnostics, only: sum_mn_name
      use SharedVariables, only: put_shared_variable
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      real, dimension (nx) :: alpha_total
      real, dimension (nx) :: meanfield_etat_tmp, meanfield_detatdz_tmp
      real, dimension (nx) :: alpha_tmp, delta_tmp
      real, dimension (nx) :: EMF_prof
      real, dimension (nx) :: jcrossb2
      real, dimension (nx) :: meanfield_qs_func, meanfield_qp_func
      real, dimension (nx) :: meanfield_qe_func, meanfield_qs_der
      real, dimension (nx) :: meanfield_qp_der, meanfield_qe_der, BiBk_Bki
      real, dimension (nx) :: meanfield_Bs21, meanfield_Bp21, meanfield_Be21
      real, dimension (nx) :: meanfield_urms21, meanfield_etaB2, Beq
      real, dimension (nx,3) :: Bk_Bki,tmp_jxb,exa_meanfield
      real :: kx,fact,z_surface=0.
      integer :: i,j,ix
!
      intent(inout) :: f,p
!
! exa
!
      if (lpencil(i_exa)) then
        if (lmeanfield_theory) then
          call cross_mn(-p%mf_EMF,p%aa,exa_meanfield)
          p%exa=p%exa+exa_meanfield
        endif
      endif
!
!  mean-field Lorentz force
!
      if (lpencil(i_jxbr_mf)) then
!
!  The following 9 lines have not been used for any publications so far.
!
        if (lmeanfield_jxb_with_vA2) then
          meanfield_urms21=1./(3.*meanfield_kf*meanfield_etat)**2
          meanfield_qs_func=meanfield_qs*(1.-2*pi_1*atan(p%vA2*meanfield_urms21))
          meanfield_qp_func=meanfield_qp*(1.-2*pi_1*atan(p%vA2*meanfield_urms21))
          meanfield_qe_func=meanfield_qe*(1.-2*pi_1*atan(p%b2*meanfield_Be21))
          meanfield_qs_der=2*pi_1*meanfield_qs/(1.+(p%vA2*meanfield_urms21)**2)
          meanfield_qp_der=2*pi_1*meanfield_qp/(1.+(p%vA2*meanfield_urms21)**2)
          meanfield_qe_der=2*pi_1*meanfield_qe*meanfield_Be21/(1.+(p%b2*meanfield_Be21)**2)
          call multsv_mn(meanfield_qs_func,p%jxb,tmp_jxb); p%jxb_mf=tmp_jxb
!
!  The follwing (not lmeanfield_jxb_with_vA2) has been used for the
!  various publications so far.
!
        else
          if (meanfield_Beq_profile=='exp(z/H)') then
            Beq=meanfield_Beq*exp(z(n)/meanfield_Beq_height)
          else
            Beq=meanfield_Beq
          endif
          meanfield_Bs21=1./(meanfield_Bs*Beq)**2
          meanfield_Bp21=1./(meanfield_Bp*Beq)**2
          meanfield_Be21=1./(meanfield_Be*Beq)**2
          meanfield_qs_func=meanfield_qs*(1.-2*pi_1*atan(p%b2*meanfield_Bs21))
          meanfield_qp_func=meanfield_qp*(1.-2*pi_1*atan(p%b2*meanfield_Bp21))
          meanfield_qe_func=meanfield_qe*(1.-2*pi_1*atan(p%b2*meanfield_Be21))
          meanfield_qs_der=2*pi_1*meanfield_qs*meanfield_Bs21/(1.+(p%b2*meanfield_Bs21)**2)
          meanfield_qp_der=2*pi_1*meanfield_qp*meanfield_Bp21/(1.+(p%b2*meanfield_Bp21)**2)
          meanfield_qe_der=2*pi_1*meanfield_qe*meanfield_Be21/(1.+(p%b2*meanfield_Be21)**2)
!
!  Add -(1/2)*grad[qp*B^2]. This initializes p%jxb_mf.
!
          call multsv_mn(-meanfield_qs_func,p%jxb,p%jxb_mf)
          call multmv_transp(p%bij,p%bb,Bk_Bki)
          call multsv_mn_add(meanfield_qp_func-meanfield_qs_func+p%b2*meanfield_qp_der,Bk_Bki,p%jxb_mf)
!         if (meanfield_Beq_height/=0.) p%jxb(:,3)=p%jxb(:,3)+p%b2**2*meanfield_Qp_der/meanfield_Beq_height
!
!  Add -B.grad[qs*B_i]. This term does not promote instability.
!
          call dot(Bk_Bki,p%bb,BiBk_Bki)
          call multsv_mn_add(-2*meanfield_qs_der*BiBk_Bki,p%bb,p%jxb_mf)
!
!  Add e_z*grad(qe*B^2). This has not yet been found to promote instability.
!
          p%jxb_mf(:,3)=p%jxb_mf(:,3)+2*(meanfield_qe_der*p%b2+meanfield_qe_func)*Bk_Bki(:,3)
        endif
        call multsv_mn(p%rho1,p%jxb_mf,p%jxbr_mf)
      endif
!
!  mf_EMF for alpha effect dynamos
!
      if (lpencil(i_mf_EMF)) then
!
!  compute alpha profile (alpha_tmp)
!
        kx=2*pi/Lx
        select case (alpha_profile)
        case ('const'); alpha_tmp=1.
        case ('siny'); alpha_tmp=sin(y(m))
        case ('sinz'); alpha_tmp=sin(z(n))
        case ('cos(z/2)'); alpha_tmp=cos(.5*z(n))
        case ('cos(z/2)_with_halo'); alpha_tmp=max(cos(.5*z(n)),0.)
        case ('z'); alpha_tmp=z(n)
        case ('z/H'); alpha_tmp=z(n)/xyz1(3)
        case ('z/H_0'); alpha_tmp=z(n)/xyz1(3); if (z(n)==xyz1(3)) alpha_tmp=0.
        case ('y/H'); alpha_tmp=y(m)/xyz1(3)
        case ('cosy'); alpha_tmp=cos(y(m))
        case ('y*(1+eps*sinx)'); alpha_tmp=y(m)*(1.+alpha_eps*sin(kx*x(l1:l2)))
        case ('step-nhemi'); alpha_tmp=-tanh((y(m)-pi/2)/alpha_gap_step)
        case ('stepy'); alpha_tmp=-tanh((y(m)-yequator)/alpha_gap_step)
        case ('stepz'); alpha_tmp=-tanh((z(n)-zequator)/alpha_gap_step)
        case ('ystep-xcutoff')
           alpha_tmp=-tanh((y(m)-pi/2)/alpha_gap_step)&
             *(1+stepdown(x(l1:l2),alpha_rmax,alpha_width))
        case ('step-drop'); alpha_tmp=(1. &
                -step_scalar(y(m),pi/2.-alpha_equator_gap,alpha_gap_step) &
                -step_scalar(y(m),pi/2.+alpha_equator_gap,alpha_gap_step) &
                -step_scalar(alpha_cutoff_up,y(m),alpha_gap_step) &
                +step_scalar(y(m),alpha_cutoff_down,alpha_gap_step))
        case ('surface_z'); alpha_tmp=0.5*(1.-erfunc((z(n)-z_surface)/alpha_width))
        case ('z/H+surface_z'); alpha_tmp=(z(n)/z_surface)*0.5*(1.-erfunc((z(n)-z_surface)/alpha_width))
          if (headtt) print*,'alpha_profile=z/H+surface_z: z_surface,alpha_width=',z_surface,alpha_width
        case ('read'); alpha_tmp=alpha_input(l1:l2,m)
        case ('nothing');
          call inevitably_fatal_error('calc_pencils_magnetic', &
            'alpha_profile="nothing" has been renamed to "const", please update your run.in')
        case default;
          call inevitably_fatal_error('calc_pencils_magnetic', &
            'alpha_profile no such alpha profile')
        endselect
!
!  compute delta effect profile (delta_tmp)
!
        select case (delta_profile)
        case ('const'); delta_tmp=1.
        case ('cos(z/2)_with_halo'); delta_tmp=max(cos(.5*z(n)),0.)
        case ('sincos(z/2)_with_halo'); delta_tmp=max(cos(.5*z(n)),0.)*sin(.5*z(n))
        case default;
          call inevitably_fatal_error('calc_pencils_magnetic', &
            'delta_profile no such delta profile')
        endselect
!
!  Possibility of dynamical alpha.
!  Here we initialize alpha_total.
!
        if (lalpm.and..not.lmeanfield_noalpm) then
          if (lalpha_profile_total) then
             alpha_total=(alpha_effect+f(l1:l2,m,n,ialpm))*alpha_tmp
           else
             alpha_total=alpha_effect*alpha_tmp+f(l1:l2,m,n,ialpm)
           endif
        else
          alpha_total=alpha_effect*alpha_tmp
        endif
!
!  Possibility of conventional alpha quenching (rescales alpha_total).
!  Initialize EMF with alpha_total*bb.
!  Here we initialize p%mf_EMF.
!
        if (alpha_quenching/=0.0) &
            alpha_total=alpha_total/(1.+alpha_quenching*p%b2)
        call multsv_mn(alpha_total,p%bb,p%mf_EMF)
!
!  Add possible delta x J effect and turbulent diffusion to EMF.
!
        if (ldelta_profile) then
          p%mf_EMF=p%mf_EMF+delta_effect*p%oxJ
        else
          p%mf_EMF(:,1)=p%mf_EMF(:,1)-delta_effect*delta_tmp*p%jj(:,2)
          p%mf_EMF(:,2)=p%mf_EMF(:,2)+delta_effect*delta_tmp*p%jj(:,1)
        endif
!
!  Compute diffusion term.
!  This initializes the meanfield_etat_tmp term.
!
        if (meanfield_etat/=0.0) then
          meanfield_etat_tmp=etat_z(n)
          meanfield_detatdz_tmp=getat_z(n,3)
!
!  Magnetic etat quenching (contribution to pumping currently ignored)
!
          if (meanfield_etaB/=0.0) then
            meanfield_etaB2=meanfield_etaB**2
            meanfield_etat_tmp=meanfield_etat_tmp/sqrt(1.+p%b2/meanfield_etaB2)
          endif
!
!  apply pumping effect in the vertical direction: EMF=...-.5*grad(etat) x B
!
          if (lmeanfield_pumping) then
            fact=.5*meanfield_pumping
            p%mf_EMF(:,1)=p%mf_EMF(:,1)+fact*meanfield_detatdz_tmp*p%bb(:,2)
            p%mf_EMF(:,2)=p%mf_EMF(:,2)-fact*meanfield_detatdz_tmp*p%bb(:,1)
          endif
!
!  Apply diffusion term: simple in Weyl gauge, which is not the default!
!  In diffusive gauge, add (divA) grad(etat) term.
!
!         if (lweyl_gauge) then
!           call multsv_mn_add(-meanfield_etat_tmp,p%jj,p%mf_EMF)
!         else
            call multsv_mn_add(+meanfield_etat_tmp,p%del2a,p%mf_EMF)
            p%mf_EMF(:,3)=p%mf_EMF(:,3)+p%diva*meanfield_detatdz_tmp
!         endif
!
!  Allow for possibility of variable etat.
!
          if (ietat/=0) then
            call multsv_mn_add(-f(l1:l2,m,n,ietat),p%jj,p%mf_EMF)
          endif
        endif
!
!  Possibility of adding contribution from large-scale velocity.
!
        if (llarge_scale_velocity) p%mf_EMF=p%mf_EMF+p%uxb
!
!  Possibility of turning EMF to zero in a certain region.
!
        if (lEMF_profile) then
          select case (EMF_profile)
          case ('xcutoff');
            EMF_prof= 1+stepdown(x(l1:l2),alpha_rmax,alpha_width)
          case ('surface_z');
            EMF_prof=0.5*(1.-erfunc((z(n)-z_surface)/alpha_width))
          case ('nothing');
          call inevitably_fatal_error('calc_pencils_magnetic', &
            'lEMF_profile=T, but no profile selected !')
          endselect
            p%mf_EMF(:,1)=p%mf_EMF(:,1)*EMF_prof(:)
            p%mf_EMF(:,2)=p%mf_EMF(:,2)*EMF_prof(:)
            p%mf_EMF(:,3)=p%mf_EMF(:,3)*EMF_prof(:)
        endif
      endif
!
!  EMFdotB
!
      if (lpencil(i_mf_EMFdotB)) call dot_mn(p%mf_EMF,p%bb,p%mf_EMFdotB)
!
!  Calculate diagnostics.
!
      if (ldiagnos) then
        if (idiag_qsm/=0) call sum_mn_name(meanfield_qs_func,idiag_qsm)
        if (idiag_qpm/=0) call sum_mn_name(meanfield_qp_func,idiag_qpm)
        if (idiag_qem/=0) call sum_mn_name(meanfield_qe_func,idiag_qem)
      endif
!
    endsubroutine calc_pencils_magnetic_mf
!***********************************************************************
    subroutine daa_dt_meanfield(f,df,p)
!
!  add mean-field evolution to magnetic field.
!
!  27-jul-10/axel: coded
!
      use Diagnostics
!     use Special, only: special_calc_magnetic
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      intent(inout)  :: f,p
      intent(inout)  :: df
!
!  Identify module and boundary conditions.
!
      if (headtt.or.ldebug) print*,'daa_dt_meanfield: SOLVE'
!
!  Add jxb/rho to momentum equation.
!
      if (lhydro) then
        if (lmeanfield_jxb) df(l1:l2,m,n,iux:iuz)=df(l1:l2,m,n,iux:iuz)+p%jxbr_mf
      endif
!
!  Multiply resistivity by Nyquist scale, for resistive time-step.
!  We include possible contribution from meanfield_etat, which is however
!  only invoked in mean field models.
!  Allow for variable etat (mean field theory).
!
      if (lfirst.and.ldt) then
        diffus_eta=diffus_eta+meanfield_etat*dxyz_2
        if (headtt.or.ldebug) then
          print*, 'daa_dt_meanfield: max(diffus_eta)  =', maxval(diffus_eta)
        endif
      endif
!
!  Alpha effect.
!  Additional terms if Mean Field Theory is included.
!
      if (lmeanfield_theory.and. &
        (meanfield_etat/=0.0 .or. ietat/=0 .or. &
        alpha_effect/=0.0.or.delta_effect/=0.0)) then
        df(l1:l2,m,n,iax:iaz)=df(l1:l2,m,n,iax:iaz)+p%mf_EMF
        if (lOmega_effect) call Omega_effect(f,df,p)
      endif
!
!  Calculate diagnostic quantities.
!  Diagnostic output for mean field dynamos.
!
      if (ldiagnos) then
        if (idiag_EMFdotBm/=0) call sum_mn_name(p%mf_EMFdotB,idiag_EMFdotBm)
        if (idiag_EMFdotB_int/=0) call integrate_mn_name(p%mf_EMFdotB,idiag_EMFdotB_int)
      endif ! endif (ldiagnos)
!
!  1d-averages. Happens at every it1d timesteps, NOT at every it1.
!
      if (l1davgfirst .or. (ldiagnos .and. ldiagnos_need_zaverages)) then
!
!  Calculate magnetic helicity flux (ExA contribution).
!
        if (idiag_EMFmz1/=0) call xysum_mn_name_z(p%mf_EMF(:,1),idiag_EMFmz1)
        if (idiag_EMFmz2/=0) call xysum_mn_name_z(p%mf_EMF(:,2),idiag_EMFmz2)
        if (idiag_EMFmz3/=0) call xysum_mn_name_z(p%mf_EMF(:,3),idiag_EMFmz3)
      endif
!
!  2-D averages.
!  Note that this does not necessarily happen with ldiagnos=.true.
!
!     if (l2davgfirst) then
!       if (idiag_Ezmxz/=0) call ysum_mn_name_xz(p%uxb(:,3),idiag_Ezmxz)
!     else
!
!  We may need to calculate bxmxy without calculating bmx. The following
!  if condition was messing up calculation of bmxy_rms
!
!       if (ldiagnos) then
!         if (idiag_bxmxy/=0) call zsum_mn_name_xy(p%bb(:,1),idiag_bxmxy)
!       endif
!     endif
!
    endsubroutine daa_dt_meanfield
!***********************************************************************
    subroutine Omega_effect(f,df,p)
!
!  Omega effect coded (normally used in context of mean field theory)
!  Can do uniform shear (0,Sx,0), and the cosx*cosz profile (solar CZ).
!  In most cases the Omega effect can be modeled using hydro_kinematic,
!  but this is not possible when the flow varies in a direction that
!  is not a coordinate direction, e.g. when U=(0,Sx,0) and A=A(z,t).
!  In such cases the Omega effect must be rewritten in terms of
!  velocity gradients operating on A, i.e. (gradU)^T.A, instead of UxB.
!
!  30-apr-05/axel: coded
!
  use Sub, only: stepdown
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
      real kx
!
      intent(in) :: f,p
      intent(inout) :: df
!
!  use gauge transformation, uxB = -Ay*grad(Uy) + gradient-term
!
      select case (Omega_profile)
      case ('nothing'); print*,'Omega_profile=nothing'
      case ('(0,Sx,0)')
        if (headtt) print*,'Omega_effect: uniform shear in x, S=',Omega_ampl
        df(l1:l2,m,n,iax)=df(l1:l2,m,n,iax)-Omega_ampl*f(l1:l2,m,n,iay)
      case ('(Sz,0,0)')
        if (headtt) print*,'Omega_effect: uniform shear in z, S=',Omega_ampl
        df(l1:l2,m,n,iaz)=df(l1:l2,m,n,iaz)-Omega_ampl*f(l1:l2,m,n,iax)
        if (lhydro) df(l1:l2,m,n,iux)=df(l1:l2,m,n,iux)-Omega_ampl*f(l1:l2,m,n,iuz)
      case ('(0,cosx*cosz,0)')
        if (headtt) print*,'Omega_effect: solar shear, S=',Omega_ampl
        df(l1:l2,m,n,iax)=df(l1:l2,m,n,iax)+Omega_ampl*f(l1:l2,m,n,iay) &
            *sin(x(l1:l2))*cos(z(n))
        df(l1:l2,m,n,iaz)=df(l1:l2,m,n,iaz)+Omega_ampl*f(l1:l2,m,n,iay) &
            *cos(x(l1:l2))*sin(z(n))
      case ('(0,0,cosx)')
        kx=2*pi/Lx
        if (headtt) print*,'Omega_effect: (0,0,cosx), S,kx=',Omega_ampl,kx
        df(l1:l2,m,n,iax)=df(l1:l2,m,n,iax)+Omega_ampl*f(l1:l2,m,n,iaz) &
            *kx*sin(kx*x(l1:l2))
      case ('(0,0,siny)')
        if (headtt) print*,'Omega_effect: (0,0,siny), Omega_ampl=',Omega_ampl
        df(l1:l2,m,n,iax)=df(l1:l2,m,n,iax)+Omega_ampl*f(l1:l2,m,n,iaz) &
            *sin(y(m))
      case('rcutoff_sin_theta')
        if (headtt) print*,'Omega_effect: r cutoff sin(theta), Omega_ampl=',Omega_ampl
!        df(l1:l2,m,n,iax)=Omega_ampl*df(l1:l2,m,n,iax)
        df(l1:l2,m,n,iax)=df(l1:l2,m,n,iax)-Omega_ampl*p%bb(:,2) &
            *sin(y(m))*x(l1:l2)*(1+stepdown(x(l1:l2),Omega_rmax,Omega_rwidth))
        df(l1:l2,m,n,iay)=df(l1:l2,m,n,iay)+Omega_ampl*p%bb(:,1) &
            *sin(y(m))*x(l1:l2)*(1+stepdown(x(l1:l2),Omega_rmax,Omega_rwidth))
      case default; print*,'Omega_profile=unknown'
      endselect
!
    endsubroutine Omega_effect
!***********************************************************************
    subroutine read_magnetic_mf_init_pars(unit,iostat)
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (present(iostat)) then
        read(unit,NML=magnetic_mf_init_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=magnetic_mf_init_pars,ERR=99)
      endif
!
99    return
!
    endsubroutine read_magnetic_mf_init_pars
!***********************************************************************
    subroutine write_magnetic_mf_init_pars(unit)
!
      integer, intent(in) :: unit
!
      write(unit,NML=magnetic_mf_init_pars)
!
    endsubroutine write_magnetic_mf_init_pars
!***********************************************************************
    subroutine read_magnetic_mf_run_pars(unit,iostat)
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (present(iostat)) then
        read(unit,NML=magnetic_mf_run_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=magnetic_mf_run_pars,ERR=99)
      endif
!
99    return
!
    endsubroutine read_magnetic_mf_run_pars
!***********************************************************************
    subroutine write_magnetic_mf_run_pars(unit)
!
      integer, intent(in) :: unit
!
      write(unit,NML=magnetic_mf_run_pars)
!
    endsubroutine write_magnetic_mf_run_pars
!***********************************************************************
    subroutine rprint_magnetic_mf(lreset,lwrite)
!
!  Reads and registers print parameters relevant for magnetic fields.
!
!   3-may-02/axel: coded
!  27-may-02/axel: added possibility to reset list
!
      use Diagnostics
!
      integer :: iname,inamex,inamey,inamez,ixy,ixz,irz,inamer,iname_half
      logical :: lreset,lwr
      logical, optional :: lwrite
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
!  Reset everything in case of RELOAD.
!  (this needs to be consistent with what is defined above!)
!
      if (lreset) then
        idiag_qsm=0; idiag_qpm=0; idiag_qem=0;
        idiag_EMFmz1=0; idiag_EMFmz2=0; idiag_EMFmz3=0
      endif
!
!  Check for those quantities that we want to evaluate online.
!
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'qsm',idiag_qsm)
        call parse_name(iname,cname(iname),cform(iname),'qpm',idiag_qpm)
        call parse_name(iname,cname(iname),cform(iname),'qem',idiag_qem)
      enddo
!
!  Check for those quantities for which we want xy-averages.
!
!     do inamex=1,nnamex
!    enddo
!
!  Check for those quantities for which we want xz-averages.
!
      do inamey=1,nnamey
      enddo
!
!  Check for those quantities for which we want yz-averages.
!
      do inamez=1,nnamez
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'EMFmz1',idiag_EMFmz1)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'EMFmz2',idiag_EMFmz2)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'EMFmz3',idiag_EMFmz3)
      enddo
!
!  Check for those quantities for which we want y-averages.
!
      do ixz=1,nnamexz
      enddo
!
!  Check for those quantities for which we want z-averages.
!
      do ixy=1,nnamexy
      enddo
!
!  Check for those quantities for which we want phi-averages.
!
      do irz=1,nnamerz
      enddo
!
!  Check for those quantities for which we want phiz-averages.
!
      do inamer=1,nnamer
      enddo
!
!  Write column, idiag_XYZ, where our variable XYZ is stored.
!
      if (lwr) then
      endif
!
    endsubroutine rprint_magnetic_mf
!***********************************************************************
endmodule Magnetic_meanfield

