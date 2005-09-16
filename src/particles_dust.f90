! $Id: particles_dust.f90,v 1.33 2005-09-16 08:33:32 ajohan Exp $
!
!  This module takes care of everything related to dust particles
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
!
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! MPVAR CONTRIBUTION 6
! CPARAM logical, parameter :: lparticles=.true.
!
!***************************************************************
module Particles

  use Cdata
  use Particles_cdata
  use Particles_sub
  use Messages

  implicit none

  include 'particles.h'

  real :: xp0=0.0, yp0=0.0, zp0=0.0, vpx0=0.0, vpy0=0.0, vpz0=0.0
  real :: delta_vp0=1.0, tausp=0.0, tausp1=0.0, eps_dtog=0.01
  real :: nu_epicycle=0.0, nu_epicycle2=0.0
  real :: beta_dPdr_dust=0.0, beta_dPdr_dust_scaled=0.0
  real :: tausgmin=0.0, tausg1max=0.0, cdtp=0.2
  real :: gravx=0.0, gravz=0.0, kx_gg=1.0, kz_gg=1.0
  real :: Ri0=0.25, eps1=0.5
  integer :: it_dustburst=0
  logical :: ldragforce_gas=.false.
  character (len=labellen) :: initxxp='origin', initvvp='nothing'
  character (len=labellen) ::gravx_profile='zero',  gravz_profile='zero'

  namelist /particles_init_pars/ &
      initxxp, initvvp, xp0, yp0, zp0, vpx0, vpy0, vpz0, delta_vp0, &
      bcpx, bcpy, bcpz, tausp, beta_dPdr_dust, &
      gravz_profile, gravz, kz_gg, rhop_tilde, eps_dtog, nu_epicycle, &
      gravx_profile, gravz_profile, gravx, gravz, kx_gg, kz_gg, Ri0, eps1

  namelist /particles_run_pars/ &
      bcpx, bcpy, bcpz, tausp, dsnap_par_minor, beta_dPdr_dust, &
      ldragforce_gas, rhop_tilde, eps_dtog, tausgmin, cdtp, &
      linterp_reality_check, nu_epicycle, &
      gravx_profile, gravz_profile, gravx, gravz, kx_gg, kz_gg, &
      it_dustburst

  integer :: idiag_xpm=0, idiag_ypm=0, idiag_zpm=0
  integer :: idiag_xp2m=0, idiag_yp2m=0, idiag_zp2m=0
  integer :: idiag_vpxm=0, idiag_vpym=0, idiag_vpzm=0
  integer :: idiag_vpx2m=0, idiag_vpy2m=0, idiag_vpz2m=0
  integer :: idiag_npm=0, idiag_np2m=0, idiag_npmax=0, idiag_npmin=0
  integer :: idiag_rhopm=0, idiag_rhopmax=0, idiag_dtdragp=0, idiag_npmz=0

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
           "$Id: particles_dust.f90,v 1.33 2005-09-16 08:33:32 ajohan Exp $")
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
!  Check that the fp and dfp arrays are big enough.
!
      if (npvar > mpvar) then
        if (lroot) write(0,*) 'npvar = ', npvar, ', mpvar = ', mpvar
        call stop_it('register_particles: npvar > mpvar')
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
      use EquationOfState, only: cs0
!
      logical :: lstarting
!
      real :: rhom
      integer, dimension (0:ncpus-1) :: ipar1, ipar2
!
!  Distribute particles evenly among processors to begin with.
!
      if (lstarting) call dist_particles_evenly_procs(npar_loc,ipar)
!
!  Size of box at local processor is needed for particle boundary conditions.
!
      Lxyz_loc(1)=Lxyz(1)/nprocx
      Lxyz_loc(2)=Lxyz(2)/nprocy
      Lxyz_loc(3)=Lxyz(3)/nprocz
      xyz0_loc(1)=xyz0(1)
      xyz0_loc(2)=xyz0(2)+ipy*Lxyz_loc(2)
      xyz0_loc(3)=xyz0(3)+ipz*Lxyz_loc(3)
      xyz1_loc(1)=xyz1(1)
      xyz1_loc(2)=xyz0(2)+(ipy+1)*Lxyz_loc(2)
      xyz1_loc(3)=xyz0(3)+(ipz+1)*Lxyz_loc(3)
