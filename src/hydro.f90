! $Id: hydro.f90,v 1.423 2008-03-25 08:31:41 brandenb Exp $
!
!  This module takes care of everything related to velocity
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lhydro = .true.
!
! MVAR CONTRIBUTION 3
! MAUX CONTRIBUTION 0
!
! PENCILS PROVIDED divu,oo,o2,ou,u2,uij,uu,sij,sij2,uij5,ugu,oij,qq
! PENCILS PROVIDED u3u21,u1u32,u2u13,del2u,del4u,del6u,graddivu,del6u_bulk
! PENCILS PROVIDED grad5divu
!
!***************************************************************
module Hydro

!  Note that Omega is already defined in cdata.

  use Cparam
  use Cdata, only: Omega, theta, huge1
  use Viscosity
  use Messages
! Dhruba 

  implicit none

  include 'hydro.h'
!
! Slice precalculation buffers
!
  real, target, dimension (nx,ny,3) :: oo_xy
  real, target, dimension (nx,ny,3) :: oo_xy2
  real, target, dimension (nx,nz,3) :: oo_xz
  real, target, dimension (ny,nz,3) :: oo_yz
  real, target, dimension (nx,ny) :: divu_xy,u2_xy,o2_xy
  real, target, dimension (nx,ny) :: divu_xy2,u2_xy2,o2_xy2
  real, target, dimension (nx,nz) :: divu_xz,u2_xz,o2_xz
  real, target, dimension (ny,nz) :: divu_yz,u2_yz,o2_yz
  real, dimension (nz,3) :: uumz
!
!  precession matrices
!
  real, dimension (3,3) :: mat_cori=0.,mat_cent=0.
!
! init parameters
!
  real :: widthuu=.1, radiusuu=1., urand=0., kx_uu=1., ky_uu=1., kz_uu=1.
  real :: urandi=0.
  real :: uu_left=0.,uu_right=0.,uu_lower=1.,uu_upper=1.
  real :: uy_left=0.,uy_right=0.
  real :: initpower=1.,cutoff=0.
  real, dimension (ninit) :: ampl_ux=0.0, ampl_uy=0.0, ampl_uz=0.0
  real, dimension (ninit) :: kx_ux=0.0, kx_uy=0.0, kx_uz=0.0
  real, dimension (ninit) :: ky_ux=0.0, ky_uy=0.0, ky_uz=0.0
  real, dimension (ninit) :: kz_ux=0.0, kz_uy=0.0, kz_uz=0.0
  real, dimension (ninit) :: phase_ux=0.0, phase_uy=0.0, phase_uz=0.0
  real :: omega_precession=0.
  real, dimension (ninit) :: ampluu=0.0
  character (len=labellen), dimension(ninit) :: inituu='nothing'
  character (len=labellen) :: borderuu='nothing'
  real, dimension(3) :: uu_const=(/0.,0.,0./)
  complex, dimension(3) :: coefuu=(/0.,0.,0./)
  real :: kep_cutoff_pos_ext= huge1,kep_cutoff_width_ext=0.0
  real :: kep_cutoff_pos_int=-huge1,kep_cutoff_width_int=0.0
  real :: u_out_kep=0.0, velocity_ceiling=-1.0
  real :: mu_omega=0., gap=0.
  integer :: nb_rings=0
  real, dimension(5) :: om_rings=0.
  integer :: N_modes_uu=0
  logical :: lcoriolis_force=.true., lcentrifugal_force=.false.
  logical :: ladvection_velocity=.true.
  logical :: lprecession=.false.
  logical :: lshear_rateofstrain=.false.
  logical :: luut_as_aux=.false.
  logical :: lpressuregradient_gas=.true.
! Dhruba
  real :: outest
  logical :: loutest,ldiffrot_test=.false.
  namelist /hydro_init_pars/ &
       ampluu, ampl_ux, ampl_uy, ampl_uz, phase_ux, phase_uy, phase_uz, &
       inituu, widthuu, radiusuu, urand, urandi, lpressuregradient_gas, &
       uu_left, uu_right, uu_lower, uu_upper, kx_uu, ky_uu, kz_uu, coefuu, &
       kx_ux, ky_ux, kz_ux, kx_uy, ky_uy, kz_uy, kx_uz, ky_uz, kz_uz, &
       uy_left, uy_right,uu_const, Omega,  initpower, cutoff, &
       kep_cutoff_pos_ext, kep_cutoff_width_ext, &
       kep_cutoff_pos_int, kep_cutoff_width_int, &
       u_out_kep, N_modes_uu, lcoriolis_force, lcentrifugal_force, &
       ladvection_velocity, lprecession, omega_precession, &
       luut_as_aux, velocity_ceiling, mu_omega, nb_rings, om_rings, gap

  ! run parameters
  real :: tdamp=0.,dampu=0.,wdamp=0.
  real :: dampuint=0.0,dampuext=0.0,rdampint=-1e20,rdampext=impossible
  real :: ruxm=0.,ruym=0.,ruzm=0.
  real :: tau_damp_ruxm1=0.,tau_damp_ruym1=0.,tau_damp_ruzm1=0.
  real :: tau_damp_ruxm=0.,tau_damp_ruym=0.,tau_damp_ruzm=0.,tau_diffrot1=0.
  real :: ampl1_diffrot=0.,ampl2_diffrot=0.
  real :: Omega_int=0.,xexp_diffrot=1.,kx_diffrot=1.,kz_diffrot=0.
  real :: othresh=0.,othresh_per_orms=0.,orms=0.,othresh_scl=1.
  real :: utop=0.,ubot=0.,omega_out=0.,omega_in=0.
  real :: width_ff_uu=1.,x1_ff_uu=0.,x2_ff_uu=0.
  integer :: novec,novecmax=nx*ny*nz/4
  logical :: ldamp_fade=.false.,lOmega_int=.false.,lupw_uu=.false.
  logical :: lfreeze_uint=.false.,lfreeze_uext=.false.
  logical :: lremove_mean_momenta=.false.
  logical :: lremove_mean_flow=.false.
  logical :: lalways_use_gij_etc=.false.
  logical :: lcalc_uumean=.false.
  logical :: lforcing_cont_uu=.false.
  character (len=labellen) :: uuprof='nothing'
!
! geodynamo
  namelist /hydro_run_pars/ &
       Omega,theta, &         ! remove and use viscosity_run_pars only
       tdamp,dampu,dampuext,dampuint,rdampext,rdampint,wdamp, &
       tau_damp_ruxm,tau_damp_ruym,tau_damp_ruzm,tau_diffrot1, &
       ampl1_diffrot,ampl2_diffrot,uuprof, &
       xexp_diffrot,kx_diffrot,kz_diffrot, &
       lremove_mean_momenta,lremove_mean_flow, &
       lOmega_int,Omega_int, ldamp_fade, lupw_uu, othresh,othresh_per_orms, &
       borderuu, lfreeze_uint, lpressuregradient_gas, &
       lfreeze_uext,lcoriolis_force,lcentrifugal_force,ladvection_velocity, &
       utop,ubot,omega_out,omega_in, & 
       lprecession, omega_precession, lshear_rateofstrain, &
       lalways_use_gij_etc,lcalc_uumean, &
       lforcing_cont_uu, &
       width_ff_uu,x1_ff_uu,x2_ff_uu, &
       luut_as_aux,loutest, ldiffrot_test,&
       velocity_ceiling

