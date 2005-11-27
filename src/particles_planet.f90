! $Id: particles_planet.f90,v 1.4 2005-11-27 10:33:44 ajohan Exp $
!
!  This module takes care of everything related to planet particles.
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

  real, dimension(npar) :: xp0=0.0, yp0=0.0, zp0=0.0
  real, dimension(npar) :: vpx0=0.0, vpy0=0.0, vpz0=0.0
  real :: delta_vp0=1.0, cdtp=0.2
  character (len=labellen) :: initxxp='origin', initvvp='nothing'
  logical :: lmigrate=.false.

  namelist /particles_init_pars/ &
      initxxp, initvvp, xp0, yp0, zp0, vpx0, vpy0, vpz0, delta_vp0, &
      bcpx, bcpy, bcpz

  namelist /particles_run_pars/ &
      bcpx, bcpy, bcpz, dsnap_par_minor, cdtp, linterp_reality_check, &
      lmigrate

  integer :: idiag_xpm=0, idiag_ypm=0, idiag_zpm=0
  integer :: idiag_xp2m=0, idiag_yp2m=0, idiag_zp2m=0
  integer :: idiag_vpxm=0, idiag_vpym=0, idiag_vpzm=0
  integer :: idiag_vpx2m=0, idiag_vpy2m=0, idiag_vpz2m=0
  integer :: idiag_vel=0, idiag_rad=0
 
  contains

!***********************************************************************
    subroutine register_particles()
!
!  Set up indices for access to the fp and dfp arrays
!
!  17-nov-05/anders+wlad: adapted
!
      use Mpicomm, only: stop_it
!
      integer :: k
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_particles: called twice')
      first = .false.
!
      if (lroot) call cvs_id( &
           "$Id: particles_planet.f90,v 1.4 2005-11-27 10:33:44 ajohan Exp $")
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
!  Check that we aren't registering too many auxilary variables
!
      if (naux > maux) then
        if (lroot) write(0,*) 'naux = ', naux, ', maux = ', maux
            call stop_it('register_particles: naux > maux')
      endif
!
!  Set npar_loc=npar for non-parallel implementation of few particles.
!
      npar_loc=npar
      do k=1,npar
        ipar(k)=k
      enddo
!
    endsubroutine register_particles
!***********************************************************************
    subroutine initialize_particles(lstarting)
!
!  Perform any post-parameter-read initialization i.e. calculate derived
!  parameters.
!
!  17-nov-05/anders+wlad: adapted
!
      logical :: lstarting
!
    endsubroutine initialize_particles
!***********************************************************************
    subroutine init_particles(f,fp,ineargrid)
!
!  Initial positions and velocities of planet particles.
!
!  17-nov-05/anders+wlad: adapted
!
      use Boundcond
      use General, only: random_number_wrapper
      use Mpicomm, only: stop_it
      use Sub
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mpar_loc,mpvar) :: fp
      integer, dimension (mpar_loc,3) :: ineargrid
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
        fp(1:npar,ixp:izp)=0.

      case ('constant')
        if (lroot) &
            print*, 'init_particles: All particles at x,y,z=', xp0, yp0, zp0
        fp(:,ixp)=xp0
        fp(:,iyp)=yp0
        fp(:,izp)=zp0

      case ('random')
        if (lroot) print*, 'init_particles: Random particle positions'
        do k=1,npar
          if (nxgrid/=1) call random_number_wrapper(fp(k,ixp))
          if (nygrid/=1) call random_number_wrapper(fp(k,iyp))
          if (nzgrid/=1) call random_number_wrapper(fp(k,izp))
        enddo
        if (nxgrid/=1) fp(1:npar,ixp)=xyz0(1)+fp(1:npar,ixp)*Lxyz(1)
        if (nygrid/=1) fp(1:npar,iyp)=xyz0(2)+fp(1:npar,iyp)*Lxyz(2)
        if (nzgrid/=1) fp(1:npar,izp)=xyz0(3)+fp(1:npar,izp)*Lxyz(3)

      case default
        if (lroot) print*, 'init_particles: No such such value for initxxp: ', &
            trim(initxxp)
        call stop_it("")

      endselect
!      
!  Particles are not allowed to be present in non-existing dimensions.
!  This would give huge problems with interpolation later.
!
      if (nxgrid==1) fp(1:npar,ixp)=x(nghost+1)
      if (nygrid==1) fp(1:npar,iyp)=y(nghost+1)
      if (nzgrid==1) fp(1:npar,izp)=z(nghost+1)
