! $Id: dustvelocity.f90,v 1.115 2006-08-23 16:53:31 mee Exp $
!
!  This module takes care of everything related to dust velocity
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! MVAR CONTRIBUTION 3
! MAUX CONTRIBUTION 0
!
! PENCILS PROVIDED divud,ood,od2,oud,ud2,udij,sdij,udgud,uud
! PENCILS PROVIDED del2ud,del6ud,graddivud
!
!***************************************************************

module Dustvelocity

!  Note that Omega is already defined in cdata.

  use Cdata
  use Messages
  use Hydro

  implicit none

  include 'dustvelocity.h'
!ajwm SHOULDN'T REALLY BE SHARED
!ajwm but are used consistently with the Dustdensity module
!ajwm - not good but for reasons of dust density / velocity interaction
  public :: dust_geometry, dimd1, rhods, surfd, mdplus, mdminus
  public :: ad, scolld, ustcst, tausd1, tausd
  public :: unit_md, dust_chemistry, mumon, mmon, mi, md

  ! init parameters
  complex, dimension (7) :: coeff
  real, dimension(ndustspec,ndustspec) :: scolld
  real, dimension(nx,ndustspec) :: tausd1
  real, dimension(ndustspec) :: md=1.0,mdplus,mdminus,ad,surfd,mi,rhodsad1
  real, dimension(ndustspec) :: tausd=1.,betad=0.,nud=0.,nud_hyper3=0.
  real :: ampluud=0.,ampl_udx=0.0,ampl_udy=0.0,ampl_udz=0.0
  real :: phase_udx=0.0, phase_udy=0.0, phase_udz=0.0
  real :: kx_uud=1.,ky_uud=1.,kz_uud=1.
  real :: rhods=1.,nd0=1.,md0=1.,rhod0=1.
  real :: ad0=0.,ad1=0.,dimd1=0.333333,deltamd=1.0
  real :: nud_all=0.,betad_all=0.,tausd_all=0.
  real :: mmon,mumon,mumon1,surfmon,ustcst,unit_md
  real :: beta_dPdr_dust=0.0, beta_dPdr_dust_scaled=0.0,cdtd=0.2
  real :: Omega_pseudo=0.0, u0_gas_pseudo=0.0, tausgmin=0.0, tausg1max=0.0
  logical :: ladvection_dust=.true.,lcoriolisforce_dust=.true.
  logical :: ldragforce_dust=.true.,ldragforce_gas=.false.
  logical :: lviscosity_dust=.true.
  logical :: ldustvelocity_shorttausd=.false., lvshear_dust_global_eps=.false.
  logical :: ldustcoagulation=.false., ldustcondensation=.false.
  character (len=labellen), dimension(ninit) :: inituud='nothing'
  character (len=labellen) :: draglaw='epstein_cst',iviscd='simplified'
  character (len=labellen) :: dust_geometry='sphere', dust_chemistry='nothing'

  namelist /dustvelocity_init_pars/ &
      ampl_udx, ampl_udy, ampl_udz, phase_udx, phase_udy, phase_udz, &
      rhods, md0, ad0, ad1, deltamd, draglaw, ampluud, inituud, &
      kx_uud, ky_uud, kz_uud, Omega_pseudo, u0_gas_pseudo, &
      dust_chemistry, dust_geometry, tausd, beta_dPdr_dust, coeff, &
      ldustcoagulation, ldustcondensation, lvshear_dust_global_eps, cdtd, &
      ldustvelocity_shorttausd

  ! run parameters
  namelist /dustvelocity_run_pars/ &
       nud, nud_all, iviscd, betad, betad_all, tausd, tausd_all, draglaw, &
       ldragforce_dust, ldragforce_gas, ldustvelocity_shorttausd, &
       ladvection_dust, lcoriolisforce_dust, beta_dPdr_dust, tausgmin, cdtd, &
       nud_hyper3

  ! other variables (needs to be consistent with reset list below)
  integer, dimension(ndustspec) :: idiag_ud2m=0
  integer, dimension(ndustspec) :: idiag_udxm=0,idiag_udym=0,idiag_udzm=0
  integer, dimension(ndustspec) :: idiag_udx2m=0,idiag_udy2m=0,idiag_udz2m=0
  integer, dimension(ndustspec) :: idiag_udm2=0,idiag_oudm=0,idiag_od2m=0
  integer, dimension(ndustspec) :: idiag_udxpt=0,idiag_udypt=0,idiag_udzpt=0
  integer, dimension(ndustspec) :: idiag_udrms=0,idiag_udmax=0,idiag_odrms=0
  integer, dimension(ndustspec) :: idiag_odmax=0,idiag_rdudmax=0
  integer, dimension(ndustspec) :: idiag_udxmz=0,idiag_udymz=0,idiag_udzmz=0
  integer, dimension(ndustspec) :: idiag_udx2mz=0,idiag_udy2mz=0,idiag_udz2mz=0
  integer, dimension(ndustspec) :: idiag_udmx=0,idiag_udmy=0,idiag_udmz=0
  integer, dimension(ndustspec) :: idiag_udxmxy=0,idiag_udymxy=0,idiag_udzmxy=0
  integer, dimension(ndustspec) :: idiag_divud2m=0,idiag_epsKd=0
  integer, dimension(ndustspec) :: idiag_dtud=0,idiag_dtnud=0
  integer, dimension(ndustspec) :: idiag_rdudxm=0,idiag_rdudym=0,idiag_rdudzm=0
  integer, dimension(ndustspec) :: idiag_rdudx2m=0


  contains

!***********************************************************************
    subroutine register_dustvelocity()
!
!  Initialise variables which should know that we solve the hydro
!  equations: iuu, etc; increase nvar accordingly.
!
!  18-mar-03/axel+anders: adapted from hydro
!
      use Cdata
      use Sub
      use General, only: chn
!
      logical, save :: first=.true.
      integer :: k
      character(len=4) :: sdust
!
      if (.not. first) call fatal_error('register_dustvelocity','module registration called twice')
      first = .false.
!
      ldustvelocity = .true.
!
      do k=1,ndustspec
        iuud(k) = nvar+1      ! Unecessary index... iudx would suffice 
        iudx(k) = nvar+1             
        iudy(k) = nvar+2
        iudz(k) = nvar+3
        nvar = nvar+3                ! add 3 variables pr. dust layer
!
        if ((ip<=8) .and. lroot) then
          print*, 'register_dustvelocity: nvar = ', nvar
          print*, 'register_dustvelocity: k = ', k
          print*, 'register_dustvelocity: iudx,iudy,iudz = ', &
              iudx(k),iudy(k),iudz(k)
        endif
!
!  Put variable name in array
!
        call chn(k,sdust)
        varname(iudx(k)) = 'udx('//trim(sdust)//')'
        varname(iudy(k)) = 'udy('//trim(sdust)//')'
        varname(iudz(k)) = 'udz('//trim(sdust)//')'
      enddo
!
!  identify version number (generated automatically by CVS)
!
      if (lroot) call cvs_id( &
           "$Id: dustvelocity.f90,v 1.115 2006-08-23 16:53:31 mee Exp $")
!
      if (nvar > mvar) then
        if (lroot) write(0,*) 'nvar = ', nvar, ', mvar = ', mvar
        call fatal_error('register_dustvelocity','nvar > mvar')
      endif
!
!  Writing files for use with IDL
!
      do k=1,ndustspec
        call chn(k,sdust)
        if (ndustspec == 1) sdust = ''
        if (lroot) then
          if (maux == 0) then
            if (nvar < mvar) write(4,*) ',uud'//trim(sdust)//' $'
            if (nvar == mvar) write(4,*) ',uud'//trim(sdust)
          else
            write(4,*) ',uud'//trim(sdust)//' $'
          endif
            write(15,*) 'uud'//trim(sdust)//' = fltarr(mx,my,mz,3)*one'
        endif
      enddo