! end geodynamo

  ! diagnostic variables (need to be consistent with reset list below)
  integer :: idiag_u2tm=0       ! DIAG_DOC: $\left<\uv(t)\cdot\int_0^t\uv(t')
                                ! DIAG_DOC:   dt'\right>$
  integer :: idiag_u2m=0        ! DIAG_DOC: $\left<\uv^2\right>$
  integer :: idiag_um2=0        ! DIAG_DOC: 
  integer :: idiag_uxpt=0       ! DIAG_DOC: 
  integer :: idiag_uypt=0       ! DIAG_DOC: 
  integer :: idiag_uzpt=0       ! DIAG_DOC: 
  integer :: idiag_urms=0       ! DIAG_DOC: $\left<\uv^2\right>^{1/2}$
  integer :: idiag_umax=0       ! DIAG_DOC: $\max(|\uv|)$
  integer :: idiag_uzrms=0      ! DIAG_DOC: $\left<u_z^2\right>^{1/2}$
  integer :: idiag_uzrmaxs=0    ! DIAG_DOC: 
  integer :: idiag_uxmax=0      ! DIAG_DOC: $\max(|u_x|)$
  integer :: idiag_uymax=0      ! DIAG_DOC: $\max(|u_y|)$
  integer :: idiag_uzmax=0      ! DIAG_DOC: $\max(|u_z|)$
  integer :: idiag_uxm=0        ! DIAG_DOC: 
  integer :: idiag_uym=0        ! DIAG_DOC: 
  integer :: idiag_uzm=0        ! DIAG_DOC: 
  integer :: idiag_ux2m=0       ! DIAG_DOC: $\left<u_x^2\right>$
  integer :: idiag_uy2m=0       ! DIAG_DOC: $\left<u_y^2\right>$
  integer :: idiag_uz2m=0       ! DIAG_DOC: $\left<u_z^2\right>$
  integer :: idiag_ux2mx=0      ! DIAG_DOC: $\left<u_x^2\right>_{yz}$
  integer :: idiag_uy2mx=0      ! DIAG_DOC: $\left<u_y^2\right>_{yz}$
  integer :: idiag_uz2mx=0      ! DIAG_DOC: $\left<u_z^2\right>_{yz}$
  integer :: idiag_ux2my=0      ! DIAG_DOC: 
  integer :: idiag_uy2my=0      ! DIAG_DOC: 
  integer :: idiag_uz2my=0      ! DIAG_DOC: 
  integer :: idiag_ux2mz=0      ! DIAG_DOC: 
  integer :: idiag_uy2mz=0      ! DIAG_DOC: 
  integer :: idiag_uz2mz=0      ! DIAG_DOC: 
  integer :: idiag_uxuym=0      ! DIAG_DOC: 
  integer :: idiag_uxuzm=0      ! DIAG_DOC: 
  integer :: idiag_uyuzm=0      ! DIAG_DOC: 
  integer :: idiag_uxuymz=0     ! DIAG_DOC: 
  integer :: idiag_uxuzmz=0     ! DIAG_DOC: 
  integer :: idiag_uyuzmz=0     ! DIAG_DOC: 
  integer :: idiag_uxuymy=0     ! DIAG_DOC: 
  integer :: idiag_uxuzmy=0     ! DIAG_DOC: 
  integer :: idiag_uyuzmy=0     ! DIAG_DOC: 
  integer :: idiag_uxuymx=0     ! DIAG_DOC: 
  integer :: idiag_uxuzmx=0     ! DIAG_DOC: 
  integer :: idiag_uyuzmx=0     ! DIAG_DOC: 
  integer :: idiag_uxmz=0       ! DIAG_DOC: $\left< u_x \right>_{x,y}$
                                ! DIAG_DOC:   \quad(horiz. averaged $x$
                                ! DIAG_DOC:   velocity)
  integer :: idiag_uymz=0       ! DIAG_DOC: 
  integer :: idiag_uzmz=0       ! DIAG_DOC: 
  integer :: idiag_umx=0        ! DIAG_DOC: 
  integer :: idiag_umy=0        ! DIAG_DOC: 
  integer :: idiag_uxmy=0       ! DIAG_DOC: 
  integer :: idiag_uymy=0       ! DIAG_DOC: 
  integer :: idiag_uzmy=0       ! DIAG_DOC: 
  integer :: idiag_u2mz=0       ! DIAG_DOC: 
  integer :: idiag_umz=0        ! DIAG_DOC: 
  integer :: idiag_uxmxy=0      ! DIAG_DOC: $\left< u_x \right>_{z}$
  integer :: idiag_uymxy=0      ! DIAG_DOC: $\left< u_y \right>_{z}$
  integer :: idiag_uzmxy=0      ! DIAG_DOC: $\left< u_z \right>_{z}$
  integer :: idiag_ruxmxy=0     ! DIAG_DOC: $\left< \rho u_x \right>_{z}$
  integer :: idiag_ruymxy=0     ! DIAG_DOC: $\left< \rho u_y \right>_{z}$
  integer :: idiag_ruzmxy=0     ! DIAG_DOC: $\left< \rho u_z \right>_{z}$
  integer :: idiag_ux2mxy=0     ! DIAG_DOC: $\left< u_x^2 \right>_{z}$
  integer :: idiag_uy2mxy=0     ! DIAG_DOC: $\left< u_y^2 \right>_{z}$
  integer :: idiag_uz2mxy=0     ! DIAG_DOC: $\left< u_z^2 \right>_{z}$
  integer :: idiag_rux2mxy=0    ! DIAG_DOC: $\left< \rho u_x^2 \right>_{z}$
  integer :: idiag_ruy2mxy=0    ! DIAG_DOC: $\left< \rho u_y^2 \right>_{z}$
  integer :: idiag_ruz2mxy=0    ! DIAG_DOC: $\left< \rho u_z^2 \right>_{z}$
  integer :: idiag_ruxuymxy=0   ! DIAG_DOC: $\left< \rho u_x u_y \right>_{z}$
  integer :: idiag_ruxuzmxy=0   ! DIAG_DOC: $\left< \rho u_x u_z \right>_{z}$
  integer :: idiag_ruyuzmxy=0   ! DIAG_DOC: $\left< \rho u_y u_z \right>_{z}$
  integer :: idiag_uxmxz=0      ! DIAG_DOC: $\left< u_x \right>_{y}$
  integer :: idiag_uymxz=0      ! DIAG_DOC: $\left< u_y \right>_{y}$
  integer :: idiag_uzmxz=0      ! DIAG_DOC: $\left< u_z \right>_{y}$
  integer :: idiag_ux2mxz=0     ! DIAG_DOC: $\left< u_x^2 \right>_{y}$
  integer :: idiag_uy2mxz=0     ! DIAG_DOC: $\left< u_y^2 \right>_{y}$
  integer :: idiag_uz2mxz=0     ! DIAG_DOC: $\left< u_z^2 \right>_{y}$
  integer :: idiag_uxmx=0       ! DIAG_DOC: 
  integer :: idiag_uymx=0       ! DIAG_DOC: 
  integer :: idiag_uzmx=0       ! DIAG_DOC: 
  integer :: idiag_divum=0      ! DIAG_DOC: 
  integer :: idiag_divu2m=0     ! DIAG_DOC: 
  integer :: idiag_u3u21m=0     ! DIAG_DOC: 
  integer :: idiag_u1u32m=0     ! DIAG_DOC: 
  integer :: idiag_u2u13m=0     ! DIAG_DOC: 
  integer :: idiag_urmphi=0     ! DIAG_DOC: 
  integer :: idiag_upmphi=0     ! DIAG_DOC: 
  integer :: idiag_uzmphi=0     ! DIAG_DOC: 
  integer :: idiag_u2mphi=0     ! DIAG_DOC: 
  integer :: idiag_u2mr=0       ! DIAG_DOC: 
  integer :: idiag_urmr=0       ! DIAG_DOC: 
  integer :: idiag_upmr=0       ! DIAG_DOC: 
  integer :: idiag_uzmr=0       ! DIAG_DOC: 
  integer :: idiag_uxfampm=0    ! DIAG_DOC: 
  integer :: idiag_uyfampm=0    ! DIAG_DOC: 
  integer :: idiag_uzfampm=0    ! DIAG_DOC: 
  integer :: idiag_uxfampim=0   ! DIAG_DOC: 
  integer :: idiag_uyfampim=0   ! DIAG_DOC: 
  integer :: idiag_uzfampim=0   ! DIAG_DOC:
  integer :: idiag_ruxm=0       ! DIAG_DOC: $\left<\varrho u_x\right>$
                                ! DIAG_DOC:   \quad(mean $x$-momentum density)
  integer :: idiag_ruym=0       ! DIAG_DOC: $\left<\varrho u_y\right>$
                                ! DIAG_DOC:   \quad(mean $y$-momentum density)
  integer :: idiag_ruzm=0       ! DIAG_DOC: $\left<\varrho u_z\right>$
                                ! DIAG_DOC:   \quad(mean $z$-momentum density)
  integer :: idiag_rumax=0      ! DIAG_DOC: $\max(\varrho |\uv|)$
                                ! DIAG_DOC:   \quad(maximum modulus of momentum)
  integer :: idiag_ruxuym=0     ! DIAG_DOC: $\left<\varrho u_x u_y\right>$
                                ! DIAG_DOC:   \quad(mean Reynold's stress)
  integer :: idiag_ruxuymz=0    ! DIAG_DOC:
  integer :: idiag_rufm=0       ! DIAG_DOC:
  integer :: idiag_dtu=0        ! DIAG_DOC: $\delta t/[c_{\delta t}\,\delta x
                                ! DIAG_DOC:  /\max|\mathbf{u}|]$
                                ! DIAG_DOC:  \quad(time step relative to
                                ! DIAG_DOC:   advective time step;
                                ! DIAG_DOC:   see \S~\ref{time-step})
  integer :: idiag_oum=0        ! DIAG_DOC: $\left<\boldsymbol{\omega}
                                ! DIAG_DOC:   \cdot\uv\right>$
  integer :: idiag_o2m=0        ! DIAG_DOC: $\left<\boldsymbol{\omega}^2\right>
                                ! DIAG_DOC:   \equiv \left<(\curl\uv)^2\right>$
  integer :: idiag_orms=0       ! DIAG_DOC: $\left<\boldsymbol{\omega}^2
                                ! DIAG_DOC:   \right>^{1/2}$
  integer :: idiag_omax=0       ! DIAG_DOC: $\max(|\boldsymbol{\omega}|)$
  integer :: idiag_ox2m=0       ! DIAG_DOC: $\left<\omega_x^2\right>$
  integer :: idiag_oy2m=0       ! DIAG_DOC: $\left<\omega_y^2\right>$
  integer :: idiag_oz2m=0       ! DIAG_DOC: $\left<\omega_z^2\right>$
  integer :: idiag_oxm=0        ! DIAG_DOC: 
  integer :: idiag_oym=0        ! DIAG_DOC: 
  integer :: idiag_ozm=0        ! DIAG_DOC: 
  integer :: idiag_oxoym=0      ! DIAG_DOC: $\left<\omega_x\omega_y\right>$
  integer :: idiag_oxozm=0      ! DIAG_DOC: $\left<\omega_x\omega_z\right>$
  integer :: idiag_oyozm=0      ! DIAG_DOC: $\left<\omega_y\omega_z\right>$
  integer :: idiag_oumphi=0     ! DIAG_DOC: 
  integer :: idiag_ozmphi=0     ! DIAG_DOC: 
  integer :: idiag_ormr=0       ! DIAG_DOC: 
  integer :: idiag_opmr=0       ! DIAG_DOC: 
  integer :: idiag_ozmr=0       ! DIAG_DOC: 
  integer :: idiag_oumx=0       ! DIAG_DOC: $\left<\boldsymbol{\omega}
                                ! DIAG_DOC: \cdot\uv\right>_{yz}$
  integer :: idiag_oumy=0       ! DIAG_DOC: $\left<\boldsymbol{\omega}
                                ! DIAG_DOC: \cdot\uv\right>_{xz}$
  integer :: idiag_oumz=0       ! DIAG_DOC: $\left<\boldsymbol{\omega}
                                ! DIAG_DOC: \cdot\uv\right>_{xy}$
  !
  integer :: idiag_Marms=0      ! DIAG_DOC: $\left<\uv^2/\cs^2\right>$
                                ! DIAG_DOC:   \quad(rms Mach number)
  integer :: idiag_Mamax=0      ! DIAG_DOC: $\max |\uv|/\cs$
                                ! DIAG_DOC:   \quad(maximum Mach number)
  !
  integer :: idiag_fintm=0      ! DIAG_DOC: 
  integer :: idiag_fextm=0      ! DIAG_DOC: 
  integer :: idiag_duxdzma=0    ! DIAG_DOC: 
  integer :: idiag_duydzma=0    ! DIAG_DOC: 
  integer :: idiag_ekin=0       ! DIAG_DOC: $\left<{1\over2}\varrho\uv^2\right>$
  integer :: idiag_ekintot=0    ! DIAG_DOC: $\int_V{1\over2}\varrho\uv^2\, dV$
  integer :: idiag_ekinz=0      ! DIAG_DOC: 
  integer :: idiag_totangmom=0  ! DIAG_DOC: 
  integer :: idiag_fmassz=0     ! DIAG_DOC: 
  integer :: idiag_fkinz=0      ! DIAG_DOC: 
  integer :: idiag_fxbxm=0      ! DIAG_DOC: 
  integer :: idiag_fxbym=0      ! DIAG_DOC: 
  integer :: idiag_fxbzm=0      ! DIAG_DOC: 

  contains

!***********************************************************************
    subroutine register_hydro()
!
!  Initialise variables which should know that we solve the hydro
!  equations: iuu, etc; increase nvar accordingly.
!
!  6-nov-01/wolf: coded
!
      use Cdata
      use Mpicomm, only: stop_it
      use SharedVariables
      use Sub
!
      logical, save :: first=.true.
      integer :: ierr
!
      if (.not. first) call stop_it('register_hydro called twice')
      first = .false.
!
!  indices to access uu
!
      iuu = nvar+1
      iux = iuu
      iuy = iuu+1
      iuz = iuu+2
      nvar = nvar+3             ! added 3 variables
!
      if ((ip<=8) .and. lroot) then
        print*, 'register_hydro: nvar = ', nvar
        print*, 'register_hydro: iux,iuy,iuz = ', iux,iuy,iuz
      endif
!
!  Put variable names in array
!
      varname(iux) = 'ux'
      varname(iuy) = 'uy'
      varname(iuz) = 'uz'
!
!  identify version number (generated automatically by CVS)
!
      if (lroot) call cvs_id( &
           "$Id: hydro.f90,v 1.423 2008-03-25 08:31:41 brandenb Exp $")
!
      if (nvar > mvar) then
        if (lroot) write(0,*) 'nvar = ', nvar, ', mvar = ', mvar
        call stop_it('register_hydro: nvar > mvar')
      endif
!
!  Writing files for use with IDL
!
      if (lroot) then
        if (maux == 0) then
          if (nvar < mvar) write(4,*) ',uu $'
          if (nvar == mvar) write(4,*) ',uu'
        else
          write(4,*) ',uu $'
        endif
        write(15,*) 'uu = fltarr(mx,my,mz,3)*one'
      endif
!
!  Share lpressuregradient_gas so Entropy module knows whether to apply
!  pressure gradient or not.
!
      call put_shared_variable('lpressuregradient_gas',lpressuregradient_gas,ierr)     
      if (ierr/=0) call fatal_error('register_hydro','there was a problem sharing lpressuregradient_gas')
!
    endsubroutine register_hydro
!***********************************************************************
    subroutine initialize_hydro(f,lstarting)
!
!  Perform any post-parameter-read initialization i.e. calculate derived
!  parameters.
!
!  24-nov-02/tony: coded
!  13-oct-03/dave: check parameters and warn (if nec.) about velocity damping
!
      use Mpicomm, only: stop_it
      use Cdata,   only: r_int,r_ext,lfreeze_varint,lfreeze_varext,epsi,leos,iux,iuy,iuz,iuut,iuxt,iuyt,iuzt,lroot,datadir
      use FArrayManager
      use SharedVariables
!
      real, dimension (mx,my,mz,mfarray) :: f
      logical :: lstarting
!
! Check any module dependencies
!
      if (.not. leos) then
        call stop_it('initialize_hydro: EOS=noeos but hydro requires an EQUATION OF STATE for the fluid')
      endif
!
!  r_int and r_ext override rdampint and rdampext if both are set
!
      if (dampuint /= 0.) then
        if (r_int > epsi) then
          rdampint = r_int
        elseif (rdampint <= epsi) then
          write(*,*) 'initialize_hydro: inner radius not yet set, dampuint= ',dampuint
        endif
      endif
!
!  damping parameters for damping velocities outside an embedded sphere
!  04-feb-2008/dintrans: corriged because otherwise rdampext=r_ext all the time
!
      if (dampuext /= 0.0) then
!       if (r_ext < impossible) then
!         rdampext = r_ext
!       elseif (rdampext == impossible) then
!         write(*,*) 'initialize_hydro: outer radius not yet set, dampuext= ',dampuext
!       endif
        if (rdampext == impossible) then
          if (r_ext < impossible) then
            write(*,*) 'initialize_hydro: set outer radius rdampext=r_ext'
            rdampext = r_ext
          else
            write(*,*) 'initialize_hydro: cannot set outer radius rdampext=r_ext'
          endif
        else
          write(*,*) 'initialize_hydro: outer radius rdampext=',rdampext
        endif
      endif
!
!  calculate inverse damping times for damping momentum in the
!  x and y directions
!
      if (tau_damp_ruxm /= 0.) tau_damp_ruxm1=1./tau_damp_ruxm
      if (tau_damp_ruym /= 0.) tau_damp_ruym1=1./tau_damp_ruym
      if (tau_damp_ruzm /= 0.) tau_damp_ruzm1=1./tau_damp_ruzm
!
!  set freezing arrays
!
      if (lfreeze_uint) lfreeze_varint(iux:iuz) = .true.
      if (lfreeze_uext) lfreeze_varext(iux:iuz) = .true.
!
!  Turn off advection for 0-D runs.
!
      if (nxgrid*nygrid*nzgrid==1) then
        ladvection_velocity=.false.
        print*, 'initialize_entropy: 0-D run, turned off advection of velocity'
      endif
!
!  Register an extra aux slot for uut if requested. This is needed
!  for calculating the correlation time from <u.intudt>. For this to work
!  you must reserve enough auxiliary workspace by setting, for example,
!     ! MAUX CONTRIBUTION 3
!  in the beginning of your src/cparam.local file, *before* setting
!  ncpus, nprocy, etc.
!
!  After a reload, we need to rewrite index.pro, but the auxiliary
!  arrays are already allocated and must not be allocated again.
!
      if (luut_as_aux) then
        if (iuut==0) then
          call farray_register_auxiliary('uut',iuut,vector=3)
          iuxt=iuut
          iuyt=iuut+1
          iuzt=iuut+2
        endif
        if (iuut/=0.and.lroot) then
          print*, 'initialize_velocity: iuut = ', iuut
          open(3,file=trim(datadir)//'/index.pro', POSITION='append')
          write(3,*) 'iuut=',iuut
          write(3,*) 'iuxt=',iuxt
          write(3,*) 'iuyt=',iuyt
          write(3,*) 'iuzt=',iuzt
          close(3)
        endif
      endif
!
      if (NO_WARN) print*,f,lstarting  !(to keep compiler quiet)
!
      endsubroutine initialize_hydro
!***********************************************************************
    subroutine read_hydro_init_pars(unit,iostat)
!
!
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (present(iostat)) then
        read(unit,NML=hydro_init_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=hydro_init_pars,ERR=99)
      endif
!
99    return
!
    endsubroutine read_hydro_init_pars
!***********************************************************************
    subroutine write_hydro_init_pars(unit)
!
!
!    
      integer, intent(in) :: unit
!
      write(unit,NML=hydro_init_pars)
!
    endsubroutine write_hydro_init_pars
!***********************************************************************
    subroutine read_hydro_run_pars(unit,iostat)
!
!
!    
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (present(iostat)) then
        read(unit,NML=hydro_run_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=hydro_run_pars,ERR=99)
      endif
!
99    return
!
    endsubroutine read_hydro_run_pars
!***********************************************************************
    subroutine write_hydro_run_pars(unit)
!
!
!    
      integer, intent(in) :: unit
!
      write(unit,NML=hydro_run_pars)
!
    endsubroutine write_hydro_run_pars
!***********************************************************************
    subroutine init_uu(f,xx,yy,zz)
!
!  initialise uu and lnrho; called from start.f90
!  Should be located in the Hydro module, if there was one.
!
!  07-nov-01/wolf: coded
!  24-nov-02/tony: renamed for consistance (i.e. init_[variable name])
!
      use Cdata
      use EquationOfState, only: cs20, gamma, beta_glnrho_scaled
      use General
      use Gravity, only: grav_const,z1
      use Initcond
      use Mpicomm, only: stop_it
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz) :: r,p,tmp,xx,yy,zz,prof
      real :: kabs,crit,eta_sigma
      integer :: j,i,l
!
!  inituu corresponds to different initializations of uu (called from start).
!
      do j=1,ninit

        select case(inituu(j))

        case('nothing'); if(lroot .and. j==1) print*,'init_uu: nothing'
        case('zero', '0')
          if(lroot) print*,'init_uu: zero velocity'
          ! Ensure really is zero, as may have used lread_oldsnap
          f(:,:,:,iux:iuz)=0.
        case('const_uu'); do i=1,3; f(:,:,:,iuu+i-1) = uu_const(i); enddo
        case('mode'); call modev(ampluu(j),coefuu,f,iuu,kx_uu,ky_uu,kz_uu,xx,yy,zz)
        case('gaussian-noise'); call gaunoise(ampluu(j),f,iux,iuz)
        case('gaussian-noise-x'); call gaunoise(ampluu(j),f,iux)
        case('gaussian-noise-y'); call gaunoise(ampluu(j),f,iuy)
        case('gaussian-noise-z'); call gaunoise(ampluu(j),f,iuz)
        case('gaussian-noise-xy'); call gaunoise(ampluu(j),f,iux,iuy)
        case('gaussian-noise-rprof')
          tmp=sqrt(xx**2+yy**2+zz**2)
          call gaunoise_rprof(ampluu(j),tmp,prof,f,iux,iuz)
        case('xjump')
          call jump(f,iux,uu_left,uu_right,widthuu,'x')
          call jump(f,iuy,uy_left,uy_right,widthuu,'x')
        case('Beltrami-x'); call beltrami(ampluu(j),f,iuu,kx=kx_uu)
        case('Beltrami-y'); call beltrami(ampluu(j),f,iuu,ky=ky_uu)
        case('Beltrami-z'); call beltrami(ampluu(j),f,iuu,kz=kz_uu)
        case('rolls'); call rolls(ampluu(j),f,iuu,kx_uu,kz_uu)
        case('trilinear-x'); call trilinear(ampluu(j),f,iux,xx,yy,zz)
        case('trilinear-y'); call trilinear(ampluu(j),f,iuy,xx,yy,zz)
        case('trilinear-z'); call trilinear(ampluu(j),f,iuz,xx,yy,zz)
        case('cos-cos-sin-uz'); call cos_cos_sin(ampluu(j),f,iuz,xx,yy,zz)
        case('tor_pert'); call tor_pert(ampluu(j),f,iux,xx,yy,zz)
        case('diffrot'); call diffrot(ampluu(j),f,iuy,xx,yy,zz)
        case('centrifugal-balance','global-shear'); call centrifugal_balance(f)
        case('olddiffrot'); call olddiffrot(ampluu(j),f,iuy,xx,yy,zz)
        case('sinwave-phase')
          call sinwave_phase(f,iux,ampl_ux(j),kx_ux(j),ky_ux(j),kz_ux(j),phase_ux(j))
          call sinwave_phase(f,iuy,ampl_uy(j),kx_uy(j),ky_uy(j),kz_uy(j),phase_uy(j))
          call sinwave_phase(f,iuz,ampl_uz(j),kx_uz(j),ky_uz(j),kz_uz(j),phase_uz(j))
        case('coswave-phase')
          call coswave_phase(f,iux,ampl_ux(j),kx_ux(j),ky_ux(j),kz_ux(j),phase_ux(j))
          call coswave_phase(f,iuy,ampl_uy(j),kx_uy(j),ky_uy(j),kz_uy(j),phase_uy(j))
          call coswave_phase(f,iuz,ampl_uz(j),kx_uz(j),ky_uz(j),kz_uz(j),phase_uz(j))
        case('sinwave-x'); call sinwave(ampluu(j),f,iux,kx=kx_uu)
        case('sinwave-y'); call sinwave(ampluu(j),f,iuy,ky=ky_uu)
        case('sinwave-z'); call sinwave(ampluu(j),f,iuz,kz=kz_uu)
        case('sinwave-ux-kx'); call sinwave(ampluu(j),f,iux,kx=kx_uu)
        case('sinwave-ux-ky'); call sinwave(ampluu(j),f,iux,ky=ky_uu)
        case('sinwave-ux-kz'); call sinwave(ampluu(j),f,iux,kz=kz_uu)
        case('sinwave-uy-kx'); call sinwave(ampluu(j),f,iuy,kx=kx_uu)
        case('sinwave-uy-ky'); call sinwave(ampluu(j),f,iuy,ky=ky_uu)
        case('sinwave-uy-kz'); call sinwave(ampluu(j),f,iuy,kz=kz_uu)
        case('sinwave-uz-kx'); call sinwave(ampluu(j),f,iuz,kx=kx_uu)
        case('sinwave-uz-ky'); call sinwave(ampluu(j),f,iuz,ky=ky_uu)
        case('sinwave-uz-kz'); call sinwave(ampluu(j),f,iuz,kz=kz_uu)
        case('sinwave-y-z')
          if (lroot) print*, 'init_uu: sinwave-y-z, ampluu=', ampluu(j)
          call sinwave(ampluu(j),f,iuy,kz=kz_uu)
        case('sinwave-z-y')
          if (lroot) print*, 'init_uu: sinwave-z-y, ampluu=', ampluu(j)
          call sinwave(ampluu(j),f,iuz,ky=ky_uu)
        case('sinwave-z-x')
          if (lroot) print*, 'init_uu: sinwave-z-x, ampluu=', ampluu(j)
          call sinwave(ampluu(j),f,iuz,kx=kx_uu)
        case('damped_sinwave-z-x')
          if (lroot) print*, 'init_uu: damped_sinwave-z-x, ampluu=', ampluu(j)
          do m=m1,m2; do n=n1,n2
            f(:,m,n,iuz)=f(:,m,n,iuz)+ampluu(j)*sin(kx_uu*x)*exp(-10*z(n)**2)
          enddo; enddo
        case('coswave-x'); call coswave(ampluu(j),f,iux,kx=kx_uu)
        case('coswave-y'); call coswave(ampluu(j),f,iuy,ky=ky_uu)
        case('coswave-z'); call coswave(ampluu(j),f,iuz,kz=kz_uu)
        case('coswave-x-z'); call coswave(ampluu(j),f,iux,kz=kz_uu)
        case('coswave-z-x'); call coswave(ampluu(j),f,iuz,kx=kx_uu)
        case('x1cosycosz'); call x1_cosy_cosz(ampluu(j),f,iuy,ky=ky_uu,kz=kz_uu)
        case('couette'); call couette(ampluu(j),mu_omega,f,iuy)
        case('couette_rings'); call couette_rings(ampluu(j),mu_omega,nb_rings,om_rings,gap,f,iuy)
        case('soundwave-x'); call soundwave(ampluu(j),f,iux,kx=kx_uu)
        case('soundwave-y'); call soundwave(ampluu(j),f,iuy,ky=ky_uu)
        case('soundwave-z'); call soundwave(ampluu(j),f,iuz,kz=kz_uu)
        case('robertsflow'); call robertsflow(ampluu(j),f,iuu)
        case('hawley-et-al'); call hawley_etal99a(ampluu(j),f,iuu,widthuu,Lxyz,xx,yy,zz)
        case('sound-wave', '11')
!
!  sound wave (should be consistent with density module)
!
          if (lroot) print*,'init_uu: x-wave in uu; ampluu(j)=',ampluu(j)
          f(:,:,:,iux)=uu_const(1)+ampluu(j)*sin(kx_uu*xx)

        case('sound-wave2')
!
!  sound wave (should be consistent with density module)
!
          crit=cs20-grav_const/kx_uu**2
          if (lroot) print*,'init_uu: x-wave in uu; crit,ampluu(j)=',crit,ampluu(j)
          if (crit>0.) then
            f(:,:,:,iux)=+ampluu(j)*cos(kx_uu*xx)*sqrt(abs(crit))
          else
            f(:,:,:,iux)=-ampluu(j)*sin(kx_uu*xx)*sqrt(abs(crit))
          endif

        case('shock-tube', '13')
!
!  shock tube test (should be consistent with density module)
!
          if (lroot) print*,'init_uu: polytopic standing shock'
          prof=.5*(1.+tanh(xx/widthuu))
          f(:,:,:,iux)=uu_left+(uu_right-uu_left)*prof

        case('shock-sphere')
!
!  shock tube test (should be consistent with density module)
!
          if (lroot) print*,'init_uu: spherical shock, widthuu=',widthuu,' radiusuu=',radiusuu
         ! where (sqrt(xx**2+yy**2+zz**2) .le. widthuu)
            f(:,:,:,iux)=0.5*xx/radiusuu*ampluu(j)*(1.-tanh((sqrt(xx**2+yy**2+zz**2)-radiusuu)/widthuu))
            f(:,:,:,iuy)=0.5*yy/radiusuu*ampluu(j)*(1.-tanh((sqrt(xx**2+yy**2+zz**2)-radiusuu)/widthuu))
            f(:,:,:,iuz)=0.5*zz/radiusuu*ampluu(j)*(1.-tanh((sqrt(xx**2+yy**2+zz**2)-radiusuu)/widthuu))
         !   f(:,:,:,iuy)=yy*ampluu(j)/(widthuu)
         !   f(:,:,:,iuz)=zz*ampluu(j)/(widthuu)
            !f(:,:,:,iux)=xx/sqrt(xx**2+yy**2+zz**2)*ampluu(j)
            !f(:,:,:,iuy)=yy/sqrt(xx**2+yy**2+zz**2)*ampluu(j)
            !f(:,:,:,iuz)=zz/sqrt(xx**2+yy**2+zz**2)*ampluu(j)
         ! endwhere
!

        case('bullets')
!
!  blob-like velocity perturbations (bullets)
!
          if (lroot) print*,'init_uu: velocity blobs'
          !f(:,:,:,iux)=f(:,:,:,iux)+ampluu(j)*exp(-(xx**2+yy**2+(zz-1.)**2)/widthuu)
          f(:,:,:,iuz)=f(:,:,:,iuz)-ampluu(j)*exp(-(xx**2+yy**2+zz**2)/widthuu)

        case('Alfven-circ-x')
!
!  circularly polarised Alfven wave in x direction
!
          if (lroot) print*,'init_uu: circular Alfven wave -> x'
          f(:,:,:,iuy) = f(:,:,:,iuy) + ampluu(j)*sin(kx_uu*xx)
          f(:,:,:,iuz) = f(:,:,:,iuz) + ampluu(j)*cos(kx_uu*xx)

        case ('coszsiny-uz')
          do n=n1,n2; do m=m1,m2
            f(l1:l2,m,n,iuz)=f(l1:l2,m,n,iuz)- &
                ampluu(j)*cos(pi*z(n)/Lxyz(3))*sin(2*pi*y(m)/Lxyz(2))
          enddo; enddo

        case('linear-shear')
!
!  Linear shear
!
          if (lroot) print*,'init_uu: linear-shear, ampluu=', ampluu(j)
          do l=l1,l2; do m=m1,m2
            f(l,m,n1:n2,iuy) = ampluu(j)*z(n1:n2)
          enddo; enddo
!
        case('tanh-x-z')
          if (lroot) print*, &
              'init_uu: tanh-x-z, widthuu, ampluu=', widthuu, ampluu(j)
          do l=l1,l2; do m=m1,m2
            f(l,m,n1:n2,iux) = ampluu(j)*tanh(z(n1:n2)/widthuu)
          enddo; enddo
!
        case('tanh-y-z')
          if (lroot) print*, &
              'init_uu: tanh-y-z, widthuu, ampluu=', widthuu, ampluu(j)
          do l=l1,l2; do m=m1,m2
            f(l,m,n1:n2,iuy) = ampluu(j)*tanh(z(n1:n2)/widthuu)
          enddo; enddo
!
        case('gauss-x-z')
          if (lroot) print*, &
              'init_uu: gauss-x-z, widthuu, ampluu=', widthuu, ampluu(j)
          do l=l1,l2; do m=m1,m2
            f(l,m,n1:n2,iux) = ampluu(j)*exp(-z(n1:n2)**2/widthuu**2)
          enddo; enddo
!
        case('const-ux')
!
!  constant x-velocity
!
          if (lroot) print*,'init_uu: constant x-velocity'
          f(:,:,:,iux) = ampluu(j)

        case('const-uy')
!
!  constant y-velocity
!
          if (lroot) print*,'init_uu: constant y-velocity'
          f(:,:,:,iuy) = ampluu(j)

        case('tang-discont-z')
!
!  tangential discontinuity: velocity is directed along x,
!  ux=uu_lower for z<0 and ux=uu_upper for z>0. This can
!  be set up together with 'rho-jump' in density.
!
          if (lroot) print*,'init_uu: tangential discontinuity of uux at z=0'
          if (lroot) print*,'init_uu: uu_lower=',uu_lower,' uu_upper=',uu_upper
          if (lroot) print*,'init_uu: widthuu=',widthuu
          prof=.5*(1.+tanh(zz/widthuu))
          f(:,:,:,iux)=uu_lower+(uu_upper-uu_lower)*prof

!  Add some random noise to see the development of instability
!WD: Can't we incorporate this into the urand stuff?
          print*, 'init_uu: ampluu(j)=',ampluu(j)
          call random_number_wrapper(r)
          call random_number_wrapper(p)
!          tmp=sqrt(-2*log(r))*sin(2*pi*p)*exp(-zz**2*10.)
          tmp=exp(-zz**2*10.)*cos(2.*xx+sin(4.*xx))
          f(:,:,:,iuz)=f(:,:,:,iuz)+ampluu(j)*tmp

        case('Fourier-trunc')
!
!  truncated simple Fourier series as nontrivial initial profile
!  for convection. The corresponding stream function is
!    exp(-(z-z1)^2/(2w^2))*(cos(kk)+2*sin(kk)+3*cos(3kk)),
!    with kk=k_x*x+k_y*y
!  Not a big success (convection starts much slower than with
!  random or 'up-down') ..
!
          if (lroot) print*,'init_uu: truncated Fourier'
          prof = ampluu(j)*exp(-0.5*(zz-z1)**2/widthuu**2) ! vertical Gaussian
          tmp = kx_uu*xx + ky_uu*yy               ! horizontal phase
          kabs = sqrt(kx_uu**2+ky_uu**2)
          f(:,:,:,iuz) = prof * kabs*(-sin(tmp) + 4*cos(2*tmp) - 9*sin(3*tmp))
          tmp = (zz-z1)/widthuu**2*prof*(cos(tmp) + 2*sin(2*tmp) + 3*cos(3*tmp))
          f(:,:,:,iux) = tmp*kx_uu/kabs
          f(:,:,:,iuy) = tmp*ky_uu/kabs

        case('up-down')
!
!  flow upwards in one spot, downwards in another; not soneloidal
!
          if (lroot) print*,'init_uu: up-down'
          prof = ampluu(j)*exp(-0.5*(zz-z1)**2/widthuu**2) ! vertical profile
          tmp = sqrt((xx-(x0+0.3*Lx))**2+(yy-(y0+0.3*Ly))**2)! dist. from spot 1
          f(:,:,:,iuz) = prof*exp(-0.5*(tmp**2)/widthuu**2)
          tmp = sqrt((xx-(x0+0.5*Lx))**2+(yy-(y0+0.8*Ly))**2)! dist. from spot 1
          f(:,:,:,iuz) = f(:,:,:,iuz) - 0.7*prof*exp(-0.5*(tmp**2)/widthuu**2)

        case('powern')
! initial spectrum k^power
          call powern(ampluu(j),initpower,cutoff,f,iux,iuz)

        case('power_randomphase')
! initial spectrum k^power
          call power_randomphase(ampluu(j),initpower,cutoff,f,iux,iuz)

        case('random-isotropic-KS')
          call random_isotropic_KS(ampluu(j),initpower,cutoff,f,iux,iuz,N_modes_uu)

        case('vortex_2d')
! Vortex solution of Goodman, Narayan, & Goldreich (1987)
          call vortex_2d(f,xx,yy,b_ell,widthuu,rbound)

        case('sub-Keplerian')
          if (lroot) print*, 'init_hydro: set sub-Keplerian gas velocity'
          f(:,:,:,iux) = -1/(2*Omega)*cs20*beta_glnrho_scaled(2)
          f(:,:,:,iuy) = 1/(2*Omega)*cs20*beta_glnrho_scaled(1)

        case('compressive-shwave')
! compressive (non-vortical) shear wave of Johnson & Gammie (2005a)
          call coswave_phase(f,iux,ampl_ux(i),kx_ux(i),ky_ux(i),kz_ux(i),phase_ux(i))
          call coswave_phase(f,iuy,ampl_uy(i),kx_uy(i),ky_uy(i),kz_uy(i),phase_uy(i))
          eta_sigma = (2. - qshear)*Omega
          do m=m1,m2; do n=n1,n2
            f(l1:l2,m,n,ilnrho) = -kx_ux(i)*ampl_uy(i)*eta_sigma* & 
                (cos(kx_ux(i)*x(l1:l2)+ky_ux(i)*y(m)+kz_ux(i)*z(n)) + &
                sin(kx_uy(i)*x(l1:l2)+ky_uy(i)*y(m)+kz_uy(i)*z(n)))
          enddo; enddo
        case default
          !
          !  Catch unknown values
          !
          if (lroot) print*, 'init_uu: No such value for inituu: ', &
            trim(inituu(j))
          call stop_it("")

        endselect
!
!  End loop over initial conditions
!
      enddo
!
!  This allows an extra random velocity perturbation on
!  top of the initialization so far.
!
      if (urand /= 0) then
        if (lroot) print*, 'init_uu: Adding random uu fluctuations'
        if (urand > 0) then
          do i=iux,iuz
            call random_number_wrapper(tmp)
            f(:,:,:,i) = f(:,:,:,i) + urand*(tmp-0.5)
          enddo
        else
          if (lroot) print*, 'init_uu:  ... multiplicative fluctuations'
          do i=iux,iuz
            call random_number_wrapper(tmp)
            f(:,:,:,i) = f(:,:,:,i) * urand*(tmp-0.5)
          enddo
        endif
      endif

! mgellert, add random fluctuation only inside domain, not on boundary 
!           (to be able to use the 'freeze' option for BCs)
      if (urandi /= 0) then
        if (lroot) print*, 'init_uu: Adding random uu fluctuations (not on boundary), urandi=',urandi
        if (urandi > 0) then
          do i=iux,iuz
            call random_number_wrapper(tmp)
            f(l1+1:l2-1,m1:m2,n1+1:n2-1,i) = f(l1+1:l2-1,m1:m2,n1+1:n2-1,i) + urandi*(tmp(l1+1:l2-1,m1:m2,n1+1:n2-1)-0.5)
          enddo
        else
          if (lroot) print*, 'init_uu:  ... multiplicative fluctuations (not on boundary)'
          do i=iux,iuz
            call random_number_wrapper(tmp)
            f(l1:l2,m1:m2,n1:n2,i) = f(l1:l2,m1:m2,n1:n2,i) * urandi*(tmp(l1:l2,m1:m2,n1:n2)-0.5)
          enddo
        endif
      endif

!
!     if (NO_WARN) print*,yy,zz !(keep compiler from complaining)
!
    endsubroutine init_uu
!***********************************************************************
    subroutine pencil_criteria_hydro()
!
!  All pencils that the Hydro module depends on are specified here.
!
!  20-11-04/anders: coded
!
      use Cdata
!
      if (ladvection_velocity) lpenc_requested(i_ugu)=.true.
      if (lprecession) lpenc_requested(i_rr)=.true.
      if (ldt) lpenc_requested(i_uu)=.true.
      if (Omega/=0.0) lpenc_requested(i_uu)=.true.
!
      if (tdamp/=0.or.dampuext/=0.or.dampuint/=0) then
        lpenc_requested(i_r_mn)=.true.
        if (lcylinder_in_a_box) lpenc_requested(i_rcyl_mn)=.true.
      endif
!
      if ( borderuu=='global-shear'      .or. &
           borderuu=='global-shear-mhs') then
        lpenc_requested(i_rcyl_mn)     =.true.
        lpenc_requested(i_rcyl_mn1)    =.true.
        lpenc_requested(i_phix)        =.true.
        lpenc_requested(i_phiy)        =.true.
      endif
!
!  1/rho needed for correcting the damping term
!
      if (tau_damp_ruxm/=0..or.tau_damp_ruym/=0..or.tau_damp_ruzm/=0.) &
        lpenc_requested(i_rho1)=.true.
!
!  video pencils
!
      if (dvid/=0.) then
        lpenc_video(i_oo)=.true.
        lpenc_video(i_o2)=.true.
        lpenc_video(i_u2)=.true.
      endif
!
!  diagnostic pencils
!
      lpenc_diagnos(i_uu)=.true.
      if (idiag_oumphi/=0) lpenc_diagnos2d(i_ou)=.true.
      if (idiag_ozmphi/=0) lpenc_diagnos2d(i_oo)=.true.
      if (idiag_u2mphi/=0) lpenc_diagnos2d(i_u2)=.true.
      if (idiag_ox2m/=0 .or. idiag_oy2m/=0 .or. idiag_oz2m/=0 .or. &
          idiag_oxm /=0 .or. idiag_oym /=0 .or. idiag_ozm /=0 .or. &
          idiag_oxoym/=0 .or. idiag_oxozm/=0 .or. idiag_oyozm/=0) &
          lpenc_diagnos(i_oo)=.true.
      if (idiag_orms/=0 .or. idiag_omax/=0 .or. idiag_o2m/=0) &
          lpenc_diagnos(i_o2)=.true.
      if (idiag_oum/=0 .or. idiag_oumx/=0.or.idiag_oumy/=0.or.idiag_oumz/=0) &
          lpenc_diagnos(i_ou)=.true.
      if (idiag_Marms/=0 .or. idiag_Mamax/=0) lpenc_diagnos(i_Ma2)=.true.
      if (idiag_u3u21m/=0) lpenc_diagnos(i_u3u21)=.true.
      if (idiag_u1u32m/=0) lpenc_diagnos(i_u1u32)=.true.
      if (idiag_u2u13m/=0) lpenc_diagnos(i_u2u13)=.true.
      if (idiag_urms/=0 .or. idiag_umax/=0 .or. idiag_rumax/=0 .or. &
          idiag_u2m/=0 .or. idiag_um2/=0 .or. idiag_u2mz/=0) &
          lpenc_diagnos(i_u2)=.true.
      if (idiag_duxdzma/=0 .or. idiag_duydzma/=0) lpenc_diagnos(i_uij)=.true.
      if (idiag_fmassz/=0 .or. idiag_ruxuym/=0 .or. idiag_ruxuymz/=0 .or. &
          idiag_ruxm/=0 .or. idiag_ruym/=0 .or. idiag_ruzm/=0) &
          lpenc_diagnos(i_rho)=.true.

      if (idiag_ormr/=0 .or. idiag_opmr/=0 .or. idiag_ozmr/=0) &
          lpenc_diagnos(i_oo)=.true.

      if (idiag_totangmom/=0 ) lpenc_diagnos(i_rcyl_mn)=.true.

      if (idiag_urmr/=0 .or.  idiag_ormr/=0) then
        lpenc_diagnos(i_pomx)=.true.
        lpenc_diagnos(i_pomy)=.true.
      endif

      if (idiag_upmr/=0 .or. idiag_opmr/=0) then
        lpenc_diagnos(i_phix)=.true.
        lpenc_diagnos(i_phiy)=.true.
      endif

      if (idiag_ekin/=0 .or. idiag_ekintot/=0 .or. idiag_fkinz/=0 .or. &
          idiag_ekinz/=0) then
        lpenc_diagnos(i_rho)=.true.
        lpenc_diagnos(i_u2)=.true.
      endif
!
      if (lisotropic_advection) lpenc_requested(i_u2)=.true.
!
    endsubroutine pencil_criteria_hydro
!***********************************************************************
    subroutine pencil_interdep_hydro(lpencil_in)
!
!  Interdependency among pencils from the Hydro module is specified here.
!
!  20-nov-04/anders: coded
!
      use Cdata, only: lcartesian_coords
!
      logical, dimension(npencils) :: lpencil_in
!
      if (lpencil_in(i_u2)) lpencil_in(i_uu)=.true.
      if (lpencil_in(i_divu)) lpencil_in(i_uij)=.true.
      if (lalways_use_gij_etc.and..not.lcartesian_coords) &
        lpencil_in(i_oo)=.true.
      if (lpencil_in(i_sij)) then
        lpencil_in(i_uij)=.true.
        lpencil_in(i_divu)=.true.
      endif
      if (lpencil_in(i_oo)) lpencil_in(i_uij)=.true.
      if (lpencil_in(i_o2)) lpencil_in(i_oo)=.true.
      if (lpencil_in(i_ou)) then
        lpencil_in(i_uu)=.true.
        lpencil_in(i_oo)=.true.
      endif
      if (lpencil_in(i_ugu)) then
        lpencil_in(i_uu)=.true.
        lpencil_in(i_uij)=.true.
      endif
      if (lpencil_in(i_u3u21) .or. &
          lpencil_in(i_u1u32) .or. &
          lpencil_in(i_u2u13)) then
        lpencil_in(i_uu)=.true.
        lpencil_in(i_uij)=.true.
      endif
      if (lpencil_in(i_sij2)) lpencil_in(i_sij)=.true.
!
    endsubroutine pencil_interdep_hydro
!***********************************************************************
    subroutine calc_pencils_hydro(f,p)
!
!  Calculate Hydro pencils.
!  Most basic pencils should come first, as others may depend on them.
!
!  08-nov-04/tony: coded
!  26-mar-07/axel: started using the gij_etc routine
!
      use Cdata
      use Deriv
      use Sub
!Dhruba
use Mpicomm, only: stop_it
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      real, dimension (nx) :: tmp, tmp2
      integer :: i, j, ju
!
      intent(in) :: f
      intent(inout) :: p
! uu
      if (lpencil(i_uu)) p%uu=f(l1:l2,m,n,iux:iuz)
! u2
      if (lpencil(i_u2)) then
        call dot2_mn(p%uu,p%u2)
      endif
!
!  calculate uij and divu, if requested
!
      if (lpencil(i_uij)) call gij(f,iuu,p%uij,1)
      if (lpencil(i_divu)) call div_mn(p%uij,p%divu,p%uu)
!
!  calculate the strain tensor sij, if requested
!
      if (lpencil(i_sij)) then
        do j=1,3
          do i=1,3
            p%sij(:,i,j)=.5*(p%uij(:,i,j)+p%uij(:,j,i))
          enddo
          p%sij(:,j,j)=p%sij(:,j,j)-(1./3.)*p%divu
        enddo
        if (lspherical_coords) then
! p%sij(:,1,1) remains unchanged in spherical coordinates  
          p%sij(:,1,2)=p%sij(:,1,2)-.5*r1_mn*p%uu(:,2)
          p%sij(:,1,3)=p%sij(:,1,3)-.5*r1_mn*p%uu(:,3)
          p%sij(:,2,1)=p%sij(:,1,2)
          p%sij(:,2,2)=p%sij(:,2,2)+r1_mn*p%uu(:,1) 
          p%sij(:,2,3)=p%sij(:,2,3)-.5*r1_mn*cotth(m)*p%uu(:,3)
          p%sij(:,1,3)=p%sij(:,3,1)
          p%sij(:,2,3)=p%sij(:,2,3)
          p%sij(:,3,3)=p%sij(:,3,3)+r1_mn*p%uu(:,1)+cotth(m)*r1_mn*p%uu(:,2) 
        elseif (lcylindrical_coords) then
          p%sij(:,1,2)=p%sij(:,1,2)-.5*rcyl_mn1*p%uu(:,2)
          p%sij(:,2,2)=p%sij(:,2,2)+.5*rcyl_mn1*p%uu(:,1)
          p%sij(:,2,1)=p%sij(:,1,2)
        endif
        if (lshear) then
          if (lshear_rateofstrain) then
            p%sij(:,1,2)=p%sij(:,1,2)+Sshear
            p%sij(:,2,1)=p%sij(:,2,1)+Sshear
          endif
        endif
      endif
! sij2
      if (lpencil(i_sij2)) call multm2_mn(p%sij,p%sij2)
! uij5
      if (lpencil(i_uij5)) call gij(f,iuu,p%uij5,5)
!
! oo (=curlu)
!
      if (lpencil(i_oo)) then
        call curl_mn(p%uij,p%oo,p%uu)
      endif
! o2
      if (lpencil(i_o2)) call dot2_mn(p%oo,p%o2)
! ou
      if (lpencil(i_ou)) call dot_mn(p%oo,p%uu,p%ou)
! Dhruba
      if(loutest.and.lpencil(i_ou))then
!      write(*,*) lpencil(i_ou)
        outest = minval(p%ou)
        if(outest.lt.(-1.0d-8))then
          write(*,*) m,n,outest,maxval(p%ou),lpencil(i_ou)
          write(*,*)'WARNING : hydro:ou has different sign than relhel'
        else
        endif
      else
      endif 
! ugu
      if (lpencil(i_ugu)) then
        if (headtt.and.lupw_uu) then
          print *,'calc_pencils_hydro: upwinding advection term. '//&
                  'Not well tested; use at own risk!'
        endif
        call u_dot_grad(f,iuu,p%uij,p%uu,p%ugu,UPWIND=lupw_uu)
      endif
!
! u3u21, u1u32, u2u13
!
      if (lpencil(i_u3u21)) p%u3u21=p%uu(:,3)*p%uij(:,2,1)
      if (lpencil(i_u1u32)) p%u1u32=p%uu(:,1)*p%uij(:,3,2)
      if (lpencil(i_u2u13)) p%u2u13=p%uu(:,2)*p%uij(:,1,3)
!
! del4u and del6u
!
      if (lpencil(i_del4u)) call del4v(f,iuu,p%del4u)
      if (lpencil(i_del6u)) call del6v(f,iuu,p%del6u)
!
! del6u_bulk
!
      if (lpencil(i_del6u_bulk)) then
        call der6(f,iux,tmp,1)
        p%del6u_bulk(:,1)=tmp
        call der6(f,iuy,tmp,2)
        p%del6u_bulk(:,2)=tmp
        call der6(f,iuz,tmp,3)
        p%del6u_bulk(:,3)=tmp
      endif
!
! del2u
! graddivu
!
      if (lspherical_coords.or.lalways_use_gij_etc) then
        if (headtt.or.ldebug) print*,'calc_pencils_hydro: call gij_etc'
        call gij_etc(f,iuu,p%uu,p%uij,p%oij,GRADDIV=p%graddivu)
        call curl_mn(p%oij,p%qq,p%oo)
        if (lpencil(i_del2u)) p%del2u=p%graddivu-p%qq
!
!   Avoid warnings from pencil consistency check...
!
        if (.not. lpencil(i_uij)) p%uij=0.0
        if (.not. lpencil(i_graddivu)) p%graddivu=0.0
      else
        if (lpencil(i_del2u)) then
          if (lpencil(i_graddivu)) then
            call del2v_etc(f,iuu,DEL2=p%del2u,GRADDIV=p%graddivu)
          else
             call del2v(f,iuu,p%del2u)
          endif
        else
        endif
         if (lpencil(i_graddivu)) call del2v_etc(f,iuu,GRADDIV=p%graddivu)
      endif
!
! grad5divu
!
      if (lpencil(i_grad5divu)) then
        do i=1,3
          tmp=0.0
          do j=1,3
            ju=iuu+j-1
            call der5i1j(f,ju,tmp2,i,j)
            tmp=tmp+tmp2
          enddo
          p%grad5divu(:,i)=tmp
        enddo
      endif
!
    endsubroutine calc_pencils_hydro
!***********************************************************************
    subroutine duu_dt(f,df,p)
!
!  velocity evolution
!  calculate du/dt = - u.gradu - 2Omega x u + grav + Fvisc
!  pressure gradient force added in density and entropy modules.
!
!   7-jun-02/axel: incoporated from subroutine pde
!  10-jun-02/axel+mattias: added Coriolis force
!  23-jun-02/axel: glnrho and fvisc are now calculated in here
!  17-jun-03/ulf: ux2, uy2 and uz2 added as diagnostic quantities
!  27-jun-07/dhruba: differential rotation as subroutine call
!
      use Cdata
      use Sub
      use IO
      use Mpicomm, only: stop_it
      use Special, only: special_calc_hydro
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      real, dimension (nx) :: space_part_re,space_part_im,u2t
      real :: c2,s2,kx
      integer :: j
!
      intent(in) :: f,p
      intent(out) :: df
!
!  identify module and boundary conditions
!
      if (headtt.or.ldebug) print*,'duu_dt: SOLVE'
      if (headtt) then
        call identify_bcs('ux',iux)
        call identify_bcs('uy',iuy)
        call identify_bcs('uz',iuz)
      endif
!
!  advection term, -u.gradu
!
      if (ladvection_velocity) &
        df(l1:l2,m,n,iux:iuz)=df(l1:l2,m,n,iux:iuz)-p%ugu
!
!  Coriolis force, -2*Omega x u (unless lprecession=T)
!  Omega=(-sin_theta, 0, cos_theta), where theta corresponds to
!  colatitude. theta=0 places the box to the north pole and theta=90
!  the equator. Cartesian coordinates (x,y,z) now correspond to
!  (theta,phi,r) i.e. (south,east,up), in spherical polar coordinates
!
      if (Omega/=0.) then
        if (lcylindrical_coords) then
          call coriolis_cylindrical(df,p)
        elseif (lspherical_coords) then
          call coriolis_spherical(df,p)
        elseif (lprecession) then
          call precession(df,p)
        else
          if (theta==0) then
            if (lcoriolis_force) then
              if (headtt) print*,'duu_dt: add Coriolis force; Omega=',Omega
              c2=2*Omega
              df(l1:l2,m,n,iux)=df(l1:l2,m,n,iux)+c2*p%uu(:,2)
              df(l1:l2,m,n,iuy)=df(l1:l2,m,n,iuy)-c2*p%uu(:,1)
!
!  add centrifugal force (doing this with periodic boundary
!  conditions in x and y would not be compatible, so it is
!  therefore usually ignored in those cases!)
!
            endif
            if (lcentrifugal_force) then
              if (headtt) print*,'duu_dt: add Centrifugal force; Omega=',Omega
              df(l1:l2,m,n,iux)=df(l1:l2,m,n,iux)+x(l1:l2)*Omega**2
              df(l1:l2,m,n,iuy)=df(l1:l2,m,n,iuy)+y(  m  )*Omega**2
            endif
          else
!
!  add Coriolis force with an angle (defined such that theta=60,
!  for example, would correspond to 30 degrees latitude).
!  Omega=(-sin_theta, 0, cos_theta).
!
            if (lcoriolis_force) then
              if (headtt) &
                  print*,'duu_dt: Coriolis force; Omega, theta=', Omega, theta
              c2= 2*Omega*cos(theta*pi/180.)
              s2=-2*Omega*sin(theta*pi/180.)
              df(l1:l2,m,n,iux)=df(l1:l2,m,n,iux)+c2*p%uu(:,2)
              df(l1:l2,m,n,iuy)=df(l1:l2,m,n,iuy)-c2*p%uu(:,1)+s2*p%uu(:,3)
              df(l1:l2,m,n,iuz)=df(l1:l2,m,n,iuz)             -s2*p%uu(:,2)
            endif
          endif
        endif
      endif
!
! calculate viscous force
!
      if (lviscosity) call calc_viscous_force(df,p)
!
!  ``uu/dx'' for timestep
!
      if (lfirst.and.ldt.and.ladvection_velocity) then 
        if      (lspherical_coords) then 
          advec_uu=abs(p%uu(:,1))*dx_1(l1:l2)+ &
                   abs(p%uu(:,2))*dy_1(  m  )*r1_mn+ &
                   abs(p%uu(:,3))*dz_1(  n  )*r1_mn*sin1th(m)
        elseif (lcylindrical_coords) then
          advec_uu=abs(p%uu(:,1))*dx_1(l1:l2)+ &
                   abs(p%uu(:,2))*dy_1(  m  )*rcyl_mn1+ &
                   abs(p%uu(:,3))*dz_1(  n  )
        else
          advec_uu=abs(p%uu(:,1))*dx_1(l1:l2)+ &
                   abs(p%uu(:,2))*dy_1(  m  )+ &
                   abs(p%uu(:,3))*dz_1(  n  )
        endif
      endif
!
!WL: don't know if this is correct, but it's the only way I can make
!    some 1D and 2D samples work when the non-existent direction has the
!    largest velocity (like a 2D rz slice of a Keplerian disk that rotates 
!    on the phi direction)
!    Please check
!
      if (lisotropic_advection) then
         if (lfirst.and.ldt) then
            if ((nxgrid==1).or.(nygrid==1).or.(nzgrid==1)) &
                 advec_uu=sqrt(p%u2*dxyz_2)
         endif
      endif
      if (headtt.or.ldebug) print*,'duu_dt: max(advec_uu) =',maxval(advec_uu)
!
!  add possibility of forcing that is not delta-correlated in time
!
      if (lforcing_cont_uu) &
        df(l1:l2,m,n,iux:iuz)=df(l1:l2,m,n,iux:iuz)+p%fcont
!
!  damp motions in some regions for some time spans if desired
!  for geodynamo: addition of dampuint evaluation
!
      if (tdamp/=0.or.dampuext/=0.or.dampuint/=0) call udamping(f,df,p)
!
!  adding differential rotation via a frictional term
!
      if (tau_diffrot1/=0) then
       call impose_profile_diffrot(f,df,uuprof,ldiffrot_test)
      else
      endif
!
!  Possibility to damp mean x momentum, ruxm, to zero.
!  This can be useful in situations where a mean flow is generated.
!  This tends to be the case when there is linear shear but no rotation
!  and the turbulence is forced. A constant drift velocity in the
!  x-direction is most dangerous, because it leads to a linear increase
!  of <uy> due to the shear term. If there is rotation, the epicyclic
!  motion brings one always back to no mean flow on the average.
!
      if (tau_damp_ruxm/=0.) &
        df(l1:l2,m,n,iux)=df(l1:l2,m,n,iux)-ruxm*p%rho1*tau_damp_ruxm1
      if (tau_damp_ruym/=0.) &
        df(l1:l2,m,n,iuy)=df(l1:l2,m,n,iuy)-ruym*p%rho1*tau_damp_ruym1
      if (tau_damp_ruzm/=0.) &
        df(l1:l2,m,n,iuz)=df(l1:l2,m,n,iuz)-ruzm*p%rho1*tau_damp_ruzm1
!
!  interface for your personal subroutines calls
!
      if (lspecial) call special_calc_hydro(f,df,p)
!
!  Apply border profiles
!
      if (lborder_profiles) call set_border_hydro(f,df,p)
!
!  write slices for output in wvid in run.f90
!  This must be done outside the diagnostics loop (accessed at different times).
!  Note: ix is the index with respect to array with ghost zones.
!
      if(lvid.and.lfirst) then
        divu_yz(m-m1+1,n-n1+1)=p%divu(ix_loc-l1+1)
        if (m.eq.iy_loc)  divu_xz(:,n-n1+1)=p%divu
        if (n.eq.iz_loc)  divu_xy(:,m-m1+1)=p%divu
        if (n.eq.iz2_loc) divu_xy2(:,m-m1+1)=p%divu
        do j=1,3
          oo_yz(m-m1+1,n-n1+1,j)=p%oo(ix_loc-l1+1,j)
          if (m==iy_loc)  oo_xz(:,n-n1+1,j)=p%oo(:,j)
          if (n==iz_loc)  oo_xy(:,m-m1+1,j)=p%oo(:,j)
          if (n==iz2_loc) oo_xy2(:,m-m1+1,j)=p%oo(:,j)
        enddo
        u2_yz(m-m1+1,n-n1+1)=p%u2(ix_loc-l1+1)
        if (m==iy_loc)  u2_xz(:,n-n1+1)=p%u2
        if (n==iz_loc)  u2_xy(:,m-m1+1)=p%u2
        if (n==iz2_loc) u2_xy2(:,m-m1+1)=p%u2
        o2_yz(m-m1+1,n-n1+1)=p%o2(ix_loc-l1+1)
        if (m==iy_loc)  o2_xz(:,n-n1+1)=p%o2
        if (n==iz_loc)  o2_xy(:,m-m1+1)=p%o2
        if (n==iz2_loc) o2_xy2(:,m-m1+1)=p%o2
        if(othresh_per_orms/=0) call calc_othresh
        call vecout(41,trim(directory)//'/ovec',p%oo,othresh,novec)
      endif
!
!  Calculate maxima and rms values for diagnostic purposes
!
      if (ldiagnos) then
        if (headtt.or.ldebug) print*,'duu_dt: Calculate maxima and rms values...'
        if (idiag_dtu/=0) call max_mn_name(advec_uu/cdt,idiag_dtu,l_dt=.true.)
        if (idiag_urms/=0)   call sum_mn_name(p%u2,idiag_urms,lsqrt=.true.)
        if (idiag_umax/=0)   call max_mn_name(p%u2,idiag_umax,lsqrt=.true.)
        if (idiag_uzrms/=0) &
            call sum_mn_name(p%uu(:,3)**2,idiag_uzrms,lsqrt=.true.)
        if (idiag_uzrmaxs/=0) &
            call max_mn_name(p%uu(:,3)**2,idiag_uzrmaxs,lsqrt=.true.)
        if (idiag_uxmax/=0) call max_mn_name(p%uu(:,1),idiag_uxmax)
        if (idiag_uymax/=0) call max_mn_name(p%uu(:,2),idiag_uymax)
        if (idiag_uzmax/=0) call max_mn_name(p%uu(:,3),idiag_uzmax)
        if (idiag_rumax/=0) call max_mn_name(p%u2*p%rho**2,idiag_rumax,lsqrt=.true.)
!
!  integrate velocity in time, to calculate correlation time later
!
        if (idiag_u2tm/=0) then
          if (iuut==0) call stop_it("Cannot calculate u2tm if iuut==0")
          call dot(p%uu,f(l1:l2,m,n,iuxt:iuzt),u2t)
          call sum_mn_name(u2t,idiag_u2tm)
        endif
        if (idiag_u2m/=0)     call sum_mn_name(p%u2,idiag_u2m)
        if (idiag_um2/=0)     call max_mn_name(p%u2,idiag_um2)
        if (idiag_divum/=0)   call sum_mn_name(p%divu,idiag_divum)
        if (idiag_divu2m/=0)  call sum_mn_name(p%divu**2,idiag_divu2m)
        if (idiag_uxm/=0)     call sum_mn_name(p%uu(:,1),idiag_uxm)
        if (idiag_uym/=0)     call sum_mn_name(p%uu(:,2),idiag_uym)
        if (idiag_uzm/=0)     call sum_mn_name(p%uu(:,3),idiag_uzm)
        if (idiag_ux2m/=0)    call sum_mn_name(p%uu(:,1)**2,idiag_ux2m)
        if (idiag_uy2m/=0)    call sum_mn_name(p%uu(:,2)**2,idiag_uy2m)
        if (idiag_uz2m/=0)    call sum_mn_name(p%uu(:,3)**2,idiag_uz2m)
        if (idiag_uxuym/=0)   call sum_mn_name(p%uu(:,1)*p%uu(:,2),idiag_uxuym)
        if (idiag_uxuzm/=0)   call sum_mn_name(p%uu(:,1)*p%uu(:,3),idiag_uxuzm)
        if (idiag_uyuzm/=0)   call sum_mn_name(p%uu(:,2)*p%uu(:,3),idiag_uyuzm)
        if (idiag_ruxuym/=0)  call sum_mn_name(p%rho*p%uu(:,1)*p%uu(:,2),idiag_ruxuym)
        if (idiag_duxdzma/=0) call sum_mn_name(abs(p%uij(:,1,3)),idiag_duxdzma)
        if (idiag_duydzma/=0) call sum_mn_name(abs(p%uij(:,2,3)),idiag_duydzma)
!
        if (idiag_ekin/=0)  call sum_mn_name(.5*p%rho*p%u2,idiag_ekin)
        if (idiag_ekintot/=0) &
            call integrate_mn_name(.5*p%rho*p%u2,idiag_ekintot)
        if (idiag_totangmom/=0) &
             call sum_lim_mn_name(p%rho*(p%uu(:,2)*x(l1:l2)-p%uu(:,1)*y(m)),&
             idiag_totangmom,p)
!
!  kinetic field components at one point (=pt)
!
        if (lroot.and.m==mpoint.and.n==npoint) then
          if (idiag_uxpt/=0) call save_name(p%uu(lpoint-nghost,1),idiag_uxpt)
          if (idiag_uypt/=0) call save_name(p%uu(lpoint-nghost,2),idiag_uypt)
          if (idiag_uzpt/=0) call save_name(p%uu(lpoint-nghost,3),idiag_uzpt)
        endif
        if (idiag_u2mz/=0)  call zsum_mn_name_xy(p%u2,idiag_u2mz)
!
!  mean momenta
!
        if (idiag_ruxm/=0) call sum_mn_name(p%rho*p%uu(:,1),idiag_ruxm)
        if (idiag_ruym/=0) call sum_mn_name(p%rho*p%uu(:,2),idiag_ruym)
        if (idiag_ruzm/=0) call sum_mn_name(p%rho*p%uu(:,3),idiag_ruzm)
!
!  things related to vorticity
!
        if (idiag_oum/=0) call sum_mn_name(p%ou,idiag_oum)
        if (idiag_orms/=0) call sum_mn_name(p%o2,idiag_orms,lsqrt=.true.)
        if (idiag_omax/=0) call max_mn_name(p%o2,idiag_omax,lsqrt=.true.)
        if (idiag_o2m/=0)  call sum_mn_name(p%o2,idiag_o2m)
        if (idiag_ox2m/=0) call sum_mn_name(p%oo(:,1)**2,idiag_ox2m)
        if (idiag_oy2m/=0) call sum_mn_name(p%oo(:,2)**2,idiag_oy2m)
        if (idiag_oz2m/=0) call sum_mn_name(p%oo(:,3)**2,idiag_oz2m)
        if (idiag_oxm /=0) call sum_mn_name(p%oo(:,1)   ,idiag_oxm)
        if (idiag_oym /=0) call sum_mn_name(p%oo(:,2)   ,idiag_oym)
        if (idiag_ozm /=0) call sum_mn_name(p%oo(:,3)   ,idiag_ozm)
        if (idiag_oxoym/=0) call sum_mn_name(p%oo(:,1)*p%oo(:,2),idiag_oxoym)
        if (idiag_oxozm/=0) call sum_mn_name(p%oo(:,1)*p%oo(:,3),idiag_oxozm)
        if (idiag_oyozm/=0) call sum_mn_name(p%oo(:,2)*p%oo(:,3),idiag_oyozm)
!
!  Mach number, rms and max
!
        if (idiag_Marms/=0) call sum_mn_name(p%Ma2,idiag_Marms,lsqrt=.true.)
        if (idiag_Mamax/=0) call max_mn_name(p%Ma2,idiag_Mamax,lsqrt=.true.)
!
!  alp11=<u3*u2,1>,  alp22=<u1*u3,2>,  alp33=<u2*u1,3>
!
        if (idiag_u3u21m/=0) call sum_mn_name(p%u3u21,idiag_u3u21m)
        if (idiag_u1u32m/=0) call sum_mn_name(p%u1u32,idiag_u1u32m)
        if (idiag_u2u13m/=0) call sum_mn_name(p%u2u13,idiag_u2u13m)
!
! fourier amplitude f(t) for non-axisymmetric waves: 
!         u_x = f(t)*exp[i(kx*x+ky*y+kz*z)]
!
        if (idiag_uxfampm/=0 .or. idiag_uyfampm/=0 .or. idiag_uzfampm/=0 .or.&
            idiag_uxfampim/=0 .or. idiag_uxfampim/=0 .or. idiag_uzfampim/=0) then
          kx = kx_uu + qshear*Omega*ky_uu*t
          space_part_re = cos(kx*x(l1:l2)+ky_uu*y(m)+kz_uu*z(n)) 
          space_part_im = -sin(kx*x(l1:l2)+ky_uu*y(m)+kz_uu*z(n)) 
        endif
!
        if(idiag_uxfampm/=0) &
            call sum_mn_name(p%uu(:,1)*space_part_re,idiag_uxfampm)
        if(idiag_uyfampm/=0) &
            call sum_mn_name(p%uu(:,2)*space_part_re,idiag_uyfampm)
        if(idiag_uzfampm/=0) &
            call sum_mn_name(p%uu(:,3)*space_part_re,idiag_uzfampm)
        if(idiag_uxfampim/=0) &
            call sum_mn_name(p%uu(:,1)*space_part_im,idiag_uxfampim)
        if(idiag_uyfampim/=0) &
            call sum_mn_name(p%uu(:,2)*space_part_im,idiag_uyfampim)
        if(idiag_uzfampim/=0) &
            call sum_mn_name(p%uu(:,3)*space_part_im,idiag_uzfampim)
!
      endif
!
!  1d-averages. Happens at every it1d timesteps, NOT at every it1
!
      if (l1ddiagnos) then
        if (idiag_fmassz/=0) call xysum_mn_name_z(p%rho*p%uu(:,3),idiag_fmassz)
        if (idiag_fkinz/=0)  call xysum_mn_name_z(.5*p%rho*p%u2*p%uu(:,3),idiag_fkinz)
        if (idiag_uxmz/=0)   call xysum_mn_name_z(p%uu(:,1),idiag_uxmz)
        if (idiag_uymz/=0)   call xysum_mn_name_z(p%uu(:,2),idiag_uymz)
        if (idiag_uzmz/=0)   call xysum_mn_name_z(p%uu(:,3),idiag_uzmz)
        if (idiag_uxmy/=0)   call xzsum_mn_name_y(p%uu(:,1),idiag_uxmy)
        if (idiag_uymy/=0)   call xzsum_mn_name_y(p%uu(:,2),idiag_uymy)
        if (idiag_uzmy/=0)   call xzsum_mn_name_y(p%uu(:,3),idiag_uzmy)
        if (idiag_uxmx/=0)   call yzsum_mn_name_x(p%uu(:,1),idiag_uxmx)
        if (idiag_uymx/=0)   call yzsum_mn_name_x(p%uu(:,2),idiag_uymx)
        if (idiag_uzmx/=0)   call yzsum_mn_name_x(p%uu(:,3),idiag_uzmx)
        if (idiag_ux2mz/=0)  call xysum_mn_name_z(p%uu(:,1)**2,idiag_ux2mz)
        if (idiag_uy2mz/=0)  call xysum_mn_name_z(p%uu(:,2)**2,idiag_uy2mz)
        if (idiag_uz2mz/=0)  call xysum_mn_name_z(p%uu(:,3)**2,idiag_uz2mz)
        if (idiag_ux2my/=0)  call xzsum_mn_name_y(p%uu(:,1)**2,idiag_ux2my)
        if (idiag_uy2my/=0)  call xzsum_mn_name_y(p%uu(:,2)**2,idiag_uy2my)
        if (idiag_uz2my/=0)  call xzsum_mn_name_y(p%uu(:,3)**2,idiag_uz2my)
        if (idiag_ux2mx/=0)  call yzsum_mn_name_x(p%uu(:,1)**2,idiag_ux2mx)
        if (idiag_uy2mx/=0)  call yzsum_mn_name_x(p%uu(:,2)**2,idiag_uy2mx)
        if (idiag_uz2mx/=0)  call yzsum_mn_name_x(p%uu(:,3)**2,idiag_uz2mx)
        if (idiag_uxuymz/=0) call xysum_mn_name_z(p%uu(:,1)*p%uu(:,2),idiag_uxuymz)
        if (idiag_uxuzmz/=0) call xysum_mn_name_z(p%uu(:,1)*p%uu(:,3),idiag_uxuzmz)
        if (idiag_uyuzmz/=0) call xysum_mn_name_z(p%uu(:,2)*p%uu(:,3),idiag_uyuzmz)
        if (idiag_ruxuymz/=0) &
          call xysum_mn_name_z(p%rho*p%uu(:,1)*p%uu(:,2),idiag_ruxuymz)
        if (idiag_uxuymy/=0) call xzsum_mn_name_y(p%uu(:,1)*p%uu(:,2),idiag_uxuymy)
        if (idiag_uxuzmy/=0) call xzsum_mn_name_y(p%uu(:,1)*p%uu(:,3),idiag_uxuzmy)
        if (idiag_uyuzmy/=0) call xzsum_mn_name_y(p%uu(:,2)*p%uu(:,3),idiag_uyuzmy)
        if (idiag_uxuymx/=0) call yzsum_mn_name_x(p%uu(:,1)*p%uu(:,2),idiag_uxuymx)
        if (idiag_uxuzmx/=0) call yzsum_mn_name_x(p%uu(:,1)*p%uu(:,3),idiag_uxuzmx)
        if (idiag_uyuzmx/=0) call yzsum_mn_name_x(p%uu(:,2)*p%uu(:,3),idiag_uyuzmx)
        if (idiag_ekinz/=0)  call xysum_mn_name_z(.5*p%rho*p%u2,idiag_ekinz)
        if (idiag_oumx/=0)   call yzsum_mn_name_x(p%ou,idiag_oumx)
        if (idiag_oumy/=0)   call xzsum_mn_name_y(p%ou,idiag_oumy)
        if (idiag_oumz/=0)   call xysum_mn_name_z(p%ou,idiag_oumz)
!  phi-z averages
        if (idiag_u2mr/=0)   call phizsum_mn_name_r(p%u2,idiag_u2mr)
        if (idiag_urmr/=0) &
             call phizsum_mn_name_r(p%uu(:,1)*p%pomx+p%uu(:,2)*p%pomy,idiag_urmr)
        if (idiag_upmr/=0) &
             call phizsum_mn_name_r(p%uu(:,1)*p%phix+p%uu(:,2)*p%phiy,idiag_upmr)
        if (idiag_uzmr/=0) &
             call phizsum_mn_name_r(p%uu(:,3),idiag_uzmr)
        if (idiag_ormr/=0) &
             call phizsum_mn_name_r(p%oo(:,1)*p%pomx+p%oo(:,2)*p%pomy,idiag_ormr)
        if (idiag_opmr/=0) &
             call phizsum_mn_name_r(p%oo(:,1)*p%phix+p%oo(:,2)*p%phiy,idiag_opmr)
        if (idiag_ozmr/=0) &
             call phizsum_mn_name_r(p%oo(:,3),idiag_ozmr)
        endif
!
!  phi-averages
!  Note that this does not necessarily happen with ldiagnos=.true.
!
      if (l2davgfirst) then
        if (idiag_urmphi/=0) &
            call phisum_mn_name_rz(p%uu(:,1)*p%pomx+p%uu(:,2)*p%pomy,idiag_urmphi)
        if (idiag_upmphi/=0) &
            call phisum_mn_name_rz(p%uu(:,1)*p%phix+p%uu(:,2)*p%phiy,idiag_upmphi)
        if (idiag_uzmphi/=0) &
            call phisum_mn_name_rz(p%uu(:,3),idiag_uzmphi)
        if (idiag_u2mphi/=0) &
            call phisum_mn_name_rz(p%u2,idiag_u2mphi)
        if (idiag_ozmphi/=0) &
            call phisum_mn_name_rz(p%oo(:,3),idiag_ozmphi)
        if (idiag_oumphi/=0) call phisum_mn_name_rz(p%ou,idiag_oumphi)
        if (idiag_uxmxz/=0) &
            call ysum_mn_name_xz(p%uu(:,1),idiag_uxmxz)
        if (idiag_uymxz/=0) &
            call ysum_mn_name_xz(p%uu(:,2),idiag_uymxz)
        if (idiag_uzmxz/=0) &
            call ysum_mn_name_xz(p%uu(:,3),idiag_uzmxz)
        if (idiag_ux2mxz/=0) &
            call ysum_mn_name_xz(p%uu(:,1)**2,idiag_ux2mxz)
        if (idiag_uy2mxz/=0) &
            call ysum_mn_name_xz(p%uu(:,2)**2,idiag_uy2mxz)
        if (idiag_uz2mxz/=0) &
            call ysum_mn_name_xz(p%uu(:,3)**2,idiag_uz2mxz)
        if (idiag_uxmxy/=0) call zsum_mn_name_xy(p%uu(:,1),idiag_uxmxy)
        if (idiag_uymxy/=0) call zsum_mn_name_xy(p%uu(:,2),idiag_uymxy)
        if (idiag_uzmxy/=0) call zsum_mn_name_xy(p%uu(:,3),idiag_uzmxy)
        if (idiag_ruxmxy/=0) call zsum_mn_name_xy(p%rho*p%uu(:,1),idiag_ruxmxy)
        if (idiag_ruymxy/=0) call zsum_mn_name_xy(p%rho*p%uu(:,2),idiag_ruymxy)
        if (idiag_ruzmxy/=0) call zsum_mn_name_xy(p%rho*p%uu(:,3),idiag_ruzmxy)
        if (idiag_ux2mxy/=0) &
            call zsum_mn_name_xy(p%uu(:,1)**2,idiag_ux2mxy)
        if (idiag_uy2mxy/=0) &
            call zsum_mn_name_xy(p%uu(:,2)**2,idiag_uy2mxy)
        if (idiag_uz2mxy/=0) &
            call zsum_mn_name_xy(p%uu(:,3)**2,idiag_uz2mxy)
        if (idiag_rux2mxy/=0) &
            call zsum_mn_name_xy(p%rho*p%uu(:,1)**2,idiag_rux2mxy)
        if (idiag_ruy2mxy/=0) &
            call zsum_mn_name_xy(p%rho*p%uu(:,2)**2,idiag_ruy2mxy)
        if (idiag_ruz2mxy/=0) &
            call zsum_mn_name_xy(p%rho*p%uu(:,3)**2,idiag_ruz2mxy)
        if (idiag_ruxuymxy/=0) &
            call zsum_mn_name_xy(p%rho*p%uu(:,1)*p%uu(:,2),idiag_ruxuymxy)
        if (idiag_ruxuzmxy/=0) &
            call zsum_mn_name_xy(p%rho*p%uu(:,1)*p%uu(:,3),idiag_ruxuzmxy)
        if (idiag_ruyuzmxy/=0) &
            call zsum_mn_name_xy(p%rho*p%uu(:,2)*p%uu(:,3),idiag_ruyuzmxy)
      endif
!
    endsubroutine duu_dt
!***********************************************************************
    subroutine calc_lhydro_pars(f)
!
!  calculate <rho*ux> and <rho*uy> when tau_damp_ruxm, tau_damp_ruym,
!  or tau_damp_ruzm are different from zero. Was used to remove net
!  momenta in any of the three directions. A better method is now
!  to set lremove_mean_momenta=T in the call to remove_mean_momenta.
!  calculate <U>, when lcalc_uumean=.true.
!
!   9-nov-06/axel: adapted from calc_ltestfield_pars
!
      use Cdata, only: iux,iuy,iuz,ilnrho,l1,l2,m1,m2,n1,n2,lroot,t,x,y
      use Mpicomm, only: mpiallreduce_sum
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx) :: rho,rux,ruy,ruz
      integer, parameter :: nreduce=3
      real, dimension (nreduce) :: fsum_tmp,fsum
      real, dimension (3,3) :: mat_cori1=0.,mat_cori2=0.
      real, dimension (3,3) :: mat_cent1=0.,mat_cent2=0.,mat_cent3=0.
      integer :: nxy=nxgrid*nygrid
!     real, dimension (nz,nprocz,3) :: uumz1
!     real, dimension (nz*nprocz*3) :: uumz2,uumz3
      real :: c,s
      integer :: m,n,j
      real :: fact
!
      intent(in) :: f
!
!  calculate averages of rho*ux and rho*uy
!
      if (ldensity) then
      if (tau_damp_ruxm/=0. .or. tau_damp_ruym/=0. .or. tau_damp_ruzm/=0.) then
        ruxm=0.
        ruym=0.
        ruzm=0.
        fact=1./nwgrid
        do n=n1,n2
          do m=m1,m2
            rho=exp(f(l1:l2,m,n,ilnrho))
            rux=rho*f(l1:l2,m,n,iux)
            ruy=rho*f(l1:l2,m,n,iuy)
            ruz=rho*f(l1:l2,m,n,iuz)
            ruxm=ruxm+fact*sum(rux)
            ruym=ruym+fact*sum(ruy)
            ruzm=ruzm+fact*sum(ruz)
          enddo
        enddo
      endif
!
!  communicate to the other processors
!
      fsum_tmp(1)=ruxm
      fsum_tmp(2)=ruym
      fsum_tmp(3)=ruzm
      call mpiallreduce_sum(fsum_tmp,fsum,nreduce)
      ruxm=fsum(1)
      ruym=fsum(2)
      ruzm=fsum(3)
      endif
!
!  do mean field for each component
!
      if (lcalc_uumean) then
        fact=1./nxy
        do n=n1,n2
          uumz(n,:)=0.
          do j=1,3
            uumz(n-n1+1,j)=fact*sum(f(l1:l2,m1:m2,n,j))
          enddo
        enddo
      endif
!
!  do communication for array of size nz*nprocz*3*njtest
!
!     if (nprocy>1) then
!       uum2=reshape(uumz1,shape=(/nz*nprocz*3/))
!       call mpireduce_sum(uumz2,uum3,nz*nprocz*3)
!       call mpibcast_real(uumz3,nz*nprocz*3)
!       uum1=reshape(uum3,shape=(/nz,nprocz,3/))
!       do n=n1,n2
!         do j=1,3
!           uumz(n,j)=uumz1(n-n1+1,ipz+1,j)
!         enddo
!       enddo
!     endif
!
!  calculate precession matrices
!
      if (lprecession) then
        c=cos(omega_precession*t)
        s=sin(omega_precession*t)
        mat_cori1(2,3)=+1.
        mat_cori1(3,2)=-1.
        mat_cori2(1,2)=+c
        mat_cori2(1,3)=-s
        mat_cori2(2,1)=-c
        mat_cori2(3,1)=+s
        mat_cent1(2,2)=+1.
        mat_cent1(3,3)=+1.
        mat_cent2(1,1)=+1.
        mat_cent2(2,2)=+c**2
        mat_cent2(3,3)=+s**2
        mat_cent2(2,3)=-2.*s*c
        mat_cent2(3,2)=-2.*s*c
        mat_cent3(1,2)=-s+c
        mat_cent3(2,1)=-s-c
        mat_cent3(1,3)=-s-c
        mat_cent3(3,1)=+s-c
        mat_cori=2.*(omega_precession*mat_cori1+Omega*mat_cori2)
        mat_cent=omega_precession**2*mat_cent1+Omega**2*mat_cent2 &
          +2.*omega_precession*Omega*mat_cent3
      endif
!
    endsubroutine calc_lhydro_pars
!***********************************************************************
    subroutine set_border_hydro(f,df,p)
!
!  Calculates the driving term for the border profile
!  of the uu variable.
!
!  28-jul-06/wlad: coded
!
      use Cdata
      use BorderProfiles,  only: border_driving
      use EquationOfState, only: cs0,cs20,get_ptlaw,rho0
      use Particles_nbody, only: get_totalmass
      use Gravity,         only: g0,qgshear
      use Sub,             only: power_law
      use Mpicomm,         only: stop_it
      use SharedVariables
      use Deriv,           only: der_pencil
      use General,         only: tridag
      use Selfgravity,     only: rhs_poisson_const
!
      real, dimension(mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
      real, dimension(mx,my,mz,mvar) :: df
      real, dimension(nx,3) :: f_target
      real    :: ptlaw,g0_,B0
      real :: tmp,OO,corr,corrmag
      integer :: ju,j,i,ierr
      real, pointer :: zmode,plaw
!!
      real :: dr,r0,alpha
      real, dimension(nx) :: tmp_nx,a_tri,b_tri,c_tri,d_tri,u_tri
      real, dimension(nx) :: usg,corr_nx,uu_nx,dens
      real, dimension(mx) :: potential,gpotential
      logical :: err
!!

!
! these tmps and where's are needed because these square roots
! go negative in the frozen inner disc if the sound speed is big enough
! (like a corona, no hydrostatic equilibrium)
!
      select case(borderuu)
      case('zero','0')
        f_target=0.
      case('constant')
        do j=1,3
          f_target(:,j) = uu_const(j)
        enddo
      case('keplerian')  
        if (.not.lspherical_coords) &
             call stop_it("keplerian border: not implemented for other grids than spherical yet")
        if (lgrav) then 
          g0_=g0
        elseif (lparticles_nbody) then
          call get_totalmass(g0_)
        else 
          call stop_it("set_border_hydro: can't get g0")
        endif
        !don't care about the pressure term, just drive it to Keplerian
        !in the inner boundary ONLY!!
        do i=1,nx
          if ( ((p%rborder_mn(i).ge.r_int).and.(p%rborder_mn(i).le.r_int+2*wborder_int)).or.&
               ((p%rborder_mn(i).ge.r_ext-2*wborder_ext).and.(p%rborder_mn(i).le.r_ext))) then
            call power_law(g0_,p%r_mn(i),qgshear,OO)
            f_target(i,1) = 0.
            f_target(i,2) = 0.
            f_target(i,3) = OO*p%r_mn(i)
          endif
        enddo

      case('global-shear')
        !get g0
        if (lgrav) then 
          g0_=g0
        elseif (lparticles_nbody) then
          call get_totalmass(g0_)
        else 
          call stop_it("set_border_hydro: can't get g0")
        endif
        !get the exponents for density and cs2
        call get_ptlaw(ptlaw)
        call get_shared_variable('plaw',plaw,ierr)
        if (ierr/=0) call stop_it("borderuu: "//&
             "there was a problem when getting plaw")
          !no need to do the whole nx array. the border is all we need
        do i=1,nx
          if ( ((p%rborder_mn(i).ge.r_int).and.(p%rborder_mn(i).le.r_int+2*wborder_int)).or.&
               ((p%rborder_mn(i).ge.r_ext-2*wborder_ext).and.(p%rborder_mn(i).le.r_ext))) then
            call power_law(g0_,p%rcyl_mn(i),2*qgshear,tmp)
            !minimize use of exponentials if no smoothing is used
            if (rsmooth.ne.0.) then 
              corr=cs20*(ptlaw+plaw)*(p%rcyl_mn(i)**2+rsmooth**2)**(-1-.5*ptlaw)
            else
              corr=cs20*(ptlaw+plaw)* p%rcyl_mn1(i)**(ptlaw+2)
            endif
            OO=sqrt(max(tmp - corr,0.))
            f_target(i,1) = OO*p%phix(i)*p%rcyl_mn(i)
            f_target(i,2) = OO*p%phiy(i)*p%rcyl_mn(i)
            f_target(i,3) = 0.
          endif
        enddo
!
      case('global-shear-mhs')
        !get g0
        if (lgrav) then 
          g0_=g0
        elseif (lparticles_nbody) then
          call get_totalmass(g0_)
        else 
          call stop_it("set_border_hydro: can't get g0")
        endif
        !get the exponents for density and cs2
        call get_ptlaw(ptlaw)
        call get_shared_variable('plaw',plaw,ierr)
        if (ierr/=0) call stop_it("borderuu: "//&
               "there was a problem when getting plaw")
        call get_shared_variable('zmode',zmode,ierr)
        if (ierr/=0) call stop_it("borderuu: "//&
             "there was a problem when getting zmode")
        B0=Lxyz(3)/(2*zmode*pi)
        !no need to do the whole nx array. the border is all we need
        do i=1,nx
          if ( ((p%rborder_mn(i).ge.r_int).and.(p%rborder_mn(i).le.r_int+2*wborder_int)).or.&
               ((p%rborder_mn(i).ge.r_ext-2*wborder_ext).and.(p%rborder_mn(i).le.r_ext))) then
            call power_law(g0_,p%rcyl_mn(i),2*qgshear,tmp)
            !minimize use of exponentials if no smoothing is used
            if (rsmooth.ne.0.) then 
              corr=cs20*(ptlaw+plaw)*(p%rcyl_mn(i)**2+rsmooth**2)**(-1-.5*ptlaw)
            else
              corr=cs20*(ptlaw+plaw)* p%rcyl_mn1(i)**(ptlaw+2)
            endif
            corrmag=B0**2*qgshear*p%rcyl_mn1(i)**(2+2*qgshear) 
            OO=sqrt(max(tmp-corr-corrmag,0.))
            f_target(i,1) = OO*p%phix(i)*p%rcyl_mn(i)
            f_target(i,2) = OO*p%phiy(i)*p%rcyl_mn(i)
            f_target(i,3) = 0.
          endif
        enddo
!
      case('global-shear-selfg')
        call get_ptlaw(ptlaw)
        call get_shared_variable('plaw',plaw,ierr)
        if (ierr/=0) call stop_it("borderuu: "//&
             "there was a problem when getting plaw")
        !minimize use of exponentials if no smoothing is used
        !power law density - what's the potential?
        call power_law(rho0,p%rcyl_mn,plaw,dens)
        !get potential
        dr=dx;r0=xyz0(1)
        do i=2,nx-1
          alpha= .5/((i-1)+r0/dr)
          a_tri(i) = (1 - alpha)/dr**2
          b_tri(i) =-2/dr**2 
          c_tri(i) = (1 + alpha)/dr**2
        enddo
        b_tri(1)=-4/dr**2;c_tri(1) = 4/dr**2;a_tri(1) =0.
        c_tri(nx)=1/dr**2;b_tri(nx)=-2/dr**2;a_tri(nx)=1/dr**2
        d_tri = dens*rhs_poisson_const
        d_tri(nx)=0.
        call tridag(a_tri,b_tri,c_tri,d_tri,tmp_nx,err)
        potential(l1:l2)=tmp_nx
        !ghost zones of the potential
        do i=1,nghost 
          potential(l1-i)=2*potential(l1)-potential(l1+i)
          potential(l2+i)=2*potential(l2)-potential(l2-i)
        enddo
        !take the gradient and correct the velocity with it  
        call der_pencil(1,potential,gpotential)
        usg=gpotential(l1:l2)*p%rcyl_mn
        !pressure correction - assumes r_ref=1.
        corr_nx=cs20*(ptlaw+plaw)* p%rcyl_mn1**(ptlaw)
        call power_law(g0,p%rcyl_mn,2*qgshear-2,tmp_nx)
        uu_nx=sqrt(max(tmp_nx -corr_nx + usg,0.))
        !only for cylindrical
        f_target(:,2) = uu_nx
        f_target(:,1) = 0.;f_target(:,3) = 0.
!
      case('nothing')
         if (lroot.and.ip<=5) &
              print*,"set_border_hydro: borderuu='nothing'"

      case default
         write(unit=errormsg,fmt=*) &
              'set_border_hydro: No such value for borderuu: ', &
              trim(borderuu)
         call fatal_error('set_border_hydro',errormsg)
      endselect
!
      if (borderuu /= 'nothing') then
        do j=1,3
          ju=j+iuu-1
          call border_driving(f,df,p,f_target(:,j),ju)
        enddo
      endif
!
    endsubroutine set_border_hydro
!***********************************************************************
    subroutine centrifugal_balance(f)
!
! This subroutine is a general routine that takes
! the gravity acceleration and adds the centrifugal force
! that numerically balances it.
!
! Pressure corrections to ensure centrifugal equilibrium are
! added in the respective modules
!
! 24-feb-05/wlad: coded
! 04-jul-07/wlad: generalized for any shear
! 08-sep-07/wlad: moved here from initcond
!
      use Cdata
      use Gravity, only: r0_pot,n_pot,acceleration,qgshear
      use Sub,     only: get_radial_distance,power_law
      use Mpicomm, only: stop_it
      use Particles_nbody, only: get_totalmass
!
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(mx) :: rr_cyl,rr_sph,OO,g_r,tmp
      real :: g0_
      integer :: i
!
      if (lroot) &
           print*,'centrifugal_balance: initializing velocity field'
!
     if ((rsmooth.ne.0.).or.(r0_pot.ne.0)) then
       if (rsmooth.ne.r0_pot) &
            call stop_it("rsmooth and r0_pot must be equal")
       if (n_pot/=2) &
            call stop_it("don't you dare using less smoothing than n_pot=2")
     endif
!
     do m=1,my
        do n=1,mz
!
          call get_radial_distance(rr_sph,rr_cyl)

          if (lgrav) then 
!
! Gravity of a static central body
!
            call acceleration(g_r)
!
            if (any(g_r .gt. 0.)) then
              do i=1,mx
                if (g_r(i) .gt. 0) then
                  print*,"centrifugal_balance: gravity at point ",x(i),y(m),&
                       z(n),"is directed outwards"
                  call stop_it("")
                endif
              enddo
            else
              if ( (coord_system=='cylindric')  .or.&
                   (coord_system=='cartesian')) then 
                OO=sqrt(max(-g_r/rr_cyl,0.))
              else if (coord_system=='spherical') then
                OO=sqrt(max(-g_r/(rr_sph*sinth(m)**2),0.))
              endif
            endif
!
          elseif (lparticles_nbody) then 
!
! Nbody gravity with a dominating but dynamical central body
!
            call get_totalmass(g0_)
            call power_law(sqrt(g0_),rr_sph,qgshear,tmp)
!
            if (lcartesian_coords.or.&
                 lcylindrical_coords) then
              OO=tmp
              if (lcylindrical_gravity) &
                   OO=tmp*sqrt(rr_sph/rr_cyl)
            elseif (lspherical_coords) then
              OO=tmp/sinth(m) 
            endif
!
          endif
!
          if (coord_system=='cartesian') then
            f(:,m,n,iux) = f(:,m,n,iux) - y(m)*OO
            f(:,m,n,iuy) = f(:,m,n,iuy) + x   *OO
            f(:,m,n,iuz) = f(:,m,n,iuz) + 0.
          elseif (coord_system=='cylindric') then
            f(:,m,n,iux) = f(:,m,n,iux) + 0.
            f(:,m,n,iuy) = f(:,m,n,iuy) + OO*rr_cyl
            f(:,m,n,iuz) = f(:,m,n,iuz) + 0.
          elseif (coord_system=='spherical') then
            f(:,m,n,iux) = f(:,m,n,iux) + 0.
            f(:,m,n,iuy) = f(:,m,n,iuy) + 0.
            f(:,m,n,iuz) = f(:,m,n,iuz) + OO*(rr_sph*sinth(m))
          endif
!
        enddo
      enddo
!
    endsubroutine centrifugal_balance
!***********************************************************************
    subroutine calc_othresh()
!
!  calculate othresh from orms, give warnings if there are problems
!
!  24-nov-03/axel: adapted from calc_bthresh
!
      use Cdata
!
!  give warning if orms is not set in prints.in
!
      if(idiag_orms==0) then
        if(lroot.and.lfirstpoint) then
          print*,'calc_othresh: need to set orms in print.in to get othresh'
        endif
      endif
!
!  if nvec exceeds novecmax (=1/4) of points per processor, then begin to
!  increase scaling factor on othresh. These settings will stay in place
!  until the next restart
!
      if(novec>novecmax.and.lfirstpoint) then
        print*,'calc_othresh: processor ',iproc,': othresh_scl,novec,novecmax=', &
                                                   othresh_scl,novec,novecmax
        othresh_scl=othresh_scl*1.2
      endif
!
!  calculate othresh as a certain fraction of orms
!
      othresh=othresh_scl*othresh_per_orms*orms
!
    endsubroutine calc_othresh
!***********************************************************************
    subroutine precession(df,p)
!
!  precession terms
!
!  19-jan-07/axel: added terms derived by Gailitis
!
      use Cdata
      use Mpicomm, only: stop_it
      use Sub, only: step,sum_mn_name
!
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      integer :: i,j,k
!
!  info about precession term
!
      if (headtt) then
        print*, 'precession: omega_precession=', omega_precession
      endif
!
!  matrix multiply
!
      do j=1,3
      do i=1,3
        k=iuu-1+i
        df(l1:l2,m,n,k)=df(l1:l2,m,n,k) &
          +mat_cent(i,j)*p%rr(:,j) &
          +mat_cori(i,j)*p%uu(:,j)
      enddo
      enddo
!
    endsubroutine precession
!***********************************************************************
    subroutine coriolis_spherical(df,p)
!
!  coriolis_spherical terms using spherical polars
!
!  21-feb-07/axel+dhruba: coded
!
      use Cdata
      use Mpicomm, only: stop_it
!
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
      real :: c2,s2
!
!  info about coriolis_spherical term
!
      if (headtt) then
        print*, 'coriolis_spherical: Omega=', Omega
      endif
!
!  -2 Omega x u
!
      c2=2*Omega*costh(m)
      s2=2*Omega*sinth(m)
      df(l1:l2,m,n,iux)=df(l1:l2,m,n,iux)+s2*p%uu(:,3)
      df(l1:l2,m,n,iuy)=df(l1:l2,m,n,iuy)+c2*p%uu(:,3)
      df(l1:l2,m,n,iuz)=df(l1:l2,m,n,iuz)-c2*p%uu(:,2)+s2*p%uu(:,1)
!
    endsubroutine coriolis_spherical
!***********************************************************************
    subroutine coriolis_cylindrical(df,p)
!
!  Coriolis terms using cylindrical coords
!  The formulation is the same as in cartesian, but it is better to 
!  keep it here because precession is not implemented for 
!  cylindrical coordinates.
!
!  19-sep-07/steveb: coded
!
     use Cdata
     use Mpicomm, only: stop_it
!
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
      real :: c2
!
!  info about coriolis_cylindrical term
!
      if (headtt) then
        print*, 'coriolis_cylindrical: Omega=', Omega
      endif
!
!  -2 Omega x u
!    
      c2=2*Omega
      df(l1:l2,m,n,iux)=df(l1:l2,m,n,iux)+c2*p%uu(:,2)
      df(l1:l2,m,n,iuy)=df(l1:l2,m,n,iuy)-c2*p%uu(:,1)
!
!   Note, there is no z-component
!
    endsubroutine coriolis_cylindrical
!***********************************************************************
    subroutine udamping(f,df,p)
!
!  damping terms (artificial, but sometimes useful):
!
!  20-nov-04/axel: added cylindrical Couette flow
!
      use Cdata
      use Mpicomm, only: stop_it
      use Sub, only: step,sum_mn_name
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      real, dimension(nx) :: pdamp,fint_work,fext_work
      real, dimension(nx,3) :: fint,fext
      real :: zbot,ztop,t_infl,t_span,tau,pfade
      integer :: i,j
!
!  warn about the damping term
!
        if (headtt .and. (dampu /= 0.) .and. (t < tdamp)) then
          if (ldamp_fade) then
            print*, 'udamping: Damping velocities constantly until time ', tdamp
          else
            print*, 'udamping: Damping velocities smoothly until time ', tdamp
          end if
        endif
!
!  define bottom and top height
!
      zbot=xyz0(3)
      ztop=xyz0(3)+Lxyz(3)
!
!  1. damp motion during time interval 0<t<tdamp.
!  Damping coefficient is dampu (if >0) or |dampu|/dt (if dampu <0).
!  With ldamp_fade=T, damping coefficient is smoothly fading out
!

        if ((dampu .ne. 0.) .and. (t < tdamp)) then
          if (ldamp_fade) then  ! smoothly fade
            !
            ! smoothly fade out damping according to the following
            ! function of time:
            !
            !    ^
            !    |
            !  1 +**************
            !    |              ****
            !    |                  **
            !    |                    *
            !    |                     **
            !    |                       ****
            !  0 +-------------+-------------**********---> t
            !    |             |             |
            !    0          Tdamp/2        Tdamp
            !
            ! i.e. for 0<t<Tdamp/2, full damping is applied, while for
            ! Tdamp/2<t<Tdamp, damping goes smoothly (with continuous
            ! derivatives) to zero.
            !
            t_infl = 0.75*tdamp ! position of inflection point
            t_span = 0.5*tdamp   ! width of transition (1->0) region
            tau = (t-t_infl)/t_span ! normalized t, tr. region is [-0.5,0.5]
            if (tau <= -0.5) then
              pfade = 1.
            elseif (tau <= 0.5) then
              pfade = 0.5*(1-tau*(3-4*tau**2))
            else
              call stop_it("UDAMPING: Never got here.")
            endif
          else                ! don't fade, switch
            pfade = 1.
          endif
          !
          ! damp absolutely or relative to time step
          !
          if (dampu > 0) then   ! absolutely
            df(l1:l2,m,n,iux:iuz) = df(l1:l2,m,n,iux:iuz) &
                                    - pfade*dampu*f(l1:l2,m,n,iux:iuz)
          else                  ! relative to dt
            if (dt > 0) then    ! dt known and good
              df(l1:l2,m,n,iux:iuz) = df(l1:l2,m,n,iux:iuz) &
                                      + pfade*dampu/dt*f(l1:l2,m,n,iux:iuz)
            else
              call stop_it("UDAMP: dt <=0 -- what does this mean?")
            endif
          endif
        endif
!
!  2. damp motions for p%r_mn > rdampext or r_ext AND p%r_mn < rdampint or r_int
!
        if (lgravr) then        ! why lgravr here? to ensure we know p%r_mn??
! geodynamo
! original block
!          pdamp = step(p%r_mn,rdamp,wdamp) ! damping profile
!          do i=iux,iuz
!            df(l1:l2,m,n,i) = df(l1:l2,m,n,i) - dampuext*pdamp*f(l1:l2,m,n,i)
!          enddo
!
          if (dampuext > 0.0 .and. rdampext /= impossible) then
            pdamp = step(p%r_mn,rdampext,wdamp) ! outer damping profile
            do i=iux,iuz
              df(l1:l2,m,n,i) = df(l1:l2,m,n,i) - dampuext*pdamp*f(l1:l2,m,n,i)
            enddo
          endif

          if (dampuint > 0.0) then
            pdamp = 1 - step(p%r_mn,rdampint,wdamp) ! inner damping profile
            do i=iux,iuz
              df(l1:l2,m,n,i) = df(l1:l2,m,n,i) - dampuint*pdamp*f(l1:l2,m,n,i)
            enddo
          endif
! end geodynamo
        endif
!
!  coupling the above internal and external rotation rates to lgravr is not
!  a good idea. So, because of that, spherical Couette flow has to be coded
!  separately.
!  ==> reconsider name <==
!  Allow now also for cylindical Couette flow (if lcylinder_in_a_box=T)
!
        if (lOmega_int) then
!
!  relax outer angular velocity to zero, and
!  calculate work done to sustain zero rotation on outer cylinder/sphere
!
!
          if (lcylinder_in_a_box) then
            pdamp = step(p%rcyl_mn,rdampext,wdamp) ! outer damping profile
          else
            pdamp = step(p%r_mn,rdampext,wdamp) ! outer damping profile
          endif
!
          do i=1,3
            j=iux-1+i
            fext(:,i)=-dampuext*pdamp*f(l1:l2,m,n,j)
            df(l1:l2,m,n,j)=df(l1:l2,m,n,j)+fext(:,i)
          enddo
          if (idiag_fextm/=0) then
            fext_work=f(l1:l2,m,n,iux)*fext(:,1)&
                     +f(l1:l2,m,n,iuy)*fext(:,2)&
                     +f(l1:l2,m,n,iuz)*fext(:,3)
            call sum_mn_name(fext_work,idiag_fextm)
          endif
!
!  internal angular velocity, uref=(-y,x,0)*Omega_int, and
!  calculate work done to sustain uniform rotation on inner cylinder/sphere
!
          if (dampuint > 0.0) then
            if (lcylinder_in_a_box) then
              pdamp = 1 - step(p%rcyl_mn,rdampint,wdamp) ! inner damping profile
            else
              pdamp = 1 - step(p%r_mn,rdampint,wdamp) ! inner damping profile
            endif
            fint(:,1)=-dampuint*pdamp*(f(l1:l2,m,n,iux)+y(m)*Omega_int)
            fint(:,2)=-dampuint*pdamp*(f(l1:l2,m,n,iuy)-x(l1:l2)*Omega_int)
            fint(:,3)=-dampuint*pdamp*(f(l1:l2,m,n,iuz))
            df(l1:l2,m,n,iux)=df(l1:l2,m,n,iux)+fint(:,1)
            df(l1:l2,m,n,iuy)=df(l1:l2,m,n,iuy)+fint(:,2)
            df(l1:l2,m,n,iuz)=df(l1:l2,m,n,iuz)+fint(:,3)
            if (idiag_fintm/=0) then
              fint_work=f(l1:l2,m,n,iux)*fint(:,1)&
                       +f(l1:l2,m,n,iuy)*fint(:,2)&
                       +f(l1:l2,m,n,iuz)*fint(:,3)
              call sum_mn_name(fint_work,idiag_fintm)
            endif
          endif
        endif
!
    endsubroutine udamping
!***********************************************************************
    subroutine rprint_hydro(lreset,lwrite)
!
!  reads and registers print parameters relevant for hydro part
!
!   3-may-02/axel: coded
!  27-may-02/axel: added possibility to reset list
!
      use Cdata
      use Sub
!
      integer :: iname,inamez,inamey,inamex,ixy,ixz,irz,inamer
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
        idiag_u2tm=0
        idiag_u2m=0
        idiag_um2=0
        idiag_uxpt=0
        idiag_uypt=0
        idiag_uzpt=0
        idiag_urms=0
        idiag_umax=0
        idiag_uzrms=0
        idiag_uzrmaxs=0
        idiag_uxmax=0
        idiag_uymax=0
        idiag_uzmax=0
        idiag_uxm=0
        idiag_uym=0
        idiag_uzm=0
        idiag_ux2m=0
        idiag_uy2m=0
        idiag_uz2m=0
        idiag_ux2mx=0
        idiag_uy2mx=0
        idiag_uz2mx=0
        idiag_ux2my=0
        idiag_uy2my=0
        idiag_uz2my=0
        idiag_ux2mz=0
        idiag_uy2mz=0 
        idiag_uz2mz=0 
        idiag_uxuym=0
        idiag_uxuzm=0
        idiag_uyuzm=0
        idiag_uxuymz=0
        idiag_uxuzmz=0
        idiag_uyuzmz=0
        idiag_uxuymz=0
        idiag_umx=0
        idiag_umy=0
        idiag_umz=0
        idiag_divum=0
        idiag_divu2m=0
        idiag_u3u21m=0
        idiag_u1u32m=0
        idiag_u2u13m=0
        idiag_urmphi=0
        idiag_upmphi=0
        idiag_uzmphi=0
        idiag_u2mphi=0
        idiag_uxmy=0
        idiag_uymy=0
        idiag_uzmy=0
        idiag_uxuymy=0
        idiag_uxuzmy=0
        idiag_uyuzmy=0
        idiag_u2mr=0
        idiag_urmr=0
        idiag_upmr=0
        idiag_uzmr=0
        idiag_uxfampm=0
        idiag_uyfampm=0
        idiag_uzfampm=0
        idiag_uxmxz=0
        idiag_uymxz=0
        idiag_uzmxz=0
        idiag_ux2mxz=0
        idiag_uy2mxz=0
        idiag_uz2mxz=0
        idiag_uxmxy=0
        idiag_uymxy=0
        idiag_uzmxy=0
        idiag_ruxmxy=0
        idiag_ruymxy=0
        idiag_ruzmxy=0
        idiag_ux2mxy=0
        idiag_uy2mxy=0
        idiag_uz2mxy=0
        idiag_rux2mxy=0
        idiag_ruy2mxy=0
        idiag_ruz2mxy=0
        idiag_ruxuymxy=0
        idiag_ruxuzmxy=0
        idiag_ruyuzmxy=0
        !
        idiag_ruxm=0
        idiag_ruym=0
        idiag_ruzm=0
        idiag_rumax=0
        idiag_rufm=0
        !
        idiag_dtu=0
        !
        idiag_oum=0
        idiag_o2m=0
        idiag_orms=0
        idiag_omax=0
        idiag_ox2m=0
        idiag_oy2m=0
        idiag_oz2m=0
        idiag_oxm=0
        idiag_oym=0
        idiag_ozm=0
        idiag_oxoym=0
        idiag_oxozm=0
        idiag_oyozm=0
        idiag_oumx=0
        idiag_oumy=0
        idiag_oumz=0
        idiag_oumphi=0
        idiag_ozmphi=0
        idiag_ormr=0
        idiag_opmr=0
        idiag_ozmr=0
        !
        idiag_Marms=0
        idiag_Mamax=0
        !
        idiag_fintm=0
        idiag_fextm=0
        idiag_duxdzma=0
        idiag_duydzma=0
        idiag_ekin=0 
        idiag_totangmom=0
        idiag_ekintot=0
        idiag_ekinz=0
        idiag_fmassz=0
        idiag_fkinz=0
        idiag_fxbxm=0
        idiag_fxbym=0
        idiag_fxbzm=0
        idiag_ruxuym=0
        idiag_ruxuymz=0
      endif
!
!  iname runs through all possible names that may be listed in print.in
!
      if(lroot.and.ip<14) print*,'rprint_hydro: run through parse list'
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'ekin',idiag_ekin)
        call parse_name(iname,cname(iname),cform(iname),'ekintot',idiag_ekintot)
        call parse_name(iname,cname(iname),cform(iname),'u2tm',idiag_u2tm)
        call parse_name(iname,cname(iname),cform(iname),'u2m',idiag_u2m)
        call parse_name(iname,cname(iname),cform(iname),'um2',idiag_um2)
        call parse_name(iname,cname(iname),cform(iname),'o2m',idiag_o2m)
        call parse_name(iname,cname(iname),cform(iname),'oum',idiag_oum)
        call parse_name(iname,cname(iname),cform(iname),'dtu',idiag_dtu)
        call parse_name(iname,cname(iname),cform(iname),'urms',idiag_urms)
        call parse_name(iname,cname(iname),cform(iname),'umax',idiag_umax)
        call parse_name(iname,cname(iname),cform(iname),'uxmax',idiag_uxmax)
        call parse_name(iname,cname(iname),cform(iname),'uymax',idiag_uymax)
        call parse_name(iname,cname(iname),cform(iname),'uzmax',idiag_uzmax)
        call parse_name(iname,cname(iname),cform(iname),'uzrms',idiag_uzrms)
        call parse_name(iname,cname(iname),cform(iname),'uzrmaxs',idiag_uzrmaxs)
        call parse_name(iname,cname(iname),cform(iname),'uxm',idiag_uxm)
        call parse_name(iname,cname(iname),cform(iname),'uym',idiag_uym)
        call parse_name(iname,cname(iname),cform(iname),'uzm',idiag_uzm)
        call parse_name(iname,cname(iname),cform(iname),'ux2m',idiag_ux2m)
        call parse_name(iname,cname(iname),cform(iname),'uy2m',idiag_uy2m)
        call parse_name(iname,cname(iname),cform(iname),'uz2m',idiag_uz2m)
        call parse_name(iname,cname(iname),cform(iname),'uxuym',idiag_uxuym)
        call parse_name(iname,cname(iname),cform(iname),'uxuzm',idiag_uxuzm)
        call parse_name(iname,cname(iname),cform(iname),'uyuzm',idiag_uyuzm)
        call parse_name(iname,cname(iname),cform(iname),'ruxuym',idiag_ruxuym)
        call parse_name(iname,cname(iname),cform(iname),'ox2m',idiag_ox2m)
        call parse_name(iname,cname(iname),cform(iname),'oy2m',idiag_oy2m)
        call parse_name(iname,cname(iname),cform(iname),'oz2m',idiag_oz2m)
        call parse_name(iname,cname(iname),cform(iname),'oxm',idiag_oxm)
        call parse_name(iname,cname(iname),cform(iname),'oym',idiag_oym)
        call parse_name(iname,cname(iname),cform(iname),'ozm',idiag_ozm)
        call parse_name(iname,cname(iname),cform(iname),'oxoym',idiag_oxoym)
        call parse_name(iname,cname(iname),cform(iname),'oxozm',idiag_oxozm)
        call parse_name(iname,cname(iname),cform(iname),'oyozm',idiag_oyozm)
        call parse_name(iname,cname(iname),cform(iname),'orms',idiag_orms)
        call parse_name(iname,cname(iname),cform(iname),'omax',idiag_omax)
        call parse_name(iname,cname(iname),cform(iname),'ruxm',idiag_ruxm)
        call parse_name(iname,cname(iname),cform(iname),'ruym',idiag_ruym)
        call parse_name(iname,cname(iname),cform(iname),'ruzm',idiag_ruzm)
        call parse_name(iname,cname(iname),cform(iname),'rumax',idiag_rumax)
        call parse_name(iname,cname(iname),cform(iname),'umx',idiag_umx)
        call parse_name(iname,cname(iname),cform(iname),'umy',idiag_umy)
        call parse_name(iname,cname(iname),cform(iname),'umz',idiag_umz)
        call parse_name(iname,cname(iname),cform(iname),'Marms',idiag_Marms)
        call parse_name(iname,cname(iname),cform(iname),'Mamax',idiag_Mamax)
        call parse_name(iname,cname(iname),cform(iname),'divum',idiag_divum)
        call parse_name(iname,cname(iname),cform(iname),'divu2m',idiag_divu2m)
        call parse_name(iname,cname(iname),cform(iname),'u3u21m',idiag_u3u21m)
        call parse_name(iname,cname(iname),cform(iname),'u1u32m',idiag_u1u32m)
        call parse_name(iname,cname(iname),cform(iname),'u2u13m',idiag_u2u13m)
        call parse_name(iname,cname(iname),cform(iname),'uxpt',idiag_uxpt)
        call parse_name(iname,cname(iname),cform(iname),'uypt',idiag_uypt)
        call parse_name(iname,cname(iname),cform(iname),'uzpt',idiag_uzpt)
        call parse_name(iname,cname(iname),cform(iname),'fintm',idiag_fintm)
        call parse_name(iname,cname(iname),cform(iname),'fextm',idiag_fextm)
        call parse_name(iname,cname(iname),cform(iname),'duxdzma',idiag_duxdzma)
        call parse_name(iname,cname(iname),cform(iname),'duydzma',idiag_duydzma)
        call parse_name(iname,cname(iname),cform(iname),'totangmom',idiag_totangmom)
        call parse_name(iname,cname(iname),cform(iname),'rufm',idiag_rufm)
        call parse_name(iname,cname(iname),cform(iname),'fxbxm',idiag_fxbxm)
        call parse_name(iname,cname(iname),cform(iname),'fxbym',idiag_fxbym)
        call parse_name(iname,cname(iname),cform(iname),'fxbzm',idiag_fxbzm)
        call parse_name(iname,cname(iname),cform(iname),'uxfampm',idiag_uxfampm)
        call parse_name(iname,cname(iname),cform(iname),'uyfampm',idiag_uyfampm)
        call parse_name(iname,cname(iname),cform(iname),'uzfampm',idiag_uzfampm)
        call parse_name(iname,cname(iname),cform(iname),'uxfampim',idiag_uxfampim)
        call parse_name(iname,cname(iname),cform(iname),'uyfampim',idiag_uyfampim)
        call parse_name(iname,cname(iname),cform(iname),'uzfampim',idiag_uzfampim)

      enddo
!
!  check for those quantities for which we want xy-averages
!
      do inamez=1,nnamez
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'uxmz',idiag_uxmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'uymz',idiag_uymz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'uzmz',idiag_uzmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez), &
            'ux2mz',idiag_ux2mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez), &
            'uy2mz',idiag_uy2mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez), &
            'uz2mz',idiag_uz2mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez), &
            'uxuymz',idiag_uxuymz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez), &
            'uxuzmz',idiag_uxuzmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez), &
            'uyuzmz',idiag_uyuzmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez), &
            'ruxuymz',idiag_ruxuymz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez), &
            'fmassz',idiag_fmassz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez), &
            'fkinz',idiag_fkinz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez), &
            'ekinz',idiag_ekinz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'u2mz',idiag_u2mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'oumz',idiag_oumz)
      enddo