!
!  The inverse stopping time is needed for drag force.
!
      tausp1=0.0
      if (tausp/=0.) tausp1=1/tausp
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
        if (lgrav) then
          rhom=sqrt(2*pi)*1.0*1.0/Lz  ! rhom = Sigma/Lz, Sigma=sqrt(2*pi)*H*rho1
        else
          rhom=1.0
        endif
        rhop_tilde=eps_dtog*rhom*nxgrid*nygrid*nzgrid/npar
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
!  Calculate nu_epicycle**2 for gravity.
!
      if (nu_epicycle/=0.0) then
        gravz_profile='linear'
        nu_epicycle2=nu_epicycle**2
      endif
!
!  Calculate inverse of minimum gas friction time.
!
      if (tausgmin/=0.0) then
        tausg1max=1.0/tausgmin
        if (lroot) print*, 'initialize_particles: '// &
            'minimum gas friction time tausgmin=', tausgmin
      endif
!
!  Write constants to disc.
!      
      if (lroot) then
        open (1,file=trim(datadir)//'/pc_constants.pro')
          write (1,*) 'rhop_tilde=', rhop_tilde
        close (1)
      endif
!
    endsubroutine initialize_particles
!***********************************************************************
    subroutine init_particles(f,fp)
!
!  Initial positions and velocities of dust particles.
!
!  29-dec-04/anders: coded
!
      use Boundcond
      use General, only: random_number_wrapper
      use Mpicomm, only: stop_it
      use Sub
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mpar_loc,mpvar) :: fp
!
      real, dimension (3) :: uup
      real :: r, p
      integer :: k
!
      intent (in) :: f
      intent (out) :: fp
!
!  Initial particle position.
!
      select case(initxxp)

      case ('origin')
        if (lroot) print*, 'init_particles: All particles at origin'
        fp(1:npar_loc,ixp:izp)=0.

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
        if (nxgrid/=1) fp(1:npar_loc,ixp)=xyz0_loc(1)+fp(1:npar_loc,ixp)*Lxyz_loc(1)
        if (nygrid/=1) fp(1:npar_loc,iyp)=xyz0_loc(2)+fp(1:npar_loc,iyp)*Lxyz_loc(2)
        if (nzgrid/=1) fp(1:npar_loc,izp)=xyz0_loc(3)+fp(1:npar_loc,izp)*Lxyz_loc(3)

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
        if (nxgrid/=1) fp(1:npar_loc,ixp)=xyz0_loc(1)+fp(1:npar_loc,ixp)*Lxyz_loc(1)
        if (nygrid/=1) fp(1:npar_loc,iyp)=xyz0_loc(2)+fp(1:npar_loc,iyp)*Lxyz_loc(2)

      case ('constant-Ri')
        call constant_richardson(fp,f)

      case default
        if (lroot) print*, 'init_particles: No such such value for initxxp: ', &
            trim(initxxp)
        call stop_it("")

      endselect
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
!  Initial particle velocity.
!
      select case(initvvp)

      case ('nothing')
        if (lroot) print*, 'init_particles: No particle velocity set'
      case ('zero')
        if (lroot) print*, 'init_particles: Zero particle velocity'
        fp(1:npar_loc,ivpx:ivpz)=0.

      case ('constant')
        if (lroot) print*, 'init_particles: Constant particle velocity'
        if (lroot) print*, 'init_particles: vpx0, vpy0, vpz0=', vpx0, vpy0, vpz0
        fp(1:npar_loc,ivpx)=vpx0
        fp(1:npar_loc,ivpy)=vpy0
        fp(1:npar_loc,ivpz)=vpz0

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

      case ('follow-gas')
        if (lroot) &
            print*, 'init_particles: Particle velocity equal to gas velocity'
        do k=1,npar_loc
          call interpolate_3d_1st(f,iux,iuz,fp(k,ixp:izp),uup)
          fp(k,ivpx:ivpz) = uup
        enddo

      case default
        if (lroot) print*, 'init_particles: No such such value for initvvp: ', &
            trim(initvvp)
        call stop_it("")

      endselect
!
    endsubroutine init_particles
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
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      integer, parameter :: nz_inc=10
      real, dimension (nz_inc*nz) :: z_dense, eps
      real, dimension (nx) :: np, eps_penc
      real :: r, p, Hg, Hd, frac, rho1, Sigmad, Sigmad_num, Xi, fXi, dfdXi
      real :: dz_dense, eps_point, z00_dense
      integer :: nz_dense=nz_inc*nz, npar_bin
      integer :: i, i0, k
