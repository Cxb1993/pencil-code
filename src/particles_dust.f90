! $Id$
!
!  This module takes care of everything related to dust particles
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
!
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! MPVAR CONTRIBUTION 6
! MAUX CONTRIBUTION 2
! CPARAM logical, parameter :: lparticles=.true.
!
! PENCILS PROVIDED np; rhop; epsp
!
!***************************************************************
module Particles

  use Cdata
  use Particles_cdata
  use Particles_sub
  use Messages

  implicit none

  include 'particles.h'

  complex, dimension (7) :: coeff=(0.0,0.0)
  real, dimension (npar_species) :: tausp_species=0.0, tausp1_species=0.0
  real :: xp0=0.0, yp0=0.0, zp0=0.0, vpx0=0.0, vpy0=0.0, vpz0=0.0
  real :: delta_vp0=1.0, tausp=0.0, tausp1=0.0, eps_dtog=0.01
  real :: nu_epicycle=0.0, nu_epicycle2=0.0
  real :: beta_dPdr_dust=0.0, beta_dPdr_dust_scaled=0.0
  real :: tausg_min=0.0, tausg1_max=0.0, epsp_friction_increase=0.0, cdtp=0.2
  real :: gravx=0.0, gravz=0.0, gravr=0.0, kx_gg=1.0, kz_gg=1.0
  real :: gravsmooth=0.0, gravsmooth2=0.0, Ri0=0.25, eps1=0.5
  real :: kx_xxp=0.0, ky_xxp=0.0, kz_xxp=0.0, amplxxp=0.0
  real :: kx_vvp=0.0, ky_vvp=0.0, kz_vvp=0.0, amplvvp=0.0
  real :: kx_vpx=0.0, kx_vpy=0.0, kx_vpz=0.0
  real :: ky_vpx=0.0, ky_vpy=0.0, ky_vpz=0.0
  real :: kz_vpx=0.0, kz_vpy=0.0, kz_vpz=0.0
  real :: phase_vpx=0.0, phase_vpy=0.0, phase_vpz=0.0
  real :: tstart_dragforce_par=0.0, tstart_grav_par=0.0
  real :: tstart_liftforce_par=0.0
  real :: tstart_brownian_par=0.0
  real :: tstart_collisional_cooling=0.0
  real :: tau_coll_min=0.0, tau_coll1_max=0.0
  real :: coeff_restitution=0.5, mean_free_path_gas=0.0
  real :: pdlaw=0.0, tausp_short_friction=0.0, tausp1_short_friction=0.0
  real :: brownian_T0=0.0
  integer :: l_hole=0, m_hole=0, n_hole=0
  integer :: iscratch_short_friction=0
  integer, dimension (npar_species) :: ipar_fence_species=0
  logical :: ldragforce_dust_par=.false., ldragforce_gas_par=.false.
  logical :: ldragforce_heat=.false., lcollisional_heat=.false.
  logical :: lpar_spec=.false., lcompensate_friction_increase=.false.
  logical :: lcollisional_cooling_rms=.false.
  logical :: lcollisional_cooling_twobody=.false.
  logical :: lcollisional_dragforce_cooling=.false.
  logical :: ltau_coll_min_courant=.true.
  logical :: ldragforce_equi_global_eps=.false.
  logical :: ldraglaw_epstein=.true.
  logical :: ldraglaw_epstein_stokes_linear=.false.
  logical :: ldraglaw_steadystate=.false.
  logical :: lcoldstart_amplitude_correction=.false.
  logical :: ldraglaw_variable=.false.
  logical :: ldraglaw_epstein_transonic=.false.
  logical :: ldraglaw_eps_stk_transonic=.false.
  logical :: luse_tau_ap=.true.
  logical :: lshort_friction_approx=.false.
  logical :: lbrownian_forces=.false.
  logical :: lenforce_policy=.false.
  logical :: lnostore_uu=.true.
  logical :: ldtgrav_par=.false.

  character (len=labellen) :: interp_pol_uu ='ngp'
  character (len=labellen) :: interp_pol_oo ='ngp'
  character (len=labellen) :: interp_pol_TT ='ngp'
  character (len=labellen) :: interp_pol_rho='ngp'
  
  character (len=labellen), dimension (ninit) :: initxxp='nothing'
  character (len=labellen), dimension (ninit) :: initvvp='nothing'
  character (len=labellen) :: gravx_profile='', gravz_profile=''
  character (len=labellen) :: gravr_profile=''

  namelist /particles_init_pars/ &
      initxxp, initvvp, xp0, yp0, zp0, vpx0, vpy0, vpz0, delta_vp0, &
      bcpx, bcpy, bcpz, tausp, beta_dPdr_dust, rhop_tilde, &
      eps_dtog, nu_epicycle, &
      gravx_profile, gravz_profile, gravr_profile, &
      gravx, gravz, gravr, gravsmooth, kx_gg, kz_gg, Ri0, eps1, &
      lmigration_redo, ldragforce_equi_global_eps, coeff, &
      kx_vvp, ky_vvp, kz_vvp, amplvvp, kx_xxp, ky_xxp, kz_xxp, amplxxp, &
      kx_vpx, kx_vpy, kx_vpz, ky_vpx, ky_vpy, ky_vpz, kz_vpx, kz_vpy, kz_vpz, &
      phase_vpx, phase_vpy, phase_vpz, lcoldstart_amplitude_correction, &
      lparticlemesh_cic, lparticlemesh_tsc, linterpolate_spline, &
      tstart_dragforce_par, tstart_grav_par, lcollisional_cooling_rms, &
      lcollisional_cooling_twobody, ipar_fence_species, tausp_species, &
      tau_coll_min, ltau_coll_min_courant, coeff_restitution, &
      tstart_collisional_cooling, tausg_min, l_hole, m_hole, n_hole, &
      epsp_friction_increase,lcollisional_dragforce_cooling, &
      ldragforce_heat, lcollisional_heat, lcompensate_friction_increase, &
      lmigration_real_check, ldraglaw_epstein, ldraglaw_epstein_stokes_linear, &
      mean_free_path_gas, ldraglaw_epstein_transonic, lcheck_exact_frontier,&
      ldraglaw_eps_stk_transonic, pdlaw, lshort_friction_approx, &
      tausp_short_friction,ldraglaw_steadystate,tstart_liftforce_par, &
      tstart_brownian_par, lbrownian_forces, lenforce_policy, &
      interp_pol_uu,interp_pol_oo,interp_pol_TT,interp_pol_rho, &
      brownian_T0, lnostore_uu, ldtgrav_par

  namelist /particles_run_pars/ &
      bcpx, bcpy, bcpz, tausp, dsnap_par_minor, beta_dPdr_dust, &
      ldragforce_gas_par, ldragforce_dust_par, &
      rhop_tilde, eps_dtog, cdtp, lpar_spec, &
      linterp_reality_check, nu_epicycle, &
      gravx_profile, gravz_profile, gravr_profile, &
      gravx, gravz, gravr, gravsmooth, kx_gg, kz_gg, &
      lmigration_redo, tstart_dragforce_par, tstart_grav_par, &
      lparticlemesh_cic, lparticlemesh_tsc, lcollisional_cooling_rms, &
      lcollisional_cooling_twobody, lcollisional_dragforce_cooling, &
      tau_coll_min, ltau_coll_min_courant, coeff_restitution, &
      tstart_collisional_cooling, tausg_min, epsp_friction_increase, &
      ldragforce_heat, lcollisional_heat, lcompensate_friction_increase, &
      lmigration_real_check,ldraglaw_variable, luse_tau_ap, &
      ldraglaw_epstein, ldraglaw_epstein_stokes_linear, mean_free_path_gas, &
      ldraglaw_epstein_transonic, lcheck_exact_frontier, &
      ldraglaw_eps_stk_transonic, lshort_friction_approx, &
      tausp_short_friction,ldraglaw_steadystate,tstart_liftforce_par, &
      tstart_brownian_par, lbrownian_forces, lenforce_policy, &
      interp_pol_uu,interp_pol_oo,interp_pol_TT,interp_pol_rho, &
      brownian_T0, lnostore_uu, ldtgrav_par

  integer :: idiag_xpm=0, idiag_ypm=0, idiag_zpm=0
  integer :: idiag_xp2m=0, idiag_yp2m=0, idiag_zp2m=0
  integer :: idiag_vpxm=0, idiag_vpym=0, idiag_vpzm=0
  integer :: idiag_vpx2m=0, idiag_vpy2m=0, idiag_vpz2m=0, idiag_ekinp=0
  integer :: idiag_vpxmax=0, idiag_vpymax=0, idiag_vpzmax=0
  integer :: idiag_npm=0, idiag_np2m=0, idiag_npmax=0, idiag_npmin=0
  integer :: idiag_rhoptilm=0, idiag_dtdragp=0, idiag_nparmax=0
  integer :: idiag_rhopm=0, idiag_rhoprms=0, idiag_rhop2m=0, idiag_rhopmax=0
  integer :: idiag_rhopmin=0, idiag_decollp=0, idiag_rhopmphi=0
  integer :: idiag_npmx=0, idiag_npmy=0, idiag_npmz=0
  integer :: idiag_rhopmx=0, idiag_rhopmy=0, idiag_rhopmz=0
  integer :: idiag_epspmx=0, idiag_epspmy=0, idiag_epspmz=0
  integer :: idiag_mpt=0, idiag_dedragp=0, idiag_rhopmxy=0, idiag_rhopmr=0
  integer :: idiag_dvpx2m=0, idiag_dvpy2m=0, idiag_dvpz2m=0
  integer :: idiag_dvpm=0,idiag_dvpmax=0
  integer :: idiag_rhopmxz=0, idiag_nparpmax=0

  contains

!***********************************************************************
    subroutine register_particles()
!
!  Set up indices for access to the fp and dfp arrays
!
!  29-dec-04/anders: coded
!
      use Mpicomm, only: stop_it
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_particles: called twice')
      first = .false.
!
      if (lroot) call cvs_id( &
           "$Id$")
!
!  Indices for particle position.
!
      ixp=npvar+1
      iyp=npvar+2
      izp=npvar+3
!
!  Indices for particle velocity.
!
      ivpx=npvar+4
      ivpy=npvar+5
      ivpz=npvar+6
!
!  Increase npvar accordingly.
!
      npvar=npvar+6
!
!  Set indices for auxiliary variables
!
      inp   = mvar + naux + 1 + (maux_com - naux_com); naux = naux + 1
      irhop = mvar + naux + 1 + (maux_com - naux_com); naux = naux + 1
!
!  Check that the fp and dfp arrays are big enough.
!
      if (npvar > mpvar) then
        if (lroot) write(0,*) 'npvar = ', npvar, ', mpvar = ', mpvar
        call stop_it('register_particles: npvar > mpvar')
      endif
!
!  Check that we aren't registering too many auxilary variables
!
      if (naux > maux) then
        if (lroot) write(0,*) 'naux = ', naux, ', maux = ', maux
            call stop_it('register_particles: naux > maux')
      endif
!
    endsubroutine register_particles
!***********************************************************************
    subroutine initialize_particles(lstarting)
!
!  Perform any post-parameter-read initialization i.e. calculate derived
!  parameters.
!
!  29-dec-04/anders: coded
!
      use EquationOfState, only: cs0,rho0
      use FArrayManager
!
      integer :: jspec
      logical :: lstarting
!
      real :: rhom
      integer :: npar_per_species, ierr
!
!  Distribute particles evenly among processors to begin with.
!
      if (lstarting) call dist_particles_evenly_procs(npar_loc,ipar)
!
!  The inverse stopping time is needed for drag force and collisional cooling.
!
      tausp1=0.0
      if (tausp/=0.) then
        tausp1=1/tausp
      endif
      if (ldragforce_dust_par .or. ldragforce_gas_par) then
        if (tausp==0.0 .and. npar_species==1) then
          if (iap==0) then  ! Particle_radius module calculates taus independently
            if (lroot) print*, &
                'initialize_particles: drag force must have tausp/=0 !'
            call fatal_error('initialize_particles','')
          endif
        endif
      endif
!
!  Multiple dust species. Friction time is given in the array tausp_species.
!
      if (npar_species>1) then
        if (lroot) print*, &
            'initialize_particles: Number of particle species = ', npar_species
!
!  Must have set tausp_species for drag force.
!
        if (ldragforce_dust_par .or. ldragforce_gas_par) then
          if (any(tausp_species==0)) then
            if (lroot) print*, &
                'initialize_particles: drag force must have tausp_species/=0 !'
                call fatal_error('initialize_particles','')
          endif
!
!  Inverse friction time is needed for drag force.
!
          do jspec=1,npar_species
            if (tausp_species(jspec)/=0.0) &
                tausp1_species(jspec)=1/tausp_species(jspec)
          enddo
        endif
!
!  If not explicitly set in start.in, the index fence between the particle
!  species is set automatically here.
!
        if (maxval(ipar_fence_species)==0) then
          npar_per_species=npar/npar_species
          ipar_fence_species(1)=npar_per_species
          ipar_fence_species(npar_species)=npar
          do jspec=2,npar_species-1
            ipar_fence_species(jspec)= &
                ipar_fence_species(jspec-1)+npar_per_species
          enddo
          if (lroot) print*, &
              'initialize_particles: Equally many particles in each species'
        endif
        if (lroot) print*, &
            'initialize_particles: Species fences at particle index ', &
            ipar_fence_species
      else
        tausp_species(1)=tausp
        if (tausp_species(1)/=0.0) &
            tausp1_species(1)=1/tausp_species(1)
      endif
!
!  Global gas pressure gradient seen from the perspective of the dust.
!
      if (beta_dPdr_dust/=0.0) then
        beta_dPdr_dust_scaled=beta_dPdr_dust*Omega/cs0
        if (lroot) print*, 'initialize_particles: Global pressure '// &
            'gradient with beta_dPdr_dust=', beta_dPdr_dust
      endif
!
!  Calculate mass density per particle (for back-reaction drag force on gas)
!  following the formula
!    rhop_tilde*N_cell = eps*rhom
!  where rhop_tilde is the mass density per particle, N_cell is the number of
!  particles per grid cell and rhom is the mean gas density in the box.
!
      if (rhop_tilde==0.0) then
! For stratification, take into account gas present outside the simulation box.
        if ( (lgravz .and. lgravz_gas) .or. gravz_profile=='linear') then
          rhom=sqrt(2*pi)*1.0*1.0/Lz  ! rhom = Sigma/Lz, Sigma=sqrt(2*pi)*H*rho1
        else
          rhom=1.0
        endif
        rhop_tilde=eps_dtog*rhom/(real(npar)/(nxgrid*nygrid*nzgrid))
        if (lroot) then
          print*, 'initialize_particles: '// &
            'dust-to-gas ratio eps_dtog=', eps_dtog
          print*, 'initialize_particles: '// &
            'mass density per particle rhop_tilde=', rhop_tilde
        endif
      else
        if (lroot) print*, 'initialize_particles: '// &
            'mass density per particle rhop_tilde=', rhop_tilde
      endif
!
! Calculate mass per particle for drag-force and back-reaction in curvilinear
! coordinates. It follows simply
!   mp_tilde*N = eps*Int(rho*dv) = eps*rhom*V
! where N is the total number of particles, eps is the dust to gas ratio and
! V is the total volume of the box 
!
      if (mp_tilde==0.0) then
        rhom=1.0*rho0
        mp_tilde  =eps_dtog*rhom*box_volume/real(npar)
        if (lroot) then
          print*, 'initialize_particles: '// &
               'dust-to-gas ratio eps_dtog=', eps_dtog
          print*, 'initialize_particles: '// &
               'mass per particle mp_tilde=', mp_tilde
        endif
      else
        if (lroot) print*, 'initialize_particles: '// &
             'mass per particle mp_tilde=', mp_tilde
      endif
!
!  Calculate nu_epicycle**2 for gravity.
!
      if (gravz_profile=='' .and. nu_epicycle/=0.0) gravz_profile='linear'
      nu_epicycle2=nu_epicycle**2
!
!  Calculate gravsmooth**2 for gravity.
!
      if (gravsmooth/=0.0) gravsmooth2=gravsmooth2**2
!
!  Inverse of minimum gas friction time (time-step control).
!
      if (tausg_min/=0.0) tausg1_max=1.0/tausg_min
!
!  Set minimum collisional time-scale so that time-step is not affected.
!
      if ((.not. lstarting) .and. ltau_coll_min_courant) then
        tau_coll_min=2*dx/cs0
        if (lroot) print*, 'initialize particles: set minimum collisional '// &
            'time-scale equal to two times the Courant time-step.'
      endif
!
!  Inverse of minimum collisional time-scale.
!
      if ((.not. lstarting) .and. tau_coll_min>0.0) tau_coll1_max=1/tau_coll_min
!
!  Gas density is needed for back-reaction friction force.
!
      if (ldragforce_gas_par .and. .not. ldensity) then
        if (lroot) then
          print*, 'initialize_particles: friction force on gas only works '
          print*, '                      together with gas density module!'
        endif
        call fatal_error('initialize_particles','')
      endif
!
!  Need to map particles on the grid for dragforce on gas.
!
      if (ldragforce_gas_par) then
        lcalc_np=.true.
!
!  When drag force is smoothed, df is also set in the first ghost zone. This
!  region needs to be folded back into the df array after pde is finished,
!
        if (lparticlemesh_cic .or. lparticlemesh_tsc) lfold_df=.true.
      endif
!
      if (lcollisional_cooling_twobody) allocate(kneighbour(mpar_loc))
!
      if (ldraglaw_epstein_stokes_linear) ldraglaw_epstein=.false.
      if (ldraglaw_epstein_transonic    .or.&
          ldraglaw_eps_stk_transonic    .or.&
          ldraglaw_steadystate) then 
        ldraglaw_epstein=.false. 
      endif
      if (ldraglaw_epstein_transonic         .and.&
          ldraglaw_eps_stk_transonic) then
        print*,'both epstein and epstein-stokes transonic '//&
               'drag laws are switched on. You cannot have '//&
               'both. Stop and choose only one.'
        call fatal_error("initialize_particles","")
      endif
!
!  Short friction time approximation. Need to keep track of pressure gradient
!  force and Lorentz force, to be able to set the particle terminal velocity.
!  Thus we open a vector scratch space already now.
!
      if (lshort_friction_approx) then
        call farray_acquire_scratch_area('scratch',iscratch_short_friction,3,ierr)
        if (ierr/=0) then
          if (lroot) print*, 'initialize_particles: there was a problem '// &
              'defining scratch array for short friction time approximation'
          call fatal_error('initialize_particles','')
        endif
        if (ldragforce_gas_par) then
          if (lroot) print*, 'initialize_particles: short friction time '// &
              'approximation is incompatible with drag from particles to gas'
          call fatal_error('initialize_particles','')
        endif
        if (tausp_short_friction/=0.0) then
          tausp1_short_friction=1/tausp_short_friction
          if (lroot) print*, 'initialize_particles: short friction time '// &
              'approximation for all particles with tausp<', &
              tausp_short_friction
        else
          if (lroot) print*, 'initialize_particles: short friction time '// &
             'approximation for all particle sizes'
        endif
      endif