!
!  check for those quantities for which we want xz-averages
!
      do inamey=1,nnamey
        call parse_name(inamey,cnamey(inamey),cformy(inamey),'uxmy',idiag_uxmy)
        call parse_name(inamey,cnamey(inamey),cformy(inamey),'uymy',idiag_uymy)
        call parse_name(inamey,cnamey(inamey),cformy(inamey),'uzmy',idiag_uzmy)
        call parse_name(inamey,cnamey(inamey),cformy(inamey), &
            'ux2my',idiag_ux2my)
        call parse_name(inamey,cnamey(inamey),cformy(inamey), &
            'uy2my',idiag_uy2my)
        call parse_name(inamey,cnamey(inamey),cformy(inamey), &
            'uz2my',idiag_uz2my)
        call parse_name(inamey,cnamey(inamey),cformy(inamey), &
            'uxuymy',idiag_uxuymy)
        call parse_name(inamey,cnamey(inamey),cformy(inamey), &
            'uxuzmy',idiag_uxuzmy)
        call parse_name(inamey,cnamey(inamey),cformy(inamey), &
            'uyuzmy',idiag_uyuzmy)
        call parse_name(inamey,cnamey(inamey),cformy(inamey),'oumy',idiag_oumy)
      enddo
!
!  check for those quantities for which we want yz-averages
!
      do inamex=1,nnamex
        call parse_name(inamex,cnamex(inamex),cformx(inamex),'uxmx',idiag_uxmx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex),'uymx',idiag_uymx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex),'uzmx',idiag_uzmx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex), &
            'ux2mx',idiag_ux2mx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex), &
            'uy2mx',idiag_uy2mx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex), &
            'uz2mx',idiag_uz2mx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex), &
            'uxuymx',idiag_uxuymx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex), &
            'uxuzmx',idiag_uxuzmx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex), &
            'uyuzmx',idiag_uyuzmx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex),'oumx',idiag_oumx)
      enddo