!
    endsubroutine register_dustvelocity
!***********************************************************************
    subroutine initialize_dustvelocity()
!
!  Perform any post-parameter-read initialization i.e. calculate derived
!  parameters.
!
!  18-mar-03/axel+anders: adapted from hydro
!
      use EquationOfState, only: cs0
!
      integer :: k
      real :: gsurften=0.,Eyoung=1.,nu_Poisson=0.,Eyoungred=1.
!
!  Output grain mass discretization type
!
      if (lroot .and. ldustcoagulation) then
        if (lmdvar) then
          print*, 'register_dustvelocity: variable grain mass'
        else
          print*, 'register_dustvelocity: constant grain mass'
        endif
      endif
!
!  Turn off dust viscosity if zero viscosity
!
      if (maxval(nud) == 0.) lviscosity_dust=.false.
      if (lroot) print*, &
          'initialize_dustvelocity: lviscosity_dust=',lviscosity_dust
!
!  Turn off all dynamical terms in duud/dt if short stopping time approximation
!
      if (ldustvelocity_shorttausd) then
        ladvection_dust=.false.
        lcoriolisforce_dust=.false.
        ldragforce_dust=.false.
        lviscosity_dust=.false.
        lgravx_dust=.false.
        lgravy_dust=.false.
        lgravz_dust=.false.
        if (lroot) print*, 'initialize_dustvelocity: '// &
            'Short stopping time approximation. Advection, Coriolis force, '// &
            'drag force, viscosity and gravity on the dust turned off'
      endif
!
!  Calculate inverse of minimum gas friction time.
!
      if (tausgmin/=0.0) then
        tausg1max=1.0/tausgmin      
        if (lroot) print*, 'initialize_dustvelocity: '// &
            'minimum gas friction time tausgmin=', tausgmin
      endif
!
      if (ldustcoagulation .or. ldustcondensation) then
!
!  Grain chemistry
!
        if (lroot) &
            print*, 'initialize_dustvelocity: dust_chemistry = ', dust_chemistry
!            
        select case (dust_chemistry)

        case ('nothing')
          unit_md = 1.

        case ('ice')
!
!  Surface tension and Young's modulus for sticking velocity
!
          gsurften   = 370. ! erg cm^-2 
          Eyoung     = 7e10 ! dyn cm^-2
          nu_Poisson = 0.25 !
          Eyoungred  = Eyoung/(2*(1-nu_Poisson**2))
        
          mumon = 18.
          mmon  = mumon*1.6733e-24
          unit_md = mmon

          if (lroot) print*, &
              'initialize_dustvelocity: mmon, surfmon = ', mmon, surfmon

        case default
          call fatal_error &
              ('initialize_dustvelocity','No valid dust chemistry specified.')

        endselect

        mumon1=1/mumon
!
!  Constant used in determination of sticking velocity 
!    (extra factor 2 from Dominik & Tielens, 1997, end of Sec. 3.2)
!
        ustcst = sqrt(2* 2*9.6 * gsurften**(5/3.) * Eyoungred**(-2/3.))
!
!  Dust physics parameters
!
        if (ad0/=0.) md0 = 4/3.*pi*ad0**3*rhods/unit_md
        if (ad1/=0.) md0 = 8*pi/(3*(1.+deltamd))*ad1**3*rhods
!
!  Mass bins
!
        do k=1,ndustspec
          mdminus(k) = md0*deltamd**(k-1)
          mdplus(k)  = md0*deltamd**k
          md(k) = 0.5*(mdminus(k)+mdplus(k))
        enddo
!
!  Grain geometry
!        
        select case(dust_geometry)

        case ('sphere')
          dimd1 = 0.333333
          if (lroot) print*, 'initialize_dustvelocity: dust geometry = sphere'
          call get_dustsurface
          call get_dustcrosssection
          surfmon = surfd(1)*(mmon/(md(1)*unit_md))**(1.-dimd1)

        case default
          call fatal_error( &
              'initialize_dustvelocity','No valid dust geometry specified.')

        endselect
      endif
!
!  Auxiliary variables necessary for different drag laws
!
      if (ldragforce_dust) then
        select case (draglaw)
     
        case ('epstein_var')
          rhodsad1 = 1./(rhods*ad)
        case ('epstein_cst')
          do k=1,ndustspec
            tausd1(:,k) = 1.0/tausd(k)
          enddo

        endselect
      endif
!
!  If *_all set, make all primordial *(:) = *_all
!
      if (nud_all /= 0.) then
        if (lroot .and. ip<6) &
            print*, 'initialize_dustvelocity: nud_all=',nud_all
        do k=1,ndustspec
          if (nud(k) == 0.) nud(k)=nud_all
        enddo
      endif
!      
      if (betad_all /= 0.) then
        if (lroot .and. ip<6) &
            print*, 'initialize_dustvelocity: betad_all=',betad_all
        do k=1,ndustspec
          if (betad(k) == 0.) betad(k) = betad_all
        enddo
      endif
!
      if (tausd_all /= 0.) then
        if (lroot .and. ip<6) &
            print*, 'initialize_dustvelocity: tausd_all=',tausd_all
        do k=1,ndustspec
          if (tausd(k) == 0.) tausd(k) = tausd_all
        enddo
      endif
!
      if (beta_dPdr_dust/=0.0) then
        beta_dPdr_dust_scaled=beta_dPdr_dust*Omega/cs0
        if (lroot) print*, 'initialize_dustvelocity: Global pressure '// &
            'gradient with beta_dPdr_dust=', beta_dPdr_dust
      endif
!
    endsubroutine initialize_dustvelocity
!***********************************************************************
    subroutine copy_bcs_dust
!
!  Copy boundary conditions on first dust species to all others
!    
!  27-feb-04/anders: Copied from initialize_dustvelocity
!
      if (lmdvar .and. lmice) then
!
!  Copy boundary conditions after dust conditions to end of array
!
        bcx(imi(ndustspec)+1:)  = bcx(iudz(1)+4:)
        bcy(imi(ndustspec)+1:)  = bcy(iudz(1)+4:)
        bcz(imi(ndustspec)+1:)  = bcz(iudz(1)+4:)
      elseif (lmdvar) then
!
!  Copy boundary conditions after dust conditions to end of array
!
        bcx(imd(ndustspec)+1:)  = bcx(iudz(1)+3:)
        bcy(imd(ndustspec)+1:)  = bcy(iudz(1)+3:)
        bcz(imd(ndustspec)+1:)  = bcz(iudz(1)+3:)
      else  
!
!  Copy boundary conditions after dust conditions to end of array
!
        bcx(ind(ndustspec)+1:)  = bcx(iudz(1)+2:)
        bcy(ind(ndustspec)+1:)  = bcy(iudz(1)+2:)
        bcz(ind(ndustspec)+1:)  = bcz(iudz(1)+2:)
      endif
!
!  Move boundary condition to correct place for first dust species 
!
      bcx(ind(1))  = bcx(iudz(1)+1)
      if (lmdvar) bcx(imd(1))  = bcx(iudz(1)+2)
      if (lmice)  bcx(imi(1))  = bcx(iudz(1)+3)

      bcy(ind(1))  = bcy(iudz(1)+1)
      if (lmdvar) bcy(imd(1))  = bcy(iudz(1)+2)
      if (lmice)  bcy(imi(1))  = bcy(iudz(1)+3)

      bcz(ind(1))  = bcz(iudz(1)+1)
      if (lmdvar) bcz(imd(1))  = bcz(iudz(1)+2)
      if (lmice)  bcz(imi(1))  = bcz(iudz(1)+3)