!
!  Redistribute particles among processors (now that positions are determined).
!
!      call boundconds_particles(fp,npar,ipar)
!
!  Initial particle velocity.
!
      select case(initvvp)

      case ('nothing')
        if (lroot) print*, 'init_particles: No particle velocity set'
      case ('zero')
        if (lroot) print*, 'init_particles: Zero particle velocity'
        fp(1:npar,ivpx:ivpz)=0.

      case ('constant')
        if (lroot) print*, 'init_particles: Constant particle velocity'
        if (lroot) print*, 'init_particles: vpx0, vpy0, vpz0=', vpx0, vpy0, vpz0
        fp(:,ivpx)=vpx0
        fp(:,ivpy)=vpy0
        fp(:,ivpz)=vpz0

      case ('random')
        if (lroot) print*, 'init_particles: Random particle velocities; '// &
            'delta_vp0=', delta_vp0
        do k=1,npar
          call random_number_wrapper(fp(k,ivpx))
          call random_number_wrapper(fp(k,ivpy))
          call random_number_wrapper(fp(k,ivpz))
        enddo
        fp(1:npar,ivpx) = -delta_vp0 + fp(1:npar,ivpx)*2*delta_vp0
        fp(1:npar,ivpy) = -delta_vp0 + fp(1:npar,ivpy)*2*delta_vp0
        fp(1:npar,ivpz) = -delta_vp0 + fp(1:npar,ivpz)*2*delta_vp0

      case ('follow-gas')
        if (lroot) &
            print*, 'init_particles: Particle velocity equal to gas velocity'
        do k=1,npar
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
    subroutine dxxp_dt(f,fp,dfp,ineargrid)
!
!  Evolution of planet particle position.
!
!  17-nov-05/anders+wlad: adapted
!
      use General, only: random_number_wrapper, random_seed_wrapper
!      
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mpar_loc,mpvar) :: fp, dfp
      integer, dimension (mpar_loc,3) :: ineargrid
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
          dfp(1:npar,ixp) = dfp(1:npar,ixp) + fp(1:npar,ivpx)
      if (nygrid/=1) &
          dfp(1:npar,iyp) = dfp(1:npar,iyp) + fp(1:npar,ivpy)
      if (nzgrid/=1) &
          dfp(1:npar,izp) = dfp(1:npar,izp) + fp(1:npar,ivpz)
!
!  With shear there is an extra term due to the background shear flow.
!
      if (lshear.and.nygrid/=0) dfp(1:npar,iyp) = &
          dfp(1:npar,iyp) - qshear*Omega*fp(1:npar,ixp)
!
      if (lfirstcall) lfirstcall=.false.
!
    endsubroutine dxxp_dt
!***********************************************************************
    subroutine dvvp_dt(f,df,fp,dfp)
!
!  Evolution of planet velocity and star velocity
!  It can't change gas velocity, so it will call
!  gravity_companion and gravity_star just to set the
!  gravity field as global variable. 
!
!  17-nov-05/anders+wlad: coded
!
      use Cdata
      use EquationOfState, only: cs20, gamma
      use Mpicomm, only: stop_it
      use Sub
      use Gravity,only: g0,r0_pot,n_pot
      use Planet, only: gc,b,gravity_companion
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (mpar_loc,mpvar) :: fp, dfp
      real, dimension (mpar_loc) :: vel,dist
!
      real, dimension (nx) :: re, grav_gas
      real :: Omega2,rp0_pot,rsep
      integer :: i, k, ix0, iy0, iz0
      logical :: lheader, lfirstcall=.true.
      real :: ax,ay,axs,ays
!
      intent (in) :: fp
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
         dfp(1:npar,ivpx) = dfp(1:npar,ivpx) + Omega2*fp(1:npar,ivpy)
         dfp(1:npar,ivpy) = dfp(1:npar,ivpy) - Omega2*fp(1:npar,ivpx)
!
!  With shear there is an extra term due to the background shear flow.
!          
         if (lshear) dfp(1:npar,ivpy) = &
              dfp(1:npar,ivpy) + qshear*Omega*fp(1:npar,ivpx)
      endif
!
!  Move particles due to the gravity of each other
!
      ax = fp(1,ixp) ; axs = fp(2,ixp) 
      ay = fp(1,iyp) ; ays = fp(2,iyp) 
!
      rsep = sqrt((ax-axs)**2 + (ay-ays)**2)
!      
!  Planet's gravity on star
!
      dfp(2,ivpx) = dfp(2,ivpx) - gc/rsep**3 * (axs-ax)
      dfp(2,ivpy) = dfp(2,ivpy) - gc/rsep**3 * (ays-ay)
!
!  Star's gravity on planet
!
      dfp(1,ivpx) = dfp(1,ivpx) - g0/rsep**3 * (ax-axs)
      dfp(1,ivpy) = dfp(1,ivpy) - g0/rsep**3 * (ay-ays)