!
!  check for those quantities for which we want y-averages
!
      do ixz=1,nnamexz
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'uxmxz',idiag_uxmxz)
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'uymxz',idiag_uymxz)
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'uzmxz',idiag_uzmxz)
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'ux2mxz',idiag_ux2mxz)
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'uy2mxz',idiag_uy2mxz)
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'uz2mxz',idiag_uz2mxz)
      enddo
!
!  check for those quantities for which we want z-averages
!
      do ixy=1,nnamexy
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'uxmxy',idiag_uxmxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'uymxy',idiag_uymxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'uzmxy',idiag_uzmxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'ruxmxy',idiag_ruxmxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'ruymxy',idiag_ruymxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'ruzmxy',idiag_ruzmxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'ux2mxy',idiag_ux2mxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'uy2mxy',idiag_uy2mxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'uz2mxy',idiag_uz2mxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'rux2mxy',idiag_rux2mxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'ruy2mxy',idiag_ruy2mxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'ruz2mxy',idiag_ruz2mxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'ruxuymxy',idiag_ruxuymxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'ruxuzmxy',idiag_ruxuzmxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'ruyuzmxy',idiag_ruyuzmxy)
      enddo
!
!  check for those quantities for which we want phi-averages
!
      do irz=1,nnamerz
        call parse_name(irz,cnamerz(irz),cformrz(irz),'urmphi',idiag_urmphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'upmphi',idiag_upmphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'uzmphi',idiag_uzmphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'u2mphi',idiag_u2mphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'oumphi',idiag_oumphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'ozmphi',idiag_ozmphi)
      enddo