!
!  Calculate dust "scale height".
!
      rho1=1.0
      Hg=1.0
      Sigmad=eps_dtog*rho1*Hg*sqrt(2*pi)
      Hd = sqrt(Ri0)*abs(beta_glnrho_scaled(1))/(2*gamma)*1.0
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
          i0, ' particles according to a Ri=const'
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
        lfirstpoint=(imn==1)
        llastpoint=(imn==(ny*nz))

        eps_penc=1/sqrt(z(n)**2/Hd**2+1/(1+eps1)**2)-1
        where (eps_penc<=0.0) eps_penc=0.0

        f(l1:l2,m,n,iux) = f(l1:l2,m,n,iux) - &
            1/gamma*cs20*beta_glnrho_scaled(1)*eps_penc*tausp/ &
            (1.0+2*eps_penc+eps_penc**2+(Omega*tausp)**2)
        f(l1:l2,m,n,iuy) = f(l1:l2,m,n,iuy) + &
            1/gamma*cs20*beta_glnrho_scaled(1)*(1+eps_penc+(Omega*tausp)**2)/ &
            (2*Omega*(1.0+2*eps_penc+eps_penc**2+(Omega*tausp)**2))
      enddo
!
!  Set particle velocity.
!      
      do k=1,npar_loc

        eps_point=1/sqrt(fp(k,izp)**2/Hd**2+1/(1+eps1)**2)-1
        if (eps_point<=0.0) eps_point=0.0

        fp(k,ivpx) = fp(k,ivpx) + &
            1/gamma*cs20*beta_glnrho_scaled(1)*tausp/ &
            (1.0+2*eps_point+eps_point**2+(Omega*tausp)**2)
        fp(k,ivpy) = fp(k,ivpy) + &
            1/gamma*cs20*beta_glnrho_scaled(1)*(1+eps_point)/ &
            (2*Omega*(1.0+2*eps_point+eps_point**2+(Omega*tausp)**2))

      enddo
!
    endsubroutine constant_richardson
!***********************************************************************
    subroutine dxxp_dt(f,fp,dfp)
!
!  Evolution of dust particle position.
!
!  02-jan-05/anders: coded
!
      use General, only: random_number_wrapper, random_seed_wrapper
!      
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mpar_loc,mpvar) :: fp, dfp
!
      real :: ran_xp, ran_yp, ran_zp
      integer, dimension (mseed) :: iseed_org
      integer :: k
      logical :: lheader, lfirstcall=.true.
!
      intent (in) :: f, fp
      intent (out) :: dfp
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
      if (nxgrid/=1) &
          dfp(1:npar_loc,ixp) = dfp(1:npar_loc,ixp) + fp(1:npar_loc,ivpx)
      if (nygrid/=1) &
          dfp(1:npar_loc,iyp) = dfp(1:npar_loc,iyp) + fp(1:npar_loc,ivpy)
      if (nzgrid/=1) &
          dfp(1:npar_loc,izp) = dfp(1:npar_loc,izp) + fp(1:npar_loc,ivpz)
!
!  With shear there is an extra term due to the background shear flow.
!
      if (lshear.and.nygrid/=0) dfp(1:npar_loc,iyp) = &
          dfp(1:npar_loc,iyp) - qshear*Omega*fp(1:npar_loc,ixp)
!
!  Displace all dust particles a random distance of around the size of
!  a grid cell.
!
      if (it_dustburst/=0 .and. it==it_dustburst) then      
        if (lroot.and.itsub==1) print*, 'dxxp_dt: dust burst!'
        if (itsub==1) call random_seed_wrapper(get=iseed_org)
        call random_seed_wrapper(put=iseed_org)  ! get same number for all itsub
        do k=1,npar_loc
          if (nxgrid/=1) then
            call random_number_wrapper(ran_xp)
            dfp(k,ixp) = dfp(k,ixp) + dx/dt*(2*ran_xp-1.0)
          endif
          if (nxgrid/=1) then
            call random_number_wrapper(ran_yp)
            dfp(k,iyp) = dfp(k,iyp) + dy/dt*(2*ran_yp-1.0)
          endif
          if (nzgrid/=1) then
            call random_number_wrapper(ran_zp)
            dfp(k,izp) = dfp(k,izp) + dz/dt*(2*ran_zp-1.0)
          endif
        enddo
      endif
!
      if (lfirstcall) lfirstcall=.false.
!
    endsubroutine dxxp_dt