!
!  Copy boundary conditions on first dust species to all species
!
      bcx(iudx) = bcx(iudx(1))
      bcx(iudy) = bcx(iudy(1))
      bcx(iudz) = bcx(iudz(1))
      bcx(ind)  = bcx(ind(1))
      if (lmdvar) bcx(imd) = bcx(imd(1))
      if (lmice)  bcx(imi) = bcx(imi(1))

      bcy(iudx) = bcy(iudx(1))
      bcy(iudy) = bcy(iudy(1))
      bcy(iudz) = bcy(iudz(1))
      bcy(ind)  = bcy(ind(1))
      if (lmdvar) bcy(imd) = bcy(imd(1))
      if (lmice)  bcy(imi) = bcy(imi(1))

      bcz(iudx) = bcz(iudx(1))
      bcz(iudy) = bcz(iudy(1))
      bcz(iudz) = bcz(iudz(1))
      bcz(ind)  = bcz(ind(1))
      if (lmdvar) bcz(imd) = bcz(imd(1))
      if (lmice)  bcz(imi) = bcz(imi(1))
!
      if (ndustspec>1 .and. lroot) then
        print*, 'copy_bcs_dust: Copied bcs on first dust species to all others'
      endif
!
    endsubroutine copy_bcs_dust
!***********************************************************************
    subroutine init_uud(f)
!
!  initialise uud; called from start.f90
!
!  18-mar-03/axel+anders: adapted from hydro
!
      use Cdata
      use EquationOfState, only: gamma, beta_glnrho_global, beta_glnrho_scaled
      use Sub
      use Global
      use Gravity
      use Initcond
      use EquationOfState, only: pressure_gradient,cs20
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx) :: lnrho,rho,cs2,rhod,cp1tilde
      real :: eps,cs,eta_glnrho,v_Kepler
      integer :: j,k,l
      logical :: lnothing
!
!  inituud corresponds to different initializations of uud (called from start).
!
      lnothing=.false.
      do j=1,ninit
        select case(inituud(j))

        case('nothing')
          if (lroot .and. .not. lnothing) print*, 'init_uud: nothing'
          lnothing=.true.
        case('zero', '0')
          do k=1,ndustspec; f(:,:,:,iudx(k):iudz(k))=0.0; enddo
          if(lroot) print*,'init_uud: zero dust velocity'
        case('gaussian-noise')
          do k=1,ndustspec; call gaunoise(ampluud,f,iudx(k),iudz(k)); enddo
        case('sinwave-phase')
          do k=1,ndustspec
            call sinwave_phase(f,iudx(k),ampl_udx,kx_uud,ky_uud,kz_uud,phase_udx)
            call sinwave_phase(f,iudy(k),ampl_udy,kx_uud,ky_uud,kz_uud,phase_udy)
            call sinwave_phase(f,iudz(k),ampl_udz,kx_uud,ky_uud,kz_uud,phase_udz)
          enddo
        case('udx_sinx')
          do l=1,mx; f(l,:,:,iudx(1)) = ampluud*sin(kx_uud*x(l)); enddo
        case('udy_siny')
          do m=1,my; f(:,m,:,iudy(1)) = ampluud*sin(ky_uud*y(m)); enddo
        case('sinwave-z-x')
          if (lroot) print*, 'init_uud: sinwave-z-x, ampluud=', ampluud
          call sinwave(ampluud,f,iudz(1),kx=kx_uud)
        case('udz_sinz')
          do n=1,mz; f(:,:,n,iudz(1)) = ampluud*sin(kz_uud*z(n)); enddo
        case('udz_siny')
          do m=m1,m2
            f(:,m,:,iudz(1)) = f(:,m,:,iudz(1)) + ampluud*sin(ky_uud*y(m))
          enddo
        case('udx_sinxsinysinz')
          do l=1,mx; do m=1,my; do n=1,mz
            f(l,m,n,iudx(1)) = &
                ampluud*sin(kx_uud*x(l))*sin(ky_uud*y(m))*sin(kz_uud*z(n))
          enddo; enddo; enddo
        case('udy_sinxsinysinz')
          do l=1,mx; do m=1,my; do n=1,mz
            f(l,m,n,iudy(1)) = &
                ampluud*sin(kx_uud*x(l))*sin(ky_uud*y(m))*sin(kz_uud*z(n))
          enddo; enddo; enddo
        case('udz_sinxsinysinz')
          do l=1,mx; do m=1,my; do n=1,mz
            f(l,m,n,iudz(1)) = &
                ampluud*sin(kx_uud*x(l))*sin(ky_uud*y(m))*sin(kz_uud*z(n))
          enddo; enddo; enddo
        case('follow_gas')
          do k=1,ndustspec
            f(:,:,:,iudx(k):iudz(k))=f(:,:,:,iux:iuz)
          enddo
        case('terminal_vz')
          if (lroot) print*, 'init_uud: terminal velocity'
          do k=1,ndustspec
            do m=m1,m2
              do n=n1,n2
                if (ldensity_nolog) then
                  rho = f(l1:l2,m,n,ilnrho)
                  lnrho = log(rho)
                else
                  lnrho = f(l1:l2,m,n,ilnrho)
                  rho = exp(lnrho)
                endif
                if (ldustdensity_log) then
                  rhod = exp(f(l1:l2,m,n,ind(k)))*md(k)
                else
                  rhod = f(l1:l2,m,n,ind(k))*md(k)
                endif
                call pressure_gradient(f,cs2,cp1tilde)
                call get_stoppingtime(f,rho,cs2,rhod,k)
                f(l1:l2,m,n,iudz(k)) = &
                    f(l1:l2,m,n,iudz(k)) - tausd1(:,k)**(-1)*nu_epicycle**2*z(n)
              enddo
            enddo
          enddo

        case('vshear_dust')
!
!  Vertical shear due to global pressure gradient and back-reaction drag force
!  from dust on gas.
!
          if (lroot) then
            print*, 'init_uud: vertical shear due to dust'
            if (maxval(abs(beta_glnrho_scaled))/=0.0) then
              print*, 'init_uud: beta_glnrho_scaled=', beta_glnrho_scaled
            elseif (beta_dPdr_dust_scaled/=0.0) then
              print*, 'init_uud: beta_dPdr_dust_scaled=', beta_dPdr_dust_scaled
            endif
          endif

          if (ldensity_nolog) then
            if (ldustdensity_log) then
              eps=sum(exp(f(l1:l2,m1:m2,n1:n2,ind(1))))/sum(f(l1:l2,m1:m2,n1:n2,ilnrho))
            else
              eps=sum(f(l1:l2,m1:m2,n1:n2,ind(1)))/sum(f(l1:l2,m1:m2,n1:n2,ilnrho))
            endif
          else
            if (ldustdensity_log) then
              eps=sum(exp(f(l1:l2,m1:m2,n1:n2,ind(1))))/sum(exp(f(l1:l2,m1:m2,n1:n2,ilnrho)))
            else
              eps=sum(f(l1:l2,m1:m2,n1:n2,ind(1)))/sum(exp(f(l1:l2,m1:m2,n1:n2,ilnrho)))
            endif
          endif

          if (lroot) print*, 'init_uud: average dust-to-gas ratio=', eps
          
          do l=l1,l2; do m=m1,m2; do n=n1,n2
            cs=sqrt(cs20)

            if (.not. lvshear_dust_global_eps) then
              if (ldensity_nolog) then
                if (ldustdensity_log) then
                  eps=exp(f(l,m,n,ind(1)))/f(l,m,n,ilnrho)
                else
                  eps=f(l,m,n,ind(1))/f(l,m,n,ilnrho)
                endif
              else
                if (ldustdensity_log) then
                  eps=exp(f(l,m,n,ind(1)))/exp(f(l,m,n,ilnrho))
                else
                  eps=f(l,m,n,ind(1))/exp(f(l,m,n,ilnrho))
                endif
              endif
            endif

            if (beta_glnrho_scaled(1)/=0.0) then
              f(l,m,n,iux) = f(l,m,n,iux) - &
                  1/gamma*cs20*beta_glnrho_scaled(1)*eps*tausd(1)/ &
                  (1.0+2*eps+eps**2+(Omega*tausd(1))**2)
              f(l,m,n,iuy) = f(l,m,n,iuy) + &
                  1/gamma*cs20*beta_glnrho_scaled(1)* &
                  (1+eps+(Omega*tausd(1))**2)/ &
                  (2*Omega*(1.0+2*eps+eps**2+(Omega*tausd(1))**2))
              f(l,m,n,iudx(1)) = f(l,m,n,iudx(1)) + &
                  1/gamma*cs20*beta_glnrho_scaled(1)*tausd(1)/ &
                  (1.0+2*eps+eps**2+(Omega*tausd(1))**2)
              f(l,m,n,iudy(1)) = f(l,m,n,iudy(1)) + &
                  1/gamma*cs20*beta_glnrho_scaled(1)*(1+eps)/ &
                  (2*Omega*(1.0+2*eps+eps**2+(Omega*tausd(1))**2))
            elseif (beta_dPdr_dust_scaled/=0.0) then
              f(l,m,n,iux) = f(l,m,n,iux) - &
                  1/gamma*cs20*beta_dPdr_dust_scaled*eps*tausd(1)/ &
                  (1.0+2*eps+eps**2+(Omega*tausd(1))**2)
              f(l,m,n,iuy) = f(l,m,n,iuy) - &
                  1/gamma*cs20*beta_dPdr_dust_scaled*(eps+eps**2)/ &
                  (2*Omega*(1.0+2*eps+eps**2+(Omega*tausd(1))**2))
              f(l,m,n,iudx(1)) = f(l,m,n,iudx(1)) + &
                  1/gamma*cs20*beta_dPdr_dust_scaled*tausd(1)/ &
                  (1.0+2*eps+eps**2+(Omega*tausd(1))**2)
              f(l,m,n,iudy(1)) = f(l,m,n,iudy(1)) - &
                  1/gamma*cs20*beta_dPdr_dust_scaled* &
                  (eps+eps**2+(Omega*tausd(1))**2)/ &
                  (2*Omega*(1.0+2*eps+eps**2+(Omega*tausd(1))**2))
            endif
          enddo; enddo; enddo