!
!  Acceleration of particles due to gas gravity.
!
!
      rp0_pot = b
!
!  Acceleration due to gas gravity if lmigrate is present
!
      do m=m1,m2
         do n=n1,n2
!
            if (lmigrate) then
!
               do k=1,npar
                  re = sqrt((x(l1:l2) - fp(k,ixp))**2 +  (y(m) - fp(k,iyp))**2)
                  !
                  ! this thing here assumes G=1, which is NOT what I use 
                  ! thru the simulation. Or I change g0 = 1e10, or I scale
                  ! it down by G. Thing about it later on, as now the results
                  ! will depend on the mass of the disk.
                  !
                  grav_gas = f(l1:l2,m,n,ilnrho)*dx*dy*re/ &
                       (re**2 + rp0_pot**2)**(-1.5)
!                  
                  dfp(k,ivpx) = dfp(k,ivpx) & 
                       + sum(grav_gas * (x(l1:l2) - fp(k,ixp))/re)
!                  
                  dfp(k,ivpy) = dfp(k,ivpy) & 
                       + sum(grav_gas * (y(  m  ) - fp(k,iyp))/re)
               enddo
            endif
!
!  Reset gravity field (star+planet) as global variable
!
            call gravity_companion(f,df,fp,g0,r0_pot,n_pot)
!
         enddo
      enddo
!
!  Add relative velocity and distance as diagnostic variables
!  Don't understand why I need to fill a whole array
! 
      dist(1:npar) = rsep 
      vel(1:npar)  = sqrt(fp(1,ivpx)**2 + fp(1,ivpy)**2)
    
!
!  Diagnostic output
!
      if (ldiagnos) then
        if (idiag_xpm/=0)  call sum_par_name(fp(1:npar,ixp),idiag_xpm)
        if (idiag_ypm/=0)  call sum_par_name(fp(1:npar,iyp),idiag_ypm)
        if (idiag_zpm/=0)  call sum_par_name(fp(1:npar,izp),idiag_zpm)
        if (idiag_xp2m/=0) call sum_par_name(fp(1:npar,ixp)**2,idiag_xp2m)
        if (idiag_yp2m/=0) call sum_par_name(fp(1:npar,iyp)**2,idiag_yp2m)
        if (idiag_zp2m/=0) call sum_par_name(fp(1:npar,izp)**2,idiag_zp2m)
        if (idiag_vpxm/=0) call sum_par_name(fp(1:npar,ivpx),idiag_vpxm)
        if (idiag_vpym/=0) call sum_par_name(fp(1:npar,ivpy),idiag_vpym)
        if (idiag_vpzm/=0) call sum_par_name(fp(1:npar,ivpz),idiag_vpzm)
        if (idiag_rad/=0)  call sum_par_name(dist(1:npar),idiag_rad)
        if (idiag_vel/=0)  call sum_par_name(vel(1:npar),idiag_vel)
        if (idiag_vpx2m/=0) &
            call sum_par_name(fp(1:npar,ivpx)**2,idiag_vpx2m)
        if (idiag_vpy2m/=0) &
            call sum_par_name(fp(1:npar,ivpy)**2,idiag_vpy2m)
        if (idiag_vpz2m/=0) &
            call sum_par_name(fp(1:npar,ivpz)**2,idiag_vpz2m)
      endif
!
      if (lfirstcall) lfirstcall=.false.
!
    endsubroutine dvvp_dt
!***********************************************************************
    subroutine read_particles_init_pars(unit,iostat)
!    
!  17-nov-05/anders+wlad: adapted
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
!  17-nov-05/anders+wlad: adapted
!
      integer, intent (in) :: unit
!
      write(unit,NML=particles_init_pars)
!
    endsubroutine write_particles_init_pars
!***********************************************************************
    subroutine read_particles_run_pars(unit,iostat)
!    
!  17-nov-05/anders+wlad: adapted
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
!  17-nov-05/anders+wlad: adapted
!    
      integer, intent (in) :: unit
!
      write(unit,NML=particles_run_pars)
!
    endsubroutine write_particles_run_pars
!***********************************************************************
    subroutine rprint_particles(lreset,lwrite)
!   
!  Read and register print parameters relevant for particles.
!
!  17-nov-05/anders+wlad: adapted
!    
      use Cdata
      use Sub, only: parse_name
!
      logical :: lreset
      logical, optional :: lwrite
!
      integer :: iname
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
        idiag_rad=0;idiag_vel=0
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
        call parse_name(iname,cname(iname),cform(iname),'rad',idiag_rad)
        call parse_name(iname,cname(iname),cform(iname),'vel',idiag_vel)
      enddo
!
    endsubroutine rprint_particles
!***********************************************************************

endmodule Particles