!
!  Set up interpolation logicals. These logicals can be OR'ed with some logical
!  in the other particle modules' initialization subroutines to enable
!  interpolation based on some condition local to that module.
!  (The particles_spin module will for instance enable interpolation of the
!  vorticity oo)
!
      if (lnostore_uu) then
        interp%luu=.false.
      else
        interp%luu=ldragforce_dust_par
      endif
      interp%loo=.false.
      interp%lTT=lbrownian_forces.and.(brownian_T0/=0.0)
      interp%lrho=lbrownian_forces.or.ldraglaw_steadystate
!
!  Determine interpolation policies:
!   Make sure that interpolation of uu is chosen in a backwards compatible
!   manner. NGP is chosen by default.
!
      if (.not.lenforce_policy) then
        if (lparticlemesh_cic) then
          interp_pol_uu='cic'
        else if (lparticlemesh_tsc) then
          interp_pol_uu='tsc'
        endif
      endif
!
!  Overwrite with new policy variables:
!     
      select case(interp_pol_uu)
      case ('tsc')
        interp%pol_uu=tsc
      case ('cic')
        interp%pol_uu=cic
      case ('ngp')
        interp%pol_uu=ngp
      case default
        call fatal_error('initialize_particles','No such such value for '// &
          'interp_pol_uu: '//trim(interp_pol_uu))
      endselect
!
      select case(interp_pol_oo)
      case ('tsc')
        interp%pol_oo=tsc
      case ('cic')
        interp%pol_oo=cic
      case ('ngp')
        interp%pol_oo=ngp
      case default
        call fatal_error('initialize_particles','No such such value for '// &
          'interp_pol_oo: '//trim(interp_pol_oo))
      endselect
!
      select case(interp_pol_TT)
      case ('tsc')
        interp%pol_TT=tsc
      case ('cic')
        interp%pol_TT=cic
      case ('ngp')
        interp%pol_TT=ngp
      case default
        call fatal_error('initialize_particles','No such such value for '// &
          'interp_pol_TT: '//trim(interp_pol_TT))
      endselect
!
      select case(interp_pol_rho)
      case ('tsc')
        interp%pol_rho=tsc
      case ('cic')
        interp%pol_rho=cic
      case ('ngp')
        interp%pol_rho=ngp
      case default
        call fatal_error('initialize_particles','No such such value for '// &
          'interp_pol_rho: '//trim(interp_pol_rho))
      endselect
!
!  Write constants to disk.
!
      if (lroot) then
        open (1,file=trim(datadir)//'/pc_constants.pro',position="append")
          write (1,*) 'rhop_tilde=', rhop_tilde
        close (1)
      endif
!
    endsubroutine initialize_particles
!***********************************************************************
    subroutine init_particles(f,fp,ineargrid)
!
!  Initial positions and velocities of dust particles.
!
!  29-dec-04/anders: coded
!
      use EquationOfState, only: gamma, beta_glnrho_global, cs20
      use General, only: random_number_wrapper
      use Mpicomm, only: stop_it, mpireduce_sum_scl
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mpar_loc,mpvar) :: fp
      integer, dimension (mpar_loc,3) :: ineargrid
!
      real, dimension (3) :: uup
      real :: vpx_sum, vpy_sum, vpz_sum
      real :: r, p, q, px, py, pz, eps, cs, k2_xxp
      real :: dim1, npar_loc_x, npar_loc_y, npar_loc_z, dx_par, dy_par, dz_par
      real :: rad,rad_scl,phi,tmp
      integer :: l, j, k, ix0, iy0, iz0
      logical :: lequidistant=.false.
!
      intent (out) :: f, fp, ineargrid
!
!  Initial particle position.
!
      do j=1,ninit

        select case(initxxp(j))

        case ('nothing')
          if (lroot .and. j==1) print*, 'init_particles: nothing'

        case ('origin')
          if (lroot) print*, 'init_particles: All particles at origin'
          fp(1:npar_loc,ixp:izp)=0.

        case ('zero-z')
          if (lroot) print*, 'init_particles: Zero z coordinate'
          fp(1:npar_loc,izp)=0.

        case ('constant')
          if (lroot) &
              print*, 'init_particles: All particles at x,y,z=', xp0, yp0, zp0
          fp(1:npar_loc,ixp)=xp0
          fp(1:npar_loc,iyp)=yp0
          fp(1:npar_loc,izp)=zp0

        case ('random')
          if (lroot) print*, 'init_particles: Random particle positions'
          do k=1,npar_loc
            if (nxgrid/=1) call random_number_wrapper(fp(k,ixp))
            if (nygrid/=1) call random_number_wrapper(fp(k,iyp))
            if (nzgrid/=1) call random_number_wrapper(fp(k,izp))
          enddo
          if (nxgrid/=1) &
              fp(1:npar_loc,ixp)=xyz0_loc(1)+fp(1:npar_loc,ixp)*Lxyz_loc(1)
          if (nygrid/=1) &
              fp(1:npar_loc,iyp)=xyz0_loc(2)+fp(1:npar_loc,iyp)*Lxyz_loc(2)
          if (nzgrid/=1) &
              fp(1:npar_loc,izp)=xyz0_loc(3)+fp(1:npar_loc,izp)*Lxyz_loc(3)

       case ('random-cylindrical','random-cyl')
          if (lroot) print*, 'init_particles: Random particle '//&
               'cylindrical positions with power-law pdlaw=',pdlaw
!
          do k=1,npar_loc
!
! Start the particles obbeying a power law pdlaw
!
            tmp=2-pdlaw
            call random_number_wrapper(rad_scl)
            rad_scl = rp_int**tmp + rad_scl*(rp_ext**tmp-rp_int**tmp)
            rad = rad_scl**(1./tmp)
!
! Random in azimuth
!
            call random_number_wrapper(phi)
!
             if (lcartesian_coords) then
               phi = 2*pi*phi
               if (nxgrid/=1) fp(k,ixp)=rad*cos(phi)
               if (nygrid/=1) fp(k,iyp)=rad*sin(phi)
             elseif (lcylindrical_coords) then
               phi = xyz0_loc(2)+phi*Lxyz_loc(2)
               if (nxgrid/=1) fp(k,ixp)=rad
               if (nygrid/=1) fp(k,iyp)=phi
             elseif (lspherical_coords) then
               call stop_it("init_particles: random-cylindrical not implemented "//&
                    "for spherical coordinates") 
             endif
!
             if (nzgrid/=1) call random_number_wrapper(fp(k,izp))
             if (nzgrid/=1) &
               fp(k,izp)=xyz0_loc(3)+fp(k,izp)*Lxyz_loc(3)
!
          enddo

        case ('np-constant')
          if (lroot) print*, 'init_particles: Constant number density'
          k=1
k_loop:   do while (.not. (k>npar_loc))
            do l=l1,l2; do m=m1,m2; do n=n1,n2
              if (nxgrid/=1) call random_number_wrapper(px)
              if (nygrid/=1) call random_number_wrapper(py)
              if (nzgrid/=1) call random_number_wrapper(pz)
              fp(k,ixp)=x(l)+(px-0.5)*dx
              fp(k,iyp)=y(m)+(py-0.5)*dy
              fp(k,izp)=z(n)+(pz-0.5)*dz
              k=k+1
              if (k>npar_loc) exit k_loop
            enddo; enddo; enddo
          enddo k_loop

        case ('equidistant')
          if (lroot) print*, 'init_particles: Particles placed equidistantly'
          dim1=1.0/dimensionality
!
!  Number of particles per direction. Found by solving the equation system
!
!    npar_loc_x/npar_loc_y = Lx_loc/Ly_loc
!    npar_loc_x/npar_loc_z = Lx_loc/Lz_loc
!    npar_loc_y/npar_loc_z = Ly_loc/Lz_loc
!    npar_loc_x*npar_loc_y*npar_loc_z = npar_loc
!
!  Found it to be easier to separate in all possible dimensionalities.
!  For a missing direction i, set npar_loc_i=1 in the above equations and
!  ignore any equation that has Li_loc in it.
!
          if (dimensionality==3) then
!  3-D
            npar_loc_x=(npar_loc*Lxyz_loc(1)**2/(Lxyz_loc(2)*Lxyz_loc(3)))**dim1
            npar_loc_y=(npar_loc*Lxyz_loc(2)**2/(Lxyz_loc(1)*Lxyz_loc(3)))**dim1
            npar_loc_z=(npar_loc*Lxyz_loc(3)**2/(Lxyz_loc(1)*Lxyz_loc(2)))**dim1
          elseif (dimensionality==2) then
!  2-D
            if (nxgrid==1) then
              npar_loc_x=1
              npar_loc_y=(npar_loc*Lxyz_loc(2)/Lxyz_loc(3))**dim1
              npar_loc_z=(npar_loc*Lxyz_loc(3)/Lxyz_loc(2))**dim1
            elseif (nygrid==1) then
              npar_loc_x=(npar_loc*Lxyz_loc(1)/Lxyz_loc(3))**dim1
              npar_loc_y=1
              npar_loc_z=(npar_loc*Lxyz_loc(3)/Lxyz_loc(2))**dim1
            elseif (nzgrid==1) then
              npar_loc_x=(npar_loc*Lxyz_loc(1)/Lxyz_loc(2))**dim1
              npar_loc_y=(npar_loc*Lxyz_loc(2)/Lxyz_loc(1))**dim1
              npar_loc_z=1
            endif
          elseif (dimensionality==1) then
!  1-D
            if (nxgrid/=1) then
              npar_loc_x=npar_loc
              npar_loc_y=1
              npar_loc_z=1
            elseif (nygrid/=1) then
              npar_loc_x=1
              npar_loc_y=npar_loc
              npar_loc_z=1
            elseif (nzgrid/=1) then
              npar_loc_x=1
              npar_loc_y=1
              npar_loc_z=npar_loc
            endif
          endif
!  Distance between particles.
          dx_par=Lxyz_loc(1)/npar_loc_x
          dy_par=Lxyz_loc(2)/npar_loc_y
          dz_par=Lxyz_loc(3)/npar_loc_z
!  Place first particle.
          fp(1,ixp) = x(l1) ; fp(1,iyp) = y(m1) ; fp(1,izp) = z(n1)
          if (nxgrid/=1) fp(1,ixp) = xyz0_loc(1)+dx_par/2
          if (nygrid/=1) fp(1,iyp) = xyz0_loc(2)+dy_par/2
          if (nzgrid/=1) fp(1,izp) = xyz0_loc(3)+dz_par/2
!  Place all other particles iteratively.
          if (dimensionality==3) then
!  3-D
            do k=2,npar_loc
              fp(k,ixp)=fp(k-1,ixp)+dx_par
              fp(k,iyp)=fp(k-1,iyp)
              fp(k,izp)=fp(k-1,izp)
              if (fp(k,ixp)>xyz1_loc(1)) then
                fp(k,ixp)=fp(1,ixp)
                fp(k,iyp)=fp(k,iyp)+dy_par
              endif
              if (fp(k,iyp)>xyz1_loc(2)) then
                fp(k,iyp)=fp(1,iyp)
                fp(k,izp)=fp(k,izp)+dz_par
              endif
            enddo
          elseif (dimensionality==2) then
!  2-D
            if (nxgrid==1) then
              do k=2,npar_loc
                fp(k,ixp)=fp(k-1,ixp)
                fp(k,iyp)=fp(k-1,iyp)+dy_par
                fp(k,izp)=fp(k-1,izp)
                if (fp(k,iyp)>xyz1_loc(2)) then
                  fp(k,iyp)=fp(1,iyp)
                  fp(k,izp)=fp(k,izp)+dz_par
                endif
              enddo
            elseif (nygrid==1) then
              do k=2,npar_loc
                fp(k,ixp)=fp(k-1,ixp)+dx_par
                fp(k,iyp)=fp(k-1,iyp)
                fp(k,izp)=fp(k-1,izp)
                if (fp(k,ixp)>xyz1_loc(1)) then
                  fp(k,ixp)=fp(1,ixp)
                  fp(k,izp)=fp(k,izp)+dz_par
                endif
              enddo
            elseif (nzgrid==1) then
              do k=2,npar_loc
                fp(k,ixp)=fp(k-1,ixp)+dx_par
                fp(k,iyp)=fp(k-1,iyp)
                fp(k,izp)=fp(k-1,izp)
                if (fp(k,ixp)>xyz1_loc(1)) then
                  fp(k,ixp)=fp(1,ixp)
                  fp(k,iyp)=fp(k,iyp)+dy_par
                endif
              enddo
            endif
          elseif (dimensionality==1) then
!  1-D
            if (nxgrid/=1) then
              do k=2,npar_loc
                fp(k,ixp)=fp(k-1,ixp)+dx_par
                fp(k,iyp)=fp(k-1,iyp)
                fp(k,izp)=fp(k-1,izp)
              enddo
            elseif (nygrid/=1) then
              do k=2,npar_loc
                fp(k,ixp)=fp(k-1,ixp)
                fp(k,iyp)=fp(k-1,iyp)+dy_par
                fp(k,izp)=fp(k-1,izp)
              enddo
            elseif (nzgrid/=1) then
              do k=2,npar_loc
                fp(k,ixp)=fp(k-1,ixp)
                fp(k,iyp)=fp(k-1,iyp)
                fp(k,izp)=fp(k-1,izp)+dz_par
              enddo
            endif
          else
!  0-D
            fp(2:npar_loc,ixp)=fp(1,ixp)
            fp(2:npar_loc,iyp)=fp(1,iyp)
            fp(2:npar_loc,izp)=fp(1,izp)
          endif
          lequidistant=.true.
!
!  Shift particle locations slightly so that a mode appears.
!
        case ('shift')
          if (lroot) print*, 'init_particles: shift particle positions'
          if (.not. lequidistant) then
            if (lroot) print*, 'init_particles: must place particles equidistantly before shifting!'
            call fatal_error('init_particles','')
          endif
          k2_xxp=kx_xxp**2+ky_xxp**2+kz_xxp**2
          if (k2_xxp==0.0) then
            if (lroot) print*, &
                'init_particles: kx_xxp=ky_xxp=kz_xxp=0.0 is not allowed!'
            call fatal_error('init_particles','')
          endif
          do k=1,npar_loc
            fp(k,ixp) = fp(k,ixp) - kx_xxp/k2_xxp*amplxxp* &
                sin(kx_xxp*fp(k,ixp)+ky_xxp*fp(k,iyp)+kz_xxp*fp(k,izp))
            fp(k,iyp) = fp(k,iyp) - ky_xxp/k2_xxp*amplxxp* &
                sin(kx_xxp*fp(k,ixp)+ky_xxp*fp(k,iyp)+kz_xxp*fp(k,izp))
            fp(k,izp) = fp(k,izp) - kz_xxp/k2_xxp*amplxxp* &
                sin(kx_xxp*fp(k,ixp)+ky_xxp*fp(k,iyp)+kz_xxp*fp(k,izp))
          enddo

        case ('gaussian-z')
          if (lroot) print*, 'init_particles: Gaussian particle positions'
          do k=1,npar_loc
            if (nxgrid/=1) call random_number_wrapper(fp(k,ixp))
            if (nygrid/=1) call random_number_wrapper(fp(k,iyp))
            call random_number_wrapper(r)
            call random_number_wrapper(p)
            if (nprocz==2) then
              if (ipz==0) fp(k,izp)=-abs(zp0*sqrt(-2*alog(r))*cos(2*pi*p))
              if (ipz==1) fp(k,izp)= abs(zp0*sqrt(-2*alog(r))*cos(2*pi*p))
            else
              fp(k,izp)= zp0*sqrt(-2*alog(r))*cos(2*pi*p)
            endif
          enddo
          if (nxgrid/=1) &
              fp(1:npar_loc,ixp)=xyz0_loc(1)+fp(1:npar_loc,ixp)*Lxyz_loc(1)
          if (nygrid/=1) &
              fp(1:npar_loc,iyp)=xyz0_loc(2)+fp(1:npar_loc,iyp)*Lxyz_loc(2)

        case ('gaussian-r')
          if (lroot) print*, 'init_particles: Gaussian particle positions'
          do k=1,npar_loc
            call random_number_wrapper(r)
            call random_number_wrapper(p)
            call random_number_wrapper(q)
            fp(k,ixp)= xp0*sqrt(-2*alog(r))*cos(2*pi*p)*cos(2*pi*q)
            fp(k,iyp)= yp0*sqrt(-2*alog(r))*cos(2*pi*p)*sin(2*pi*q)
          enddo

        case ('hole')
          call map_nearest_grid(fp,ineargrid)
          call map_xxp_grid(f,fp,ineargrid)
          call sort_particles_imn(fp,ineargrid,ipar)
          do k=k1_imn(imn_array(m_hole+m1-1,n_hole+n1-1)), &
               k2_imn(imn_array(m_hole+m1-1,n_hole+n1-1))
            if (ineargrid(k,1)==l_hole+l1-1) then
              print*, k
              if (nxgrid/=0) fp(k,ixp)=fp(k,ixp)-dx
            endif
          enddo

        case ('streaming')
          call streaming(fp,f)

        case ('streaming_coldstart')
          call streaming_coldstart(fp,f)

        case ('constant-Ri')
          call constant_richardson(fp,f)

        case default
          if (lroot) &
              print*, 'init_particles: No such such value for initxxp: ', &
              trim(initxxp(j))
          call stop_it("")

        endselect

      enddo ! do j=1,ninit
!
!  Particles are not allowed to be present in non-existing dimensions.
!  This would give huge problems with interpolation later.
!
      if (nxgrid==1) fp(1:npar_loc,ixp)=x(nghost+1)
      if (nygrid==1) fp(1:npar_loc,iyp)=y(nghost+1)
      if (nzgrid==1) fp(1:npar_loc,izp)=z(nghost+1)
!
!  Redistribute particles among processors (now that positions are determined).
!
      call boundconds_particles(fp,npar_loc,ipar)
!
!  Map particle position on the grid.
!
      call map_nearest_grid(fp,ineargrid)
      call map_xxp_grid(f,fp,ineargrid)
!
!  Initial particle velocity.
!
      do j=1,ninit

        select case(initvvp(j))

        case ('nothing')
          if (lroot.and.j==1) print*, 'init_particles: No particle velocity set'
        case ('zero')
          if (lroot) print*, 'init_particles: Zero particle velocity'
          fp(1:npar_loc,ivpx:ivpz)=0.

        case ('constant')
          if (lroot) print*, 'init_particles: Constant particle velocity'
          if (lroot) &
              print*, 'init_particles: vpx0, vpy0, vpz0=', vpx0, vpy0, vpz0
          fp(1:npar_loc,ivpx)=vpx0
          fp(1:npar_loc,ivpy)=vpy0
          fp(1:npar_loc,ivpz)=vpz0

        case ('sinwave-phase')
          if (lroot) print*, 'init_particles: sinwave-phase'
          if (lroot) &
              print*, 'init_particles: vpx0, vpy0, vpz0=', vpx0, vpy0, vpz0
          do k=1,npar_loc
            fp(k,ivpx)=fp(k,ivpx)+vpx0*sin(kx_vpx*fp(k,ixp)+ky_vpx*fp(k,iyp)+kz_vpx*fp(k,izp)+phase_vpx)
            fp(k,ivpy)=fp(k,ivpy)+vpy0*sin(kx_vpy*fp(k,ixp)+ky_vpy*fp(k,iyp)+kz_vpy*fp(k,izp)+phase_vpy)
            fp(k,ivpz)=fp(k,ivpz)+vpz0*sin(kx_vpz*fp(k,ixp)+ky_vpz*fp(k,iyp)+kz_vpz*fp(k,izp)+phase_vpz)
          enddo

        case ('coswave-phase')
          if (lroot) print*, 'init_particles: coswave-phase'
          if (lroot) &
              print*, 'init_particles: vpx0, vpy0, vpz0=', vpx0, vpy0, vpz0
          do k=1,npar_loc
            fp(k,ivpx)=fp(k,ivpx)+vpx0*cos(kx_vpx*fp(k,ixp)+ky_vpx*fp(k,iyp)+kz_vpx*fp(k,izp)+phase_vpx)
            fp(k,ivpy)=fp(k,ivpy)+vpy0*cos(kx_vpy*fp(k,ixp)+ky_vpy*fp(k,iyp)+kz_vpy*fp(k,izp)+phase_vpy)
            fp(k,ivpz)=fp(k,ivpz)+vpz0*cos(kx_vpz*fp(k,ixp)+ky_vpz*fp(k,iyp)+kz_vpz*fp(k,izp)+phase_vpz)
          enddo

        case ('random')
          if (lroot) print*, 'init_particles: Random particle velocities; '// &
              'delta_vp0=', delta_vp0
          do k=1,npar_loc
            call random_number_wrapper(fp(k,ivpx))
            call random_number_wrapper(fp(k,ivpy))
            call random_number_wrapper(fp(k,ivpz))
          enddo
          fp(1:npar_loc,ivpx) = -delta_vp0 + fp(1:npar_loc,ivpx)*2*delta_vp0
          fp(1:npar_loc,ivpy) = -delta_vp0 + fp(1:npar_loc,ivpy)*2*delta_vp0
          fp(1:npar_loc,ivpz) = -delta_vp0 + fp(1:npar_loc,ivpz)*2*delta_vp0

        case ('average-to-zero')
          call mpireduce_sum_scl(sum(fp(1:npar_loc,ivpx)),vpx_sum)
          fp(1:npar_loc,ivpx)=fp(1:npar_loc,ivpx)-vpx_sum/npar
          call mpireduce_sum_scl(sum(fp(1:npar_loc,ivpy)),vpy_sum)
          fp(1:npar_loc,ivpy)=fp(1:npar_loc,ivpy)-vpy_sum/npar
          call mpireduce_sum_scl(sum(fp(1:npar_loc,ivpz)),vpz_sum)
          fp(1:npar_loc,ivpz)=fp(1:npar_loc,ivpz)-vpz_sum/npar

        case ('follow-gas')
          if (lroot) &
              print*, 'init_particles: Particle velocity equal to gas velocity'
          do k=1,npar_loc
            call interpolate_linear(f,iux,iuz,fp(k,ixp:izp),uup,ineargrid(k,:))
            fp(k,ivpx:ivpz) = uup
          enddo

        case('jeans-wave-dustpar-x')
        ! assumes rhs_poisson_const=1 !
          do k=1,npar_loc
            fp(k,ivpx) = fp(k,ivpx) - amplxxp* &
                (sqrt(1+4*1.0*1.0*tausp**2)-1)/ &
                (2*kx_xxp*1.0*tausp)*sin(kx_xxp*(fp(k,ixp)))
          enddo

        case('dragforce_equilibrium')
!
!  Equilibrium between drag forces on dust and gas and other forces
!  (from Nakagawa, Sekiya, & Hayashi 1986).
!
          if (lroot) then
            print*, 'init_particles: drag equilibrium'
            print*, 'init_particles: beta_glnrho_global=', beta_glnrho_global
          endif
!  Calculate average dust-to-gas ratio in box.
          if (ldensity_nolog) then
            eps = sum(f(l1:l2,m1:m2,n1:n2,irhop))/ &
                sum(f(l1:l2,m1:m2,n1:n2,ilnrho))
          else
            eps = sum(f(l1:l2,m1:m2,n1:n2,irhop))/ &
                sum(exp(f(l1:l2,m1:m2,n1:n2, ilnrho)))
          endif

          if (lroot) print*, 'init_particles: average dust-to-gas ratio=', eps
!  Set gas velocity field.
          do l=l1,l2; do m=m1,m2; do n=n1,n2
            cs=sqrt(cs20)
!  Take either global or local dust-to-gas ratio.
            if (.not. ldragforce_equi_global_eps) then
              if (ldensity_nolog) then
                eps = f(l,m,n,irhop)/f(l,m,n,ilnrho)
              else
                eps = f(l,m,n,irhop)/exp(f(l,m,n,ilnrho))
              endif
            endif

            f(l,m,n,iux) = f(l,m,n,iux) - &
                beta_glnrho_global(1)*eps*Omega*tausp/ &
                ((1.0+eps)**2+(Omega*tausp)**2)*cs
            f(l,m,n,iuy) = f(l,m,n,iuy) + &
                beta_glnrho_global(1)*(1+eps+(Omega*tausp)**2)/ &
                (2*((1.0+eps)**2+(Omega*tausp)**2))*cs

          enddo; enddo; enddo
!  Set particle velocity field.
          do k=1,npar_loc
!  Take either global or local dust-to-gas ratio.
            if (.not. ldragforce_equi_global_eps) then
              ix0=ineargrid(k,1); iy0=ineargrid(k,2); iz0=ineargrid(k,3)
              if (ldensity_nolog) then
                eps = f(ix0,iy0,iz0,irhop)/f(ix0,iy0,iz0,ilnrho)
              else
                eps = f(ix0,iy0,iz0,irhop)/exp(f(ix0,iy0,iz0,ilnrho))
              endif
            endif

            fp(k,ivpx) = fp(k,ivpx) + &
                beta_glnrho_global(1)*Omega*tausp/ &
                ((1.0+eps)**2+(Omega*tausp)**2)*cs
            fp(k,ivpy) = fp(k,ivpy) + &
                beta_glnrho_global(1)*(1+eps)/ &
                (2*((1.0+eps)**2+(Omega*tausp)**2))*cs

          enddo

        case('dragforce_equi_dust')
!
!  Equilibrium between drag force and Coriolis force on the dust.
!
          if (lroot) then
            print*, 'init_particles: drag equilibrium dust'
            print*, 'init_particles: beta_dPdr_dust=', beta_dPdr_dust
          endif
!  Set particle velocity field.
          cs=sqrt(cs20)
          do k=1,npar_loc
            fp(k,ivpx) = fp(k,ivpx) + &
                1/gamma*beta_dPdr_dust/ &
                (Omega*tausp+1/(Omega*tausp))*cs
            fp(k,ivpy) = fp(k,ivpy) - &
                1/gamma*beta_dPdr_dust*Omega*tausp*0.5/ &
                (Omega*tausp+1/(Omega*tausp))*cs
          enddo

       case ('Keplerian','keplerian')
!
!  Keplerian velocities assuming GM=1 
!
          if (lroot) then
            print*,'init_particles: Keplerian velocities assuming GM=1'
            if (lspherical_coords) call stop_it("Keplerian particle "//&
                 "initial condition: not implemented for spherical coordinates")
          endif
          do k=1,npar_loc
            if (lcartesian_coords) then
              !tmp is the Keplerian velocity
              rad=sqrt(fp(k,ixp)**2 + fp(k,iyp)**2 + fp(k,izp)**2)
              tmp=rad**(-1.5)
              fp(k,ivpx) = -tmp*fp(k,iyp)
              fp(k,ivpy) =  tmp*fp(k,ixp)
              fp(k,ivpz) =  0.0
            elseif (lcylindrical_coords) then
              rad=fp(k,ixp)
              tmp=rad**(-1.5)
              fp(k,ivpx) =  0.0
              fp(k,ivpy) =  tmp*rad
              fp(k,ivpz) =  0.0
            endif
          enddo

        case default
          if (lroot) &
              print*, 'init_particles: No such such value for initvvp: ', &
              trim(initvvp(j))
          call stop_it("")

        endselect
!
      enddo ! do j=1,ninit
!
!  Sort particles (must happen at the end of the subroutine so that random
!  positions and velocities are not displaced relative to when there is no
!  sorting).
!
      call sort_particles_imn(fp,ineargrid,ipar)
!
    endsubroutine init_particles
!***********************************************************************
    subroutine streaming_coldstart(fp,f)
!
!  Mode that is unstable to the streaming instability of Youdin & Goodman (2005)
!
!  14-apr-06/anders: coded
!
      use EquationOfState, only: gamma, beta_glnrho_global
      use General, only: random_number_wrapper
!
      real, dimension (mpar_loc,mpvar) :: fp
      real, dimension (mx,my,mz,mfarray) :: f
!
      real :: eta_glnrho, v_Kepler, ampluug, dxp, dzp
      integer :: i, i1, i2, j, k, npar_loc_x, npar_loc_z
!
!  The number of particles per grid cell must be a quadratic number.
!
      if ( sqrt(npar/real(nwgrid))/=int(sqrt(npar/real(nwgrid))) .or. &
           sqrt(npar_loc/real(nw))/=int(sqrt(npar_loc/real(nw))) ) then
        if (lroot) then
          print*, 'streaming_coldstart: the number of particles per grid must'
          print*, '                     be a quadratic number!'
        endif
        print*, '                     iproc, npar/nw, npar_loc/nwgrid=', &
            iproc, npar/real(nwgrid), npar_loc/real(nw)
        call fatal_error('streaming_coldstart','')
      endif
!
!  Define a few disc parameters.
!
      eta_glnrho = -0.5*abs(beta_glnrho_global(1))*beta_glnrho_global(1)
      v_Kepler   =  1.0/abs(beta_glnrho_global(1))
      if (lroot) print*, 'streaming: eta, vK=', eta_glnrho, v_Kepler
!
!  Place particles equidistantly.
!
      npar_loc_x=sqrt(npar_loc/(Lxyz_loc(3)/Lxyz_loc(1)))
      npar_loc_z=npar_loc/npar_loc_x
      dxp=Lxyz_loc(1)/npar_loc_x
      dzp=Lxyz_loc(3)/npar_loc_z
      do i=1,npar_loc_x
        i1=(i-1)*npar_loc_z+1; i2=i*npar_loc_z
        fp(i1:i2,ixp)=mod(i*dxp,Lxyz_loc(1))+dxp/2
        do j=i1,i2
          fp(j,izp)=xyz0_loc(3)+dzp/2+(j-i1)*dzp
        enddo
      enddo
!
!  Shift particle locations slightly so that wanted mode appears.
!
      do k=1,npar_loc
        fp(k,ixp) = fp(k,ixp) - &
            amplxxp/(2*(kx_xxp**2+kz_xxp**2))* &
            (kx_xxp*sin(kx_xxp*fp(k,ixp)+kz_xxp*fp(k,izp))+ &
             kx_xxp*sin(kx_xxp*fp(k,ixp)-kz_xxp*fp(k,izp)))
        fp(k,izp) = fp(k,izp) - &
            amplxxp/(2*(kx_xxp**2+kz_xxp**2))* &
            (kz_xxp*sin(kx_xxp*fp(k,ixp)+kz_xxp*fp(k,izp))- &
             kz_xxp*sin(kx_xxp*fp(k,ixp)-kz_xxp*fp(k,izp)))
        fp(k,ixp) = fp(k,ixp) + &
            kx_xxp/(2*(kx_xxp**2+kz_xxp**2))*amplxxp**2* &
            sin(2*(kx_xxp*fp(k,ixp)+kz_xxp*fp(k,izp)))
        fp(k,izp) = fp(k,izp) + &
            kz_xxp/(2*(kx_xxp**2+kz_xxp**2))*amplxxp**2* &
            sin(2*(kx_xxp*fp(k,ixp)+kz_xxp*fp(k,izp)))
      enddo
!  Set particle velocity.
      do k=1,npar_loc
        fp(k,ivpx) = fp(k,ivpx) + eta_glnrho*v_Kepler*amplxxp* &
            ( real(coeff(1))*cos(kx_xxp*fp(k,ixp)) - &
             aimag(coeff(1))*sin(kx_xxp*fp(k,ixp)))*cos(kz_xxp*fp(k,izp))
        fp(k,ivpy) = fp(k,ivpy) + eta_glnrho*v_Kepler*amplxxp* &
            ( real(coeff(2))*cos(kx_xxp*fp(k,ixp)) - &
             aimag(coeff(2))*sin(kx_xxp*fp(k,ixp)))*cos(kz_xxp*fp(k,izp))
        fp(k,ivpz) = fp(k,ivpz) + eta_glnrho*v_Kepler*(-amplxxp)* &
            (aimag(coeff(3))*cos(kx_xxp*fp(k,ixp)) + &
              real(coeff(3))*sin(kx_xxp*fp(k,ixp)))*sin(kz_xxp*fp(k,izp))
      enddo
!
!  Change the gas velocity amplitude so that the numerical error on the drag
!  force is corrected (the error is due to the interpolation of the gas
!  velocity field to the positions of the particles). A better way to correct
!  this is to go to a quadratic interpolation scheme.
!
      ampluug=amplxxp
      if (lcoldstart_amplitude_correction) &
          ampluug=amplxxp/(1-dx**2/8*(kx_xxp**2+kz_xxp**2))
!
!  Set fluid fields.
!
      do m=m1,m2; do n=n1,n2
        f(l1:l2,m,n,ilnrho) = f(l1:l2,m,n,ilnrho) + &
            amplxxp* &
            ( real(coeff(7))*cos(kx_xxp*x(l1:l2)) - &
             aimag(coeff(7))*sin(kx_xxp*x(l1:l2)))*cos(kz_xxp*z(n))
!
        f(l1:l2,m,n,iux) = f(l1:l2,m,n,iux) + &
            eta_glnrho*v_Kepler*ampluug* &
            ( real(coeff(4))*cos(kx_xxp*x(l1:l2)) - &
             aimag(coeff(4))*sin(kx_xxp*x(l1:l2)))*cos(kz_xxp*z(n))
!
        f(l1:l2,m,n,iuy) = f(l1:l2,m,n,iuy) + &
            eta_glnrho*v_Kepler*ampluug* &
            ( real(coeff(5))*cos(kx_xxp*x(l1:l2)) - &
             aimag(coeff(5))*sin(kx_xxp*x(l1:l2)))*cos(kz_xxp*z(n))
!
        f(l1:l2,m,n,iuz) = f(l1:l2,m,n,iuz) + &
            eta_glnrho*v_Kepler*(-ampluug)* &
            (aimag(coeff(6))*cos(kx_xxp*x(l1:l2)) + &
              real(coeff(6))*sin(kx_xxp*x(l1:l2)))*sin(kz_xxp*z(n))
      enddo; enddo
!
    endsubroutine streaming_coldstart
!***********************************************************************
    subroutine streaming(fp,f)
!
!  Mode that is unstable to the streaming instability of Youdin & Goodman (2005)
!
!  30-jan-06/anders: coded
!
      use EquationOfState, only: gamma, beta_glnrho_global
      use General, only: random_number_wrapper
!
      real, dimension (mpar_loc,mpvar) :: fp
      real, dimension (mx,my,mz,mfarray) :: f
!
      real :: eta_glnrho, v_Kepler, kx, kz
      real :: r, p, xprob, zprob, dzprob, fprob, dfprob
      integer :: j, k
      logical :: lmigration_redo_org
!
!  Define a few disc parameters.
!
      eta_glnrho = -0.5*abs(beta_glnrho_global(1))*beta_glnrho_global(1)
      v_Kepler   =  1.0/abs(beta_glnrho_global(1))
      if (lroot) print*, 'streaming: eta, vK=', eta_glnrho, v_Kepler
!
!  Place particles according to probability function.
!
!  Invert
!    r = x
!    p = int_0^z f(x,z') dz' = z + A/kz*cos(kx*x)*sin(kz*z)
!  where r and p are random numbers between 0 and 1.
      kx=kx_xxp*Lxyz(1); kz=kz_xxp*Lxyz(3)
      do k=1,npar_loc

        call random_number_wrapper(r)
        call random_number_wrapper(p)

        fprob = 1.0
        zprob = 0.0

        j=0
!  Use Newton-Raphson iteration to invert function.
        do while ( abs(fprob)>0.0001 )

          xprob = r
          fprob = zprob + amplxxp/kz*cos(kx*xprob)*sin(kz*zprob) - p
          dfprob= 1.0 + amplxxp*cos(kx*xprob)*cos(kz*zprob)
          dzprob= -fprob/dfprob
          zprob = zprob+0.2*dzprob

          j=j+1

        enddo

        if ( mod(k,npar_loc/100)==0) then
          print '(i7,i3,4f11.7)', k, j, r, p, xprob, zprob
        endif

        fp(k,ixp)=xprob*Lxyz(1)+xyz0(1)
        fp(k,izp)=zprob*Lxyz(3)+xyz0(3)
!  Set particle velocity.
        fp(k,ivpx) = fp(k,ivpx) + eta_glnrho*v_Kepler*amplxxp* &
            ( real(coeff(1))*cos(kx_xxp*fp(k,ixp)) - &
             aimag(coeff(1))*sin(kx_xxp*fp(k,ixp)))*cos(kz_xxp*fp(k,izp))
        fp(k,ivpy) = fp(k,ivpy) + eta_glnrho*v_Kepler*amplxxp* &
            ( real(coeff(2))*cos(kx_xxp*fp(k,ixp)) - &
             aimag(coeff(2))*sin(kx_xxp*fp(k,ixp)))*cos(kz_xxp*fp(k,izp))
        fp(k,ivpz) = fp(k,ivpz) + eta_glnrho*v_Kepler*(-amplxxp)* &
            (aimag(coeff(3))*cos(kx_xxp*fp(k,ixp)) + &
              real(coeff(3))*sin(kx_xxp*fp(k,ixp)))*sin(kz_xxp*fp(k,izp))

      enddo
!
!  Particles were placed randomly in the entire simulation space, so they need
!  to be send to the correct processors now.
!
      if (lmpicomm) then
        lmigration_redo_org=lmigration_redo
        lmigration_redo=.true.
        call redist_particles_procs(fp,npar_loc,ipar)
        lmigration_redo=lmigration_redo_org
      endif
!
!  Set fluid fields.
!
      do m=m1,m2; do n=n1,n2
        f(l1:l2,m,n,ilnrho) = f(l1:l2,m,n,ilnrho) + &
            (eta_glnrho*v_Kepler)**2*amplxxp* &
            ( real(coeff(7))*cos(kx_xxp*x(l1:l2)) - &
             aimag(coeff(7))*sin(kx_xxp*x(l1:l2)))*cos(kz_xxp*z(n))
!
        f(l1:l2,m,n,iux) = f(l1:l2,m,n,iux) + &
            eta_glnrho*v_Kepler*amplxxp* &
            ( real(coeff(4))*cos(kx_xxp*x(l1:l2)) - &
             aimag(coeff(4))*sin(kx_xxp*x(l1:l2)))*cos(kz_xxp*z(n))
!
        f(l1:l2,m,n,iuy) = f(l1:l2,m,n,iuy) + &
            eta_glnrho*v_Kepler*amplxxp* &
            ( real(coeff(5))*cos(kx_xxp*x(l1:l2)) - &
             aimag(coeff(5))*sin(kx_xxp*x(l1:l2)))*cos(kz_xxp*z(n))
!
        f(l1:l2,m,n,iuz) = f(l1:l2,m,n,iuz) + &
            eta_glnrho*v_Kepler*(-amplxxp)* &
            (aimag(coeff(6))*cos(kx_xxp*x(l1:l2)) + &
              real(coeff(6))*sin(kx_xxp*x(l1:l2)))*sin(kz_xxp*z(n))
      enddo; enddo
!
    endsubroutine streaming
!***********************************************************************
    subroutine constant_richardson(fp,f)
!
!  Setup dust density with a constant Richardson number (Sekiya, 1998).
!    eps=1/sqrt(z^2/Hd^2+1/(1+eps1)^2)-1
!
!  14-sep-05/anders: coded
!
      use EquationOfState, only: beta_glnrho_scaled, gamma, cs20
      use General, only: random_number_wrapper
!
      real, dimension (mpar_loc,mpvar) :: fp
      real, dimension (mx,my,mz,mfarray) :: f
!
      integer, parameter :: nz_inc=10
      real, dimension (nz_inc*nz) :: z_dense, eps
      real :: r, Hg, Hd, frac, rho1, Sigmad, Sigmad_num, Xi, fXi, dfdXi
      real :: dz_dense, eps_point, z00_dense, rho, lnrho
      integer :: nz_dense=nz_inc*nz, npar_bin
      integer :: i, i0, k
!
!  Calculate dust "scale height".
!
      rho1=1.0
      Hg=1.0
      Sigmad=eps_dtog*rho1*Hg*sqrt(2*pi)
      Hd = sqrt(Ri0)*abs(beta_glnrho_scaled(1))/2*1.0
!
!  Need to find eps1 that results in given dust column density.
!
      Xi = sqrt(eps1*(2+eps1))/(1+eps1)
      fXi=-2*Xi + alog((1+Xi)/(1-Xi))-Sigmad/(Hd*rho1)
      i=0
!
!  Newton-Raphson on equation Sigmad/(Hd*rho1)=-2*Xi + alog((1+Xi)/(1-Xi)).
!  Here Xi = sqrt(eps1*(2+eps1))/(1+eps1).
!
      do while (abs(fXi)>=0.00001)

        dfdXi=2*Xi**2/(1-Xi**2)
        Xi=Xi-0.1*fXi/dfdXi

        fXi=-2*Xi + alog((1+Xi)/(1-Xi))-Sigmad/(Hd*rho1)

        i=i+1
        if (i>=1000) stop

      enddo
!
!  Calculate eps1 from Xi.
!
      eps1=-1+1/sqrt(-(Xi**2)+1)
      if (lroot) print*, 'constant_richardson: Hd, eps1=', Hd, eps1
!
!  Make z denser for higher resolution in density.
!
      dz_dense=Lxyz_loc(3)/nz_dense
      z00_dense=xyz0_loc(3)+0.5*dz_dense
      do n=1,nz_dense
        z_dense(n)=z00_dense+(n-1)*dz_dense
      enddo
!
!  Dust-to-gas ratio as a function of z (with cutoff).
!
      eps=1/sqrt(z_dense**2/Hd**2+1/(1+eps1)**2)-1
      where (eps<=0.0) eps=0.0
!
!  Calculate the dust column density numerically.
!
      Sigmad_num=sum(rho1*eps*dz_dense)
      if (lroot) print*, 'constant_richardson: Sigmad, Sigmad (numerical) = ', &
          Sigmad, Sigmad_num
!
!  Place particles according to probability function.
!
      i0=0
      do n=1,nz_dense
        frac=eps(n)/Sigmad_num*dz_dense
        npar_bin=int(frac*npar_loc)
        if (npar_bin>=2.and.mod(n,2)==0) npar_bin=npar_bin+1
        do i=i0+1,i0+npar_bin
          if (i<=npar_loc) then
            call random_number_wrapper(r)
            fp(i,izp)=z_dense(n)+(2*r-1.0)*dz_dense/2
          endif
        enddo
        i0=i0+npar_bin
      enddo
      if (lroot) print '(A,i7,A)', 'constant_richardson: placed ', &
          i0, ' particles according to Ri=const'
!
!  Particles left out by round off are just placed randomly.
!
      if (i0+1<=npar_loc) then
        do k=i0+1,npar_loc
          call random_number_wrapper(fp(k,izp))
          fp(k,izp)=xyz0(3)+fp(k,izp)*Lxyz(3)
        enddo
        if (lroot) print '(A,i7,A)', 'constant_richardson: placed ', &
            npar_loc-i0, ' particles randomly.'
      endif
!
!  Random positions in x and y.
!
      do k=1,npar_loc
        if (nxgrid/=1) call random_number_wrapper(fp(k,ixp))
        if (nygrid/=1) call random_number_wrapper(fp(k,iyp))
      enddo
      if (nxgrid/=1) &
          fp(1:npar_loc,ixp)=xyz0_loc(1)+fp(1:npar_loc,ixp)*Lxyz_loc(1)
      if (nygrid/=1) &
          fp(1:npar_loc,iyp)=xyz0_loc(2)+fp(1:npar_loc,iyp)*Lxyz_loc(2)
!
!  Set gas velocity according to dust-to-gas ratio and global pressure gradient.
!
      do imn=1,ny*nz

        n=nn(imn); m=mm(imn)

        if (abs(z(n))<=Hd*sqrt(1-1/(1+eps1)**2)) then
          lnrho = -sqrt(z(n)**2/Hd**2+1/(1+eps1)**2)* &
              gamma*Omega**2*Hd**2/cs20 + gamma*Omega**2*Hd**2/(cs20*(1+eps1))
        else
          lnrho = -0.5*gamma*Omega**2/cs20*z(n)**2 + &
              gamma*Omega**2*Hd**2/cs20*(1/(1+eps1)-1/(2*(1+eps1)**2) - 0.5)
        endif
!
!  Isothermal stratification.
!
        if (lentropy) f(l1:l2,m,n,iss) = (1/gamma-1.0)*lnrho

        rho=exp(lnrho)

        if (ldensity_nolog) then
          f(l1:l2,m,n,ilnrho)=rho
        else
          f(l1:l2,m,n,ilnrho)=lnrho
        endif

        eps_point=1/sqrt(z(n)**2/Hd**2+1/(1+eps1)**2)-1
        if (eps_point<=0.0) eps_point=0.0

        f(l1:l2,m,n,iux) = f(l1:l2,m,n,iux) - &
            cs20*beta_glnrho_scaled(1)*eps_point*tausp/ &
            (1.0+2*eps_point+eps_point**2+(Omega*tausp)**2)
        f(l1:l2,m,n,iuy) = f(l1:l2,m,n,iuy) + &
            cs20*beta_glnrho_scaled(1)*(1+eps_point+(Omega*tausp)**2)/ &
            (2*Omega*(1.0+2*eps_point+eps_point**2+(Omega*tausp)**2))
        f(l1:l2,m,n,iuz) = f(l1:l2,m,n,iuz) + 0.0
      enddo
!
!  Set particle velocity.
!
      do k=1,npar_loc

        eps_point=1/sqrt(fp(k,izp)**2/Hd**2+1/(1+eps1)**2)-1
        if (eps_point<=0.0) eps_point=0.0

        fp(k,ivpx) = fp(k,ivpx) + &
            cs20*beta_glnrho_scaled(1)*tausp/ &
            (1.0+2*eps_point+eps_point**2+(Omega*tausp)**2)
        fp(k,ivpy) = fp(k,ivpy) + &
            cs20*beta_glnrho_scaled(1)*(1+eps_point)/ &
            (2*Omega*(1.0+2*eps_point+eps_point**2+(Omega*tausp)**2))
        fp(k,ivpz) = fp(k,ivpz) - tausp*Omega**2*fp(k,izp)

      enddo
!
    endsubroutine constant_richardson
!***********************************************************************
    subroutine pencil_criteria_particles()
!
!  All pencils that the Particles module depends on are specified here.
!
!  20-04-06/anders: coded
!
      use Cdata
!
      if (ldragforce_gas_par) then
        lpenc_requested(i_epsp)=.true.
        lpenc_requested(i_np)=.true.
      endif
      if (ldragforce_heat .or. lcollisional_heat) then
        lpenc_requested(i_TT1)=.true.
        lpenc_requested(i_rho1)=.true.
      endif
      if (lcollisional_cooling_rms) then
        lpenc_requested(i_epsp)=.true.
      endif
      if (lcollisional_cooling_rms .or. lcollisional_dragforce_cooling) then
        lpenc_requested(i_np)=.true.
        lpenc_requested(i_rho1)=.true.
      endif
      if (ldraglaw_epstein_transonic  .or.&
          ldraglaw_eps_stk_transonic) then
        lpenc_requested(i_uu)=.true.
        lpenc_requested(i_rho)=.true.
        lpenc_requested(i_cs2)=.true.
      endif
      if (lshort_friction_approx) then
        lpenc_requested(i_fpres)=.true.
        lpenc_requested(i_jxbr)=.true.
      endif
!
      lpenc_diagnos(i_np)=.true.
      lpenc_diagnos(i_rhop)=.true.
      if (idiag_dedragp/=0 .or. idiag_decollp/=0) then
        lpenc_diagnos(i_TT1)=.true.
        lpenc_diagnos(i_rho1)=.true.
      endif
      if (idiag_epspmx/=0 .or. idiag_epspmy/=0 .or. idiag_epspmz/=0) &
          lpenc_diagnos(i_epsp)=.true.
      if (idiag_rhopmxy/=0 .or. idiag_rhopmxz/=0) lpenc_diagnos2d(i_rhop)=.true.
!
    endsubroutine pencil_criteria_particles
!***********************************************************************
    subroutine pencil_interdep_particles(lpencil_in)
!
!  Interdependency among pencils provided by the Particles module
!  is specified here.
!
!  16-feb-06/anders: dummy
!
      logical, dimension(npencils) :: lpencil_in
!
      if (lpencil_in(i_rhop) .and. irhop==0) lpencil_in(i_np)=.true.
!
      if (lpencil_in(i_epsp)) then
        lpencil_in(i_rhop)=.true.
        lpencil_in(i_rho1)=.true.
      endif
!
    endsubroutine pencil_interdep_particles
!***********************************************************************
    subroutine calc_pencils_particles(f,p)
!
!  Calculate particle pencils.
!
!  16-feb-06/anders: dummy
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      if (lpencil(i_np)) p%np=f(l1:l2,m,n,inp)
!
      if (lpencil(i_rhop)) then
        if (irhop/=0) then
          p%rhop=f(l1:l2,m,n,irhop)
        else
          p%rhop=rhop_tilde*f(l1:l2,m,n,inp)
        endif
      endif
!
      if (lpencil(i_epsp)) p%epsp=p%rhop*p%rho1
!
    endsubroutine calc_pencils_particles
!***********************************************************************
    subroutine dxxp_dt_pencil(f,df,fp,dfp,p,ineargrid)
!
!  Evolution of particle position (called from main pencil loop).
!
!  25-apr-06/anders: dummy
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (mpar_loc,mpvar) :: fp, dfp
      type (pencil_case) :: p
      integer, dimension (mpar_loc,3) :: ineargrid
!
      if (NO_WARN) print*, f, df, fp, dfp, p, ineargrid
!
    endsubroutine dxxp_dt_pencil
!***********************************************************************
    subroutine dvvp_dt_pencil(f,df,fp,dfp,p,ineargrid)
!
!  Evolution of dust particle velocity (called from main pencil loop).
!
!  25-apr-06/anders: coded
!
      use Cdata
      use Cparam, only: lparticles_spin
      use EquationOfState, only: cs20, gamma
      use Mpicomm, only: stop_it
      use Particles_number, only: get_nptilde
      use Particles_spin, only: calc_liftforce
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
      real, dimension (mpar_loc,mpvar) :: fp, dfp
      integer, dimension (mpar_loc,3) :: ineargrid
!
      real, dimension (nx) :: dt1_drag, dt1_drag_gas, dt1_drag_dust
      real, dimension (nx) :: drag_heat
      real, dimension (3) :: dragforce, liftforce, bforce, uup
      real, dimension(:), allocatable :: rep,stocunn
      real :: rho_point, rho1_point, tausp1_par, up2
      real :: weight, weight_x, weight_y, weight_z
      real :: dt1_advpx, dt1_advpy, dt1_advpz
      integer :: k, l, ix0, iy0, iz0
      integer :: ixx, iyy, izz, ixx0, iyy0, izz0, ixx1, iyy1, izz1
      logical :: lsink
!
      intent (in) :: fp, ineargrid
      intent (inout) :: f, df, dfp
!
!  Identify module.
!     
      if (headtt) then
        if (lroot) print*,'dvvp_dt_pencil: calculate dvvp_dt'
      endif
!
!  Precalculate certain quantities, if necessary.
!
      if (npar_imn(imn)/=0) then
!
!  Precalculate particle Reynolds numbers.
!
        if (ldraglaw_steadystate.or.lparticles_spin) then
          allocate(rep(k1_imn(imn):k2_imn(imn)))
!
          if (.not.allocated(rep)) then
            call fatal_error('dvvp_dt_pencil','unable to allocate sufficient'//&
              ' memory for rep')
          endif
!
          call calc_pencil_rep(fp,interp_uu,rep)
        endif
!
!  Precalculate Stokes-Cunningham factor
!
        if (ldraglaw_steadystate.or.lbrownian_forces) then
          allocate(stocunn(k1_imn(imn):k2_imn(imn)))
          if (.not.allocated(stocunn)) then
            call fatal_error('dvvp_dt_pencil','unable to allocate sufficient'//&
              'memory for stocunn')
          endif
!
          call calc_stokes_cunningham(fp,stocunn)
        endif
      endif
!
!  Drag force on particles and on gas.
!
      if (ldragforce_dust_par .and. t>=tstart_dragforce_par) then
        if (headtt) print*,'dvvp_dt: Add drag force; tausp=', tausp
!
        if (ldragforce_heat.or.(ldiagnos.and.idiag_dedragp/=0)) drag_heat=0.0
!
        if (npar_imn(imn)/=0) then
!
          if (lfirst.and.ldt) then
            dt1_drag_dust=0.0
            if (ldragforce_gas_par) dt1_drag_gas=0.0
          endif
!
!  Loop over all particles in current pencil.
!
          do k=k1_imn(imn),k2_imn(imn)
!
!  Exclude the massive sink particles from the drag calculations
!
            lsink=(lparticles_nbody.and.any(ipar(k).eq.ipar_sink))
            if (.not.lsink) then
              ix0=ineargrid(k,1)
              iy0=ineargrid(k,2)
              iz0=ineargrid(k,3)
!
!  The interpolated gas velocity is either precalculated, and stored in
!  interp_uu, or it must be calculated here.
!
              if (.not.interp%luu) then
                if (lhydro) then
                  if (lparticlemesh_cic) then
                    call interpolate_linear( &
                         f,iux,iuz,fp(k,ixp:izp),uup,ineargrid(k,:),ipar(k) )
                  elseif (lparticlemesh_tsc) then
                    if (linterpolate_spline) then
                      call interpolate_quadratic_spline( &
                           f,iux,iuz,fp(k,ixp:izp),uup,ineargrid(k,:),ipar(k) )
                    else
                      call interpolate_quadratic( &
                           f,iux,iuz,fp(k,ixp:izp),uup,ineargrid(k,:),ipar(k) )
                    endif
                  else
                    uup=f(ix0,iy0,iz0,iux:iuz)
                  endif
                else
                  uup=0.0
                endif
              else
                uup=interp_uu(k,:)
              endif
!
!  Get the friction time. For the case of |uup| ~> cs, the Epstein drag law
!  is dependent on the relative mach number, hence the need to feed uup as 
!  an optional argument to get_frictiontime.
!
              if (ldraglaw_epstein_transonic .or. &
                  ldraglaw_eps_stk_transonic) then
                call get_frictiontime(f,fp,p,ineargrid,k,tausp1_par,uup)
              elseif (ldraglaw_steadystate) then
                call get_frictiontime(f,fp,p,ineargrid,k,tausp1_par,rep=rep(k),&
                  stocunn=stocunn(k))
              else
                call get_frictiontime(f,fp,p,ineargrid,k,tausp1_par)
              endif
!
!  Short friction time approximation. The particle velocity is set to the
!  terminal velocity in dxxp_dt later. The cycle statement refers to the
!  loop over particles above.
!
              if (lshort_friction_approx .and. &
                  tausp1_par>tausp1_short_friction) cycle
!
!  Calculate and add drag force.
!
              dragforce = -tausp1_par*(fp(k,ivpx:ivpz)-uup)
!
              dfp(k,ivpx:ivpz) = dfp(k,ivpx:ivpz) + dragforce
!
!  Back-reaction friction force from particles on gas. Three methods are
!  implemented for assigning a particle to the mesh (see Hockney & Eastwood):
!
!    0. NGP (Nearest Grid Point)
!       The entire effect of the particle goes to the nearest grid point.
!    1. CIC (Cloud In Cell)
!       The particle has a region of influence with the size of a grid cell.
!       This is equivalent to a first order (spline) interpolation scheme.
!    2. TSC (Triangular Shaped Cloud)
!       The particle is spread over a length of two grid cells, but with
!       a density that falls linearly outwards.
!       This is equivalent to a second order spline interpolation scheme.
!
              if (ldragforce_gas_par) then
!
!  Cloud In Cell (CIC) scheme.
!
                if (lparticlemesh_cic) then
                  ixx0=ix0; iyy0=iy0; izz0=iz0
                  ixx1=ix0; iyy1=iy0; izz1=iz0
!
!  Particle influences the 8 surrounding grid points. The reference point is
!  the grid point at the lower left corner.
!
                  if ( (x(ix0)>fp(k,ixp)) .and. nxgrid/=1) ixx0=ixx0-1
                  if ( (y(iy0)>fp(k,iyp)) .and. nygrid/=1) iyy0=iyy0-1
                  if ( (z(iz0)>fp(k,izp)) .and. nzgrid/=1) izz0=izz0-1
                  if (nxgrid/=1) ixx1=ixx0+1
                  if (nygrid/=1) iyy1=iyy0+1
                  if (nzgrid/=1) izz1=izz0+1
                  do izz=izz0,izz1; do iyy=iyy0,iyy1; do ixx=ixx0,ixx1
                    weight=1.0
                    if (nxgrid/=1) &
                         weight=weight*( 1.0-abs(fp(k,ixp)-x(ixx))*dx_1(ixx) )
                    if (nygrid/=1) &
                         weight=weight*( 1.0-abs(fp(k,iyp)-y(iyy))*dy_1(iyy) )
                    if (nzgrid/=1) &
                         weight=weight*( 1.0-abs(fp(k,izp)-z(izz))*dz_1(izz) )
!  Save the calculation of rho1 when inside pencil.
                    if ( (iyy/=m).or.(izz/=n).or.(ixx<l1).or.(ixx>l2) ) then
                      rho_point=f(ixx,iyy,izz,ilnrho)
                      if (.not. ldensity_nolog) rho_point=exp(rho_point)
                      rho1_point=1/rho_point
                    else
                      rho1_point=p%rho1(ixx-nghost)
                    endif
!  Add friction force to grid point.
                    if (lcartesian_coords) then
                      df(ixx,iyy,izz,iux:iuz)=df(ixx,iyy,izz,iux:iuz) - &
                           rhop_tilde*rho1_point*dragforce*weight
                    else
                      df(ixx,iyy,izz,iux:iuz)=df(ixx,iyy,izz,iux:iuz) - &
                           mp_tilde*dvolume_1(ixx)*rho1_point*dragforce*weight
                    endif
                  enddo; enddo; enddo
!
!  Triangular Shaped Cloud (TSC) scheme.
!
                elseif (lparticlemesh_tsc) then
!
!  Particle influences the 27 surrounding grid points, but has a density that
!  decreases with the distance from the particle centre.
!
                  if (nxgrid/=1) then
                    ixx0=ix0-1; ixx1=ix0+1
                  else
                    ixx0=ix0  ; ixx1=ix0
                  endif
                  if (nygrid/=1) then
                    iyy0=iy0-1; iyy1=iy0+1
                  else
                    iyy0=iy0  ; iyy1=iy0
                  endif
                  if (nzgrid/=1) then
                    izz0=iz0-1; izz1=iz0+1
                  else
                    izz0=iz0  ; izz1=iz0
                  endif
!
!  The nearest grid point is influenced differently than the left and right
!  neighbours are. A particle that is situated exactly on a grid point gives
!  3/4 contribution to that grid point and 1/8 to each of the neighbours.
!
                  do izz=izz0,izz1; do iyy=iyy0,iyy1; do ixx=ixx0,ixx1
                    if ( ((ixx-ix0)==-1) .or. ((ixx-ix0)==+1) ) then
                      weight_x=1.125-1.5* abs(fp(k,ixp)-x(ixx))*dx_1(ixx) + &
                                     0.5*(abs(fp(k,ixp)-x(ixx))*dx_1(ixx))**2
                    else
                      if (nxgrid/=1) &
                           weight_x=0.75-((fp(k,ixp)-x(ixx))*dx_1(ixx))**2
                    endif
                    if ( ((iyy-iy0)==-1) .or. ((iyy-iy0)==+1) ) then
                      weight_y=1.125-1.5* abs(fp(k,iyp)-y(iyy))*dy_1(iyy) + &
                                     0.5*(abs(fp(k,iyp)-y(iyy))*dy_1(iyy))**2
                    else
                      if (nygrid/=1) &
                           weight_y=0.75-((fp(k,iyp)-y(iyy))*dy_1(iyy))**2
                    endif
                    if ( ((izz-iz0)==-1) .or. ((izz-iz0)==+1) ) then
                      weight_z=1.125-1.5* abs(fp(k,izp)-z(izz))*dz_1(izz) + &
                                     0.5*(abs(fp(k,izp)-z(izz))*dz_1(izz))**2
                    else
                      if (nzgrid/=1) &
                           weight_z=0.75-((fp(k,izp)-z(izz))*dz_1(izz))**2
                    endif
!
                    weight=1.0
!
                    if (nxgrid/=1) weight=weight*weight_x
                    if (nygrid/=1) weight=weight*weight_y
                    if (nzgrid/=1) weight=weight*weight_z
!  Save the calculation of rho1 when inside pencil.
                    if ( (iyy/=m).or.(izz/=n).or.(ixx<l1).or.(ixx>l2) ) then
                      rho_point=f(ixx,iyy,izz,ilnrho)
                      if (.not. ldensity_nolog) rho_point=exp(rho_point)
                      rho1_point=1/rho_point
                    else
                      rho1_point=p%rho1(ixx-nghost)
                    endif
!  Add friction force to grid point.
                    if (lcartesian_coords) then
                      df(ixx,iyy,izz,iux:iuz)=df(ixx,iyy,izz,iux:iuz) - &
                           rhop_tilde*rho1_point*dragforce*weight
                    else
                      df(ixx,iyy,izz,iux:iuz)=df(ixx,iyy,izz,iux:iuz) - &
                           mp_tilde*dvolume_1(ixx)*rho1_point*dragforce*weight
                    endif
                  enddo; enddo; enddo
                else
!
!  Nearest Grid Point (NGP) scheme.
!
                  l=ineargrid(k,1)
                  if (lcartesian_coords) then
                    df(l,m,n,iux:iuz) = df(l,m,n,iux:iuz) - &
                         rhop_tilde*p%rho1(l-nghost)*dragforce
                  else
                    df(l,m,n,iux:iuz) = df(l,m,n,iux:iuz) - &
                         mp_tilde*dvolume_1(l-nghost)*p%rho1(l-nghost)*dragforce
                  endif
                endif
              endif
!
!  Heating of gas due to drag force.
!
              if (ldragforce_heat .or. (ldiagnos .and. idiag_dedragp/=0)) then
                if (ldragforce_gas_par) then
                  up2=sum((fp(k,ivpx:ivpz)-uup)**2)
                else
                  up2=sum(fp(k,ivpx:ivpz)*(fp(k,ivpx:ivpz)-uup))
                endif
!
                drag_heat(ix0-nghost)=drag_heat(ix0-nghost) + &
                     rhop_tilde*tausp1_par*up2
              endif
!
!  The minimum friction time of particles in a grid cell sets the local friction
!  time-step when there is only drag force on the dust,
!    dt1_drag = max(1/tausp)
!
!  With drag force on the gas as well, the maximum time-step is set as
!    dt1_drag = Sum_k[eps_k/tau_k]
!
              if (lfirst.and.ldt) then
                dt1_drag_dust(ix0-nghost)= &
                     max(dt1_drag_dust(ix0-nghost),tausp1_par)
                if (ldragforce_gas_par) then
                  if (p%np(ix0-nghost)/=0.0) &
                       dt1_drag_gas(ix0-nghost)=dt1_drag_gas(ix0-nghost)+ &
                       p%epsp(ix0-nghost)/p%np(ix0-nghost)*tausp1_par
                endif
              endif
            endif
          enddo
!
!  Add drag force heating in pencils.
!
          if (lentropy .and. ldragforce_heat) &
              df(l1:l2,m,n,iss) = df(l1:l2,m,n,iss) + p%rho1*p%TT1*drag_heat
!
!  Contribution of friction force to time-step. Dust and gas inverse friction
!  time-steps are added up to give a valid expression even when the two are
!  of similar magnitude.
!
          if (lfirst.and.ldt) then
            if (ldragforce_gas_par) then
              dt1_drag=dt1_drag_dust+dt1_drag_gas
            else
              dt1_drag=dt1_drag_dust
            endif
            dt1_drag=dt1_drag/cdtp
            dt1_max=max(dt1_max,dt1_drag)
          endif
        else
!
!  No particles in this pencil.
!          
          if (lfirst.and.ldt) dt1_drag=0.0
        endif
      endif
!
!  Collisional cooling is in a separate subroutine.
!
      if ( (lcollisional_cooling_rms .or. lcollisional_cooling_twobody .or. &
          lcollisional_dragforce_cooling) .and. t>=tstart_collisional_cooling) &
          call collisional_cooling(f,df,fp,dfp,p,ineargrid)
!
!  Compensate for increased friction time by appying extra friction force to
!  particles.
!
      if (lcompensate_friction_increase) &
          call compensate_friction_increase(f,df,fp,dfp,p,ineargrid)
!
!  Add lift forces.
!
      if (lparticles_spin .and. t>=tstart_liftforce_par) then
        if (npar_imn(imn)/=0) then
          do k=k1_imn(imn),k2_imn(imn)
            call calc_liftforce(fp(k,:), k, rep(k), liftforce)
            dfp(k,ivpx:ivpz)=dfp(k,ivpx:ivpz)+liftforce
          enddo
        endif
      endif
!
!  Add Brownian forces.
!
      if (lbrownian_forces .and. t>=tstart_brownian_par) then
        if (npar_imn(imn)/=0) then
          do k=k1_imn(imn),k2_imn(imn)
            call calc_brownian_force(fp,k,stocunn(k),bforce)
            dfp(k,ivpx:ivpz)=dfp(k,ivpx:ivpz)+bforce
          enddo
        endif
      endif
!
!  Contribution of dust particles to time step.
!
      if (npar_imn(imn)/=0) then
        do k=k1_imn(imn),k2_imn(imn)
          if (lfirst.and.ldt) then
            ix0=ineargrid(k,1); iy0=ineargrid(k,2); iz0=ineargrid(k,3)
            dt1_advpx=fp(k,ivpx)*dx_1(ix0)/cdtp
            if (lshear) then
              dt1_advpy=(-qshear*Omega*fp(k,ixp)+fp(k,ivpy))*dy_1(iy0)/cdtp
            else
              dt1_advpy=fp(k,ivpy)*dy_1(iy0)/cdtp
            endif
            dt1_advpz=fp(k,ivpz)*dz_1(iz0)/cdtp

            dt1_max(ix0-nghost)=max(dt1_max(ix0-nghost),dt1_advpx)
            dt1_max(ix0-nghost)=max(dt1_max(ix0-nghost),dt1_advpy)
            dt1_max(ix0-nghost)=max(dt1_max(ix0-nghost),dt1_advpz)
          endif
        enddo
      endif
!
!  For short friction time approximation we need to record the pressure
!  gradient force and the Lorentz force.
!
      if (lshort_friction_approx) f(l1:l2,m,n,iscratch_short_friction:iscratch_short_friction+2)=p%fpres+p%jxbr
!
!  Diagnostic output
!
      if (ldiagnos) then
        if (idiag_npm/=0)      call sum_mn_name(p%np,idiag_npm)
        if (idiag_np2m/=0)     call sum_mn_name(p%np**2,idiag_np2m)
        if (idiag_npmax/=0)    call max_mn_name(p%np,idiag_npmax)
        if (idiag_npmin/=0)    call max_mn_name(-p%np,idiag_npmin,lneg=.true.)
        if (idiag_rhopm/=0)    call sum_mn_name(p%rhop,idiag_rhopm)
        if (idiag_rhop2m/=0 )  call sum_mn_name(p%rhop**2,idiag_rhop2m)
        if (idiag_rhoprms/=0)  call sum_mn_name(p%rhop**2,idiag_rhoprms,lsqrt=.true.)
        if (idiag_rhopmax/=0)  call max_mn_name(p%rhop,idiag_rhopmax)
        if (idiag_rhopmin/=0)  call max_mn_name(-p%rhop,idiag_rhopmin,lneg=.true.)
        if (idiag_dedragp/=0)  call sum_mn_name(drag_heat,idiag_dedragp)
        if (idiag_dvpx2m /=0  .or. &
            idiag_dvpx2m /=0  .or. &
            idiag_dvpx2m /=0  .or. &
            idiag_dvpm   /=0  .or. &
            idiag_dvpmax /=0)  call calculate_rms_speed(fp,ineargrid,p)
      endif
!
!  1d-averages. Happens at every it1d timesteps, NOT at every it1
!
      if (l1ddiagnos) then
        if (idiag_npmx/=0)    call yzsum_mn_name_x(p%np,idiag_npmx)
        if (idiag_npmy/=0)    call xzsum_mn_name_y(p%np,idiag_npmy)
        if (idiag_npmz/=0)    call xysum_mn_name_z(p%np,idiag_npmz)
        if (idiag_rhopmx/=0)  call yzsum_mn_name_x(p%rhop,idiag_rhopmx)
        if (idiag_rhopmy/=0)  call xzsum_mn_name_y(p%rhop,idiag_rhopmy)
        if (idiag_rhopmz/=0)  call xysum_mn_name_z(p%rhop,idiag_rhopmz)
        if (idiag_epspmx/=0)  call yzsum_mn_name_x(p%epsp,idiag_epspmx)
        if (idiag_epspmy/=0)  call xzsum_mn_name_y(p%epsp,idiag_epspmy)
        if (idiag_epspmz/=0)  call xysum_mn_name_z(p%epsp,idiag_epspmz)
        if (idiag_rhopmr/=0)  call phizsum_mn_name_r(p%rhop,idiag_rhopmr)
        if (idiag_dtdragp/=0.and.(lfirst.and.ldt))  &
            call max_mn_name(dt1_drag,idiag_dtdragp,l_dt=.true.)
      endif
!
      if (l2davgfirst) then
        if (idiag_rhopmphi/=0) call phisum_mn_name_rz(p%rhop,idiag_rhopmphi)
        if (idiag_rhopmxy/=0)  call zsum_mn_name_xy(p%rhop,idiag_rhopmxy)
        if (idiag_rhopmxz/=0)  call ysum_mn_name_xz(p%rhop,idiag_rhopmxz)
      endif
!
!  Clean up (free allocated memory)
!
      if (allocated(rep)) deallocate(rep)
      if (allocated(stocunn)) deallocate(stocunn)
!
    endsubroutine dvvp_dt_pencil
!***********************************************************************
    subroutine dxxp_dt(f,df,fp,dfp,ineargrid)
!
!  Evolution of dust particle position.
!
!  02-jan-05/anders: coded
!
      use General, only: random_number_wrapper, random_seed_wrapper
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (mpar_loc,mpvar) :: fp, dfp
      integer, dimension (mpar_loc,3) :: ineargrid
!
      logical :: lheader, lfirstcall=.true.
!
      intent (in) :: f, fp, ineargrid
      intent (inout) :: df, dfp
!
!  Print out header information in first time step.
!
      lheader=lfirstcall .and. lroot
!
!  Identify module and boundary conditions.
!
      if (lheader) print*,'dxxp_dt: Calculate dxxp_dt'
      if (lheader) then
        print*, 'dxxp_dt: Particles boundary condition bcpx=', bcpx
        print*, 'dxxp_dt: Particles boundary condition bcpy=', bcpy
        print*, 'dxxp_dt: Particles boundary condition bcpz=', bcpz
      endif
!
      if (lheader) print*, 'dxxp_dt: Set rate of change of particle '// &
          'position equal to particle velocity.'
!
!  The rate of change of a particle's position is the particle's velocity.
!
      if (lcartesian_coords) then
!
        if (nxgrid/=1) &
             dfp(1:npar_loc,ixp) = dfp(1:npar_loc,ixp) + fp(1:npar_loc,ivpx)
        if (nygrid/=1) &
             dfp(1:npar_loc,iyp) = dfp(1:npar_loc,iyp) + fp(1:npar_loc,ivpy)
        if (nzgrid/=1) &
             dfp(1:npar_loc,izp) = dfp(1:npar_loc,izp) + fp(1:npar_loc,ivpz)
!
      elseif (lcylindrical_coords) then
!
        if (nxgrid/=1) &
             dfp(1:npar_loc,ixp) = dfp(1:npar_loc,ixp) + fp(1:npar_loc,ivpx)
        if (nygrid/=1) &
             dfp(1:npar_loc,iyp) = dfp(1:npar_loc,iyp) + &
             fp(1:npar_loc,ivpy)/fp(1:npar_loc,ixp)
        if (nzgrid/=1) &
             dfp(1:npar_loc,izp) = dfp(1:npar_loc,izp) + fp(1:npar_loc,ivpz)
!
      elseif (lspherical_coords) then
!
        if (nxgrid/=1) &
             dfp(1:npar_loc,ixp) = dfp(1:npar_loc,ixp) + fp(1:npar_loc,ivpx)
        if (nygrid/=1) &
             dfp(1:npar_loc,iyp) = dfp(1:npar_loc,iyp) + &
             fp(1:npar_loc,ivpy)/fp(1:npar_loc,ixp)
        if (nzgrid/=1) &
             dfp(1:npar_loc,izp) = dfp(1:npar_loc,izp) + &
             fp(1:npar_loc,ivpz)/(fp(1:npar_loc,ixp)*sin(fp(1:npar_loc,iyp)))
!
      endif
!
!  With shear there is an extra term due to the background shear flow.
!
      if (lshear.and.nygrid/=1) dfp(1:npar_loc,iyp) = &
          dfp(1:npar_loc,iyp) - qshear*Omega*fp(1:npar_loc,ixp)
!
      if (lfirstcall) lfirstcall=.false.
!
      if (NO_WARN) print*, f, df, ineargrid
!
    endsubroutine dxxp_dt
!***********************************************************************
    subroutine dvvp_dt(f,df,fp,dfp,ineargrid)
!
!  Evolution of dust particle velocity.
!
!  29-dec-04/anders: coded
!
      use Cdata
      use EquationOfState, only: cs20, gamma
      use Mpicomm, only: stop_it
      use Particles_number, only: get_nptilde
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (mpar_loc,mpvar) :: fp, dfp
      integer, dimension (mpar_loc,3) :: ineargrid
!
      real, dimension(3) :: ggp
      real :: Omega2, np_tilde, rsph, vsph, OO2
      integer :: k
      logical :: lheader, lfirstcall=.true.
!
      intent (in) :: f, fp, ineargrid
      intent (inout) :: df, dfp
!
!  Print out header information in first time step.
!
      lheader=lfirstcall .and. lroot
!
!  Add Coriolis force from rotating coordinate frame.
!
      if (Omega/=0.) then
        if (lheader) print*,'dvvp_dt: Add Coriolis force; Omega=', Omega
        Omega2=2*Omega
        dfp(1:npar_loc,ivpx) = dfp(1:npar_loc,ivpx) + Omega2*fp(1:npar_loc,ivpy)
        dfp(1:npar_loc,ivpy) = dfp(1:npar_loc,ivpy) - Omega2*fp(1:npar_loc,ivpx)
!
!  With shear there is an extra term due to the background shear flow.
!
        if (lshear) dfp(1:npar_loc,ivpy) = &
            dfp(1:npar_loc,ivpy) + qshear*Omega*fp(1:npar_loc,ivpx)
      endif
!
!  Add constant background pressure gradient beta=alpha*H0/r0, where alpha
!  comes from a global pressure gradient P = P0*(r/r0)^alpha.
!  (the term must be added to the dust equation of motion when measuring
!  velocities relative to the shear flow modified by the global pressure grad.)
!
      if (beta_dPdr_dust/=0.0 .and. t>=tstart_dragforce_par) then
        dfp(1:npar_loc,ivpx) = &
            dfp(1:npar_loc,ivpx) + 1/gamma*cs20*beta_dPdr_dust_scaled
      endif
!
!  Gravity on the particles.
!
      if (t>=tstart_grav_par) then
!
!  Gravity in the x-direction.
!
        select case (gravx_profile)
!
          case ('')
            if (lheader) print*, 'dvvp_dt: No gravity in x-direction.'
!
          case ('zero')
            if (lheader) print*, 'dvvp_dt: No gravity in x-direction.'
!
          case ('linear')
            if (lheader) print*, 'dvvp_dt: Linear gravity field in x-direction.'
            dfp(1:npar_loc,ivpx)=dfp(1:npar_loc,ivpx) - &
                nu_epicycle2*fp(1:npar_loc,ixp)
!
          case ('sinusoidal')
            if (lheader) &
                print*, 'dvvp_dt: Sinusoidal gravity field in x-direction.'
            dfp(1:npar_loc,ivpx)=dfp(1:npar_loc,ivpx) - &
                gravx*sin(kx_gg*fp(1:npar_loc,ixp))
!
          case default
            call fatal_error('dvvp_dt','chosen gravx_profile is not valid!')
!
        endselect
!
!  Gravity in the z-direction.
!
        select case (gravz_profile)
!
          case ('')
            if (lheader) print*, 'dvvp_dt: No gravity in z-direction.'
!
          case ('zero')
            if (lheader) print*, 'dvvp_dt: No gravity in z-direction.'
!
          case ('linear')
            if (lheader) print*, 'dvvp_dt: Linear gravity field in z-direction.'
            dfp(1:npar_loc,ivpz)=dfp(1:npar_loc,ivpz) - &
                nu_epicycle2*fp(1:npar_loc,izp)
!
          case ('sinusoidal')
            if (lheader) &
                print*, 'dvvp_dt: Sinusoidal gravity field in z-direction.'
            dfp(1:npar_loc,ivpz)=dfp(1:npar_loc,ivpz) - &
                gravz*sin(kz_gg*fp(1:npar_loc,izp))
!
          case default
            call fatal_error('dvvp_dt','chosen gravz_profile is not valid!')
!
        endselect
!
!  Radial gravity.
!
        select case (gravr_profile)
!
        case ('')
           if (lheader) print*, 'dvvp_dt: No radial gravity'
!
        case ('zero')
           if (lheader) print*, 'dvvp_dt: No radial gravity'
!
        case('newtonian-central','newtonian')
          if (lparticles_nbody) &
              call fatal_error('dvvp_dt','You are using massive particles. '//&
              'The N-body code should take care of the stellar-like '// &
              'gravity on the dust. Switch off the '// &
              'gravr_profile=''newtonian'' on particles_init')
           if (lheader) &
               print*, 'dvvp_dt: Newtonian gravity from a fixed central object'
           do k=1,npar_loc
             if (lcartesian_coords) then
               rsph=sqrt(fp(k,ixp)**2+fp(k,iyp)**2+fp(k,izp)**2+gravsmooth2)
               OO2=rsph**(-3)*gravr
               ggp(1) = -fp(k,ixp)*OO2
               ggp(2) = -fp(k,iyp)*OO2
               ggp(3) = -fp(k,izp)*OO2
               dfp(k,ivpx:ivpz) = dfp(k,ivpx:ivpz) + ggp
             elseif (lcylindrical_coords) then
               rsph=sqrt(fp(k,ixp)**2+fp(k,izp)**2+gravsmooth2)
               OO2=rsph**(-3)*gravr
               ggp(1) = -fp(k,ixp)*OO2
               ggp(2) = 0.0
               ggp(3) = -fp(k,izp)*OO2
               dfp(k,ivpx:ivpz) = dfp(k,ivpx:ivpz) + ggp
             elseif (lspherical_coords) then
               rsph=sqrt(fp(k,ixp)**2+gravsmooth2)
               OO2=rsph**(-3)*gravr
               ggp(1) = -fp(k,ixp)*OO2
               ggp(2) = 0.0; ggp(3) = 0.0
               dfp(k,ivpx:ivpz) = dfp(k,ivpx:ivpz) + ggp
             endif
!  Limit time-step if particles close to gravity source.
             if (ldtgrav_par.and.(lfirst.and.ldt)) then
               if (lcartesian_coords) then
                 vsph=sqrt(fp(k,ivpx)**2+fp(k,ivpy)**2+fp(k,ivpz)**2)
               elseif (lcylindrical_coords) then
                 vsph=sqrt(fp(k,ivpx)**2+fp(k,ivpz)**2)
               elseif (lspherical_coords) then
                 vsph=abs(fp(k,ivpx))
               endif
               dt1_max=max(dt1_max,10.0*vsph/rsph)
             endif
           enddo
!
        case default
           call fatal_error('dvvp_dt','chosen gravr_profile is not valid!')
!
        endselect
!
      endif
!
!  Diagnostic output
!
      if (ldiagnos) then
        if (idiag_nparmax/=0)  call max_name(npar_loc,idiag_nparmax)
        if (idiag_nparpmax/=0) call max_name(maxval(npar_imn),idiag_nparpmax)
        if (idiag_xpm/=0)  call sum_par_name(fp(1:npar_loc,ixp),idiag_xpm)
        if (idiag_ypm/=0)  call sum_par_name(fp(1:npar_loc,iyp),idiag_ypm)
        if (idiag_zpm/=0)  call sum_par_name(fp(1:npar_loc,izp),idiag_zpm)
        if (idiag_xp2m/=0) call sum_par_name(fp(1:npar_loc,ixp)**2,idiag_xp2m)
        if (idiag_yp2m/=0) call sum_par_name(fp(1:npar_loc,iyp)**2,idiag_yp2m)
        if (idiag_zp2m/=0) call sum_par_name(fp(1:npar_loc,izp)**2,idiag_zp2m)
        if (idiag_vpxm/=0) call sum_par_name(fp(1:npar_loc,ivpx),idiag_vpxm)
        if (idiag_vpym/=0) call sum_par_name(fp(1:npar_loc,ivpy),idiag_vpym)
        if (idiag_vpzm/=0) call sum_par_name(fp(1:npar_loc,ivpz),idiag_vpzm)
        if (idiag_vpx2m/=0) &
            call sum_par_name(fp(1:npar_loc,ivpx)**2,idiag_vpx2m)
        if (idiag_vpy2m/=0) &
            call sum_par_name(fp(1:npar_loc,ivpy)**2,idiag_vpy2m)
        if (idiag_vpz2m/=0) &
            call sum_par_name(fp(1:npar_loc,ivpz)**2,idiag_vpz2m)
        if (idiag_ekinp/=0) &
            call sum_par_name(0.5*rhop_tilde*npar_per_cell* &
                             (fp(1:npar_loc,ivpx)**2 + &
                              fp(1:npar_loc,ivpy)**2 + &
                              fp(1:npar_loc,ivpz)**2),idiag_ekinp)
        if (idiag_vpxmax/=0) call max_par_name(fp(1:npar_loc,ivpx),idiag_vpxmax)
        if (idiag_vpymax/=0) call max_par_name(fp(1:npar_loc,ivpy),idiag_vpymax)
        if (idiag_vpzmax/=0) call max_par_name(fp(1:npar_loc,ivpz),idiag_vpzmax)
        if (idiag_rhoptilm/=0) then
          do k=1,npar_loc
            call get_nptilde(fp,k,np_tilde)
            call sum_par_name( &
                (/4/3.*pi*rhops*fp(k,iap)**3*np_tilde/),idiag_rhoptilm)
          enddo
        endif
        if (idiag_mpt/=0) then
          do k=1,npar_loc
            call get_nptilde(fp,k,np_tilde)
            call integrate_par_name( &
                (/4/3.*pi*rhops*fp(k,iap)**3*np_tilde/),idiag_mpt)
          enddo
        endif
      endif
!
      if (lfirstcall) lfirstcall=.false.
!
      if (NO_WARN) print*, f, df, ineargrid
!
    endsubroutine dvvp_dt
!***********************************************************************
    subroutine get_frictiontime(f,fp,p,ineargrid,k,tausp1_par,uup,&
      nochange_opt,rep,stocunn)
!
!  Calculate the friction time.
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mpar_loc,mpvar) :: fp
      type (pencil_case) :: p
      real :: tausp1_par, tmp
      integer, dimension (mpar_loc,3) :: ineargrid
      integer :: k
      logical, optional :: nochange_opt
!
      real, optional, dimension(3) :: uup
      real, optional :: rep, stocunn
!
      real :: tausg1_point,OO
      integer :: ix0, inx0, jspec
      logical :: nochange=.false.
!
      intent(in) :: rep,uup
!
      if (present(nochange_opt)) then
        if (nochange_opt) then
          nochange=.true.
        else
          nochange=.false.
        endif
      else
        nochange=.false.
      endif
!
      ix0=ineargrid(k,1);inx0=ix0-nghost
!
!  Epstein drag law.
!
      if (ldraglaw_epstein) then
        if (iap/=0) then
          if (fp(k,iap)/=0.0) tausp1_par = 1/(fp(k,iap)*rhops)
        else
!  Check if we are using multiple or single particle species.
          if (npar_species>1) then
            jspec=npar_species*(ipar(k)-1)/npar+1
            tmp=tausp1_species(jspec)
          else
            tmp=tausp1
          endif
!  Discriminate between constant tau and special case for 
!  1/tau=omega when omega is not constant (as, for instance, 
!  global Keplerian disks, for which omega=rad**(-3/2)
          if (ldraglaw_variable) then
            if (lcartesian_coords) then
              OO=(fp(k,ixp)**2 + fp(k,iyp)**2)**(-0.75) 
            elseif (lcylindrical_coords) then
              OO=fp(k,ixp)**(-1.5)
            elseif (lspherical_coords) then
              call fatal_error("get_frictiontime",&
                   "variable draglaw not implemented for"//&
                   "spherical coordinates")
            endif
            tausp1_par=tmp*OO
          else
            tausp1_par=tmp
          endif
        endif
      else if (ldraglaw_epstein_stokes_linear) then
!
!  When the particle radius is larger than 9/4 times the mean free path
!  of the gas molecules one must use the Stokes drag law rather than the
!  Epstein law.
!
!  We need here to know the mean free path of the gas molecules:
!    lambda = mu_mol/(rhog*sigma_mol) 
!
!  The quantities are:
!    mu_mol    = mean molecular weight          [=3.9e-24 g for H_2]
!    rhog      = gas density
!    sigma_mol = cross section of gas molecules [=2e-15 cm^2 for H_2]
!
!  Actually need to know the mean free path in units of the gas scale
!  height H [if H=1]. Inserting the mid-plane expression
!    rhog=Sigmag/[sqrt(2*pi)*H]
!  gives
!    lambda/H = sqrt(2*pi)*mu_mol/(Sigmag*sigma_mol)
!            ~= 4.5e-9/Sigmag
!  when Sigmag is given in g/cm^2.
!
        if (iap==0) then
          if (lroot) print*, 'get_frictiontime: need particle radius as dynamical variable for Stokes law'
          call fatal_error('get_frictiontime','')
        endif
        if (fp(k,iap)<2.25*mean_free_path_gas) then
          tausp1_par = 1/(fp(k,iap)*rhops)
        else
          tausp1_par = 1/(fp(k,iap)*rhops)*2.25*mean_free_path_gas/fp(k,iap)
        endif
!
      else if (ldraglaw_epstein_transonic) then
!
! Draw laws for intermediate mach number. This is for pure Epstein drag...
!
        call calc_draglaw_parameters(fp,k,uup,p,inx0,tausp1_par)
!
      else if (ldraglaw_eps_stk_transonic) then
!
! ...and this is for a linear combination of Esptein and Stokes drag at
! intermediate mach number. Pure Stokes drag is not implemented.
!
        call calc_draglaw_parameters(fp,k,uup,p,inx0,tausp1_par,lstokes=.true.)
!
      elseif (ldraglaw_steadystate) then
        if (.not.present(rep)) then
          call fatal_error('get_frictiontime','need particle reynolds '// &
                  'number, rep, to calculate the steady state drag '// &
                  'relaxation time!')
        elseif (.not.present(stocunn)) then
          call fatal_error('get_frictiontime','need particle stokes '// &
                  'cunningham factor, stocunn, to calculate the steady '// &
                  ' state drag relaxation time!')
        else
          call calc_draglaw_steadystate(fp,k,rep,stocunn,tausp1_par)
        endif
!
      endif
!
!  Change friction time artificially.
!
      if (.not. nochange) then
!
!  Increase friction time to avoid very small time-steps where the
!  dust-to-gas ratio is high.
!
        if (tausg_min/=0.0) then
          tausg1_point=tausp1_par*p%epsp(ix0-nghost)
          if (tausg1_point>tausg1_max) &
              tausp1_par=tausg1_max/p%epsp(ix0-nghost)
        endif
!
!  Increase friction time linearly with dust density where the dust-to-gas
!  ratio is higher than a chosen value. Supposed to mimick decreased cooling
!  when the gas follows the dust.
!
        if (epsp_friction_increase/=0.0) then
          if (p%epsp(ix0-nghost)>epsp_friction_increase) &
              tausp1_par=tausp1_par/(p%epsp(ix0-nghost)/epsp_friction_increase)
        endif

      endif
!
      if (NO_WARN) print*, f, ineargrid
!
    endsubroutine get_frictiontime
!***********************************************************************
    subroutine calc_draglaw_parameters(fp,k,uup,p,inx0,tausp1_par,lstokes)
!
      use EquationOfState, only: rho0,cs0
!
      real, dimension (mpar_loc,mpvar) :: fp
      real, dimension(3) :: uup,duu
      type (pencil_case) :: p
      real :: tausp1_par,tmp,tmp1
      integer :: k, inx0, jspec
      real :: kd,fd,mach,mach2,fac,OO
      real :: knudsen,reynolds,lambda
      real :: inv_particle_radius,kn_crit
      logical, optional :: lstokes
      logical, save :: lfirstcall
!
!  Epstein drag away from the limit of subsonic particle motion. The drag
!  force is given by (Schaaf 1963)
!  
!       Feps=-pi*a**2 * rhog * |Delta(u)| * Delta(u) &                    (1)
!        *[(1+1/m**2+1/(4*m**4))*erf(m) + (1/m+1/(2*m**3)*exp(-m**2)/sqrt(pi)]
!
!  where Delta(u) is the relative dust-to-gas velocity (vector) 
!  and m=|Delta(u)|/cs (scalar) is the relative mach number of the flow
!
!  As erf is too cumbersome a function to implement numerically, an interpolation 
!  between the limits of 
!  
!     subsonic:    Feps=-sqrt(128*pi)/3*a**2*rhog*cs*Delta(u)             (2)
!     supersonic:  Feps=-pi*a**2*rhog*|Delta(u)|*Delta(u)                 (3) 
!  
!  is used, leading to an expression that can be used for arbitrary velocities
!  as derived by Kwok (1975). 
!
!     transonic:  Feps=-sqrt(128*pi)/3*a**2*rhog*cs*fd*Delta(u)          (4)
!
!  where fd=sqrt(1 + 9*pi/128*m**2)                                       (5)
!
!  The force Feps is divided by the mass of the particle mp=4/3*pi*a**3*rhops
!  to yield the acceleration feps=Feps/mp
!
!         feps = -sqrt(8/pi)*rhog*cs*fd*Delta(u)/[a*rhops]                (6)
!
!  Epstein drag ceases to work when the particle diameter becomes comparable
!  to the mean free path (lambda) of the gas molecules. In this case, the force 
!  is given by Stokes friction in the viscous case (low dust Reynolds number)
!
!      Fsto=-6*pi*a*mu_kin*Delta(u)                                    (7) 
!
!  where mu_kin is the kinematic viscosity of the gas 
!
!      mu_kin=1/3*rhog*vth*lambda                                         (8)
!
!  and vth=sqrt(8/pi)*cs is the mean thermal velocity of the gas. For high dust
!  Reynolds numbers the viscosity if uninmportant and the drag force of the tur-
!  bulent flow past the particle is given by Newtonian friction 
!
!     Fnew=-1.3*pi*a**2*rhog*|Delta(u)|*Delta(u)
!
!  The two cases are once again connected by an interpolating factor
!
!     F'sto=-6*pi*a*kd*mu_kin*Delta(u) 
!
!  where kd is a factor that contains the Reynolds number of the flow over the 
!  particle (defined in the code, some lines below). 
!
!  The following interpolation then works for flows of arbitrary Knudsen, Mach and Reynolds
!  numbers 
! 
!     Fdrag = [Kn'/(Kn'+1)]**2 * Feps +  [1/(Kn'+1)]**2 * F'sto
!
!  Where Kn'=3*Kn is the critical Knudsen number where the viscous (Stokes) drag and the subsonic
!  Epstein drag are equal. 
!
!  (The discussion above was taken from Paardekooper 2006, Woite & Helling 2003 and Kwok 1975) 
!
!  In the 2D case, the density rhog is to be replaced by 
!
!     rhog=Sigmag/[sqrt(2*pi)H]
!         =Sigmag*Omega/[sqrt(2*pi)*cs]
!
!  which removes the dependence of (6) on cs. We are left with 
!
!         feps = -2/pi*sigmag*Omega*fd*Delta(u)/[a*rhops]
!  
!  the constant terms are tausp1. The same follows for Stokes drag
!
!  Friction time for different species
!
      if (npar_species==1) then 
        tmp=tausp
        tmp1=tausp1
      else
        jspec=npar_species*(ipar(k)-1)/npar+1
        tmp=tausp_species(jspec)
        tmp1=tausp1_species(jspec)
      endif
!
!  Relative velocity
!
      duu=fp(k,ivpx:ivpz)-uup
!
      if (nzgrid==1) then 
!  then omega is needed
        if (ldraglaw_variable) then
          !these omegas assume GM=1
          if (lcartesian_coords) then
            OO=(fp(k,ixp)**2 + fp(k,iyp)**2)**(-0.75) 
          elseif (lcylindrical_coords) then
            OO=fp(k,ixp)**(-1.5)
          elseif (lspherical_coords) then
            call fatal_error("get_frictiontime",&
                 "variable draglaw not implemented for"//&
                 "spherical coordinates")
          endif
        else
          OO=nu_epicycle
        endif
      endif
!  
!  Possibility to include the transition from Esptein to Stokes drag
!
      if (present(lstokes)) then
!
        if (lfirstcall) &
             print*,'get_frictiontime: Epstein-Stokes transonic drag law'
!
!  The mach number and the correction fd to flows of arbitrary mach number
!
        mach=sqrt((duu(1)**2+duu(2)**2+duu(3)**2)/p%cs2(inx0))
        fd=sqrt(1+(9.*pi/128)*mach**2)
!
!  For Stokes drag, the mean free path is needed
!
!   lambda = 1/rhog*(mu/sigma_coll)_H2
!
!  were mu_H2 is the mean molecular weight of the hydrogen molecule (3.9e-24 g), 
!  and sigma_coll its cross section (2e-15 cm^2). 
!  Assume that (mu/sigma_coll) is the input parameter mean_free_path_gas
!
        if (mean_free_path_gas.eq.0) then
          print*,'You want to use Stokes drag but you forgot to set '//&
               'mean_free_path_gas in the .in files. Stop and check.'
          call fatal_error("calc_draglaw_parameters","")
        endif
             
        if (nzgrid==1) then
          !the sqrt(2pi) factor is inside the mean_free_path_gas constant
          lambda=mean_free_path_gas * sqrt(p%cs2(inx0))*rho0/(p%rho(inx0)*OO*cs0)
        else
          lambda=mean_free_path_gas * rho0/p%rho(inx0)
        endif        
!
!  The Knudsen number is the ratio of the mean free path to the particle radius, 2s
!  To keep consistency with the formulation evolving for radius, tausp1 is C/(s*rhops)
!  where C is 2/pi for 2d runs and sqrt(8/pi) for 3D runs (because of the sqrt(2*pi) 
!  factor coming from the substitution Sigma=rho/(sqrt(2*pi)*H). 's' is the particle 
!  radius
!
        if (iap/=0) then
          inv_particle_radius=1./fp(k,iap)
        else
          if (luse_tau_ap) then
            ! use tausp as the radius (in meter) to make life easier
            inv_particle_radius=tmp1
          else
            if (nzgrid==1) then
              inv_particle_radius=.5*pi*tmp1       !rhops=1, particle_radius in meters
            else
              inv_particle_radius=sqrt(pi/8)*tmp1 !rhops=1, particle_radius in meters
            endif
          endif
        endif
!
        knudsen=.5*lambda*inv_particle_radius
!
!  The Stokes drag depends non-linearly on 
!
!    Re = 2*s*rho_g*|delta(v)|/mu_kin
!
        reynolds=3.*sqrt(pi/8)*mach/knudsen
!
!  the Reynolds number of the flow over the particle. It can parameterized by 
!        
        if (reynolds.le.500) then
          kd=1+0.15*reynolds**0.687
        elseif ((reynolds.gt.500).and.(reynolds.le.1500)) then
          kd=3.96e-6*reynolds**2.4
        elseif  (reynolds.gt.1500) then
          kd=0.11*reynolds
        endif
!
!  And we finally have the Stokes correction to intermediate Knudsen numbers
!  kn_crit is the critical knudsen number where viscous (low reynolds) 
!  Stokes and subsonic Epstein friction are equal (Woitke & Helling, 2003) 
!
        kn_crit=3*knudsen 
        fac=kn_crit/(kn_crit+1)**2 * (kn_crit*fd + kd)
!
      else 
!
!  Only use Epstein drag
!
        if (lfirstcall) &
             print*,'get_frictiontime: Epstein transonic drag law'
!
        mach2=(duu(1)**2+duu(2)**2+duu(3)**2)/p%cs2(inx0)
        fd=sqrt(1+(9.*pi/128)*mach2)
        fac=fd
!
      endif
!
! Calculate tausp1_par for 2d and 3d cases with and without particle_radius 
! as a dynamical variable
!      
      if (iap/=0) then
        if (fp(k,iap)/=0.0) then
          if (nzgrid==1) then
            tausp1_par=     2*pi_1*OO          *p%rho(inx0)*fac/(fp(k,iap)*rhops)
          else
            tausp1_par=sqrt(8*pi_1*p%cs2(inx0))*p%rho(inx0)*fac/(fp(k,iap)*rhops)
          endif
        endif
      else
          !normalize to make tausp1 not dependent on cs0 or rho0
          !bad because it comes at the expense of evil divisions
        if (nzgrid==1) then
          if (luse_tau_ap) then 
            tausp1_par=tmp1*2*pi_1*OO*p%rho(inx0)*fac/ rho0
          else
            tausp1_par=tmp1*OO*p%rho(inx0)*fac/ rho0
          endif
        else
          if (luse_tau_ap) then
            tausp1_par=tmp1*sqrt(8*pi_1*p%cs2(inx0))*p%rho(inx0)*fac/(rho0*cs0)
          else
            tausp1_par=tmp1*sqrt(p%cs2(inx0))*p%rho(inx0)*fac/(rho0*cs0)
          endif
        endif
      endif
!
      if (lfirstcall) lfirstcall=.false. 
!
    endsubroutine calc_draglaw_parameters
!***********************************************************************
    subroutine collisional_cooling(f,df,fp,dfp,p,ineargrid)
!
!  Reduce relative speed between particles due to inelastic collisions.
!
!  23-sep-06/anders: coded
!
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (mpar_loc,mpvar) :: fp, dfp
      type (pencil_case) :: p
      integer, dimension (mpar_loc,3) :: ineargrid
!
      real, dimension (nx,npar_species,npar_species) :: tau_coll_species
      real, dimension (nx,npar_species,npar_species) :: tau_coll1_species
      real, dimension (nx,3,npar_species) :: vvpm_species
      real, dimension (nx,npar_species) :: np_species, vpm_species
      real, dimension (nx,npar_species) :: tau_coll1_tot
      real, dimension (nx,3) :: vvpm
      real, dimension (nx) :: vpm, tau_coll1, tausp1m, vcoll, coll_heat
      real, dimension (3) :: deltavp_vec, vbar_jk
      real :: deltavp, tau_cool1_par, dt1_cool
      real :: tausp1_par, tausp1_parj, tausp1_park, tausp_parj, tausp_park
      real :: tausp_parj3, tausp_park3
      integer :: j, k, l, ix0
      integer :: ispecies, jspecies
!
      if (ldiagnos .or. lentropy .and. lcollisional_heat) coll_heat=0.0
!
!  Add collisional cooling of the rms speed.
!
      if (lcollisional_cooling_rms) then
        if (npar_imn(imn)/=0) then
!  When multiple friction times are present, the average is used for the
!  number density in each superparticle.
          if (npar_species>1) then
            tausp1m=0.0
          else
            call get_frictiontime(f,fp,p,ineargrid,1,tausp1_par, &
                nochange_opt=.true.)
          endif
!  Need vpm=<|vvp-<vvp>|> to calculate the collisional time-scale.
          vvpm=0.0; vpm=0.0
          do k=k1_imn(imn),k2_imn(imn)
            ix0=ineargrid(k,1)
            vvpm(ix0-nghost,:) = vvpm(ix0-nghost,:) + fp(k,ivpx:ivpz)
            if (npar_species>1) then
              call get_frictiontime(f,fp,p,ineargrid,k,tausp1_par, &
                  nochange_opt=.true.)
              tausp1m(ix0-nghost) = tausp1m(ix0-nghost) + tausp1_par
            endif
          enddo
          do l=1,nx
            if (p%np(l)>1.0) then
              vvpm(l,:)=vvpm(l,:)/p%np(l)
              if (npar_species>1) tausp1m=tausp1m/p%np
            endif
          enddo
!  vpm
          do k=k1_imn(imn),k2_imn(imn)
            ix0=ineargrid(k,1)
            vpm(ix0-nghost) = vpm(ix0-nghost) + &
                sqrt( (fp(k,ivpx)-vvpm(ix0-nghost,1))**2 + &
                      (fp(k,ivpy)-vvpm(ix0-nghost,2))**2 + &
                      (fp(k,ivpz)-vvpm(ix0-nghost,3))**2 )
          enddo
          do l=1,nx
            if (p%np(l)>1.0) then
              vpm(l)=vpm(l)/p%np(l)
            endif
          enddo
!  The collisional time-scale is 1/tau_coll=nd*vrms*sigma_coll.
!  Inserting Epstein friction time gives 1/tau_coll=3*rhod/rho*vprms/tauf.
          if (npar_species>1) then
            tau_coll1=(1.0-coeff_restitution)*p%epsp*vpm*tausp1m
          else
            tau_coll1=(1.0-coeff_restitution)*p%epsp*vpm*tausp1_par
          endif
!  Limit inverse time-step of collisional cooling if requested.
          if (tau_coll_min>0.0) then
            where (tau_coll1>tau_coll1_max) tau_coll1=tau_coll1_max
          endif
          dt1_max=max(dt1_max,tau_coll1/cdtp)
!
          do k=k1_imn(imn),k2_imn(imn)
            ix0=ineargrid(k,1)
            dfp(k,ivpx:ivpz) = dfp(k,ivpx:ivpz) - &
                tau_coll1(ix0-nghost)*(fp(k,ivpx:ivpz)-vvpm(ix0-nghost,:))
            if (lcollisional_heat .or. ldiagnos) then
              coll_heat(ix0-nghost) = coll_heat(ix0-nghost) + & 
                  rhop_tilde*tau_coll1(ix0-nghost)*&
                  sum(fp(k,ivpx:ivpz)*(fp(k,ivpx:ivpz)-vvpm(ix0-nghost,:)))
            endif
          enddo
        endif
      endif
!
!  More advanced collisional cooling model. Collisions are considered for
!  every possible two-body process in a grid cell.
!
      if (lcollisional_cooling_twobody) then
        do l=1,nx
! Collisions between particle k and all other particles in the grid cell.
          k=kshepherd(l)
          if (k>0) then
!  Limit inverse time-step of collisional cooling if requested.
            do while (k/=0)
              dt1_cool=0.0
              call get_frictiontime(f,fp,p,ineargrid,k,tausp1_park, &
                  nochange_opt=.true.)
              tausp_park=1/tausp1_park
              tausp_park3=tausp_park**3
              j=k
              do while (kneighbour(j)/=0)
!  Collide with the neighbours of k and their neighbours.
                j=kneighbour(j)
                call get_frictiontime(f,fp,p,ineargrid,j,tausp1_parj, &
                    nochange_opt=.true.)
                tausp_parj=1/tausp1_parj
                tausp_parj3=tausp_parj**3
!  Collision velocity.
                deltavp_vec=fp(k,ivpx:ivpz)-fp(j,ivpx:ivpz)
                deltavp=sqrt( deltavp_vec(1)**2 + deltavp_vec(2)**2 + &
                              deltavp_vec(3)**2 )
                vbar_jk= &
                    (tausp_parj3*fp(k,ivpx:ivpz)+tausp_park3*fp(j,ivpx:ivpz))/ &
                    (tausp_parj3+tausp_park3)
!  Cooling time-scale.
                tau_cool1_par= &
                    (1.0-coeff_restitution)* &
                    rhop_tilde*deltavp*(tausp_parj+tausp_park)**2/ &
                    (tausp_parj3+tausp_park3)
                dt1_cool=dt1_cool+tau_cool1_par
!                if (tau_coll_min>0.0) then
!                  if (tau_cool1_par>tau_coll1_max) tau_cool1_par=tau_coll1_max
!                endif
                dfp(j,ivpx:ivpz) = dfp(j,ivpx:ivpz) - &
                    tau_cool1_par*(fp(j,ivpx:ivpz)-vbar_jk)
                dfp(k,ivpx:ivpz) = dfp(k,ivpx:ivpz) - &
                    tau_cool1_par*(fp(k,ivpx:ivpz)-vbar_jk)
              enddo
              dt1_max=max(dt1_max(l),dt1_cool/cdtp)
!  Go through all possible k.
              k=kneighbour(k)
            enddo
          endif
        enddo
!
      endif
!
!  Treat collisions as a drag force that damps the rms speed at the same
!  time-scale.
!
      if (lcollisional_dragforce_cooling) then
        if (npar_imn(imn)/=0) then
          vvpm_species=0.0; vpm_species=0.0; np_species=0.0
!  Calculate mean velocity and number of particles for each species.
          do k=k1_imn(imn),k2_imn(imn)
            ix0=ineargrid(k,1)
            ispecies=npar_species*(ipar(k)-1)/npar+1
            vvpm_species(ix0-nghost,:,ispecies) = &
                vvpm_species(ix0-nghost,:,ispecies) + fp(k,ivpx:ivpz)
            np_species(ix0-nghost,ispecies)  = &
                np_species(ix0-nghost,ispecies) + 1.0
          enddo
          do l=1,nx
            do ispecies=1,npar_species
              if (np_species(l,ispecies)>1.0) then
                vvpm_species(l,:,ispecies)=vvpm_species(l,:,ispecies)/np_species(l,ispecies)
              endif
            enddo
          enddo
!  Calculate rms speed for each species.
          do k=k1_imn(imn),k2_imn(imn)
            ix0=ineargrid(k,1)
            ispecies=npar_species*(ipar(k)-1)/npar+1
            vpm_species(ix0-nghost,ispecies) = &
                vpm_species(ix0-nghost,ispecies) + sqrt( &
                (fp(k,ivpx)-vvpm_species(ix0-nghost,1,ispecies))**2 + &
                (fp(k,ivpy)-vvpm_species(ix0-nghost,2,ispecies))**2 + &
                (fp(k,ivpz)-vvpm_species(ix0-nghost,3,ispecies))**2 )
          enddo
          do l=1,nx
            do ispecies=1,npar_species
              if (np_species(l,ispecies)>1.0) then
                vpm_species(l,ispecies)=vpm_species(l,ispecies)/np_species(l,ispecies)
              endif
            enddo
          enddo
!
!  Collisional drag force time-scale between particles i and j with R_i < R_j.
!
!    tau_ji = tau_j^3/(tau_i+tau_j)^2/(deltav_ij/cs*rhoi/rhog)
!    tau_ij = tau_ji*rho_j/rho_i
!
          do ispecies=1,npar_species; do jspecies=ispecies,npar_species
            vcoll= &
                sqrt(vpm_species(:,ispecies)**2+vpm_species(:,ispecies)**2 + &
                  (vvpm_species(:,1,ispecies)-vvpm_species(:,1,jspecies))**2 + &
                  (vvpm_species(:,2,ispecies)-vvpm_species(:,2,jspecies))**2 + &
                  (vvpm_species(:,3,ispecies)-vvpm_species(:,3,jspecies))**2)
            tau_coll1_species(:,jspecies,ispecies) = &
                  vcoll*np_species(:,ispecies)*rhop_tilde*p%rho1 / ( &
                tausp_species(jspecies)**3/ &
                (tausp_species(ispecies)+tausp_species(jspecies))**2 )
            where (np_species(:,ispecies)/=0.0) &
              tau_coll1_species(:,ispecies,jspecies)= &
                   tau_coll1_species(:,jspecies,ispecies)*np_species(:,jspecies)/np_species(:,ispecies)
          enddo; enddo
!
          tau_coll1_tot=0.0
          do ispecies=1,npar_species; do jspecies=1,npar_species
            tau_coll1_tot(:,ispecies)=tau_coll1_tot(:,ispecies)+tau_coll1_species(:,ispecies,jspecies)
          enddo; enddo
!  Limit inverse time-step of collisional cooling if requested.
          if (tau_coll_min>0.0) then
            do ispecies=1,npar_species; do l=1,nx
              if (tau_coll1_tot(l,ispecies) > tau_coll1_max) then
                tau_coll1_species(l,ispecies,:)=tau_coll1_species(l,ispecies,:)* &
                    tau_coll1_max/tau_coll1_tot(l,ispecies)
              endif
            enddo; enddo
            tau_coll1_tot=0.0
            do ispecies=1,npar_species; do jspecies=1,npar_species
              tau_coll1_tot(:,ispecies)=tau_coll1_tot(:,ispecies)+tau_coll1_species(:,ispecies,jspecies)
            enddo; enddo
          endif
          do ispecies=1,npar_species
            dt1_max=max(dt1_max,tau_coll1_tot(:,ispecies)/cdtp)
          enddo
!  Add to equation of motion.
          do k=k1_imn(imn),k2_imn(imn)
            ix0=ineargrid(k,1)
            ispecies=npar_species*(ipar(k)-1)/npar+1
            do jspecies=1,npar_species
              dfp(k,ivpx:ivpz) = dfp(k,ivpx:ivpz) - &
                  tau_coll1_species(ix0-nghost,ispecies,jspecies)* &
                  (fp(k,ivpx:ivpz)-vvpm_species(ix0-nghost,:,jspecies))
              if (lcollisional_heat .or. ldiagnos) then
                coll_heat(ix0-nghost) = coll_heat(ix0-nghost) + &
                    rhop_tilde*tau_coll1_species(ix0-nghost,ispecies,jspecies)*&
                    sum(fp(k,ivpx:ivpz)*(fp(k,ivpx:ivpz) - &
                                         vvpm_species(ix0-nghost,:,jspecies)))
              endif
            enddo
          enddo
        endif
      endif
!
!  Heating of the gas due to dissipative collisions.
!
      if (lentropy .and. lcollisional_heat) &
          df(l1:l2,m,n,iss) = df(l1:l2,m,n,iss) + p%rho1*p%TT1*coll_heat

!  Diagnostics.
      if (ldiagnos) then
        if (idiag_decollp/=0) &
          call sum_mn_name(coll_heat,idiag_decollp)
      endif
!
    endsubroutine collisional_cooling
!***********************************************************************
    subroutine compensate_friction_increase(f,df,fp,dfp,p,ineargrid)
!
!  Compensate for increased friction time in regions of high solids-to-gas
!  ratio by applying missing friction force to particles only.
!
!  26-feb-07/anders: coded
!
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (mpar_loc,mpvar) :: fp, dfp
      type (pencil_case) :: p
      integer, dimension (mpar_loc,3) :: ineargrid
!
      real, dimension (nx,3) :: vvpm
      real :: tausp1_par, tausp1_par_mod, tausp1_par_org
      integer :: k, l, ix0
!
      if (npar_imn(imn)/=0) then
!  Calculate mean particle velocity.
        vvpm=0.0
        do k=k1_imn(imn),k2_imn(imn)
          ix0=ineargrid(k,1)
          vvpm(ix0-nghost,:) = vvpm(ix0-nghost,:) + fp(k,ivpx:ivpz)
        enddo
        do l=1,nx
          if (p%np(l)>1.0) vvpm(l,:)=vvpm(l,:)/p%np(l)
        enddo
!
!  Compare actual and modified friction time and apply the difference as
!  friction force relative to mean particle velocity.
!
        do k=k1_imn(imn),k2_imn(imn)
          call get_frictiontime(f,fp,p,ineargrid,k,tausp1_par_mod, &
              nochange_opt=.false.)
          call get_frictiontime(f,fp,p,ineargrid,k,tausp1_par_org, &
              nochange_opt=.true.)
          tausp1_par=tausp1_par_org-tausp1_par_mod
          ix0=ineargrid(k,1)
          dfp(k,ivpx:ivpz) = dfp(k,ivpx:ivpz) - &
              tausp1_par*(fp(k,ivpx:ivpz)-vvpm(ix0-nghost,:))
        enddo
      endif
!
    endsubroutine compensate_friction_increase
!***********************************************************************
    subroutine calculate_rms_speed(fp,ineargrid,p)
!
      use Sub,only:sum_mn_name,max_mn_name
!
!  Calculate the rms speed dvpm=sqrt(<(vvp-<vvp>)^2>) of the 
!  particle for diagnostic purposes
!
!  08-04-08/wlad: coded
!
      real,dimension(mpar_loc,mpvar) :: fp
      integer, dimension (mpar_loc,3) :: ineargrid
      real,dimension(nx,3) :: vvpm,dvp2m
      integer :: inx0,k,l
      type (pencil_case) :: p
      logical :: lsink
!
!  Calculate the average velocity at each cell
!
      vvpm=0.0; dvp2m=0.0
      do k=k1_imn(imn),k2_imn(imn)
        lsink=any(ipar(k).eq.ipar_sink)
        if (.not.lsink) then
          inx0=ineargrid(k,1)-nghost
          vvpm(inx0,:) = vvpm(inx0,:) + fp(k,ivpx:ivpz)
        endif
      enddo
      do l=1,nx
        if (p%np(l)>1.0) vvpm(l,:)=vvpm(l,:)/p%np(l)
      enddo
!
!  Get the residual in quadrature, dvp2m
!
      do k=k1_imn(imn),k2_imn(imn)
        lsink=any(ipar(k).eq.ipar_sink)
        if (.not.lsink) then
          inx0=ineargrid(k,1)-nghost
          dvp2m(inx0,1)=dvp2m(inx0,1)+(fp(k,ivpx)-vvpm(inx0,1))**2
          dvp2m(inx0,2)=dvp2m(inx0,2)+(fp(k,ivpy)-vvpm(inx0,2))**2
          dvp2m(inx0,3)=dvp2m(inx0,3)+(fp(k,ivpz)-vvpm(inx0,3))**2
        endif
      enddo
      do l=1,nx
        if (p%np(l)>1.0) dvp2m(l,:)=dvp2m(l,:)/p%np(l)
      enddo
!
!  Output the diagnostics
!
      if (idiag_dvpx2m/=0) call sum_mn_name(dvp2m(:,1),idiag_dvpx2m)
      if (idiag_dvpy2m/=0) call sum_mn_name(dvp2m(:,2),idiag_dvpy2m)
      if (idiag_dvpz2m/=0) call sum_mn_name(dvp2m(:,3),idiag_dvpz2m)
      if (idiag_dvpm/=0)   call sum_mn_name(dvp2m(:,1)+dvp2m(:,2)+dvp2m(:,3),&
                                            idiag_dvpm,lsqrt=.true.)
      if (idiag_dvpmax/=0) call max_mn_name(dvp2m(:,1)+dvp2m(:,2)+dvp2m(:,3),&
                                            idiag_dvpmax,lsqrt=.true.)
!     
    endsubroutine calculate_rms_speed
!***********************************************************************
    subroutine calc_pencil_rep(fp,uup,rep)
!
!  Calculate particle Reynolds numbers
!
!  16-jul-08/kapelrud: coded
!
      use Viscosity, only: getnu
!
      real,dimension(mpar_loc,mpvar) :: fp
      real,dimension(:,:) :: uup
      real,dimension(:) :: rep
      intent(in) :: fp, uup
      intent(inout) :: rep
!
      real :: nu
      integer :: k
!
      call getnu(nu)
!
      if (.not.lparticles_radius) then
        print*,'calc_pencil_rep: particle_radius module needs to be '// &
          'enabled to calculate the particles Reynolds numbers.'
        call fatal_error('calc_pencil_rep','')
      elseif (nu==0.0) then
        print*,'calc_pencil_rep: nu (kinematic visc.) must be non-zero!'
        call fatal_error('calc_pencil_rep','')
      endif
!
      do k=k1_imn(imn),k2_imn(imn)
        rep(k)=2.0*fp(k,iap)*sqrt(sum((uup(k,:)-fp(k,ivpx:ivpz))**2))/nu
      enddo
!
    endsubroutine calc_pencil_rep
!***********************************************************************
    subroutine calc_stokes_cunningham(fp,stocunn)
!
!  Calculate thi Stokes-Cunningham factor
!
!  12-aug-08/kapelrud: coded
!
      use Particles_radius
!
      real,dimension(mpar_loc,mpvar) :: fp
      real,dimension(:) :: stocunn
!
      real :: dia
      integer :: k
!
      do k=k1_imn(imn),k2_imn(imn)
!
!  Particle diameter
!
        dia=2.0*fp(k,iap)
!
        stocunn(k)=1.+2.*mean_free_path_gas/dia* &
          (1.257+0.4*exp(-0.55*dia/mean_free_path_gas))
!
      enddo
!
    endsubroutine calc_stokes_cunningham
!***********************************************************************
    subroutine calc_draglaw_steadystate(fp,k,rep,stocunn,tausp1_par)
!
!   Calculate relaxation time for particles under steady state drag.
!
!   15-jul-08/kapelrud: coded
!
      use Viscosity, only: getnu
      use Particles_radius
!
      real, dimension(mpar_loc,mpvar) :: fp
      integer :: k
      real :: rep, stocunn, tausp1_par
!
      intent(in) :: fp,k,rep,stocunn
      intent(out) :: tausp1_par
!
      real :: cdrag,dia,nu
!
      call getnu(nu)
!
!  Particle diameter
!
      if (.not.lparticles_radius) then
        print*,'calc_draglaw_steadystate: need particles_radius module to '// &
            'calculate the relaxation time!'
        call fatal_error('calc_draglaw_steadystate','')
      endif
!
      dia=2.0*fp(k,iap)
!
!  Calculate drag coefficent pre-factor:
!
      if (rep<1) then
        cdrag=1.0
      elseif (rep>1000) then
        cdrag=0.44*rep/24.0
      else
        cdrag=(1.+0.15*rep**0.687)
      endif
!
!  Relaxation time:
!
      tausp1_par=18.0*cdrag*nu/((rhop_tilde/interp_rho(k))*stocunn*dia**2)
!
    endsubroutine calc_draglaw_steadystate
!***********************************************************************
    subroutine calc_brownian_force(fp,k,stocunn,force)
!
!  Calculate the Brownian force contribution due to the random thermal motions
!  of the gas molecules.
!
!  28-jul-08/kapelrud: coded
!
      use Cdata, only: pi_1, k_B, dt
      use General, only: normal_deviate
      use Viscosity, only: getnu
!
      real, dimension(mpar_loc,mpvar) :: fp
      real, dimension(3), intent(out) :: force
      integer :: k
      real :: stocunn
!
      intent(in) :: fp,k
!
      real :: Szero,dia,TT,nu
!
      call getnu(nu)
!
!  Particle diameter:
!
      dia=2.0*fp(k,iap)
!
!  Get zero mean, unit variance Gaussian random numbers:
!
      call normal_deviate(force(1))
      call normal_deviate(force(2))
      call normal_deviate(force(3))
!
      if (interp%lTT) then
        TT=interp_TT(k)
      else
        TT=brownian_T0
      endif
!
      Szero=216*nu*k_B*TT*pi_1/ &
        (dia**5*stocunn*rhop_tilde**2/interp_rho(k))
!
      if (dt==0.0) then
        force=0.0
      else
        force=force*sqrt(Szero/dt)
      endif
!
    endsubroutine calc_brownian_force
!***********************************************************************
    subroutine read_particles_init_pars(unit,iostat)
!
      integer, intent (in) :: unit
      integer, intent (inout), optional :: iostat
!
      if (present(iostat)) then
        read(unit,NML=particles_init_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=particles_init_pars,ERR=99)
      endif
!
99    return
!
    endsubroutine read_particles_init_pars
!***********************************************************************
    subroutine write_particles_init_pars(unit)
!
      integer, intent (in) :: unit
!
      write(unit,NML=particles_init_pars)
!
    endsubroutine write_particles_init_pars
!***********************************************************************
    subroutine read_particles_run_pars(unit,iostat)
!
      integer, intent (in) :: unit
      integer, intent (inout), optional :: iostat
!
      if (present(iostat)) then
        read(unit,NML=particles_run_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=particles_run_pars,ERR=99)
      endif
!
99    return
!
    endsubroutine read_particles_run_pars
!***********************************************************************
    subroutine write_particles_run_pars(unit)
!
      integer, intent (in) :: unit
!
      write(unit,NML=particles_run_pars)
!
    endsubroutine write_particles_run_pars
!***********************************************************************
    subroutine powersnap_particles(f)
!
!  Calculate power spectra of dust particle variables.
!
!  01-jan-06/anders: coded
!
      use Power_spectrum, only: power_1d
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      if (lpar_spec) call power_1d(f,'p',0,irhop)
!
    endsubroutine powersnap_particles
!***********************************************************************
    subroutine rprint_particles(lreset,lwrite)
!
!  Read and register print parameters relevant for particles
!
!  29-dec-04/anders: coded
!
      use Cdata
      use Sub, only: parse_name
!
      logical :: lreset
      logical, optional :: lwrite
!
      integer :: iname,inamez,inamey,inamex,inamexy,inamexz,inamer,inamerz
      logical :: lwr
!
!  Write information to index.pro
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite

      if (lwr) then
        write(3,*) 'ixp=', ixp
        write(3,*) 'iyp=', iyp
        write(3,*) 'izp=', izp
        write(3,*) 'ivpx=', ivpx
        write(3,*) 'ivpy=', ivpy
        write(3,*) 'ivpz=', ivpz
        write(3,*) 'inp=', inp
        write(3,*) 'irhop=', irhop
      endif
!
!  Reset everything in case of reset
!
      if (lreset) then
        idiag_xpm=0; idiag_ypm=0; idiag_zpm=0
        idiag_xp2m=0; idiag_yp2m=0; idiag_zp2m=0
        idiag_vpxm=0; idiag_vpym=0; idiag_vpzm=0
        idiag_vpx2m=0; idiag_vpy2m=0; idiag_vpz2m=0; idiag_ekinp=0
        idiag_vpxmax=0; idiag_vpymax=0; idiag_vpzmax=0
        idiag_npm=0; idiag_np2m=0; idiag_npmax=0; idiag_npmin=0
        idiag_rhoptilm=0; idiag_dtdragp=0; idiag_dedragp=0
        idiag_rhopm=0; idiag_rhoprms=0; idiag_rhop2m=0; idiag_rhopmax=0
        idiag_rhopmin=0; idiag_decollp=0; idiag_rhopmphi=0
        idiag_nparmax=0; idiag_nmigmax=0; idiag_mpt=0
        idiag_npmx=0; idiag_npmy=0; idiag_npmz=0
        idiag_rhopmx=0; idiag_rhopmy=0; idiag_rhopmz=0
        idiag_epspmx=0; idiag_epspmy=0; idiag_epspmz=0
        idiag_rhopmxy=0; idiag_rhopmxz=0; idiag_rhopmr=0
        idiag_dvpx2m=0; idiag_dvpy2m=0; idiag_dvpz2m=0
        idiag_dvpmax=0; idiag_dvpm=0; idiag_nparpmax=0
      endif
!
!  Run through all possible names that may be listed in print.in
!
      if (lroot .and. ip<14) print*,'rprint_particles: run through parse list'
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'nparmax',idiag_nparmax)
        call parse_name(iname,cname(iname),cform(iname),'nparpmax',idiag_nparpmax)
        call parse_name(iname,cname(iname),cform(iname),'xpm',idiag_xpm)
        call parse_name(iname,cname(iname),cform(iname),'ypm',idiag_ypm)
        call parse_name(iname,cname(iname),cform(iname),'zpm',idiag_zpm)
        call parse_name(iname,cname(iname),cform(iname),'xp2m',idiag_xp2m)
        call parse_name(iname,cname(iname),cform(iname),'yp2m',idiag_yp2m)
        call parse_name(iname,cname(iname),cform(iname),'zp2m',idiag_zp2m)
        call parse_name(iname,cname(iname),cform(iname),'vpxm',idiag_vpxm)
        call parse_name(iname,cname(iname),cform(iname),'vpym',idiag_vpym)
        call parse_name(iname,cname(iname),cform(iname),'vpzm',idiag_vpzm)
        call parse_name(iname,cname(iname),cform(iname),'vpx2m',idiag_vpx2m)
        call parse_name(iname,cname(iname),cform(iname),'vpy2m',idiag_vpy2m)
        call parse_name(iname,cname(iname),cform(iname),'vpz2m',idiag_vpz2m)
        call parse_name(iname,cname(iname),cform(iname),'ekinp',idiag_ekinp)
        call parse_name(iname,cname(iname),cform(iname),'vpxmax',idiag_vpxmax)
        call parse_name(iname,cname(iname),cform(iname),'vpymax',idiag_vpymax)
        call parse_name(iname,cname(iname),cform(iname),'vpzmax',idiag_vpzmax)
        call parse_name(iname,cname(iname),cform(iname),'dtdragp',idiag_dtdragp)
        call parse_name(iname,cname(iname),cform(iname),'npm',idiag_npm)
        call parse_name(iname,cname(iname),cform(iname),'np2m',idiag_np2m)
        call parse_name(iname,cname(iname),cform(iname),'npmax',idiag_npmax)
        call parse_name(iname,cname(iname),cform(iname),'npmin',idiag_npmin)
        call parse_name(iname,cname(iname),cform(iname),'rhopm',idiag_rhopm)
        call parse_name(iname,cname(iname),cform(iname),'rhoprms',idiag_rhoprms)
        call parse_name(iname,cname(iname),cform(iname),'rhop2m',idiag_rhop2m)
        call parse_name(iname,cname(iname),cform(iname),'rhopmin',idiag_rhopmin)
        call parse_name(iname,cname(iname),cform(iname),'rhopmax',idiag_rhopmax)
        call parse_name(iname,cname(iname),cform(iname),'rhopmphi',idiag_rhopmphi)
        call parse_name(iname,cname(iname),cform(iname),'nmigmax',idiag_nmigmax)
        call parse_name(iname,cname(iname),cform(iname),'mpt',idiag_mpt)
        call parse_name(iname,cname(iname),cform(iname),'dvpx2m',idiag_dvpx2m)
        call parse_name(iname,cname(iname),cform(iname),'dvpy2m',idiag_dvpy2m)
        call parse_name(iname,cname(iname),cform(iname),'dvpz2m',idiag_dvpz2m)
        call parse_name(iname,cname(iname),cform(iname),'dvpm',idiag_dvpm)
        call parse_name(iname,cname(iname),cform(iname),'dvpmax',idiag_dvpmax)
         call parse_name(iname,cname(iname),cform(iname), &
            'rhoptilm',idiag_rhoptilm)
        call parse_name(iname,cname(iname),cform(iname), &
            'dedragp',idiag_dedragp)
        call parse_name(iname,cname(iname),cform(iname), &
            'decollp',idiag_decollp)
      enddo
!
!  check for those quantities for which we want x-averages
!
      do inamex=1,nnamex
        call parse_name(inamex,cnamex(inamex),cformx(inamex),'npmx',idiag_npmx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex),'rhopmx',idiag_rhopmx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex),'epspmx',idiag_epspmx)
      enddo
!
!  check for those quantities for which we want y-averages
!
      do inamey=1,nnamey
        call parse_name(inamey,cnamey(inamey),cformy(inamey),'npmy',idiag_npmy)
        call parse_name(inamey,cnamey(inamey),cformy(inamey),'rhopmy',idiag_npmy)
        call parse_name(inamey,cnamey(inamey),cformy(inamey),'epspmy',idiag_epspmy)
      enddo
!
!  check for those quantities for which we want z-averages
!
      do inamez=1,nnamez
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'npmz',idiag_npmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'rhopmz',idiag_rhopmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'epspmz',idiag_epspmz)
      enddo
!
!  check for those quantities for which we want xy-averages
!
      do inamexy=1,nnamexy
        call parse_name(inamexy,cnamexy(inamexy),cformxy(inamexy),'rhopmxy',idiag_rhopmxy)
      enddo
!
!  check for those quantities for which we want xz-averages
!
      do inamexz=1,nnamexz
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'rhopmxz',idiag_rhopmxz)
      enddo
!
!  check for those quantities for which we want phiz-averages
!
      do inamer=1,nnamer
        call parse_name(inamer,cnamer(inamer),cformr(inamer),'rhopmr',idiag_rhopmr)
      enddo
!
!  check for those quantities for which we want phi-averages
!
      do inamerz=1,nnamerz
        call parse_name(inamerz,cnamer(inamerz),cformr(inamerz),'rhopmphi',idiag_rhopmphi)
      enddo
!
    endsubroutine rprint_particles
!***********************************************************************

endmodule Particles