!
!  check for those quantities for which we want phiz-averages
!
      do inamer=1,nnamer
        call parse_name(inamer,cnamer(inamer),cformr(inamer),'urmr',  idiag_urmr)
        call parse_name(inamer,cnamer(inamer),cformr(inamer),'upmr',  idiag_upmr)
        call parse_name(inamer,cnamer(inamer),cformr(inamer),'uzmr',  idiag_uzmr)
        call parse_name(inamer,cnamer(inamer),cformr(inamer),'ormr',  idiag_ormr)
        call parse_name(inamer,cnamer(inamer),cformr(inamer),'opmr',  idiag_opmr)
        call parse_name(inamer,cnamer(inamer),cformr(inamer),'ozmr',  idiag_ozmr)
        call parse_name(inamer,cnamer(inamer),cformr(inamer),'u2mr',  idiag_u2mr)
      enddo
!
!  write column where which hydro variable is stored
!
      if (lwr) then
        write(3,*) 'i_ekin=',idiag_ekin
        write(3,*) 'i_ekintot=',idiag_ekintot
        write(3,*) 'i_u2tm=',idiag_u2tm
        write(3,*) 'i_u2m=',idiag_u2m
        write(3,*) 'i_um2=',idiag_um2
        write(3,*) 'i_o2m=',idiag_o2m
        write(3,*) 'i_oum=',idiag_oum
        write(3,*) 'i_dtu=',idiag_dtu
        write(3,*) 'i_urms=',idiag_urms
        write(3,*) 'i_umax=',idiag_umax
        write(3,*) 'i_uxmax=',idiag_uxmax
        write(3,*) 'i_uymax=',idiag_uymax
        write(3,*) 'i_uzmax=',idiag_uzmax
        write(3,*) 'i_uzrms=',idiag_uzrms
        write(3,*) 'i_uzrmaxs=',idiag_uzrmaxs
        write(3,*) 'i_ux2m=',idiag_ux2m
        write(3,*) 'i_uy2m=',idiag_uy2m
        write(3,*) 'i_uz2m=',idiag_uz2m
        write(3,*) 'i_uxuym=',idiag_uxuym
        write(3,*) 'i_uxuzm=',idiag_uxuzm
        write(3,*) 'i_uyuzm=',idiag_uyuzm
        write(3,*) 'i_ruxuym=',idiag_ruxuym
        write(3,*) 'i_ox2m=',idiag_ox2m
        write(3,*) 'i_oy2m=',idiag_oy2m
        write(3,*) 'i_oz2m=',idiag_oz2m
        write(3,*) 'i_oxm=',idiag_oxm
        write(3,*) 'i_oym=',idiag_oym
        write(3,*) 'i_ozm=',idiag_ozm
        write(3,*) 'i_oxoym=',idiag_oxoym
        write(3,*) 'i_oxozm=',idiag_oxozm
        write(3,*) 'i_oyozm=',idiag_oyozm
        write(3,*) 'i_orms=',idiag_orms
        write(3,*) 'i_omax=',idiag_omax
        write(3,*) 'i_ruxm=',idiag_ruxm
        write(3,*) 'i_ruym=',idiag_ruym
        write(3,*) 'i_ruzm=',idiag_ruzm
        write(3,*) 'i_rumax=',idiag_rumax
        write(3,*) 'i_umx=',idiag_umx
        write(3,*) 'i_umy=',idiag_umy
        write(3,*) 'i_umz=',idiag_umz
        write(3,*) 'i_Marms=',idiag_Marms
        write(3,*) 'i_Mamax=',idiag_Mamax
        write(3,*) 'i_divum=',idiag_divum
        write(3,*) 'i_divu2m=',idiag_divu2m
        write(3,*) 'i_u3u21m=',idiag_u3u21m
        write(3,*) 'i_u1u32m=',idiag_u1u32m
        write(3,*) 'i_u2u13m=',idiag_u2u13m
        write(3,*) 'i_uxfampm=',idiag_uxfampm
        write(3,*) 'i_uyfampm=',idiag_uyfampm
        write(3,*) 'i_uzfampm=',idiag_uzfampm
        write(3,*) 'i_uxfampim=',idiag_uxfampim
        write(3,*) 'i_uyfampim=',idiag_uyfampim
        write(3,*) 'i_uzfampim=',idiag_uzfampim
        write(3,*) 'i_uxpt=',idiag_uxpt
        write(3,*) 'i_uypt=',idiag_uypt
        write(3,*) 'i_uzpt=',idiag_uzpt
        write(3,*) 'i_fmassz=',idiag_fmassz
        write(3,*) 'i_fkinz=',idiag_fkinz
        write(3,*) 'i_ekinz=',idiag_ekinz
        write(3,*) 'i_uxmz=',idiag_uxmz
        write(3,*) 'i_uymz=',idiag_uymz
        write(3,*) 'i_uzmz=',idiag_uzmz
        write(3,*) 'i_uxmxy=',idiag_uxmxy
        write(3,*) 'i_uymxy=',idiag_uymxy
        write(3,*) 'i_uzmxy=',idiag_uzmxy
        write(3,*) 'i_ruxmxy=',idiag_ruxmxy
        write(3,*) 'i_ruymxy=',idiag_ruymxy
        write(3,*) 'i_ruzmxy=',idiag_ruzmxy
        write(3,*) 'i_ux2mxy=',idiag_ux2mxy
        write(3,*) 'i_uy2mxy=',idiag_uy2mxy
        write(3,*) 'i_uz2mxy=',idiag_uz2mxy
        write(3,*) 'i_rux2mxy=',idiag_rux2mxy
        write(3,*) 'i_ruy2mxy=',idiag_ruy2mxy
        write(3,*) 'i_ruz2mxy=',idiag_ruz2mxy
        write(3,*) 'i_ruxuymxy=',idiag_ruxuymxy
        write(3,*) 'i_ruxuzmxy=',idiag_ruxuzmxy
        write(3,*) 'i_ruyuzmxy=',idiag_ruyuzmxy
        write(3,*) 'i_uxmxz=',idiag_uxmxz
        write(3,*) 'i_uymxz=',idiag_uymxz
        write(3,*) 'i_uzmxz=',idiag_uzmxz
        write(3,*) 'i_ux2mxz=',idiag_ux2mxz
        write(3,*) 'i_uy2mxz=',idiag_uy2mxz
        write(3,*) 'i_uz2mxz=',idiag_uz2mxz
        write(3,*) 'i_u2mz=',idiag_u2mz
        write(3,*) 'i_urmphi=',idiag_urmphi
        write(3,*) 'i_upmphi=',idiag_upmphi
        write(3,*) 'i_uzmphi=',idiag_uzmphi
        write(3,*) 'i_u2mphi=',idiag_u2mphi
        write(3,*) 'i_oumphi=',idiag_oumphi
        write(3,*) 'i_ozmphi=',idiag_ozmphi
        write(3,*) 'i_urmr=',idiag_urmr
        write(3,*) 'i_upmr=',idiag_upmr
        write(3,*) 'i_uzmr=',idiag_uzmr
        write(3,*) 'i_ormr=',idiag_ormr
        write(3,*) 'i_opmr=',idiag_opmr
        write(3,*) 'i_ozmr=',idiag_ozmr
        write(3,*) 'i_u2mr=',idiag_u2mr
        write(3,*) 'i_fintm=',idiag_fintm
        write(3,*) 'i_fextm=',idiag_fextm
        write(3,*) 'i_duxdzma=',idiag_duxdzma
        write(3,*) 'i_duydzma=',idiag_duydzma
        write(3,*) 'i_totangmom=',idiag_totangmom
        write(3,*) 'i_rufm=',idiag_rufm
        write(3,*) 'i_fxbxm=',idiag_fxbxm
        write(3,*) 'i_fxbym=',idiag_fxbym
        write(3,*) 'i_fxbzm=',idiag_fxbzm
        write(3,*) 'nname=',nname
        write(3,*) 'iuu=',iuu
        write(3,*) 'iux=',iux
        write(3,*) 'iuy=',iuy
        write(3,*) 'iuz=',iuz
      endif