!
        case('vshear_dust_pseudo')
!
!  Vertical shear due to pseudo Coriolis force
!
          if (lroot) then
            print*, 'init_uud: vertical shear due to dust (pseudo)'
            print*, 'init_uud: u0_gas_pseudo=', u0_gas_pseudo
          endif
          do l=l1,l2; do m=m1,m2; do n=n1,n2
            if (ldensity_nolog) then
              if (ldustdensity_log) then
                eps=exp(f(l,m,n,ind(1)))/f(l,m,n,ilnrho)
              else
                eps=f(l,m,n,ind(1))/f(l,m,n,ilnrho)
              endif
            else
              if (ldustdensity_log) then
                eps=exp(f(l,m,n,ind(1)))/exp(f(l,m,n,ilnrho))
              else
                eps=f(l,m,n,ind(1))/exp(f(l,m,n,ilnrho))
              endif
            endif
            f(l,m,n,iux) = f(l,m,n,iux) + &
                u0_gas_pseudo*(1.0 + Omega_pseudo*tausd(1))/ &
                (1.0 + eps + Omega_pseudo*tausd(1))
            f(l,m,n,iudx) = f(l,m,n,iudx) + &
                u0_gas_pseudo/(1.0 + eps + Omega_pseudo*tausd(1))
          enddo; enddo; enddo
!
        case('streaming')
!
!  Mode unstable to streaming instability (Youdin & Goodman 2005)
!
          eta_glnrho = -0.5*1/gamma*abs(beta_glnrho_global(1))*beta_glnrho_global(1)
          v_Kepler   =  1.0/abs(beta_glnrho_global(1))

          if (lroot) print*, 'init_uud: eta, vK=', eta_glnrho, v_Kepler
!
          if (ldensity_nolog) then
            if (ldustdensity_log) then
              eps=sum(exp(f(l1:l2,m1:m2,n1:n2,ind(1))))/ &
                  sum(f(l1:l2,m1:m2,n1:n2,ilnrho))
            else
              eps=sum(f(l1:l2,m1:m2,n1:n2,ind(1)))/ &
                  sum(f(l1:l2,m1:m2,n1:n2,ilnrho))
            endif
          else
            if (ldustdensity_log) then
              eps=sum(exp(f(l1:l2,m1:m2,n1:n2,ind(1))))/ &
                  sum(exp(f(l1:l2,m1:m2,n1:n2,ilnrho)))
            else
              eps=sum(f(l1:l2,m1:m2,n1:n2,ind(1)))/ &
                  sum(exp(f(l1:l2,m1:m2,n1:n2,ilnrho)))
            endif
          endif
!          
          do m=m1,m2; do n=n1,n2
!            
            f(l1:l2,m,n,ind(1)) = 0.0*f(l1:l2,m,n,ind(1)) + &
                eps*ampluud*cos(kz_uud*z(n))*cos(kx_uud*x(l1:l2))
!                
            f(l1:l2,m,n,ilnrho) = f(l1:l2,m,n,ilnrho) + &
                ampluud* &
                ( real(coeff(7))*cos(kx_uud*x(l1:l2)) - &
                 aimag(coeff(7))*sin(kx_uud*x(l1:l2)))*cos(kz_uud*z(n))
!                
            f(l1:l2,m,n,iux) = f(l1:l2,m,n,iux) + &
                eta_glnrho*v_Kepler*ampluud* &
                ( real(coeff(4))*cos(kx_uud*x(l1:l2)) - &
                 aimag(coeff(4))*sin(kx_uud*x(l1:l2)))*cos(kz_uud*z(n))
!                
            f(l1:l2,m,n,iuy) = f(l1:l2,m,n,iuy) + &
                eta_glnrho*v_Kepler*ampluud* &
                ( real(coeff(5))*cos(kx_uud*x(l1:l2)) - &
                 aimag(coeff(5))*sin(kx_uud*x(l1:l2)))*cos(kz_uud*z(n))
!
            f(l1:l2,m,n,iuz) = f(l1:l2,m,n,iuz) + &
                eta_glnrho*v_Kepler*(-ampluud)* &
                (aimag(coeff(6))*cos(kx_uud*x(l1:l2)) + &
                  real(coeff(6))*sin(kx_uud*x(l1:l2)))*sin(kz_uud*z(n))
!                
            f(l1:l2,m,n,iudx(1)) = f(l1:l2,m,n,iudx(1)) + &
                eta_glnrho*v_Kepler*ampluud* &
                ( real(coeff(1))*cos(kx_uud*x(l1:l2)) - &
                 aimag(coeff(1))*sin(kx_uud*x(l1:l2)))*cos(kz_uud*z(n))
!                
            f(l1:l2,m,n,iudy(1)) = f(l1:l2,m,n,iudy(1)) + &
                eta_glnrho*v_Kepler*ampluud* &
                ( real(coeff(2))*cos(kx_uud*x(l1:l2)) - &
                 aimag(coeff(2))*sin(kx_uud*x(l1:l2)))*cos(kz_uud*z(n))
!
            f(l1:l2,m,n,iudz(1)) = f(l1:l2,m,n,iudz(1)) + &
                eta_glnrho*v_Kepler*(-ampluud)* &
                (aimag(coeff(3))*cos(kx_uud*x(l1:l2)) + &
                  real(coeff(3))*sin(kx_uud*x(l1:l2)))*sin(kz_uud*z(n))
!
          enddo; enddo
!
!  Catch unknown values
!
        case default
          write (unit=errormsg,fmt=*) 'No such such value for inituu: ', trim(inituud(j))
          call fatal_error('init_uud',errormsg)

        endselect
!
!  End loop over initial conditions
!        
      enddo
!
    endsubroutine init_uud
!***********************************************************************
    subroutine pencil_criteria_dustvelocity()