!***********************************************************************
    subroutine dvvp_dt(f,df,fp,dfp)
!
!  Evolution of dust particle velocity.
!
!  29-dec-04/anders: coded
!
      use Cdata
      use EquationOfState, only: cs20, gamma
      use Global
      use Mpicomm, only: stop_it
      use Sub
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (mpar_loc,mpvar) :: fp, dfp
!
      real, dimension (nx,3) :: uupsum
      real, dimension (nx) :: np, tausg1, rho
      real, dimension (3) :: uup
      real :: Omega2, cp1tilde
      integer :: i,k
      logical :: lheader, lfirstcall=.true.
!
      intent (in) :: f, fp
      intent (out) :: dfp
!
!  Print out header information in first time step.
!
      lheader=lfirstcall .and. lroot
!
!  Identify module.
!
      if (lheader) print*,'dvvp_dt: Calculate dvvp_dt'
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
!  Add drag force if stopping time is not infinite.
!
      if (tausp1/=0.) then
        if (lheader) print*,'dvvp_dt: Add drag force; tausp=', tausp
!
!  Use interpolation to calculate gas velocity at position of particles.
!          
        do k=1,npar_loc
          call interpolate_3d_1st(f,iux,iuz,fp(k,ixp:izp),uup,ipar(k))
          dfp(k,ivpx:ivpz) = dfp(k,ivpx:ivpz) - tausp1*(fp(k,ivpx:ivpz)-uup)
        enddo
!
!  Back-reaction from dust particles on the gas.
!        
        if (ldragforce_gas) then
          call reset_global('np')
          call reset_global('uupsum')
          do k=1,npar_loc
            call map_xxp_vvp_grid(fp(k,ixp:izp),fp(k,ivpx:ivpz))
          enddo
!
!  Loop over pencils to avoid global arrays.
!          
          do imn=1,ny*nz
            n=nn(imn); m=mm(imn)
            lfirstpoint=(imn==1)
            llastpoint=(imn==(ny*nz))
            call get_global(np,m,n,'np')
            call get_global(uupsum,m,n,'uupsum')
            if (ldensity_nolog) then
              rho=f(l1:l2,m,n,ilnrho)
            else
              rho=exp(f(l1:l2,m,n,ilnrho))
            endif
            tausg1 = rhop_tilde*np*tausp1/rho
!
!  Minimum friction time of the gas.
!            
            if (tausgmin/=0.0) where (tausg1>=tausg1max) tausg1=tausg1max
!
!  Add drag force on gas.
!              
            do i=1,3
              where (np/=0) df(l1:l2,m,n,iux-1+i) = df(l1:l2,m,n,iux-1+i) - &
                  tausg1*(f(l1:l2,m,n,iux-1+i)-uupsum(:,i)/np(:))
            enddo
!
!  Drag force contribution to time-step.
!            
            if (lfirst.and.ldt) dt1_max=max(dt1_max,(tausp1+tausg1)/cdtp)
            if (ldiagnos.and.idiag_dtdragp/=0) &
                call max_mn_name((tausp1+tausg1)/cdtp,idiag_dtdragp,l_dt=.true.)
!            
          enddo
        else
!
!  No back-reaction on gas.
!            
          if (lfirst.and.ldt) dt1_max=max(dt1_max,tausp1/cdtp)
          if (ldiagnos.and.idiag_dtdragp/=0) &
              call max_mn_name(spread(tausp1/cdtp,1,nx),idiag_dtdragp,l_dt=.true.)
        endif
!          
      endif
!
!  Add constant background pressure gradient beta=alpha*H0/r0, where alpha
!  comes from a global pressure gradient P = P0*(r/r0)^alpha.
!  (the term must be added to the dust equation of motion when measuring
!  velocities relative to the shear flow modified by the global pressure grad.)
!
      if (beta_dPdr_dust/=0.0) then
        dfp(1:npar_loc,ivpx) = &
            dfp(1:npar_loc,ivpx) + 1/gamma*cs20*beta_dPdr_dust_scaled
      endif