!
    endsubroutine rprint_hydro
!***********************************************************************
    subroutine get_slices_hydro(f,slices)
!
!  Write slices for animation of hydro variables.
!
!  26-jul-06/tony: coded
!
      use Cdata
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (slice_data) :: slices
!
!  Loop over slices
!
      select case (trim(slices%name))
!
!  Velocity field (code variable)
!
        case ('uu')
          if (slices%index >= 3) then
            slices%ready = .false.
          else
            slices%yz=f(slices%ix,m1:m2    ,n1:n2,iux+slices%index)
            slices%xz=f(l1:l2    ,slices%iy,n1:n2,iux+slices%index)
            slices%xy=f(l1:l2    ,m1:m2    ,slices%iz,iux+slices%index)
            slices%xy2=f(l1:l2    ,m1:m2    ,slices%iz2,iux+slices%index)
            slices%index = slices%index+1
            if (slices%index < 3) slices%ready = .true.
          endif
!
!  Divergence of velocity (derived variable)
!
        case ('divu')
          slices%yz=>divu_yz
          slices%xz=>divu_xz
          slices%xy=>divu_xy
          slices%xy2=>divu_xy2
          slices%ready = .true.
!
!  Velocity squared (derived variable)
!
        case ('u2')
          slices%yz=>u2_yz
          slices%xz=>u2_xz
          slices%xy=>u2_xy
          slices%xy2=>u2_xy2
          slices%ready = .true.
