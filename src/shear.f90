! $Id$
!
!  This modules deals with all aspects of shear; if no
!  shear is invoked, a corresponding replacement dummy
!  routine is used instead which absorbs all the calls to the
!  shear relevant subroutines listed in here.
!  Shear can either be given relative to Omega (using qshear),
!  or in absolute fashion via the parameters Sshear.
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lshear = .true.
!
!***************************************************************
module Shear
!
  use Cparam, only: ltestflow
  use Cdata
  use General, only: keep_compiler_quiet
  use Messages, only: svn_id, fatal_error
!
  implicit none
!
  integer :: norder_poly = 3
  real :: x0_shear=0.0, qshear0=0.0, sini=0.0
  real :: Sshear1=0.0, Sshear_sini=0.0
  real, dimension(3) :: u0_advec = 0.0
  real, dimension(:), pointer :: B_ext
  character(len=6) :: shear_method = 'fft'
  logical, dimension(mcom) :: lposdef = .false.
  logical :: lshearadvection_as_shift=.false.
  logical :: ltvd_advection = .false., lposdef_advection = .false.
  logical :: lmagnetic_stretching=.true.,lrandomx0=.false.
  logical :: lmagnetic_tilt=.false.
  logical :: lexternal_magnetic_field = .true.
!
  include 'shear.h'
!
  namelist /shear_init_pars/ &
      qshear, qshear0, Sshear, Sshear1, deltay, Omega, u0_advec, &
      lshearadvection_as_shift, shear_method, lrandomx0, x0_shear, &
      norder_poly, ltvd_advection, lposdef_advection, lposdef, &
      lmagnetic_stretching, sini
!
  namelist /shear_run_pars/ &
      qshear, qshear0, Sshear, Sshear1, deltay, Omega, &
      lshearadvection_as_shift, shear_method, lrandomx0, x0_shear, &
      norder_poly, ltvd_advection, lposdef_advection, lposdef, &
      lmagnetic_stretching, lexternal_magnetic_field, sini
!
  integer :: idiag_dtshear=0    ! DIAG_DOC: advec\_shear/cdt
  integer :: idiag_deltay=0     ! DIAG_DOC: deltay
!
!  Module variables
!
  real, dimension(nx) :: uy0 = 0.0
  logical :: lbext = .false.
!
  contains
!***********************************************************************
    subroutine register_shear()
!
!  Initialise variables.
!
!  2-july-02/nils: coded
!
      if (lroot) call svn_id( &
           "$Id$")
!
    endsubroutine register_shear
!***********************************************************************
    subroutine initialize_shear()
!
!  21-nov-02/tony: coded
!  08-jul-04/anders: Sshear calculated whenever qshear /= 0
!
!  Calculate shear flow velocity; if qshear is given, then
!    Sshear=-(qshear-qshear0)*Omega  (shear in advection and magnetic stretching)
!    Sshear1=-qshear*Omega           (Lagrangian shear)
!  are calculated. Otherwise Sshear and Sshear1 keep their values from the input
!  list.
!
!  Definitions:
!    qshear = -(R / Omega) d Omega / dR,
!    qshear0 = 1 - Omega_p / Omega,
!  where Omega_p is the angular speed at which the shearing box revolves about
!  the central host.  If Omega_p = Omega, the usual shearing approximation is
!  recovered.
!
      use SharedVariables, only: get_shared_variable
      use Messages, only: fatal_error
!
      integer :: ierr
!
!  Calculate the shear velocity.
!
      if (qshear/=0.0) then
        Sshear=-(qshear-qshear0)*Omega
        Sshear1=-qshear*Omega
      else if (Sshear/=0.0.and.Sshear1==0.0) then
        Sshear1=Sshear
      endif
!
      uy0 = Sshear * (x(l1:l2) - x0_shear)
!
      if (lroot .and. ip<=12) then
        print*, 'initialize_shear: Sshear,Sshear1=', Sshear, Sshear1
        print*, 'initialize_shear: qshear,qshear0=', qshear, qshear0
      endif