! 
!  All pencils that the Dustvelocity module depends on are specified here.
! 
!  20-11-04/anders: coded
!
      lpenc_requested(i_uud)=.true.
      if (ladvection_dust) lpenc_requested(i_udgud)=.true.
      if (ldustvelocity_shorttausd) then
        lpenc_requested(i_gg)=.true.
        lpenc_requested(i_cs2)=.true.
        lpenc_requested(i_jxbr)=.true.
        lpenc_requested(i_glnrho)=.true.
      endif
      if (ldragforce_dust) lpenc_requested(i_rhod)=.true.
      if (ldragforce_gas) lpenc_requested(i_rho1)=.true.
      if (ldragforce_dust) then
        lpenc_requested(i_uu)=.true.
        if (draglaw=='epstein_var') then
          lpenc_requested(i_cs2)=.true.
          lpenc_requested(i_rho)=.true.
        endif
      endif
      if (lviscosity_dust) then
        if ((iviscd=='nud-const' .or. iviscd=='hyper3_nud-const') &
            .and. ldustdensity) then
          lpenc_requested(i_sdij)=.true.
          lpenc_requested(i_glnnd)=.true.
        endif
        if (iviscd=='simplified' .or. iviscd=='nud-const') &
            lpenc_requested(i_del2ud)=.true.
        if (iviscd=='hyper3_simplified' .or. iviscd=='hyper3_nud-const' .or. &
            iviscd=='hyper3_rhod_nud-const') &
            lpenc_requested(i_del6ud)=.true.
        if (iviscd=='nud-const' .or. iviscd=='hyper3_nud-const') &
            lpenc_requested(i_sdglnnd)=.true.
        if (iviscd=='nud-const') lpenc_requested(i_graddivud)=.true.
        if (iviscd=='hyper3_rhod_nud-const') lpenc_requested(i_rhod)=.true.
      endif
      if (beta_dPdr_dust/=0.) lpenc_requested(i_cs2)=.true.
!
      lpenc_diagnos(i_uud)=.true.
      if (maxval(idiag_divud2m)/=0) lpenc_diagnos(i_divud)=.true.
      if (maxval(idiag_rdudmax)/=0 .or. maxval(idiag_rdudxm)/=0 .or. &
          maxval(idiag_rdudym)/=0 .or. maxval(idiag_rdudzm)/=0 .or. &
          maxval(idiag_rdudx2m)/=0) &
          lpenc_diagnos(i_rhod)=.true.
      if (maxval(idiag_udrms)/=0 .or. maxval(idiag_udmax)/=0 .or. &
          maxval(idiag_rdudmax)/=0 .or. maxval(idiag_ud2m)/=0 .or. &
          maxval(idiag_udm2)/=0) &
          lpenc_diagnos(i_ud2)=.true.
      if (maxval(idiag_odrms)/=0 .or. maxval(idiag_odmax)/=0 .or. &
          maxval(idiag_od2m)/=0) lpenc_diagnos(i_od2)=.true.
      if (maxval(idiag_oudm)/=0) lpenc_diagnos(i_oud)=.true.
!
    endsubroutine pencil_criteria_dustvelocity
!***********************************************************************
    subroutine pencil_interdep_dustvelocity(lpencil_in)
!
!  Interdependency among pencils provided by the Dustvelocity module
!  is specified here.
!
!  20-11-04/anders: coded
!
      logical, dimension(npencils) :: lpencil_in
!
      if (lpencil_in(i_ud2)) lpencil_in(i_uud)=.true.
      if (lpencil_in(i_divud)) lpencil_in(i_udij)=.true.
      if (lpencil_in(i_udgud)) then
        lpencil_in(i_uud)=.true.
        lpencil_in(i_udij)=.true.
      endif
      if (lpencil_in(i_ood)) lpencil_in(i_udij)=.true.
      if (lpencil_in(i_od2)) lpencil_in(i_ood)=.true.
      if (lpencil_in(i_oud)) then
        lpencil_in(i_uud)=.true.
        lpencil_in(i_ood)=.true.
      endif
      if (lpencil_in(i_sdij)) then
        if (iviscd=='nud-const') then
          lpencil_in(i_udij)=.true.
          lpencil_in(i_divud)=.true.
        endif
      endif
!
    endsubroutine pencil_interdep_dustvelocity
!***********************************************************************
    subroutine calc_pencils_dustvelocity(f,p)
!
!  Calculate Dustvelocity pencils.
!  Most basic pencils should come first, as others may depend on them.
!
!  13-nov-04/anders: coded
!
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      real, dimension (nx,3,3) :: tmp_pencil_3x3
      integer :: i,j,k
!
      intent(in) :: f
      intent(inout) :: p
!
      do k=1,ndustspec
! uud
        if (lpencil(i_uud)) p%uud(:,:,k)=f(l1:l2,m,n,iudx(k):iudz(k))
! ud2
        if (lpencil(i_ud2)) call dot2_mn(p%uud(:,:,k),p%ud2(:,k))
! udij
        if (lpencil(i_udij)) call gij(f,iuud(k),p%udij,1)
! divud
        if (lpencil(i_divud)) &
            p%divud(:,k) = p%udij(:,1,1,k) + p%udij(:,2,2,k) + p%udij(:,3,3,k)
! udgud      
        if (lpencil(i_udgud)) call multmv_mn(p%udij,p%uud(:,:,k),p%udgud)
! ood
        if (lpencil(i_ood)) then
          p%ood(:,1,k)=p%udij(:,3,2,k)-p%udij(:,2,3,k)
          p%ood(:,2,k)=p%udij(:,1,3,k)-p%udij(:,3,1,k)
          p%ood(:,3,k)=p%udij(:,2,1,k)-p%udij(:,1,2,k)
        endif
! od2
        if (lpencil(i_od2)) call dot2_mn(p%ood(:,:,k),p%od2(:,k))
! oud
        if (lpencil(i_oud)) call dot_mn(p%ood(:,:,k),p%uud(:,:,k),p%oud(:,k))
! sdij
        if (lpencil(i_sdij)) then
          select case (iviscd)
          case ('nud-const')
            do j=1,3
              do i=1,3
                p%sdij(:,i,j,k)=.5*(p%udij(:,i,j,k)+p%udij(:,j,i,k))
              enddo
              p%sdij(:,j,j,k)=p%sdij(:,j,j,k)-.333333*p%divud(:,k)
            enddo
          case ('hyper3_nud-const')
            call gij(f,iuud(k),tmp_pencil_3x3,5)
            do i=1,3
              do j=1,3
                p%sdij(:,i,j,k)=tmp_pencil_3x3(:,i,j)
              enddo
            enddo
          case default
            if (headtt) then
              write (unit=errormsg,fmt=*) 'No rate-of-strain tensor matches iviscd=', iviscd
              call warning('calc_pencils_dustvelocity',errormsg)
            endif
          endselect
        endif
! del2ud
        if (lpencil(i_del2ud)) call del2v(f,iuud(k),p%del2ud(:,:,k))
! del6ud
        if (lpencil(i_del6ud)) call del6v(f,iuud(k),p%del6ud(:,:,k))
! graddivud          
        if (lpencil(i_graddivud)) &
            call del2v_etc(f,iuud(k),GRADDIV=p%graddivud(:,:,k))
      enddo
!
    endsubroutine calc_pencils_dustvelocity
!***********************************************************************
    subroutine duud_dt(f,df,p)
!
!  Dust velocity evolution
!  Calculate duud/dt = - uud.graduud - 2Omega x uud - 1/tausd*(uud-uu)
!
!  18-mar-03/axel+anders: adapted from hydro
!
      use Cdata
      use General
      use Sub
      use EquationOfState, only: gamma
      use IO
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!      
      real, dimension (nx,3) :: fviscd,tausd13,tausg13,AA_sfta,BB_sfta
      real, dimension (nx) :: tausg1,mudrhod1
      real :: c2,s2 !(coefs for Coriolis force with inclined Omega)
      integer :: i,j,k