!
!  Vorticity (derived variable)
!
        case ('oo')
          if (slices%index == 3) then
            slices%ready = .false.
          else
            slices%index = slices%index+1
            slices%yz=>oo_yz(:,:,slices%index)
            slices%xz=>oo_xz(:,:,slices%index)
            slices%xy=>oo_xy(:,:,slices%index)
            slices%xy2=>oo_xy2(:,:,slices%index)
            if (slices%index < 3) slices%ready = .true.
          endif
!
!  Vorticity squared (derived variable)
!
        case ('o2')
          slices%yz=>o2_yz
          slices%xz=>o2_xz
          slices%xy=>o2_xy
          slices%xy2=>o2_xy2
          slices%ready = .true.
!
      endselect
!
    endsubroutine get_slices_hydro
!***********************************************************************
    subroutine calc_mflow
!
!  calculate mean flow field from xy- or z-averages
!
!   8-nov-02/axel: adapted from calc_mfield
!   9-nov-02/axel: allowed mean flow to be compressible
!
      use Cdata
      use Mpicomm
      use Sub
!
      logical,save :: first=.true.
      real, dimension(nx) :: uxmx,uymx,uzmx
      real, dimension(ny,nprocy) :: uxmy,uymy,uzmy
      real :: umx,umy,umz
      integer :: l,j