!
!  Get the external magnetic field if exists.
!
      if (lmagnetic .and. .not. lbfield) then
        call get_shared_variable('B_ext', B_ext, ierr)
        if (ierr /= 0) call fatal_error('initialize_shear', 'unable to get shared variable B_ext')
        lbext = any(B_ext /= 0.0)
      endif
!
!  Turn on tilt of magnetic stretching if requested.
!
      if (sini /= 0.) then
        lmagnetic_tilt=.true.
        if (lroot) then
          print*, 'initialize_shear: turn on tilt of magnetic stretching with sini = ', sini
          if (abs(sini) > .1) print*, 'Warning: current formulation only allows for small sini. '
        endif
        Sshear_sini=Sshear*sini
      endif
!
!  Turn on positive definiteness for some common sense variables.
!
      posdef: if (lposdef_advection .and. .not. any(lposdef)) then
        if (ldensity .and. ldensity_nolog) lposdef(irho) = .true.
        if (lenergy .and. lthermal_energy) lposdef(ieth) = .true.
        if (lshock) lposdef(ishock) = .true.
        if (ldetonate) lposdef(idet) = .true.
      endif posdef
!
    endsubroutine initialize_shear
!***********************************************************************
    subroutine read_shear_init_pars(unit,iostat)
!
!  Read initial shear parameters.
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (present(iostat)) then
        read(unit,NML=shear_init_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=shear_init_pars,ERR=99)
      endif
!
99    return
!
    endsubroutine read_shear_init_pars
!***********************************************************************
    subroutine write_shear_init_pars(unit)
!
!  Write initial shear parameters.
!
      integer, intent(in) :: unit
!
      write(unit,NML=shear_init_pars)
!
    endsubroutine write_shear_init_pars
!***********************************************************************
    subroutine read_shear_run_pars(unit,iostat)
!
!  Read run shear parameters.
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (present(iostat)) then
        read(unit,NML=shear_run_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=shear_run_pars,ERR=99)
      endif
!
99    return
!
    endsubroutine read_shear_run_pars
!***********************************************************************
    subroutine write_shear_run_pars(unit)
!
!  Write run shear parameters.
!
      integer, intent(in) :: unit
!
      write(unit,NML=shear_run_pars)
!
    endsubroutine write_shear_run_pars
!***********************************************************************
    subroutine shear_before_boundary(f)
!
!  Actions to take before boundary conditions are set.
!
!   1-may-08/anders: coded
!
      use General, only: random_number_wrapper
      use Mpicomm, only: mpibcast_real
!
      real, dimension (mx,my,mz,mfarray) :: f
!
!  Possible to shear around a random position in x, to let all points
!  be subjected to shear in a statistically equal way.
!
      if (lfirst) then
        if (lrandomx0) then
          if (lroot) then
            call random_number_wrapper(x0_shear)
            x0_shear=x0_shear*Lxyz(1)+xyz0(1)
          endif
          call mpibcast_real(x0_shear,1,0)
          uy0 = Sshear * (x(l1:l2) - x0_shear)
        endif
      endif
!
      call keep_compiler_quiet(f)
!
    endsubroutine shear_before_boundary
!***********************************************************************
    subroutine pencil_criteria_shear()
!
!  All pencils that the Shear module depends on are specified here.
!
!  01-may-09/wlad: coded
!
      if (lhydro)    lpenc_requested(i_uu)=.true.
      if (lmagnetic .and. .not. lbfield) lpenc_requested(i_aa)=.true.
!
    endsubroutine pencil_criteria_shear
!***********************************************************************
    subroutine pencil_interdep_shear(lpencil_in)
!
!  Interdependency among pencils from the Shear module is specified here.
!
!  01-may-09/wlad: coded
!
      logical, dimension(npencils) :: lpencil_in
!
      call keep_compiler_quiet(lpencil_in)
!
    endsubroutine pencil_interdep_shear
!***********************************************************************
    subroutine calc_pencils_shear(f,p)