!
      intent(in) :: f,p
      intent(out) :: df
!
!  Identify module and boundary conditions
!
      if (headtt.or.ldebug) print*,'duud_dt: SOLVE duud_dt'
      if (headtt) then
        call identify_bcs('udx',iudx(1))
        call identify_bcs('udy',iudy(1))
        call identify_bcs('udz',iudz(1))
      endif
!
!  Short stopping time approximation
!  Calculated from master equation d(wx-ux)/dt = A + B*(wx-ux) = 0
!
      if (ldustvelocity_shorttausd) then
        if (headtt) print*, 'duud_dt: Short stopping time approximation'
        do k=1,ndustspec
          do j=1,3
            AA_sfta(:,j)=p%gg(:,j)
          enddo
          if (ldensity) then
            do j=1,3; AA_sfta(:,j)=AA_sfta(:,j)+p%cs2(:)*p%glnrho(:,j); enddo
          endif
          if (lgrav) then
            if (lgravx_gas .neqv. lgravx_dust) then
              if (lgravx_gas) AA_sfta(:,1)=AA_sfta(:,1)-p%gg(:,1)
              if (lgravx_dust) AA_sfta(:,1)=AA_sfta(:,1)+p%gg(:,1)
            endif
            if (lgravz_gas .neqv. lgravz_dust) then
              if (lgravz_gas) AA_sfta(:,3)=AA_sfta(:,3)-p%gg(:,3)
              if (lgravz_dust) AA_sfta(:,3)=AA_sfta(:,3)+p%gg(:,3)
            endif
          endif
          if (lmagnetic) AA_sfta=AA_sfta-p%JxBr
          BB_sfta=-1/tausd(k)
          df(l1:l2,m,n,iudx(k):iudz(k)) = 1/dt_beta(itsub)*( &
              f(l1:l2,m,n,iux:iuz)-f(l1:l2,m,n,iudx(k):iudz(k))-AA_sfta/BB_sfta)
        enddo
      endif
!
!  Loop over dust species
!
      do k=1,ndustspec
!
!  Advection term
!
        if (ladvection_dust) df(l1:l2,m,n,iudx(k):iudz(k)) = &
              df(l1:l2,m,n,iudx(k):iudz(k)) - p%udgud(:,:,k)
!
!  Coriolis force, -2*Omega x ud
!  Omega=(-sin_theta, 0, cos_theta)
!  theta corresponds to latitude
!
        if (Omega/=0. .and. lcoriolisforce_dust) then
          if (theta==0) then
            if (headtt .and. k == 1) &
                print*,'duud_dt: add Coriolis force; Omega=',Omega
            c2=2*Omega
            df(l1:l2,m,n,iudx(k)) = df(l1:l2,m,n,iudx(k)) + c2*p%uud(:,2,k)
            df(l1:l2,m,n,iudy(k)) = df(l1:l2,m,n,iudy(k)) - c2*p%uud(:,1,k)
          else
            if (headtt .and. k == 1) print*, &
                'duud_dt: Coriolis force; Omega,theta=',Omega,theta
            c2=2*Omega*cos(theta*pi/180.)
            s2=2*Omega*sin(theta*pi/180.)
            df(l1:l2,m,n,iudx(k)) = &
                df(l1:l2,m,n,iudx(k)) + c2*p%uud(:,2,k)
            df(l1:l2,m,n,iudy(k)) = &
                df(l1:l2,m,n,iudy(k)) - c2*p%uud(:,1,k) + s2*p%uud(:,3,k)
            df(l1:l2,m,n,iudz(k)) = &
                df(l1:l2,m,n,iudz(k))                   + s2*p%uud(:,2,k)
          endif
        endif
!
!  Stopping time of dust is calculated in get_stoppingtime
!
        if (ldragforce_dust) then
          call get_stoppingtime(f,p%rho,p%cs2,p%rhod(:,k),k)
!
!  Add drag force on dust
!
          do i=1,3; tausd13(:,i) = tausd1(:,k); enddo
          df(l1:l2,m,n,iudx(k):iudz(k)) = df(l1:l2,m,n,iudx(k):iudz(k)) - &
              tausd13*(p%uud(:,:,k)-p%uu)
!
!  Add drag force on gas (back-reaction from dust)
!
          if (ldragforce_gas) then
            tausg1 = p%rhod(:,k)*tausd1(:,k)*p%rho1
            if (tausgmin/=0.0) where (tausg1>=tausg1max) tausg1=tausg1max
            do i=1,3; tausg13(:,i) = tausg1; enddo
            df(l1:l2,m,n,iux:iuz) = df(l1:l2,m,n,iux:iuz) - &
                tausg13*(p%uu-p%uud(:,:,k))
            if (lfirst.and.ldt) dt1_max=max(dt1_max,(tausg1+tausd1(:,k))/cdtd)
          else
            if (lfirst.and.ldt) dt1_max=max(dt1_max,tausd1(:,k)/cdtd)
          endif
        endif
!
!  Add constant background pressure gradient beta=alpha*H0/r0, where alpha
!  comes from a global pressure gradient P = P0*(r/r0)^alpha.
!  (the term must be added to the dust equation of motion when measuring
!  velocities relative to the shear flow modified by the global pressure grad.)
!
        if (beta_dPdr_dust/=0.0) df(l1:l2,m,n,iudx(k)) = &
            df(l1:l2,m,n,iudx(k)) + 1/gamma*p%cs2*beta_dPdr_dust_scaled
!
!  Add pseudo Coriolis force (to drive velocity difference between dust and gas)
!
        if (Omega_pseudo/=0.0) then
          df(l1:l2,m,n,iux) = &
              df(l1:l2,m,n,iux) - Omega_pseudo*(p%uu(:,1)-u0_gas_pseudo)
          df(l1:l2,m,n,iudx(:)) = &
              df(l1:l2,m,n,iudx(:)) - Omega_pseudo*p%uud(:,1,:)
        endif
!
!  Add viscosity on dust
!
        if (lviscosity_dust) then
!
          fviscd=0.0
          diffus_nud=0.0  ! Do not sum viscosity from all dust species
!
          select case (iviscd)
!
!  Viscous force: nud*del2ud
!     -- not physically correct (no momentum conservation)
!
          case('simplified')
            if (headtt) print*, 'Viscous force (dust): nud*del2ud'
            fviscd = fviscd + nud(k)*p%del2ud(:,:,k)
            if (lfirst.and.ldt) diffus_nud=diffus_nud+nud(k)*dxyz_2
!
!  Viscous force: nud*(del2ud+graddivud/3+2Sd.glnnd)
!    -- the correct expression for nud=const
!
          case('nud-const')
            if (headtt) print*, &
                'Viscous force (dust): nud*(del2ud+graddivud/3+2Sd.glnnd)'
            if (ldustdensity) then
              fviscd = fviscd + 2*nud(k)*p%sdglnnd(:,:,k) + &
                  nud(k)*(p%del2ud(:,:,k)+1/3.*p%graddivud(:,:,k))
            else
              fviscd = fviscd + nud(k)*(p%del2ud(:,:,k)+1/3.*p%graddivud(:,:,k))
            endif
            if (lfirst.and.ldt) diffus_nud=diffus_nud+nud(k)*dxyz_2
!
!  Viscous force: nud*del6ud (not momentum-conserving)
!
          case('hyper3_simplified')
            if (headtt) print*, 'Viscous force (dust): nud*del6ud'
            fviscd = fviscd + nud_hyper3(k)*p%del6ud(:,:,k)
            if (lfirst.and.ldt) diffus_nud=diffus_nud+nud_hyper3(k)*dxyz_6

          case('hyper3_rhod_nud-const')