!
!  For vector output (of oo vectors) we need orms
!  on all processors. It suffices to have this for times when lout=.true.,
!  but we need to broadcast the result to all procs.
!
!
!  calculate orms (this requires that orms is set in print.in)
!  broadcast result to other processors
!
      if (idiag_orms/=0) then
        if (iproc==0) orms=fname(idiag_orms)
        call mpibcast_real(orms,1)
      endif

      if (.not.lroot) return
!
!  Magnetic energy in vertically averaged field
!  The uymxy and uzmxy must have been calculated,
!  so they are present on the root processor.
!
      if (idiag_umx/=0) then
        if(idiag_uymxy==0.or.idiag_uzmxy==0) then
          if(first) print*, 'calc_mflow:                    WARNING'
          if(first) print*, &
                  "calc_mflow: NOTE: to get umx, uymxy and uzmxy must also be set in zaver"
          if(first) print*, &
                  "calc_mflow:      We proceed, but you'll get umx=0"
          umx=0.
        else
          do l=1,nx
            uxmx(l)=sum(fnamexy(l,:,:,idiag_uxmxy))/(ny*nprocy)
            uymx(l)=sum(fnamexy(l,:,:,idiag_uymxy))/(ny*nprocy)
            uzmx(l)=sum(fnamexy(l,:,:,idiag_uzmxy))/(ny*nprocy)
          enddo
          umx=sqrt(sum(uxmx**2+uymx**2+uzmx**2)/nx)
        endif
        call save_name(umx,idiag_umx)
      endif
!
!  similarly for umy
!
      if (idiag_umy/=0) then
        if(idiag_uxmxy==0.or.idiag_uzmxy==0) then
          if(first) print*, 'calc_mflow:                    WARNING'
          if(first) print*, &
                  "calc_mflow: NOTE: to get umy, uxmxy and uzmxy must also be set in zaver"
          if(first) print*, &
                  "calc_mflow:       We proceed, but you'll get umy=0"
          umy=0.
        else
          do j=1,nprocy
          do m=1,ny
            uxmy(m,j)=sum(fnamexy(:,m,j,idiag_uxmxy))/nx
            uymy(m,j)=sum(fnamexy(:,m,j,idiag_uymxy))/nx
            uzmy(m,j)=sum(fnamexy(:,m,j,idiag_uzmxy))/nx
          enddo
          enddo
          umy=sqrt(sum(uxmy**2+uymy**2+uzmy**2)/(ny*nprocy))
        endif
        call save_name(umy,idiag_umy)
      endif
!
!  Kinetic energy in horizontally averaged flow
!  The uxmz and uymz must have been calculated,
!  so they are present on the root processor.
!
      if (idiag_umz/=0) then
        if(idiag_uxmz==0.or.idiag_uymz==0.or.idiag_uzmz==0) then
          if(first) print*,"calc_mflow:                    WARNING"
          if(first) print*, &
                  "calc_mflow: NOTE: to get umz, uxmz, uymz and uzmz must also be set in xyaver"
          if(first) print*, &
                  "calc_mflow:       This may be because we renamed zaver.in into xyaver.in"
          if(first) print*, &
                  "calc_mflow:       We proceed, but you'll get umz=0"
          umz=0.
        else
          umz=sqrt(sum(fnamez(:,:,idiag_uxmz)**2 &
                      +fnamez(:,:,idiag_uymz)**2 &
                      +fnamez(:,:,idiag_uzmz)**2)/(nz*nprocz))
        endif
        call save_name(umz,idiag_umz)
      endif
!
      first = .false.
    endsubroutine calc_mflow
!***********************************************************************
    subroutine remove_mean_momenta(f)
!
!  Substract mean x-momentum over density from the x-velocity field.
!  Useful to avoid unphysical winds in shearing box simulations.
!  Note: this is possibly not useful when there is rotation, because
!  then epicyclic motions don't usually grow catastrophically.
!
!  15-nov-06/tobi: coded
!
      use Cdata, only: ilnrho,iux,iuz,ldensity_nolog
      use Mpicomm, only: mpiallreduce_sum

      real, dimension (mx,my,mz,mfarray), intent (inout) :: f

      real, dimension (nx) :: rho,rho1,uu
      real :: fac,fsum_tmp,fsum
      real, dimension (iux:iuz) :: rum
      integer :: m,n,j

      if (lremove_mean_momenta) then

        rum = 0.0
        fac = 1.0/nwgrid

        do n = n1,n2
        do m = m1,m2
          if (ldensity_nolog) then
            rho = f(l1:l2,m,n,ilnrho)
          else
            rho = exp(f(l1:l2,m,n,ilnrho))
          endif
          do j=iux,iuz
            uu = f(l1:l2,m,n,j)
            rum(j) = rum(j) + fac*sum(rho*uu)
          enddo
        enddo
        enddo

        do j=iux,iuz
          fsum_tmp = rum(j)
          call mpiallreduce_sum(fsum_tmp,fsum)
          rum(j) = fsum
        enddo

        do n = n1,n2
        do m = m1,m2
          if (ldensity_nolog) then
            rho1 = 1.0/f(l1:l2,m,n,ilnrho)
          else
            rho1 = exp(-f(l1:l2,m,n,ilnrho))
          endif
          do j=iux,iuz
            f(l1:l2,m,n,j) = f(l1:l2,m,n,j) - rho1*rum(j)
          enddo
        enddo
        enddo

      elseif (lremove_mean_flow) then
        call remove_mean_flow(f)

      endif

    endsubroutine remove_mean_momenta
!***********************************************************************
    subroutine remove_mean_flow(f)
!
!  Substract mean x-flow over density from the x-velocity field.
!  Useful to avoid unphysical winds in shearing box simulations.
!  Note: this is possibly not useful when there is rotation, because
!  then epicyclic motions don't usually grow catastrophically.
!
!  22-may-07/axel: adapted from remove_mean_momenta
!
      use Cdata, only: iux,iuz,ldensity_nolog
      use Mpicomm, only: mpiallreduce_sum

      real, dimension (mx,my,mz,mfarray), intent (inout) :: f

      real, dimension (nx) :: uu
      real :: fac,fsum_tmp,fsum
      real, dimension (iux:iuz) :: um
      integer :: m,n,j

      if (lremove_mean_flow) then

        um = 0.0
        fac = 1.0/nwgrid

        do n = n1,n2
        do m = m1,m2
          do j=iux,iuz
            uu = f(l1:l2,m,n,j)
            um(j) = um(j) + fac*sum(uu)
          enddo
        enddo
        enddo

        do j=iux,iuz
          fsum_tmp = um(j)
          call mpiallreduce_sum(fsum_tmp,fsum)
          um(j) = fsum
        enddo

        do n = n1,n2
        do m = m1,m2
          do j=iux,iuz
            f(l1:l2,m,n,j) = f(l1:l2,m,n,j) - um(j)
          enddo
        enddo
        enddo

      endif

    endsubroutine remove_mean_flow
!***********************************************************************
    subroutine impose_profile_diffrot(f,df,prof_diffrot,ldiffrot_test)
!
!  forcing of differential rotation with a -(1/tau)*(u-uref) method
!
!  27-june-2007 dhruba: coded
!
      use Mpicomm
      use Cdata
      use Sub, only: step
      real :: slope,uinn,uext,zbot
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (nx) :: prof_amp1,prof_amp2
      character (len=labellen) :: prof_diffrot 
      logical :: ldiffrot_test
      integer :: llx
!
      select case(prof_diffrot)
!
!  diffrot profile from Brandenburg & Sandin (2004, A&A)
!
      case ('BS04')
      if (wdamp/=0.) then
        prof_amp1=ampl1_diffrot*(1.-step(x(l1:l2),rdampint,wdamp))
      else
        prof_amp1=ampl1_diffrot
      endif
      df(l1:l2,m,n,iuy)=df(l1:l2,m,n,iuy)-tau_diffrot1*(f(l1:l2,m,n,iuy) &
        -prof_amp1*cos(kx_diffrot*x(l1:l2))**xexp_diffrot*cos(z(n)))
!
!  vertical shear profile
!
      case ('vertical_shear')
      zbot=xyz0(3)
      df(l1:l2,m,n,iuy)=df(l1:l2,m,n,iuy) &
        -tau_diffrot1*(f(l1:l2,m,n,iuy)-ampl1_diffrot*cos(kz_diffrot*(z(n)-zbot)))
!
!  vertical shear profile
!
      case ('vertical_shear_x')
      zbot=xyz0(3)
      df(l1:l2,m,n,iux)=df(l1:l2,m,n,iux) &
        -tau_diffrot1*(f(l1:l2,m,n,iux)-ampl1_diffrot*cos(kz_diffrot*(z(n)-zbot)))
!
!  write differential rotation in terms of Gegenbauer polynomials
!  Omega = Omega0 + Omega2*P31(costh)/sinth + Omega4*P51(costh)/sinth + ...
!  Note that P31(theta)/sin(theta) = (3/2) * [1 - 5*cos(theta)^2 ]
!
      case ('solar_simple')
      prof_amp1=ampl1_diffrot*step(x(l1:l2),x1_ff_uu,width_ff_uu)
      prof_amp2=1.-step(x(l1:l2),x2_ff_uu,width_ff_uu)
      if(lspherical_coords) then
        df(l1:l2,m,n,iuz)=df(l1:l2,m,n,iuz)-tau_diffrot1*(f(l1:l2,m,n,iuz) &
          -prof_amp1*(1.5-7.5*costh(m)*costh(m)))
      else
        do llx=l1,l2
          df(llx,m,n,iuz)=df(llx,m,n,iuz)-tau_diffrot1*( f(llx,m,n,iuz) &
               -ampl1_diffrot*cos(x(llx))*cos(y(m))*cos(y(m)) )
!            -prof_amp1*cos(20.*x(llx))*cos(20.*y(m)) )
        enddo
      endif
      if(ldiffrot_test) then
        f(l1:l2,m,n,iux) = 0.
        f(l1:l2,m,n,iuy) = 0.
        if(lspherical_coords) then
          f(l1:l2,m,n,iuz) = prof_amp1*(1.5-7.5*costh(m)*costh(m))
        else
          do llx=l1,l2 
            f(llx,m,n,iuz) = prof_amp1(llx)*cos(y(m))*cos(y(m)) 
!prof_amp1(llx)*cos(y(m))*cos(y(m)) 
          enddo
        endif
        f(l1:l2,m,n,iuz) = prof_amp1*(1.5-7.5*costh(m)*costh(m))
       else
       endif
!
!  radial_uniform_shear
!  uphi = slope*x + uoffset
!
      case('radial_uniform_shear')
       uinn = omega_in*x(l1)
       uext = omega_out*x(l2)
       slope = (uext - uinn)/(x(l2)-x(l1))
       prof_amp1=  slope*x(l1:l2)+(uinn*x(l2)- uext*x(l1))/(x(l2)-x(l1)) 
       df(l1:l2,m,n,iuz)=df(l1:l2,m,n,iuz)-tau_diffrot1*(f(l1:l2,m,n,iuz) &
             - prof_amp1)
!
!  no profile matches
!
      case default
          if(lroot) print*,'duu_dt: No such profile ',trim(prof_diffrot)
      endselect
!
    endsubroutine impose_profile_diffrot
!***********************************************************************
    subroutine impose_velocity_ceiling(f)
!
!  Impose a maximum velocity by setting all higher velocities to the maximum
!  value (velocity_ceiling). Useful for debugging purposes.
!
!  13-aug-2007/anders: implemented.
!
      use Cdata
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
!
      if (velocity_ceiling>0.0) then
        where (f(:,:,:,iux:iuz)> velocity_ceiling) &
            f(:,:,:,iux:iuz)= velocity_ceiling
        where (f(:,:,:,iux:iuz)<-velocity_ceiling) &
            f(:,:,:,iux:iuz)=-velocity_ceiling
      endif
!
    endsubroutine impose_velocity_ceiling
!***********************************************************************
endmodule Hydro