!
!  Calculate Shear pencils.
!  Most basic pencils should come first, as others may depend on them.
!
!  01-may-09/wlad: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      intent(in) :: f,p
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(p)
!
    endsubroutine calc_pencils_shear
!***********************************************************************
    subroutine shearing(f,df,p)
!
!  Calculates the shear terms -uy0*df/dy (shearing sheat approximation).
!
!  2-jul-02/nils: coded
!  6-jul-02/axel: runs through all nvar variables; added timestep check
! 16-aug-02/axel: use now Sshear which is calculated in param_io.f90
! 20-aug-02/axel: added magnetic stretching term
! 25-feb-11/MR:   restored shearing of testflow solutions, when demanded
! 20-Mar-11/MR:   testflow variables now completely processed in testflow module
!
      use Deriv, only: der
      use Diagnostics, only: max_mn_name
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      real, dimension (nx) :: dfdy
      integer :: j,k,jseg,nseg,na,ne
!
      intent(in)  :: f
!
!  Print identifier.
!
      if (headtt.or.ldebug) then
        print*, 'shearing: Sshear,Sshear1=', Sshear, Sshear1
        print*, 'shearing: qshear,qshear0=', qshear, qshear0
      endif
!
!  Advection of all variables by shear flow.
!
      if (.not. lshearadvection_as_shift) then
! 
        if ( ltestflow ) then
!
!  Treatment of variables in two segments necessary as 
!  shear is potentially handled differently in testflow
!
          nseg = 2
          ne = iuutest-1
        else
          nseg = 1
          ne = nvar
        endif
!
        na=1
        do jseg=1,nseg
!
          comp: do j=na,ne
!           bfield module handles its own shearing.
            if (lbfield .and. ibx <= j .and. j <= ibz) cycle comp
            call der(f,j,dfdy,2)
            df(l1:l2,m,n,j)=df(l1:l2,m,n,j)-uy0*dfdy
          enddo comp
!
          na=iuutest+ntestflow
          ne=nvar
!
        enddo
      endif
!
!  Lagrangian shear of background velocity profile. Appears like a correction
!  to the Coriolis force, but is actually not related to the Coriolis
!  force.
!
      if (lhydro) df(l1:l2,m,n,iuy)=df(l1:l2,m,n,iuy)-Sshear1*p%uu(:,1)
!
!  Add (Lagrangian) shear term for all dust species.
!
      if (ldustvelocity) then
        do k=1,ndustspec
          df(l1:l2,m,n,iudy(k))=df(l1:l2,m,n,iudy(k)) &
            -Sshear1*f(l1:l2,m,n,iudx(k))
        enddo
      endif
!
!  Magnetic stretching and tilt terms (can be turned off for debugging purposes).
!
      if (lmagnetic .and. .not. lbfield .and. lmagnetic_stretching) then
        df(l1:l2,m,n,iax)=df(l1:l2,m,n,iax)-Sshear*p%aa(:,2)
        if (lmagnetic_tilt) then
          df(l1:l2,m,n,iax)=df(l1:l2,m,n,iax)-Sshear_sini*p%aa(:,1)
          df(l1:l2,m,n,iay)=df(l1:l2,m,n,iay)+Sshear_sini*p%aa(:,2)
        endif
      endif
!
!  Consider the external magnetic field.
!
      if (lmagnetic .and. .not. lbfield .and. lexternal_magnetic_field .and. lbext) then
        df(l1:l2,m,n,iax) = df(l1:l2,m,n,iax) + B_ext(3) * uy0
        df(l1:l2,m,n,iaz) = df(l1:l2,m,n,iaz) - B_ext(1) * uy0
      endif
!
!  Testfield stretching term.
!  Loop through all the dax/dt equations and add -S*ay contribution.
!
      if (ltestfield) then
        do j=iaatest,iaztestpq,3
          df(l1:l2,m,n,j)=df(l1:l2,m,n,j)-Sshear*f(l1:l2,m,n,j+1)
        enddo
        if (iuutest/=0) then
          do j=iuutest,iuztestpq,3
            df(l1:l2,m,n,j+1)=df(l1:l2,m,n,j+1)-Sshear*f(l1:l2,m,n,j)
          enddo
        endif
      endif