!
!  Viscous force: mud/rhod*del6ud
!
            if (headtt) print*, 'Viscous force (dust): mud/rhod*del6ud'
            mudrhod1=(nud_hyper3(k)*nd0*md0)/p%rhod(:,k)   ! = mud/rhod
            do i=1,3
              fviscd(:,i) = fviscd(:,i) + mudrhod1*p%del6ud(:,i,k)
            enddo
            if (lfirst.and.ldt) diffus_nud=diffus_nud+nud_hyper3(k)*dxyz_6

          case('hyper3_nud-const')
!
!  Viscous force: nud*(del6ud+S.glnnd), where S_ij=d^5 ud_i/dx_j^5
!
            if (headtt) print*, 'Viscous force (dust): nud*(del6ud+S.glnnd)'
            fviscd = fviscd + nud_hyper3(k)*(p%del6ud(:,:,k)+p%sdglnnd(:,:,k))
            if (lfirst.and.ldt) diffus_nud=diffus_nud+nud_hyper3(k)*dxyz_6

          case default

            write (unit=errormsg,fmt=*) 'No such value for iviscd: ', trim(iviscd)
            call fatal_error('duud_dt',errormsg)

          endselect

        df(l1:l2,m,n,iudx(k):iudz(k)) = df(l1:l2,m,n,iudx(k):iudz(k)) + fviscd

        endif
!
!  ``uud/dx'' for timestep
!
        if (lfirst .and. ldt) then
          advec_uud=max(advec_uud,abs(p%uud(:,1,k))*dx_1(l1:l2)+ &
                                  abs(p%uud(:,2,k))*dy_1(  m  )+ &
                                  abs(p%uud(:,3,k))*dz_1(  n  ))
          if (idiag_dtud(k)/=0) &
              call max_mn_name(advec_uud/cdt,idiag_dtud(k),l_dt=.true.)
          if (idiag_dtnud(k)/=0) &
              call max_mn_name(diffus_nud/cdtv,idiag_dtnud(k),l_dt=.true.)
        endif
        if (headtt.or.ldebug) then
          print*,'duud_dt: max(advec_uud) =',maxval(advec_uud)
          print*,'duud_dt: max(diffus_nud) =',maxval(diffus_nud)
        endif
!
!  Calculate diagnostic variables
!
        if (ldiagnos) then
          if ((headtt.or.ldebug) .and. (ip<6)) &
              print*, 'duud_dt: Calculate diagnostic values...'
          if (idiag_udrms(k)/=0) &
              call sum_mn_name(p%ud2(:,k),idiag_udrms(k),lsqrt=.true.)
          if (idiag_udmax(k)/=0) &
              call max_mn_name(p%ud2(:,k),idiag_udmax(k),lsqrt=.true.)
          if (idiag_rdudmax(k)/=0) &
              call max_mn_name(p%rhod(:,k)**2*p%ud2(:,k),idiag_rdudmax(k), &
              lsqrt=.true.)
          if (idiag_ud2m(k)/=0) call sum_mn_name(p%ud2(:,k),idiag_ud2m(k))
          if (idiag_udxm(k)/=0) call sum_mn_name(p%uud(:,1,k),idiag_udxm(k))
          if (idiag_udym(k)/=0) call sum_mn_name(p%uud(:,2,k),idiag_udym(k))
          if (idiag_udzm(k)/=0) call sum_mn_name(p%uud(:,3,k),idiag_udzm(k))
          if (idiag_udx2m(k)/=0) &
              call sum_mn_name(p%uud(:,1,k)**2,idiag_udx2m(k))
          if (idiag_udy2m(k)/=0) &
              call sum_mn_name(p%uud(:,2,k)**2,idiag_udy2m(k))
          if (idiag_udz2m(k)/=0) &
              call sum_mn_name(p%uud(:,3,k)**2,idiag_udz2m(k))
          if (idiag_udm2(k)/=0) call max_mn_name(p%ud2(:,k),idiag_udm2(k))
          if (idiag_divud2m(k)/=0) &
              call sum_mn_name(p%divud(:,k)**2,idiag_divud2m(k))
          if (idiag_rdudxm(k)/=0) &
              call sum_mn_name(p%rhod(:,k)*p%uud(:,1,k),idiag_rdudxm(k))
          if (idiag_rdudym(k)/=0) &
              call sum_mn_name(p%rhod(:,k)*p%uud(:,2,k),idiag_rdudym(k))
          if (idiag_rdudzm(k)/=0) &
              call sum_mn_name(p%rhod(:,k)*p%uud(:,3,k),idiag_rdudzm(k))
          if (idiag_rdudx2m(k)/=0) &
              call sum_mn_name((p%rhod(:,k)*p%uud(:,1,k))**2,idiag_rdudx2m(k))
!
!  xy-averages
!
          if (idiag_udxmz(k)/=0) &
              call xysum_mn_name_z(p%uud(:,1,k),idiag_udxmz(k))
          if (idiag_udymz(k)/=0) &
              call xysum_mn_name_z(p%uud(:,2,k),idiag_udymz(k))
          if (idiag_udzmz(k)/=0) &
              call xysum_mn_name_z(p%uud(:,3,k),idiag_udzmz(k))
          if (idiag_udx2mz(k)/=0) &
              call xysum_mn_name_z(p%uud(:,1,k)**2,idiag_udx2mz(k))
          if (idiag_udy2mz(k)/=0) &
              call xysum_mn_name_z(p%uud(:,2,k)**2,idiag_udy2mz(k))
          if (idiag_udz2mz(k)/=0) &
              call xysum_mn_name_z(p%uud(:,3,k)**2,idiag_udz2mz(k))
!
!  z-averages
!
          if (idiag_udxmxy(k)/=0) &
              call zsum_mn_name_xy(p%uud(:,1,k),idiag_udxmxy(k))
          if (idiag_udymxy(k)/=0) &
              call zsum_mn_name_xy(p%uud(:,2,k),idiag_udymxy(k))
          if (idiag_udzmxy(k)/=0) &
              call zsum_mn_name_xy(p%uud(:,3,k),idiag_udzmxy(k))
!
!  kinetic field components at one point (=pt)
!
          if (lroot.and.m==mpoint.and.n==npoint) then
            if (idiag_udxpt(k)/=0) &
                call save_name(p%uud(lpoint-nghost,1,k),idiag_udxpt(k))
            if (idiag_udypt(k)/=0) &
                call save_name(p%uud(lpoint-nghost,2,k),idiag_udypt(k))
            if (idiag_udzpt(k)/=0) &
                call save_name(p%uud(lpoint-nghost,3,k),idiag_udzpt(k))
          endif
!
!  Things related to vorticity and helicity
!
          if (idiag_odrms(k)/=0) &
              call sum_mn_name(p%od2,idiag_odrms(k),lsqrt=.true.)
          if (idiag_odmax(k)/=0) &
              call max_mn_name(p%od2,idiag_odmax(k),lsqrt=.true.)
          if (idiag_od2m(k)/=0) call sum_mn_name(p%od2,idiag_od2m(k))
          if (idiag_oudm(k)/=0) call sum_mn_name(p%oud,idiag_oudm(k))
!          
        endif
!
!  End loop over dust species
!
      enddo
!
    endsubroutine duud_dt
!***********************************************************************
    subroutine get_dustsurface
!
!  Calculate surface of dust particles
!
    integer :: i
!    
    ad(1)    = (0.75*md(1)*unit_md/(pi*rhods))**dimd1
    surfd(1) = 4*pi*ad(1)**2
    do i=2,ndustspec
      ad(i)  = ad(1)*(md(i)/md(1))**dimd1
      surfd(i) = surfd(1)*(md(i)/md(1))**(1.-dimd1)
    enddo
!
    endsubroutine get_dustsurface
!***********************************************************************
    subroutine get_dustcrosssection
!
!  Calculate surface of dust particles
!
      integer :: i,j