!
!  Gravity on the particles.
!
      select case (gravx_profile)

        case ('zero')
          if (lheader) print*, 'dvvp_dt: No gravity in x-direction.'
 
        case ('sinusoidal')
          if (lheader) &
              print*, 'dvvp_dt: Sinusoidal gravity field in x-direction.'
          dfp(1:npar_loc,ivpx)=dfp(1:npar_loc,ivpx) - &
              gravx*sin(kx_gg*fp(1:npar_loc,ixp))
 
        case ('default')
          call fatal_error('dvvp_dt','chosen gravx_profile is not valid!')

      endselect

      select case (gravz_profile)

        case ('zero')
          if (lheader) print*, 'dvvp_dt: No gravity in z-direction.'
 
        case ('linear')
          if (lheader) print*, 'dvvp_dt: Linear gravity field in z-direction.'
          dfp(1:npar_loc,ivpz)=dfp(1:npar_loc,ivpz) - &
              nu_epicycle2*fp(1:npar_loc,izp)
 
        case ('sinusoidal')
          if (lheader) &
              print*, 'dvvp_dt: Sinusoidal gravity field in z-direction.'
          dfp(1:npar_loc,ivpz)=dfp(1:npar_loc,ivpz) - &
              gravz*sin(kz_gg*fp(1:npar_loc,izp))
 
        case ('default')
          call fatal_error('dvvp_dt','chosen gravz_profile is not valid!')

      endselect
!
!  Diagnostic output
!
      if (ldiagnos) then
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
        if (idiag_rhopm/=0) call sum_par_name_nw(4/3.*pi*rhops*fp(1:npar_loc,iap)**3*np_tilde,idiag_rhopm)
        if (idiag_npm/=0 .or. idiag_np2m/=0 .or. idiag_npmax/=0 .or. &
            idiag_npmin/=0 .or. idiag_rhopmax/=0) then
          if (.not. ldragforce_gas) then
            call reset_global('np')
            do k=1,npar_loc
              call map_xxp_grid(fp(k,ixp:izp))
            enddo
          endif
          do imn=1,ny*nz
            n=nn(imn); m=mm(imn)
            lfirstpoint=(imn==1)
            llastpoint=(imn==(ny*nz))
            call get_global(np,m,n,'np')
            if (idiag_npm/=0)     call sum_mn_name(np,idiag_npm)
            if (idiag_np2m/=0)    call sum_mn_name(np**2,idiag_np2m)
            if (idiag_npmax/=0)   call max_mn_name(np,idiag_npmax)
            if (idiag_npmin/=0)   call max_mn_name(-np,idiag_npmin,lneg=.true.)
            if (idiag_rhopmax/=0) call max_mn_name(rhop_tilde*np,idiag_rhopmax)
            if (idiag_npmz/=0)    call xysum_mn_name_z(np,idiag_npmz)
          enddo
        endif
      endif
!
      if (lfirstcall) lfirstcall=.false.
!
    endsubroutine dvvp_dt
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
      integer :: iname,inamez
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
      endif
!
!  Reset everything in case of reset
!
      if (lreset) then
        idiag_xpm=0; idiag_ypm=0; idiag_zpm=0
        idiag_xp2m=0; idiag_yp2m=0; idiag_zp2m=0
        idiag_vpxm=0; idiag_vpym=0; idiag_vpzm=0
        idiag_vpx2m=0; idiag_vpy2m=0; idiag_vpz2m=0
        idiag_npm=0; idiag_np2m=0; idiag_npmax=0; idiag_npmin=0
        idiag_rhopm=0; idiag_rhopmax=0; idiag_dtdragp=0; idiag_npmz=0
      endif
!
!  Run through all possible names that may be listed in print.in
!
      if (lroot .and. ip<14) print*,'rprint_particles: run through parse list'
      do iname=1,nname
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
        call parse_name(iname,cname(iname),cform(iname),'dtdragp',idiag_dtdragp)
        call parse_name(iname,cname(iname),cform(iname),'npm',idiag_npm)
        call parse_name(iname,cname(iname),cform(iname),'np2m',idiag_np2m)
        call parse_name(iname,cname(iname),cform(iname),'npmax',idiag_npmax)
        call parse_name(iname,cname(iname),cform(iname),'npmin',idiag_npmin)
        call parse_name(iname,cname(iname),cform(iname),'rhopm',idiag_rhopm)
        call parse_name(iname,cname(iname),cform(iname),'rhopmax',idiag_rhopmax)
        call parse_name(iname,cname(iname),cform(iname),'nmigmax',idiag_nmigmax)
      enddo
!
!  check for those quantities for which we want z-averages
!
      do inamez=1,nnamez
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'npmz',idiag_npmz)
      enddo
!
    endsubroutine rprint_particles
!***********************************************************************

endmodule Particles