!
!  Meanfield stretching term.
!  Loop through all the dax/dt equations and add -S*ay contribution.
!
      if (iam/=0) then
        df(l1:l2,m,n,iamx)=df(l1:l2,m,n,iamx)-Sshear*f(l1:l2,m,n,iamy)
      endif
!
!  Take shear into account for calculating time step.
!
      if (lfirst.and.ldt.and.(lhydro.or.ldensity).and. &
          (.not.lshearadvection_as_shift)) &
          advec_shear=abs(uy0*dy_1(m))
!
!  Calculate shearing related diagnostics.
!
      if (ldiagnos) then
        if (idiag_dtshear/=0) &
            call max_mn_name(advec_shear/cdt,idiag_dtshear,l_dt=.true.)
      endif
!
    endsubroutine shearing
!***********************************************************************
    subroutine shear_variables(f,df,nvars,jstart,jstep,shear1)
!
!  Allow shear treatment of variables in other modules
!  jstart, jend - start and end indices of slots in df 
!                 to which advection term is added
!  jstep        - stepsize in df for selecting slots to 
!                 which Langrangian shear is added;
!                 only relevant for velocity variables, 
!                 jstart corresponds to u_x; default value: 3
!                 = 0 : Langrangian shear is not added
!
! 20-Mar-11/MR: coded
!
      use Deriv, only: der
!
      real, dimension(mx,my,mz,mfarray), intent(in)    :: f
      real, dimension(mx,my,mz,mvar)   , intent(inout) :: df
!
      integer, intent(in) :: nvars, jstart 
      integer, intent(in), optional :: jstep
      logical, intent(in), optional :: shear1
!
      integer :: j,jend,js
      real, dimension (nx) :: dfdy
      real :: sh
!
      if ( .not.present(jstep) ) then
        js = 3
      else
        js = jstep
      endif
!
      if ( .not.present(shear1) ) then
        sh = Sshear
      else if ( shear1 ) then
        sh = Sshear1
      else
        sh = Sshear
      endif
!
!  Advection of all variables by shear flow.
!
      jend = jstart+nvars-1
!
      if (.not. lshearadvection_as_shift) then
        do j=jstart,jend
          call der(f,j,dfdy,2)
          df(l1:l2,m,n,j)=df(l1:l2,m,n,j)-uy0*dfdy
        enddo
      endif
!
!  Lagrangian shear of background velocity profile.
!
      if ( js>0 ) then
        do j=jstart,jend,js
          df(l1:l2,m,n,j+1)=df(l1:l2,m,n,j+1)-sh*f(l1:l2,m,n,j)
        enddo
      endif
!
    endsubroutine shear_variables  
!***********************************************************************
    subroutine advance_shear(f,df,dt_shear)
!
!  Advance shear distance, deltay, using dt. Using t instead introduces
!  significant errors when nt = t/dt exceeds ~100,000 steps.
!  This formulation works also when Sshear is changed during the run.
!
!  18-aug-02/axel: incorporated from nompicomm.f90
!  05-jun-12/ccyang: move SAFI to subroutine sheared_advection_fft
!
      use Diagnostics, only: save_name
      use Messages, only: fatal_error
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real :: dt_shear
      integer :: ivar
      logical :: posdef
!
!  Must currently use lshearadvection_as_shift=T when Sshear is positive.
!
      if (Sshear>0. .and. .not. lshearadvection_as_shift &
        .and. ncpus/=1 .and. headt) then
        print*
        print*, 'NOTE: for Sshear > 0, MPI is not completely correct.'
        print*, 'It is better to use lshearadvection_as_shift=T and use:'
        print*, 'FOURIER=fourier_fftpack'
        print*
      endif
!
!  Make sure deltay is in the range 0 <= deltay < Ly (assuming Sshear<0).
!
      deltay=deltay-Sshear*Lx*dt_shear
      deltay=deltay-int(deltay/Ly)*Ly