!    
      do i=1,ndustspec
        do j=1,ndustspec
          scolld(i,j) = pi*(ad(i)+ad(j))**2
        enddo
      enddo
!
    endsubroutine get_dustcrosssection
!***********************************************************************
    subroutine get_stoppingtime(f,rho,cs2,rhod,k)
!
!  Calculate stopping time depending on choice of drag law
!
      use Cdata
      use Sub, only: dot2
      
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx) :: rho,rhod,csrho,cs2,deltaud2
      integer :: k
!
      select case(draglaw)
        
      case ('epstein_cst')
        ! Do nothing, initialized in initialize_dustvelocity
      case ('epstein_cst_b')
        tausd1(:,k) = betad(k)/rhod
      case ('epstein_var')
        call dot2(f(l1:l2,m,n,iudx(k):iudz(k))-f(l1:l2,m,n,iux:iuz),deltaud2)
        csrho       = sqrt(cs2+deltaud2)*rho
        tausd1(:,k) = csrho*rhodsad1(k)
      case default
        call fatal_error("get_stoppingtime","No valid drag law specified.")

      endselect
!
    endsubroutine get_stoppingtime
!***********************************************************************
    subroutine read_dustvelocity_init_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
                                                                                                   
      if (present(iostat)) then
        read(unit,NML=dustvelocity_init_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=dustvelocity_init_pars,ERR=99)
      endif
                                                                                                   
                                                                                                   
99    return
    endsubroutine read_dustvelocity_init_pars
!***********************************************************************
    subroutine write_dustvelocity_init_pars(unit)
      integer, intent(in) :: unit
                                                                                                   
      write(unit,NML=dustvelocity_init_pars)
                                                                                                   
    endsubroutine write_dustvelocity_init_pars
!***********************************************************************
    subroutine read_dustvelocity_run_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
                                                                                                   
      if (present(iostat)) then
        read(unit,NML=dustvelocity_run_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=dustvelocity_run_pars,ERR=99)
      endif
                                                                                                   
                                                                                                   
99    return
    endsubroutine read_dustvelocity_run_pars
!***********************************************************************
    subroutine write_dustvelocity_run_pars(unit)
      integer, intent(in) :: unit
                                                                                                   
      write(unit,NML=dustvelocity_run_pars)
                                                                                                   
    endsubroutine write_dustvelocity_run_pars
!***********************************************************************
    subroutine rprint_dustvelocity(lreset,lwrite)
!
!  reads and registers print parameters relevant for hydro part
!
!   3-may-02/axel: coded
!  27-may-02/axel: added possibility to reset list
!
      use Cdata
      use Sub
      use General, only: chn
!
      integer :: iname,inamez,k
      logical :: lreset,lwr
      logical, optional :: lwrite
      character (len=4) :: sdust,sdustspec,suud1,sudx1,sudy1,sudz1
!
!  Write information to index.pro that should not be repeated for i
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
      
      if (lwr) then
        write(3,*) 'ndustspec=',ndustspec
        write(3,*) 'nname=',nname
      endif
!
!  reset everything in case of reset
!
      if (lreset) then
        idiag_dtud=0; idiag_dtnud=0; idiag_ud2m=0; idiag_udx2m=0
        idiag_udxm=0; idiag_udym=0; idiag_udzm=0
        idiag_udy2m=0; idiag_udz2m=0; idiag_udm2=0; idiag_oudm=0; idiag_od2m=0
        idiag_udxpt=0; idiag_udypt=0; idiag_udzpt=0; idiag_udrms=0
        idiag_udmax=0; idiag_odrms=0; idiag_odmax=0; idiag_rdudmax=0
        idiag_udmx=0; idiag_udmy=0; idiag_udmz=0; idiag_divud2m=0
        idiag_epsKd=0; idiag_rdudxm=0;idiag_rdudym=0; idiag_rdudzm=0;
        idiag_rdudx2m=0; idiag_udx2mz=0; idiag_udy2mz=0; idiag_udz2mz=0
      endif
!
!  Loop over dust layers
!
      do k=1,ndustspec
!
!  iname runs through all possible names that may be listed in print.in
!
        if(lroot.and.ip<14) print*,'rprint_dustvelocity: run through parse list'
        do iname=1,nname
          call chn(k,sdust)
          if (ndustspec == 1) sdust=''
          call parse_name(iname,cname(iname),cform(iname), &
              'dtud'//trim(sdust),idiag_dtud(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'dtnud'//trim(sdust),idiag_dtnud(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'udxm'//trim(sdust),idiag_udxm(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'udym'//trim(sdust),idiag_udym(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'udzm'//trim(sdust),idiag_udzm(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'ud2m'//trim(sdust),idiag_ud2m(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'udx2m'//trim(sdust),idiag_udx2m(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'udy2m'//trim(sdust),idiag_udy2m(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'udz2m'//trim(sdust),idiag_udz2m(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'udm2'//trim(sdust),idiag_udm2(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'od2m'//trim(sdust),idiag_od2m(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'oudm'//trim(sdust),idiag_oudm(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'udrms'//trim(sdust),idiag_udrms(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'udmax'//trim(sdust),idiag_udmax(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'rdudmax'//trim(sdust),idiag_rdudmax(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'rdudxm'//trim(sdust),idiag_rdudxm(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'rdudym'//trim(sdust),idiag_rdudym(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'rdudzm'//trim(sdust),idiag_rdudzm(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'rdudx2m'//trim(sdust),idiag_rdudx2m(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'odrms'//trim(sdust),idiag_odrms(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'odmax'//trim(sdust),idiag_odmax(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'udmx'//trim(sdust),idiag_udmx(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'udmy'//trim(sdust),idiag_udmy(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'udmz'//trim(sdust),idiag_udmz(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'divud2m'//trim(sdust),idiag_divud2m(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'epsKd'//trim(sdust),idiag_epsKd(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'udxpt'//trim(sdust),idiag_udxpt(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'udypt'//trim(sdust),idiag_udypt(k))
          call parse_name(iname,cname(iname),cform(iname), &
              'udzpt'//trim(sdust),idiag_udzpt(k))
        enddo
!
!  check for those quantities for which we want xy-averages
!
        do inamez=1,nnamez
          call parse_name(inamez,cnamez(inamez),cformz(inamez), &
              'udxmz'//trim(sdust),idiag_udxmz(k))
          call parse_name(inamez,cnamez(inamez),cformz(inamez), &
              'udymz'//trim(sdust),idiag_udymz(k))
          call parse_name(inamez,cnamez(inamez),cformz(inamez), &
              'udzmz'//trim(sdust),idiag_udzmz(k))
          call parse_name(inamez,cnamez(inamez),cformz(inamez), &
              'udx2mz'//trim(sdust),idiag_udx2mz(k))
          call parse_name(inamez,cnamez(inamez),cformz(inamez), &
              'udy2mz'//trim(sdust),idiag_udy2mz(k))
          call parse_name(inamez,cnamez(inamez),cformz(inamez), &
              'udz2mz'//trim(sdust),idiag_udz2mz(k))
        enddo
!
!  End loop over dust layers
!
      enddo
!
!  Write dust index in short notation
!
      call chn(ndustspec,sdustspec)
      call chn(iuud(1),suud1)
      call chn(iudx(1),sudx1)
      call chn(iudy(1),sudy1)
      call chn(iudz(1),sudz1)
      if (lwr) then
        write(3,*) 'iuud=indgen('//trim(sdustspec)//')*3 + '//trim(suud1)
        write(3,*) 'iudx=indgen('//trim(sdustspec)//')*3 + '//trim(sudx1)
        write(3,*) 'iudy=indgen('//trim(sdustspec)//')*3 + '//trim(sudy1)
        write(3,*) 'iudz=indgen('//trim(sdustspec)//')*3 + '//trim(sudz1)
      endif
!
    endsubroutine rprint_dustvelocity
!***********************************************************************

endmodule Dustvelocity