!
!  Solve for advection by shear motion by shifting all variables and their
!  time derivative (following Gammie 2001). Removes time-step constraint
!  from shear motion.
!
      shear: if (lshearadvection_as_shift) then
        comp: do ivar = 1, mvar
!         bfield module handles its own shearing.
          if (lbfield .and. ibx <= ivar .and. ivar <= ibz) cycle comp
          method: select case (shear_method)
          case ('fft') method
            call sheared_advection_fft(f, ivar, ivar, dt_shear)
            if (.not. llast) call sheared_advection_fft(df, ivar, ivar, dt_shear)
          case ('spline', 'poly') method
            posdef = lposdef_advection .and. lposdef(ivar)
            call sheared_advection_nonfft(f, ivar, ivar, dt_shear, shear_method, ltvd_advection, posdef)
            if (.not. llast) call sheared_advection_nonfft(df, ivar, ivar, dt_shear, shear_method, ltvd_advection, .false.)
          case default method
            call fatal_error('advance_shear', 'unknown method')
          end select method
        enddo comp
      endif shear
!
!  Print identifier.
!
      if (headtt.or.ldebug) print*, 'advance_shear: deltay=',deltay
!
!  Calculate shearing related diagnostics
!
      if (ldiagnos) call save_name(deltay,idiag_deltay)
!
    endsubroutine advance_shear
!***********************************************************************
    subroutine sheared_advection_fft(a, comp_start, comp_end, dt_shear)
!
!  Uses Fourier interpolation to integrate the shearing terms.
!
!  05-jun-12/ccyang: modularized from advance_shear and advect_shear_xparallel
!
!  Input/Ouput Argument
!    a: field to be sheared
!  Input Argument
!    ic1, ic2: start and end indices in a
!    dt_shear: time increment
!
      use Fourier, only: fourier_shift_y, fft_y_parallel
      use Messages, only: fatal_error
!
      real, dimension(:,:,:,:), intent(inout) :: a
      integer, intent(in) :: comp_start, comp_end
      real, intent(in) :: dt_shear
!
      real, dimension(nx,ny,nz) :: a_re, a_im
      real, dimension(nx) :: shift
      integer :: ic
!
!  Sanity check
!
      if (any(u0_advec /= 0.0)) call fatal_error('sheared_advection_fft', 'uniform background advection is not implemented.')
!
!  Find the sheared length as a function of x.
!
      shift = uy0 * dt_shear
      shift = shift - int(shift / Ly) * Ly
!
!  Conduct the Fourier interpolation.
!
      do ic = comp_start, comp_end
        a_re = a(l1:l2,m1:m2,n1:n2,ic)
        if (nprocx == 1) then
          call fourier_shift_y(a_re, shift)
        else
          a_im = 0.
          call fft_y_parallel(a_re, a_im, SHIFT_Y=shift, lneed_im=.false.)
          call fft_y_parallel(a_re, a_im, linv=.true.)
        endif
        a(l1:l2,m1:m2,n1:n2,ic) = a_re
      enddo
!
    endsubroutine sheared_advection_fft
!***********************************************************************
    subroutine sheared_advection_nonfft(a, ic1, ic2, dt_shear, method, tvd, posdef)
!
!  Uses interpolation to integrate the constant advection and shearing
!  terms with either spline or polynomials.
!
!  25-feb-13/ccyang: coded.
!
!  Input/Ouput Argument
!    a: field to be advected and sheared
!  Input Argument
!    ic1, ic2: start and end indices in a
!    dt_shear: time increment
!    method: interpolation method
!
      use General, only: spline, polynomial_interpolation
      use Messages, only: warning, fatal_error
      use Mpicomm, only: transp_xy
!
      real, dimension(:,:,:,:), intent(inout) :: a
      character(len=*), intent(in) :: method
      logical, intent(in) :: tvd, posdef
      integer, intent(in) :: ic1, ic2
      real, intent(in) :: dt_shear
!
      real, dimension(:,:), allocatable :: b
      real, dimension(nxgrid) :: xnew, penc, dpenc, yshift
      real, dimension(nygrid) :: ynew, ynew1
      real, dimension(mygrid) :: by
      character(len=256) :: message
      logical :: error
      integer :: istat
      integer :: ic, j, k
!
!  Santiy check
!
      if (nprocx /= 1) call fatal_error('sheared_advection_spline', 'currently only works with nprocx = 1.')
      if (nygrid > 1 .and. nxgrid /= nygrid) &
        call fatal_error('sheared_advection_spline', 'currently only works with nxgrid = nygrid.')
!
!  Allocate working arrays.
!
      alloc: if (nygrid > 1) then
        allocate(b(nx,ny), stat=istat)
        if (istat /= 0) call fatal_error('sheared_advection_spline', 'unable to allocate array b')
      endif alloc
!
!  Find the displacement traveled with the advection.
!
      xnew = xgrid - dt_shear * u0_advec(1)
      ynew = ygrid - dt_shear * u0_advec(2)
      yshift = Sshear * (xgrid - x0_shear) * dt_shear
!
!  Loop through each component.
!
      comp: do ic = ic1, ic2
!
!  Interpolation in x: assuming the correct boundary conditions have been applied.
!
        scan_xz: do k = n1, n2
          scan_xy: do j = m1, m2
            xmethod: select case (method)
            case ('spline') xmethod
              call spline(xglobal, a(:,j,k,ic), xnew, penc, mx, nxgrid, err=error, msg=message)
            case ('poly') xmethod
              call polynomial_interpolation(xglobal, a(:,j,k,ic), xnew, penc, dpenc, norder_poly, tvd=tvd, posdef=posdef, &
                                            istatus=istat, message=message)
              error = istat /= 0
            case default xmethod
              call fatal_error('sheared_advection_nonfft', 'unknown method')
            endselect xmethod
            if (error) call warning('sheared_advection_nonfft', 'error in x interpolation; ' // trim(message))
            a(l1:l2,j,k,ic) = penc(1:nx)
          enddo scan_xy
        enddo scan_xz
!
!  Interpolation in y: assuming periodic boundary conditions
!
        ydir: if (nygrid > 1) then
          scan_yz: do k = n1, n2
            b = a(l1:l2,m1:m2,k,ic)
            call transp_xy(b)
            scan_yx: do j = 1, ny
              ynew1 = ynew - yshift(j+ipy*ny)
              ynew1 = ynew1 - floor((ynew1 - y0) / Ly) * Ly
!
              by(nghost+1:mygrid-nghost) = b(1:nygrid,j)
              by(1:nghost) = by(mygrid-2*nghost+1:mygrid-nghost)
              by(mygrid-nghost+1:mygrid) = by(nghost+1:nghost+nghost)
!
              ymethod: select case (method)
              case ('spline') ymethod
                call spline(yglobal, by, ynew1, penc, mygrid, nygrid, err=error, msg=message)
              case ('poly') ymethod
                call polynomial_interpolation(yglobal, by, ynew1, penc, dpenc, norder_poly, tvd=tvd, posdef=posdef, &
                                              istatus=istat, message=message)
                error = istat /= 0
              case default ymethod
                call fatal_error('sheared_advection_nonfft', 'unknown method')
              endselect ymethod
              if (error) call warning('sheared_advection_nonfft', 'error in y interpolation; ' // trim(message))
!
              b(:,j) = penc(1:nx)
            enddo scan_yx
            call transp_xy(b)
            a(l1:l2,m1:m2,k,ic) = b
          enddo scan_yz
        endif ydir
!
!  Currently no interpolation in z
!
        if (u0_advec(3) /= 0.0) call fatal_error('sheared_advection_nonfft', 'Advection in z is not implemented.')
!
      enddo comp
!
!  Deallocate working arrays.
!
      if (nygrid > 1) deallocate(b)
!
    endsubroutine sheared_advection_nonfft
!***********************************************************************
    subroutine boundcond_shear(f,ivar1,ivar2)
!
!  Shearing boundary conditions, called from the Boundconds module.
!
!  02-oct-07/anders: coded
!
      use Mpicomm, only: initiate_shearing, finalize_shearing
      use Messages, only: fatal_error
!
      real, dimension (mx,my,mz,mfarray) :: f
      integer :: ivar1, ivar2
!
      if (ip<12.and.headtt) print*, &
          'boundconds_x: use shearing sheet boundary condition'
!
      if (lshearadvection_as_shift) then
        method: select case (shear_method)
        case ('fft') method
          call fourier_shift_ghostzones(f,ivar1,ivar2)
        case ('spline', 'poly') method
          call shift_ghostzones_nonfft(f,ivar1,ivar2)
        case default method
          call fatal_error('boundcond_shear', 'unknown method')
        end select method
      else
        call initiate_shearing(f,ivar1,ivar2)
        call finalize_shearing(f,ivar1,ivar2)
      endif
!
    endsubroutine boundcond_shear
!***********************************************************************
    subroutine fourier_shift_ghostzones(f,ivar1,ivar2)
!
!  Shearing boundary conditions by Fourier interpolation.
!
!  02-oct-07/anders: coded
!
      use Fourier, only: fourier_shift_yz_y
!
      real, dimension (mx,my,mz,mfarray) :: f
      integer :: ivar1, ivar2
!
      real, dimension (ny,nz) :: f_tmp_yz
      integer :: i, ivar
!
      if (nxgrid/=1) then
        f(l2+1:mx,m1:m2,n1:n2,ivar1:ivar2)=f(l1:l1+2,m1:m2,n1:n2,ivar1:ivar2)
        f( 1:l1-1,m1:m2,n1:n2,ivar1:ivar2)=f(l2-2:l2,m1:m2,n1:n2,ivar1:ivar2)
      endif
!
      if (nygrid/=1) then
        do ivar=ivar1,ivar2
          do i=1,3
            f_tmp_yz=f(l1-i,m1:m2,n1:n2,ivar)
            call fourier_shift_yz_y(f_tmp_yz,+deltay)
            f(l1-i,m1:m2,n1:n2,ivar)=f_tmp_yz
            f_tmp_yz=f(l2+i,m1:m2,n1:n2,ivar)
            call fourier_shift_yz_y(f_tmp_yz,-deltay)
            f(l2+i,m1:m2,n1:n2,ivar)=f_tmp_yz
          enddo
        enddo
      endif
!
    endsubroutine fourier_shift_ghostzones
!***********************************************************************
    subroutine shift_ghostzones_nonfft(f, ivar1, ivar2)
!
!  Shearing boundary conditions by spline interpolation.
!
!  25-feb-13/ccyang: coded.
!
      real, dimension(mx,my,mz,mfarray), intent(inout) :: f
      integer, intent(in) :: ivar1, ivar2
!
      integer :: nvar
!
!  Periodically assign the ghost cells in x direction.
!
      xdir: if (nxgrid > 1) then
        f(1:nghost,       m1:m2, n1:n2, ivar1:ivar2) = f(l2-nghost+1:l2, m1:m2, n1:n2, ivar1:ivar2)
        f(mx-nghost+1:mx, m1:m2, n1:n2, ivar1:ivar2) = f(l1:l1+nghost-1, m1:m2, n1:n2, ivar1:ivar2)
      endif xdir
!
!  Shift the ghost cells in y direction.
!
      ydir: if (nygrid > 1) then
        nvar = ivar2 - ivar1 + 1
        call shift_ghostzones_nonfft_subtask(f(1:nghost,m1:m2,n1:n2,ivar1:ivar2), nvar, deltay, shear_method)
        call shift_ghostzones_nonfft_subtask(f(mx-nghost+1:mx,m1:m2,n1:n2,ivar1:ivar2), nvar, -deltay, shear_method)
      endif ydir
!
    endsubroutine shift_ghostzones_nonfft
!***********************************************************************
    subroutine shift_ghostzones_nonfft_subtask(a, nvar, shift, method)
!
!  Subtask for spline_shift_ghostzones.
!
!  25-feb-13/ccyang: coded.
!
      use Mpicomm, only: remap_to_pencil_y, unmap_from_pencil_y
      use General, only: spline, polynomial_interpolation
      use Messages, only: warning, fatal_error
!
      integer, intent(in) :: nvar
      real, dimension(nghost,ny,nz,nvar), intent(inout) :: a
      character(len=*), intent(in) :: method
      real, intent(in) :: shift
!
      real, dimension(nghost,ny,nz) :: work1
      real, dimension(nghost,nygrid,nz) :: work2
      real, dimension(nygrid) :: ynew, penc, dpenc
      real, dimension(mygrid) :: worky
      character(len=256) :: message
      logical :: error, posdef
      integer :: istat
      integer :: ivar, i, k
!
!  Find the new y-coordinates after shift.
!
      ynew = ygrid - shift
      ynew = ynew - floor((ynew - y0) / Ly) * Ly
!
!  Shift the ghost cells.
!
      comp: do ivar = 1, nvar
        work1 = a(:,:,:,ivar)
        call remap_to_pencil_y(work1, work2)
        scan_z: do k = 1, nz
          scan_x: do i = 1, nghost
            worky(nghost+1:mygrid-nghost) = work2(i,:,k)
            worky(1:nghost) = worky(mygrid-2*nghost+1:mygrid-nghost)
            worky(mygrid-nghost+1:mygrid) = worky(nghost+1:nghost+nghost)
!
            dispatch: select case (method)
            case ('spline') dispatch
              call spline(yglobal, worky, ynew, penc, mygrid, nygrid, err=error, msg=message)
            case ('poly') dispatch
              posdef = lposdef_advection .and. lposdef(ivar)
              call polynomial_interpolation(yglobal, worky, ynew, penc, dpenc, norder_poly, tvd=ltvd_advection, posdef=posdef, &
                                            istatus=istat, message=message)
              error = istat /= 0
            case default dispatch
              call fatal_error('shift_ghostzones_nonfft_subtask', 'unknown method')
            endselect dispatch
            if (error) call warning('shift_ghostzones_nonfft_subtask', 'error in spline; ' // trim(message))
!
            work2(i,:,k) = penc
          enddo scan_x
        enddo scan_z
        call unmap_from_pencil_y(work2, work1)
        a(:,:,:,ivar) = work1
      enddo comp
!
    endsubroutine shift_ghostzones_nonfft_subtask
!***********************************************************************
    subroutine rprint_shear(lreset,lwrite)
!
!  Reads and registers print parameters relevant to shearing.
!
!   2-jul-04/tobi: adapted from entropy
!
      use Diagnostics, only: parse_name
!
      integer :: iname
      logical :: lreset,lwr
      logical, optional :: lwrite
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
!  Reset everything in case of reset.
!  (this needs to be consistent with what is defined above!)
!
      if (lreset) then
        idiag_dtshear=0
        idiag_deltay=0
      endif
!
!  iname runs through all possible names that may be listed in print.in.
!
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'dtshear',idiag_dtshear)
        call parse_name(iname,cname(iname),cform(iname),'deltay',idiag_deltay)
      enddo
!
!  Write column where which shear variable is stored.
!
      if (lwr) then
!
      endif
!
    endsubroutine rprint_shear
!***********************************************************************
    subroutine get_uy0_shear(uy0_shear, x)
!
!  Gets the shear velocity.
!
!  08-oct-13/ccyang: coded
!
      real, dimension(:), intent(out) :: uy0_shear
      real, dimension(:), intent(in), optional :: x
!
      if (present(x)) then
        uy0_shear = Sshear * (x - x0_shear)
      else
        if (size(uy0_shear) /= nx) call fatal_error('get_uy0_shear', 'unconformable output array uy0_shear')
        uy0_shear(1:nx) = uy0
      endif
!
    endsubroutine
!***********************************************************************
endmodule Shear
