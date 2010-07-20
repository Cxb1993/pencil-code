! $Id$
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lspecial = .true.
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
!***************************************************************
!
module Special
!
  use Cdata
  use Cparam
  use Messages
  use Sub, only: keep_compiler_quiet
!
  implicit none
!
  include '../special.h'
!
  real :: tdown=0.,allp=0.,Kgpara=0.,cool_RTV=0.,Kgpara2=0.,tdownr=0.,allpr=0.
  real :: lntt0=0.,wlntt=0.,bmdi=0.,hcond1=0.,heatexp=0.,heatamp=0.,Ksat=0.
  real :: diffrho_hyper3=0.,chi_hyper3=0.,chi_hyper2=0.,K_iso=0.
  real :: Bavoid=huge1,nvor=5.,tau_inv=1.,Bz_flux=0.,q0=1.,qw=1.,dq=0.1
  logical :: lgranulation=.false.,lrotin=.true.,lquench=.false.
  logical :: luse_ext_vel_field=.false.,lmassflux=.false.
  integer :: irefz=0,nglevel=3
  real :: massflux=0.,u_add,hcond2=0.,hcond3=0.
!
  real, dimension (nx,ny) :: A_init_x, A_init_y
  real, dimension (mz) :: init_lnTT, init_lnrho
! 
  character (len=labellen), dimension(3) :: iheattype='nothing'
  real :: heat_par1=0.,heat_par2=0.,heat_par3=0.
  real, dimension(2) :: heat_par_exp=(/0.,1./)
  real, dimension(3) :: heat_par_gauss=(/0.,1.,0./)
!
! input parameters
!  namelist /special_init_pars/ dumy
!
! run parameters
  namelist /special_run_pars/ &
       tdown,allp,Kgpara,cool_RTV,lntt0,wlntt,bmdi,hcond1,Kgpara2, &
       tdownr,allpr,heatexp,heatamp,Ksat,diffrho_hyper3, &
       chi_hyper3,chi_hyper2,K_iso,lgranulation,irefz, &
       Bavoid,nglevel,lrotin,nvor,tau_inv,Bz_flux, &
       lquench,q0,qw,dq,massflux,luse_ext_vel_field, &
       lmassflux,hcond2,hcond3,heat_par_gauss,heat_par_exp, &
       iheattype,heat_par1,heat_par2,heat_par3
!!
!! Declare any index variables necessary for main or
!!
!!   integer :: iSPECIAL_VARIABLE_INDEX=0
!!
!! other variables (needs to be consistent with reset list below)
!!
!!   integer :: i_POSSIBLEDIAGNOSTIC=0
!!
    integer :: idiag_dtnewt=0
    integer :: idiag_dtchi2=0   ! DIAG_DOC: $\delta t / [c_{\delta t,{\rm v}}\,
                                ! DIAG_DOC:   \delta x^2/\chi_{\rm max}]$
                                ! DIAG_DOC:   \quad(time step relative to time
                                ! DIAG_DOC:   step based on heat conductivity;
                                ! DIAG_DOC:   see \S~\ref{time-step})
!
    TYPE point
      real, dimension(2) :: pos
      real, dimension(4) :: data
      type(point),pointer :: next
    end TYPE point
!
    Type(point), pointer :: first
    Type(point), pointer :: previous
    Type(point), pointer :: current
    Type(point), pointer,save :: firstlev
    Type(point), pointer,save :: secondlev
    Type(point), pointer,save :: thirdlev
!
    integer :: xrange,yrange,pow
    real, dimension(nxgrid,nygrid) :: w,vx,vy
    real, dimension(nxgrid,nygrid) :: Ux,Uy
    real, dimension(nxgrid,nygrid) :: Ux_ext,Uy_ext
    real, dimension(nxgrid,nygrid) :: BB2
    real :: ampl,dxdy2,ig,granr,pd,life_t,upd,avoid
    integer, dimension(nxgrid,nygrid) :: avoidarr
    real, save :: tsnap_uu=0.,thresh
    integer, save :: isnap
    integer, save, dimension(mseed) :: points_rstate
    real, dimension(nx,ny), save :: ux_local,uy_local
    real, dimension(nx,ny), save :: ux_ext_local,uy_ext_local
    real :: Bzflux
!
  contains
!
!***********************************************************************
    subroutine register_special()
!
!  Configure pre-initialised (i.e. before parameter read) variables
!  which should be know to be able to evaluate
!
!  6-oct-03/tony: coded
!
      if (lroot) call svn_id( &
           "$Id$")
!
    endsubroutine register_special
!***********************************************************************
    subroutine initialize_special(f,lstarting)
!
!  called by run.f90 after reading parameter either at the beginning
!  or if RELOAD is found
!
!  06-oct-03/tony: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      real :: zref
      integer :: i
      logical :: lstarting
!
      call keep_compiler_quiet(f)
!
      if (lgranulation.and.ipz.eq.0) then
        call setdrparams(lstarting)
!
! if irefz is not set choose z=0 or irefz=n1
        if (irefz .eq. 0)  then
          zref = minval(abs(z(n1:n2)))
          irefz = n1
          do i=n1,n2
            if (abs(z(i)).eq.zref) irefz=i; exit
          enddo
!
        endif
      endif
!
      call setup_special()
!
    endsubroutine initialize_special
!***********************************************************************
    subroutine init_special(f)
!
!  initialise special condition; called from start.f90
!  06-oct-2003/tony: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      intent(in) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine init_special
!***********************************************************************
    subroutine setup_special()
!
!  Compute and save initial magnetic vector potential A_init_x/_y
!
!  25-mar-10/Bourdin.KIS: coded
!
      use Fourier, only: fourier_transform_other
      use Mpicomm, only: mpibcast_real, mpisend_real, mpirecv_real, stop_it_if_any
      use Syscalls, only: file_exists
!
      integer, parameter :: prof_nz=150
      real, dimension (prof_nz) :: prof_lnT, prof_z, prof_lnrho
!
      real, dimension(:,:), allocatable :: kx, ky, k2
      real, dimension(:,:), allocatable :: Bz0_i, Bz0_r
      real, dimension(:,:), allocatable :: Ax_i, Ay_i
      real, dimension(:,:), allocatable :: Ax_r, Ay_r
      real, dimension(:), allocatable :: kxp, kyp
!
      real :: dummy,var1,var2
      integer :: idx2,idy2,lend,ierr
      integer :: i,j,px,py,unit=1
      integer :: Ax_tag=366,Ay_tag=367
!
      ! file location settings
      character (len=*), parameter :: mag_field_txt = 'driver/mag_field.txt'
      character (len=*), parameter :: mag_field_dat = 'driver/mag_field.dat'
      character (len=*), parameter :: stratification_dat = 'stratification.dat'
      character (len=*), parameter :: lnrho_dat = 'driver/b_lnrho.dat'
      character (len=*), parameter :: lnT_dat = 'driver/b_lnT.dat'
!
      inquire(IOLENGTH=lend) dummy
!
      if (.not. lfirst_proc_z .or. (bmdi == 0.0)) then
        A_init_x = 0.0
        A_init_y = 0.0
      else
        ! Magnetic field is set only in the bottom layer
        if (lroot) then
          allocate(kx(nxgrid,nygrid), ky(nxgrid,nygrid), k2(nxgrid,nygrid))
          allocate(Bz0_i(nxgrid,nygrid), Bz0_r(nxgrid,nygrid))
          allocate(Ax_i(nxgrid,nygrid), Ay_i(nxgrid,nygrid))
          allocate(Ax_r(nxgrid,nygrid), Ay_r(nxgrid,nygrid))
          allocate(kxp(nxgrid), kyp(nygrid))
          ! Auxiliary quantities:
          ! idx2 and idy2 are essentially =2, but this makes compilers
          ! complain if nygrid=1 (in which case this is highly unlikely to be
          ! correct anyway), so we try to do this better:
          idx2 = min(2,nxgrid)
          idy2 = min(2,nygrid)
!
          kxp=cshift((/(i-(nxgrid-1)/2,i=0,nxgrid-1)/),+(nxgrid-1)/2)*2*pi/Lx
          kyp=cshift((/(i-(nygrid-1)/2,i=0,nygrid-1)/),+(nygrid-1)/2)*2*pi/Ly
!
          kx=spread(kxp,2,nygrid)
          ky=spread(kyp,1,nxgrid)
!
          k2 = kx*kx + ky*ky
!
          ! Read in magnetogram
          if (file_exists(mag_field_txt)) then
            open (unit,file=mag_field_txt)
            read (unit,*,iostat=ierr) Bz0_r
            if (ierr /= 0) call stop_it_if_any(.true.,'setup_special: '// &
                'Error reading magnetogram file: "'//trim(mag_field_txt)//'"')
            close (unit)
          elseif (file_exists(mag_field_dat)) then
            open (unit,file=mag_field_dat,form='unformatted',status='unknown', &
                recl=lend*nxgrid*nygrid,access='direct')
            read (unit,rec=1,iostat=ierr) Bz0_r
            if (ierr /= 0) call stop_it_if_any(.true.,'setup_special: '// &
                'Error reading magnetogram file: "'//trim(mag_field_dat)//'"')
            close (unit)
          else
            call stop_it_if_any(.true., 'setup_special: No magnetogram file found.')
          endif
!
          ! Gauss to Tesla and SI to PENCIL units
          Bz0_r = Bz0_r * 1e-4 / unit_magnetic
          Bz0_i = 0.
!
          ! Fourier Transform of Bz0:
          call fourier_transform_other(Bz0_r,Bz0_i)
!
          where (k2 /= 0)
            Ax_r = -Bz0_i*ky/k2*exp(-sqrt(k2)*z(n1) )
            Ax_i =  Bz0_r*ky/k2*exp(-sqrt(k2)*z(n1) )
!
            Ay_r =  Bz0_i*kx/k2*exp(-sqrt(k2)*z(n1) )
            Ay_i = -Bz0_r*kx/k2*exp(-sqrt(k2)*z(n1) )
          elsewhere
            Ax_r = -Bz0_i*ky/ky(1,idy2)*exp(-sqrt(k2)*z(n1) )
            Ax_i =  Bz0_r*ky/ky(1,idy2)*exp(-sqrt(k2)*z(n1) )
!
            Ay_r =  Bz0_i*kx/kx(idx2,1)*exp(-sqrt(k2)*z(n1) )
            Ay_i = -Bz0_r*kx/kx(idx2,1)*exp(-sqrt(k2)*z(n1) )
          endwhere
!
          deallocate(kx, ky, k2)
          deallocate(Bz0_i, Bz0_r)
          deallocate(kxp, kyp)
!
          call fourier_transform_other(Ax_r,Ax_i,linv=.true.)
          call fourier_transform_other(Ay_r,Ay_i,linv=.true.)
!
          ! Distribute inital A data
          do px=0, nprocx-1
            do py=0, nprocy-1
              if ((px /= 0) .or. (py /= 0)) then
                A_init_x = Ax_r(px*nx+1:(px+1)*nx,py*ny+1:(py+1)*ny)
                A_init_y = Ay_r(px*nx+1:(px+1)*nx,py*ny+1:(py+1)*ny)
                call mpisend_real (A_init_x, (/ nx, ny /), px+py*nprocx, Ax_tag)
                call mpisend_real (A_init_y, (/ nx, ny /), px+py*nprocx, Ay_tag)
              endif
            enddo
          enddo
          A_init_x = Ax_r(1:nx,1:ny)
          A_init_y = Ay_r(1:nx,1:ny)
!
          deallocate(Ax_i, Ay_i)
          deallocate(Ax_r, Ay_r)
!
        else
          ! Receive inital A data
          call mpirecv_real (A_init_x, (/ nx, ny /), 0, Ax_tag)
          call mpirecv_real (A_init_y, (/ nx, ny /), 0, Ay_tag)
        endif
      endif
      ! globally catch eventual 'stop_it_if_any' calls from single MPI ranks
      call stop_it_if_any(.false.,'')
!
!  Initial temperature profile is given in ln(T) [K] over z [Mm]
!  It will be read at the beginning and then kept in memory
!
!  Only read in if needed, e.g. Newton cooling
      if (tdown/=0) then
      if (lroot.and.(ltemperature.or.lentropy)) then
        ! check wether stratification.dat or b_ln*.dat should be used
        if (file_exists(stratification_dat)) then
          open (unit,file=stratification_dat)
          do i=1,nzgrid
            read(unit,*,iostat=ierr) dummy,var1,var2
            if (ierr /= 0) call stop_it_if_any(.true.,'setup_special: '// &
                'Error reading stratification file: "'//trim(stratification_dat)//'"')
            if ((i > ipz*nz) .and. (i <= (ipz+1)*nz)) then
              j = i - ipz*nz
              init_lnrho(j+nghost)=var1
              init_lnTT(j+nghost) =var2
            endif
          enddo
          close(unit)
        elseif (file_exists(lnT_dat) .and. file_exists(lnrho_dat)) then
          open (unit,file=lnT_dat,form='unformatted',status='unknown',recl=lend*prof_nz)
          read (unit,iostat=ierr) prof_lnT
          read (unit,iostat=ierr) prof_z
          if (ierr /= 0) call stop_it_if_any(.true.,'setup_special: '// &
              'Error reading stratification file: "'//trim(lnT_dat)//'"')
          close (unit)
!
          open (unit,file=lnrho_dat,form='unformatted',status='unknown',recl=lend*prof_nz)
          read (unit,iostat=ierr) prof_lnrho
          if (ierr /= 0) call stop_it_if_any(.true.,'setup_special: '// &
              'Error reading stratification file: "'//trim(lnrho_dat)//'"')
          close (unit)
!
          prof_lnT = prof_lnT - alog(real(unit_temperature))
          prof_lnrho = prof_lnrho - alog(real(unit_density))
!
          if (unit_system == 'SI') then
            prof_z = prof_z * 1.e6 / unit_length
          elseif (unit_system == 'cgs') then
            prof_z = prof_z * 1.e8 / unit_length
          endif
!
          do j=n1,n2
            if (z(j) < prof_z(1) ) then
              init_lnTT(j) = prof_lnT(1)
              init_lnrho(j)= prof_lnrho(1)
            elseif (z(j) >= prof_z(prof_nz)) then
              init_lnTT(j) = prof_lnT(prof_nz)
              init_lnrho(j) = prof_lnrho(prof_nz)
            else
              do i=1,prof_nz-1
                if ((z(j) >= prof_z(i)) .and. (z(j) < prof_z(i+1))) then
                  ! linear interpolation: y = m*(x-x1) + y1
                  init_lnTT(j) = (prof_lnT(i+1)-prof_lnT(i)) / &
                      (prof_z(i+1)-prof_z(i)) * (z(j)-prof_z(i)) + prof_lnT(i)
                  init_lnrho(j) = (prof_lnrho(i+1)-prof_lnrho(i)) / &
                      (prof_z(i+1)-prof_z(i)) * (z(j)-prof_z(i)) + prof_lnrho(i)
                  exit
                endif
              enddo
            endif
          enddo
        else
          call stop_it_if_any(.true.,'setup_special: No stratification file found.')
        endif
      endif
      ! globally catch eventual 'stop_it_if_any' calls from single MPI ranks
      call stop_it_if_any(.false.,'')
!
      ! distribute stratification data
      call mpibcast_real(init_lnTT, prof_nz)
      call mpibcast_real(init_lnrho, prof_nz)
!
      endif
!
    endsubroutine setup_special
!***********************************************************************
    subroutine pencil_criteria_special()
!
!  All pencils that this special module depends on are specified here.
!
!  18-07-06/tony: coded
!
      integer :: i
!
      if (cool_RTV/=0) then
        lpenc_requested(i_lnrho)=.true.
        lpenc_requested(i_lnTT)=.true.
        lpenc_requested(i_cp1)=.true.
      endif
!
      if (tdown/=0) then
        lpenc_requested(i_lnrho)=.true.
        lpenc_requested(i_lnTT)=.true.
      endif
!
      if (hcond1/=0) then
        lpenc_requested(i_bb)=.true.
        lpenc_requested(i_bij)=.true.
        lpenc_requested(i_lnTT)=.true.
        lpenc_requested(i_glnTT)=.true.
        lpenc_requested(i_hlnTT)=.true.
        lpenc_requested(i_del2lnTT)=.true.
        lpenc_requested(i_lnrho)=.true.
        lpenc_requested(i_glnrho)=.true.
      endif
!
      if (hcond2/=0) then
        lpenc_requested(i_bb)=.true.
        lpenc_requested(i_bij)=.true.
        lpenc_requested(i_glnTT)=.true.
        lpenc_requested(i_hlnTT)=.true.
        lpenc_requested(i_glnrho)=.true.
      endif
!
      if (hcond3/=0) then
        lpenc_requested(i_bb)=.true.
        lpenc_requested(i_bij)=.true.
        lpenc_requested(i_glnTT)=.true.
        lpenc_requested(i_hlnTT)=.true.
        lpenc_requested(i_glnrho)=.true.
      endif
!
      if (K_iso/=0) then
        lpenc_requested(i_glnrho)=.true.
        lpenc_requested(i_TT)=.true.
        lpenc_requested(i_lnTT)=.true.
        lpenc_requested(i_glnTT)=.true.
        lpenc_requested(i_hlnTT)=.true.
        lpenc_requested(i_del2lnTT)=.true.
      endif
!
      if (Kgpara/=0) then
        lpenc_requested(i_bb)=.true.
        lpenc_requested(i_bij)=.true.
        lpenc_requested(i_TT)=.true.
        lpenc_requested(i_lnTT)=.true.
        lpenc_requested(i_glnTT)=.true.
        lpenc_requested(i_hlnTT)=.true.
        lpenc_requested(i_del2lnTT)=.true.
        lpenc_requested(i_rho1)=.true.
        lpenc_requested(i_glnrho)=.true.
        lpenc_requested(i_cp1)=.true.
        lpenc_requested(i_rho1)=.true.
      endif
!
      if (idiag_dtchi2/=0) then
        lpenc_diagnos(i_rho1)=.true.
        lpenc_diagnos(i_cv1) =.true.
        lpenc_diagnos(i_cs2)=.true.
      endif
!
      do i=1,3
        select case(iheattype(i))
        case ('sven')
          lpenc_diagnos(i_cp1)=.true.
          lpenc_diagnos(i_TT1)=.true.
          lpenc_diagnos(i_rho1)=.true.
        endselect
      enddo
!
    endsubroutine pencil_criteria_special
!***********************************************************************
    subroutine dspecial_dt(f,df,p)
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      intent(in) :: f,p
      intent(inout) :: df
!
!  identify module and boundary conditions
!
      if (headtt.or.ldebug) print*,'dspecial_dt: SOLVE dSPECIAL_dt'
!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
!
    endsubroutine dspecial_dt
!***********************************************************************
    subroutine read_special_run_pars(unit,iostat)
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (present(iostat)) then
        read(unit,NML=special_run_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=special_run_pars,ERR=99)
      endif
!
      if (Kgpara2/=0) then
        if (K_iso/=0) then
          call fatal_error('calc_heatcond_grad', &
              'Use only K_iso instead of Kgpara2')
        else
          call warning('calc_heatcond_grad', &
              'Please use K_iso instead of Kgpara2')
          K_iso = Kgpara2
        endif
      endif
!
 99    return
!
    endsubroutine read_special_run_pars
!***********************************************************************
    subroutine write_special_run_pars(unit)
!
      integer, intent(in) :: unit
!
      call keep_compiler_quiet(unit)
!
    endsubroutine write_special_run_pars
!***********************************************************************
    subroutine rprint_special(lreset,lwrite)
!
!  reads and registers print parameters relevant to special
!
!   06-oct-03/tony: coded
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
!  reset everything in case of reset
!  (this needs to be consistent with what is defined above!)
!
      if (lreset) then
        idiag_dtchi2=0.
        idiag_dtnewt=0.
      endif
!
!  iname runs through all possible names that may be listed in print.in
!
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'dtchi2',idiag_dtchi2)
        call parse_name(iname,cname(iname),cform(iname),'dtnewt',idiag_dtnewt)
      enddo
!
!  write column where which variable is stored
!
      if (lwr) then
        write(3,*) 'i_dtchi2=',idiag_dtchi2
        write(3,*) 'i_dtnewt=',idiag_dtnewt
      endif
!
    endsubroutine rprint_special
!***********************************************************************
    subroutine get_slices_special(f,slices)
!
!  Write slices for animation of special variables.
!
!  26-jun-06/tony: dummy
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (slice_data) :: slices
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(slices%ready)
!
    endsubroutine get_slices_special
!***********************************************************************
    subroutine special_calc_hydro(f,df,p)
!
      use Diagnostics, only: max_mn_name
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
      real, dimension(nx) :: tmp
!
      if (lgranulation) then
        if (n.eq.n1.and.ipz.eq.0) then
          df(l1:l2,m,n,iux) = df(l1:l2,m,n,iux) - &
              tau_inv*(f(l1:l2,m,n,iux)-ux_local(:,m-nghost))
!
          df(l1:l2,m,n,iuy) = df(l1:l2,m,n,iuy) - &
              tau_inv*(f(l1:l2,m,n,iuy)-uy_local(:,m-nghost))
        endif
!
        tmp(:)  = tau_inv
        if (lfirst.and.ldt) then
          if (ldiagnos.and.idiag_dtnewt/=0) then
            itype_name(idiag_dtnewt)=ilabel_max_dt
            call max_mn_name(tmp        ,idiag_dtnewt,l_dt=.true.)
          endif
          dt1_max=max(dt1_max,tmp/cdts)
        endif
      endif
!
      if (lmassflux) call force_solar_wind(df,p)
!
    endsubroutine special_calc_hydro
!***********************************************************************
    subroutine special_calc_density(f,df,p)
!
!  computes hyper diffusion for non equidistant grid
!  using the IGNOREDX keyword.
!
!  17-feb-10/bing: coded
!
      use Deriv, only: der6
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
      real, dimension (nx) :: fdiff,tmp
!
      if (diffrho_hyper3/=0) then
        if (.not. ldensity_nolog) then
          call der6(f,ilnrho,fdiff,1,IGNOREDX=.true.)
          call der6(f,ilnrho,tmp,2,IGNOREDX=.true.)
          fdiff=fdiff + tmp
          call der6(f,ilnrho,tmp,3,IGNOREDX=.true.)
          fdiff=fdiff + tmp
          fdiff = diffrho_hyper3*fdiff
        else
          call fatal_error('special_calc_density', &
              'not yet implented for ldensity_nolog')
        endif
!
!        if (lfirst.and.ldt) diffus_diffrho3=diffus_diffrho3+diffrho_hyper3
!
        df(l1:l2,m,n,ilnrho) = df(l1:l2,m,n,ilnrho) + fdiff
!
        if (headtt) print*,'special_calc_density: diffrho_hyper3=', &
            diffrho_hyper3
      endif
!
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_density
!***********************************************************************
    subroutine special_calc_entropy(f,df,p)
!
!   calculate a additional 'special' term on the right hand side of the
!   entropy (or temperature) equation.
!
!  23-jun-08/bing: coded
!  17-feb-10/bing: added hyperdiffusion for non-equidistant grid
!
      use Deriv, only: der6,der4
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
      real, dimension (nx) :: hc,tmp
!
      if (chi_hyper3/=0) then
        hc(:) = 0.
        call der6(f,ilnTT,tmp,1,IGNOREDX=.true.)
        hc = hc + tmp
        call der6(f,ilnTT,tmp,2,IGNOREDX=.true.)
        hc = hc + tmp
        call der6(f,ilnTT,tmp,3,IGNOREDX=.true.)
        hc = hc + tmp
        hc = chi_hyper3*hc
        df(l1:l2,m,n,ilnTT) = df(l1:l2,m,n,ilnTT) + hc
!
!  due to ignoredx chi_hyperx has [1/s]
!
        if (lfirst.and.ldt) diffus_chi3=diffus_chi3  &
            + chi_hyper3
      endif
!
      if (chi_hyper2/=0) then
        hc(:) = 0.
        call der4(f,ilnTT,tmp,1,IGNOREDX=.true.)
        hc =  hc - chi_hyper2*tmp
        call der4(f,ilnTT,tmp,2,IGNOREDX=.true.)
        hc =  hc - chi_hyper2*tmp
        call der4(f,ilnTT,tmp,3,IGNOREDX=.true.)
        hc =  hc - chi_hyper2*tmp
        df(l1:l2,m,n,ilnTT) = df(l1:l2,m,n,ilnTT) + hc
!
!  due to ignoredx chi_hyperx has [1/s]
!
        if (lfirst.and.ldt) diffus_chi3=diffus_chi3 &
            + chi_hyper2
      endif
!
      if (Kgpara/=0) call calc_heatcond_tensor(df,p,Kgpara,2.5)
      if (hcond1/=0) call calc_heatcond_constchi(df,p)
      if (hcond2/=0) call calc_heatcond_glnTT(df,p)
      if (hcond3/=0) call calc_heatcond_glnTT_iso(df,p)
      if (cool_RTV/=0) call calc_heat_cool_RTV(df,p)
      if (tdown/=0) call calc_heat_cool_newton(df,p)
      if (K_iso/=0) call calc_heatcond_grad(df,p)
      if (iheattype(1)/='nothing') call calc_artif_heating(df,p)
!
    endsubroutine special_calc_entropy
!***********************************************************************
    subroutine special_before_boundary(f)
!
!   Possibility to modify the f array before the boundaries are
!   communicated.
!
!   Some precalculated pencils of data are passed in for efficiency
!   others may be calculated directly from the f array
!
!   06-jul-06/tony: coded
!
      use Mpicomm, only: stop_it
!
      real, dimension(mx,my,mz,mfarray) :: f
!
!  Do somehow Newton cooling.
!
      if (lfirst_proc_z .and. (bmdi /= 0.0)) then
        f(l1:l2,m1:m2,n1,iax)=f(l1:l2,m1:m2,n1,iax)*(1.-dt*bmdi) + &
            dt*bmdi * A_init_x
        f(l1:l2,m1:m2,n1,iay)=f(l1:l2,m1:m2,n1,iay)*(1.-dt*bmdi) + &
            dt*bmdi * A_init_y
!
        if (bmdi*dt > 1) call stop_it('special before boundary: bmdi*dt > 1 ')
      endif
!
! Read external velocity file. Has to be read before the granules are
! calculated.
      if (luse_ext_vel_field) call read_ext_vel_field()
!
! Compute photospheric granulation.
      if (lgranulation .and. ipz.eq.0 ) then
        if (.not. lpencil_check_at_work) call uudriver(f)
      endif
!
      if (lmassflux) call get_wind_speed_offset(f)
!
    endsubroutine special_before_boundary
!***********************************************************************
    subroutine calc_heat_cool_newton(df,p)
!
!  newton cooling dT/dt = -1/tau * (T-T0)
!
      use Diagnostics, only: max_mn_name
!
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
!
      integer, parameter :: prof_nz=150
      real, dimension (nx) :: newton,newtonr,tmp_tau
      real, dimension (prof_nz) :: prof_lnT,prof_z,prof_lnrho
      real, dimension (mz), save :: init_lnTT,init_lnrho
      real :: dummy,var1,var2
      logical :: exist
      integer :: i,lend,j,stat
!
      if (headtt) print*,'special_calc_entropy: newton cooling',tdown
!
!  Initial temperature profile is given in ln(T) [K] over z [Mm]
!  It will be read at the beginning and then kept in memory
!
      if (it .eq. 1 .and. lfirstpoint) then
!
!   check wether stratification.dat or b_ln*.dat should be used
!
        inquire(file='stratification.dat',exist=exist)
        if (exist) then
          open (10+ipz,file='stratification.dat')
          do i=1,nzgrid
            read(10+ipz,*,iostat=stat) dummy,var1,var2
            if (i.gt.ipz*nz.and.i.le.(ipz+1)*nz) then
              j = i - ipz*nz
              init_lnrho(j+nghost)=var1
              init_lnTT(j+nghost) =var2
            endif
          enddo
          close(10+ipz)
        else
          inquire(IOLENGTH=lend) dummy
          open (10,file='driver/b_lnT.dat',form='unformatted', &
              status='unknown',recl=lend*prof_nz)
          read (10) prof_lnT
          read (10) prof_z
          close (10)
          !
          open (10,file='driver/b_lnrho.dat',form='unformatted', &
              status='unknown',recl=lend*prof_nz)
          read (10) prof_lnrho
          close (10)
          !
          prof_lnT = prof_lnT - alog(real(unit_temperature))
          prof_lnrho = prof_lnrho - alog(real(unit_density))
          !
          if (unit_system == 'SI') then
            prof_z = prof_z * 1.e6 / unit_length
          elseif (unit_system == 'cgs') then
            prof_z = prof_z * 1.e8 / unit_length
          endif
          !
          do j=n1,n2
            if (z(j) .lt. prof_z(1) ) then
              init_lnTT(j) = prof_lnT(1)
              init_lnrho(j)= prof_lnrho(1)
            elseif (z(j) .ge. prof_z(prof_nz)) then
              init_lnTT(j) = prof_lnT(prof_nz)
              init_lnrho(j) = prof_lnrho(prof_nz)
            else
              do i=1,prof_nz-1
                if (z(j) .ge. prof_z(i) .and. z(j) .lt. prof_z(i+1)) then
                  !
                  ! linear interpol   y = m*(x-x1) + y1
                  init_lnTT(j) = (prof_lnT(i+1)-prof_lnT(i))/(prof_z(i+1)-prof_z(i)) *&
                      (z(j)-prof_z(i)) + prof_lnT(i)
                  init_lnrho(j) = (prof_lnrho(i+1)-prof_lnrho(i))/(prof_z(i+1)-prof_z(i)) *&
                      (z(j)-prof_z(i)) + prof_lnrho(i)
                  exit
                endif
              enddo
            endif
          enddo
        endif
      endif
      !
      !  Get reference temperature
      !
      newton  = exp(init_lnTT(n)-p%lnTT)-1.
      newtonr = exp(init_lnrho(n)-p%lnrho)-1.
!
      tmp_tau = tdownr* (exp(-allpr*(z(n)*unit_length*1e-6)) )
      newtonr = newtonr * tmp_tau
!
      tmp_tau = tdown* (exp(-allp*(z(n)*unit_length*1e-6)) )
      newton  = newton  * tmp_tau
      !
      !  Add newton cooling term to entropy
      !
      df(l1:l2,m,n,ilnTT) = df(l1:l2,m,n,ilnTT) + newton
      df(l1:l2,m,n,ilnrho) = df(l1:l2,m,n,ilnrho) + newtonr
      !
      if (lfirst.and.ldt) then
        if (ldiagnos.and.idiag_dtnewt/=0) then
          itype_name(idiag_dtnewt)=ilabel_max_dt
          call max_mn_name(tmp_tau        ,idiag_dtnewt,l_dt=.true.)
        endif
        dt1_max=max(dt1_max,tdown*exp(-allp*(z(n)*unit_length*1e-6))/cdts)
      endif
!
    endsubroutine calc_heat_cool_newton
!***********************************************************************
    subroutine calc_heatcond_tensor(df,p,Kpara,expo)
!
!    anisotropic heat conduction with T^5/2
!    Div K T Grad ln T
!      =Grad(KT).Grad(lnT)+KT DivGrad(lnT)
!
      use Diagnostics,     only : max_mn_name
      use Sub,             only : dot2,dot,multsv,multmv,cubic_step
      use Io,              only : output_pencil
      use EquationOfState, only : gamma
!
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (nx,3) :: hhh,bunit,tmpv,gKp
      real, dimension (nx) :: tmpj,hhh2,quenchfactor
      real, dimension (nx) :: cosbgT,glnTT2,b2,bbb,b1,tmpk
      real, dimension (nx) :: chi_1,chi_2,rhs
      real :: Ksatb,Kpara,expo
      integer :: i,j,k
      type (pencil_case) :: p
!
!  calculate unit vector of bb
!
      call dot2(p%bb,bbb,PRECISE_SQRT=.true.)
      b1=1./max(tini,bbb)
      call multsv(b1,p%bb,bunit)
!
!  calculate H_i
!
      do i=1,3
        hhh(:,i)=0.
        do j=1,3
          tmpj(:)=0.
          do k=1,3
            tmpj(:)=tmpj(:)-2.*bunit(:,k)*p%bij(:,k,j)
          enddo
          hhh(:,i)=hhh(:,i)+bunit(:,j)*(p%bij(:,i,j)+bunit(:,i)*tmpj(:))
        enddo
      enddo
      call multsv(b1,hhh,tmpv)
!
!  calculate abs(h) limiting
!
      call dot2(tmpv,hhh2,PRECISE_SQRT=.true.)
!
!  limit the length of h
!
      quenchfactor=1./max(1.,3.*hhh2*dxmax)
      call multsv(quenchfactor,tmpv,hhh)
!
      call dot(hhh,p%glnTT,rhs)
!
      chi_1 =  Kpara * p%rho1 * p%TT**expo*cubic_step(t*unit_time,300.,300.)
!
      tmpv(:,:)=0.
      do i=1,3
        do j=1,3
          tmpv(:,i)=tmpv(:,i)+p%glnTT(:,j)*p%hlnTT(:,j,i)
        enddo
      enddo
!
      gKp = (expo+1.) * p%glnTT
!
      call dot2(p%glnTT,glnTT2)
!
      if (Ksat/=0.) then
        Ksatb = Ksat*7.28e7 /unit_velocity**3. * unit_temperature**1.5
!
        where (glnTT2 .le. tini)
          chi_2 =  0.
        elsewhere
          chi_2 =  Ksatb * sqrt(p%TT/max(tini,glnTT2))
        endwhere
!
        where (chi_1 .gt. chi_2)
          gKp(:,1)=p%glnrho(:,1) + 1.5*p%glnTT(:,1) - tmpv(:,1)/max(tini,glnTT2)
          gKp(:,2)=p%glnrho(:,2) + 1.5*p%glnTT(:,2) - tmpv(:,2)/max(tini,glnTT2)
          gKp(:,3)=p%glnrho(:,3) + 1.5*p%glnTT(:,3) - tmpv(:,3)/max(tini,glnTT2)
          chi_1 =  chi_2
        endwhere
      endif
!
      call dot(bunit,gKp,tmpj)
      call dot(bunit,p%glnTT,tmpk)
      rhs = rhs + tmpj*tmpk
!
      call multmv(p%hlnTT,bunit,tmpv)
      call dot(tmpv,bunit,tmpj)
      rhs = rhs + tmpj
!
      rhs = gamma*rhs*chi_1
!
      df(l1:l2,m,n,ilnTT)=df(l1:l2,m,n,ilnTT) + rhs
!
!  for timestep extension multiply with the
!  cosine between grad T and bunit
!
      call dot(p%bb,p%glnTT,cosbgT)
      call dot2(p%bb,b2)
!
      where (glnTT2*b2.le.tini)
        cosbgT=0.
      elsewhere
        cosbgT=cosbgT/sqrt(glnTT2*b2)
      endwhere
!
      if (lfirst.and.ldt) then
        chi_1=abs(cosbgT)*chi_1
        diffus_chi=diffus_chi+gamma*chi_1*dxyz_2
        if (ldiagnos.and.idiag_dtchi2/=0) then
          call max_mn_name(diffus_chi/cdtv,idiag_dtchi2,l_dt=.true.)
        endif
      endif
!
    endsubroutine calc_heatcond_tensor
!***********************************************************************
    subroutine calc_heatcond_grad(df,p)
!
! additional heat conduction where the heat flux is
! is proportional to \rho abs(gradT)
! L= Div(rho |Grad(T)| Grad(T))
!
      use Diagnostics,     only : max_mn_name
      use Sub,             only : dot,dot2
      use EquationOfState, only : gamma
!
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (nx,3) :: tmpv
      real, dimension (nx) :: tmpj,tmpi
      real, dimension (nx) :: rhs,g2,chix
      integer :: i,j
      type (pencil_case) :: p
!
      call dot2(p%glnTT,tmpi)
!
      tmpv(:,:)=0.
      do i=1,3
         do j=1,3
            tmpv(:,i)=tmpv(:,i)+p%glnTT(:,j)*p%hlnTT(:,j,i)
         enddo
      enddo
      call dot(tmpv,p%glnTT,tmpj)
!
      call dot(p%glnrho,p%glnTT,g2)
!
      rhs=p%TT*(tmpi*(p%del2lnTT+2.*tmpi + g2)+tmpj)/max(tini,sqrt(tmpi))
!
!      if (itsub .eq. 3 .and. ip .eq. 118) &
!          call output_pencil(trim(directory)//'/tensor3.dat',rhs,1)
!
      df(l1:l2,m,n,ilnTT)=df(l1:l2,m,n,ilnTT)+ K_iso * rhs
!
      if (lfirst.and.ldt) then
        chix=K_iso*p%TT*sqrt(tmpi)        
        diffus_chi=diffus_chi+gamma*chix*dxyz_2
        if (ldiagnos.and.idiag_dtchi2/=0) then
          call max_mn_name(diffus_chi/cdtv,idiag_dtchi2,l_dt=.true.)
        endif
      endif
!
    endsubroutine calc_heatcond_grad
!***********************************************************************
    subroutine calc_heatcond_constchi(df,p)
!
! L = Div( K rho b*(b*Grad(T))
!
      use Diagnostics,     only : max_mn_name
      use Sub,             only : dot2,dot,multsv,multmv,cubic_step
      use EquationOfState, only : gamma
!
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
      real, dimension (nx,3) :: bunit,hhh,tmpv
      real, dimension (nx) :: hhh2,quenchfactor
      real, dimension (nx) :: abs_b,b1
      real, dimension (nx) :: rhs,tmp,tmpi,tmpj,chix
      integer :: i,j,k
!
      intent(in) :: p
      intent(out) :: df
!
      if (headtt) print*,'special/calc_heatcond_chiconst',hcond1
!
!  Define chi= K_0/rho
!
!  calculate unit vector of bb
!
      call dot2(p%bb,abs_b,PRECISE_SQRT=.true.)
      b1=1./max(tini,abs_b)
      call multsv(b1,p%bb,bunit)
!
!  calculate first H_i
!
      do i=1,3
        hhh(:,i)=0.
        do j=1,3
          tmpj(:)=0.
          do k=1,3
            tmpj(:)=tmpj(:)-2.*bunit(:,k)*p%bij(:,k,j)
          enddo
          hhh(:,i)=hhh(:,i)+bunit(:,j)*(p%bij(:,i,j)+bunit(:,i)*tmpj(:))
        enddo
      enddo
      call multsv(b1,hhh,tmpv)
!
!  calculate abs(h) for limiting H vector
!
      call dot2(tmpv,hhh2,PRECISE_SQRT=.true.)
!
!  limit the length of H
!
      quenchfactor=1./max(1.,3.*hhh2*dxmax)
      call multsv(quenchfactor,tmpv,hhh)
!
!  dot H with Grad lnTT
!
      call dot(hhh,p%glnTT,tmp)
!
!  dot Hessian matrix of lnTT with bi*bj, and add into tmp
!
      call multmv(p%hlnTT,bunit,tmpv)
      call dot(tmpv,bunit,tmpj)
      tmp = tmp+tmpj
!
!  calculate (Grad lnTT * bunit)^2 needed for lnecr form; also add into tmp
!
      call dot(p%glnTT,bunit,tmpi)
!
      call dot(p%glnrho,bunit,tmpj)
      tmp=tmp+(tmpj+tmpi)*tmpi
!
!  calculate rhs
!
      chix = hcond1*cubic_step(t*unit_time,300.,300.)
!
      rhs = gamma*chix*tmp
!
      if (.not.(ipz.eq.nprocz-1.and.n.ge.n2-3)) &
          df(l1:l2,m,n,ilnTT)=df(l1:l2,m,n,ilnTT)+rhs
!
!      if (itsub .eq. 3 .and. ip .eq. 118) &
!          call output_pencil(trim(directory)//'/tensor2.dat',rhs,1)
!
      if (lfirst.and.ldt) then
        diffus_chi=diffus_chi+gamma*chix*dxyz_2
        advec_cs2=max(advec_cs2,maxval(chix*dxyz_2))
        if (ldiagnos.and.idiag_dtchi2/=0) then
          call max_mn_name(diffus_chi/cdtv,idiag_dtchi2,l_dt=.true.)
        endif
      endif
!
    endsubroutine calc_heatcond_constchi
!***********************************************************************
    subroutine calc_heatcond_glnTT(df,p)
!
!  L = Div( Grad(lnT)^2  rho b*(b*Grad(T)))
!  => flux = T  Grad(lnT)^2  rho
!    gflux = flux * (glnT + glnrho +Grad( Grad(lnT)^2))
!  => chi =  Grad(lnT)^2
!
      use Diagnostics, only: max_mn_name
      use Sub, only: dot2,dot,multsv,multmv,cubic_step
      use EquationOfState, only: gamma
!
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      real, dimension (nx) :: glnT2
      real, dimension (nx) :: tmp,rhs,chi
      real, dimension (nx,3) :: bunit,hhh,tmpv,gflux
      real, dimension (nx) :: hhh2,quenchfactor
      real, dimension (nx) :: abs_b,b1
      real, dimension (nx) :: tmpj
      integer :: i,j,k
!
      intent(in) :: p
      intent(out) :: df
!
!  calculate unit vector of bb
!
      call dot2(p%bb,abs_b,PRECISE_SQRT=.true.)
      b1=1./max(tini,abs_b)
      call multsv(b1,p%bb,bunit)
!
!  calculate first H_i
!
      do i=1,3
        hhh(:,i)=0.
        do j=1,3
          tmpj(:)=0.
          do k=1,3
            tmpj(:)=tmpj(:)-2.*bunit(:,k)*p%bij(:,k,j)
          enddo
          hhh(:,i)=hhh(:,i)+bunit(:,j)*(p%bij(:,i,j)+bunit(:,i)*tmpj(:))
        enddo
      enddo
      call multsv(b1,hhh,tmpv)
!
!  calculate abs(h) for limiting H vector
!
      call dot2(tmpv,hhh2,PRECISE_SQRT=.true.)
!
!  limit the length of H
!
      quenchfactor=1./max(1.,3.*hhh2*dxmax)
      call multsv(quenchfactor,tmpv,hhh)
!
!  dot H with Grad lnTT
!
      call dot(hhh,p%glnTT,tmp)
!
!  dot Hessian matrix of lnTT with bi*bj, and add into tmp
!
      call multmv(p%hlnTT,bunit,tmpv)
      call dot(tmpv,bunit,tmpj)
      tmp = tmp+tmpj
!
      call dot2(p%glnTT,glnT2)
!
      tmpv = p%glnTT+p%glnrho
!
      call multsv(glnT2,tmpv,gflux)
!
      do i=1,3
        tmpv(:,i) = 2.*(&
            p%glnTT(:,1)*p%hlnTT(:,i,1) + &
            p%glnTT(:,2)*p%hlnTT(:,i,2) + &
            p%glnTT(:,3)*p%hlnTT(:,i,3) )
      enddo
!
      gflux  = gflux +tmpv
!
      call dot(gflux,bunit,rhs)
      call dot(p%glnTT,bunit,tmpj)
      rhs = rhs*tmpj
!
      chi = glnT2*hcond2
!
      rhs = hcond2*(rhs + glnT2*tmp)
!
      df(l1:l2,m,n,ilnTT)=df(l1:l2,m,n,ilnTT) + &
          rhs*gamma*cubic_step(t*unit_time,300.,300.)
!
      if (lfirst.and.ldt) then
        diffus_chi=diffus_chi+gamma*chi*dxyz_2
        if (ldiagnos.and.idiag_dtchi2/=0) then
          call max_mn_name(diffus_chi/cdtv,idiag_dtchi2,l_dt=.true.)
        endif
      endif
!
    endsubroutine calc_heatcond_glnTT
!***********************************************************************
    subroutine calc_heatcond_glnTT_iso(df,p)
!
!  L = Div( Grad(lnT)^2 Grad(T))
!
      use Diagnostics,     only : max_mn_name
      use Sub,             only : dot2,dot,multsv,multmv,cubic_step
      use EquationOfState, only : gamma
!
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
      real, dimension (nx,3) :: tmpv
      real, dimension (nx) :: glnT2,glnT_glnr
      real, dimension (nx) :: tmp,rhs,chi
      integer :: i
!
      intent(in) :: p
      intent(out) :: df
!
      call dot2(p%glnTT,glnT2)
      call dot(p%glnTT,p%glnrho,glnT_glnr)
!
      do i=1,3
        tmpv(:,i) = p%glnTT(:,1)*p%hlnTT(:,1,i) + &
                    p%glnTT(:,2)*p%hlnTT(:,2,i) + &
                    p%glnTT(:,3)*p%hlnTT(:,3,i)
      enddo
      call dot(p%glnTT,tmpv,tmp)
!
      chi = glnT2*hcond3
!
      rhs = 2*tmp+glnT2*(glnT2+p%del2lnTT+glnT_glnr)
!
      df(l1:l2,m,n,ilnTT)=df(l1:l2,m,n,ilnTT) + rhs*gamma*hcond3
!
      if (lfirst.and.ldt) then
        diffus_chi=diffus_chi+gamma*chi*dxyz_2
        if (ldiagnos.and.idiag_dtchi2/=0) then
          call max_mn_name(diffus_chi/cdtv,idiag_dtchi2,l_dt=.true.)
        endif
      endif
!
    endsubroutine calc_heatcond_glnTT_iso
!***********************************************************************
    subroutine calc_heat_cool_RTV(df,p)
!
!  Electron Temperature should be used for the radiative loss
!  L = n_e * n_H * Q(T_e)
!
!  30-jan-08/bing: coded
!
      use EquationOfState, only: gamma
      use Diagnostics,     only: max_mn_name
      use Mpicomm,         only: stop_it
      use Sub,             only: cubic_step
!
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (nx) :: lnQ,rtv_cool,lnTT_SI,lnneni
      real :: unit_lnQ
      type (pencil_case) :: p
!
      unit_lnQ=3*alog(real(unit_velocity))+&
          5*alog(real(unit_length))+alog(real(unit_density))
      lnTT_SI = p%lnTT + alog(real(unit_temperature))
!
!     calculate ln(ne*ni) :
!          ln(ne*ni) = ln( 1.17*rho^2/(1.34*mp)^2)
!     lnneni = 2*p%lnrho + alog(1.17) - 2*alog(1.34)-2.*alog(real(m_p))
!
      lnneni = 2.*(p%lnrho+61.4412 +alog(real(unit_mass)))
!
      lnQ   = get_lnQ(lnTT_SI)
!
      rtv_cool = lnQ-unit_lnQ+lnneni-p%lnTT-p%lnrho
      rtv_cool = gamma*p%cp1*exp(rtv_cool)
!
      rtv_cool = rtv_cool*cool_RTV *cubic_step(t*unit_time,300.,300.)
!     for adjusting by setting cool_RTV in run.in
!
      rtv_cool=rtv_cool &
          *(1.-cubic_step(p%lnrho,-12.-alog(real(unit_density)),3.))
!
!     add to temperature equation
!
      if (ltemperature) then
        df(l1:l2,m,n,ilnTT) = df(l1:l2,m,n,ilnTT)-rtv_cool
      else
        if (lentropy) &
            call stop_it('solar_corona: calc_heat_cool:lentropy=not implented')
      endif
!
      if (lfirst.and.ldt) then
        if (ldiagnos.and.idiag_dtnewt/=0) then
          itype_name(idiag_dtnewt)=ilabel_max_dt
          call max_mn_name(rtv_cool/cdts &
              ,idiag_dtnewt,l_dt=.true.)
        endif
        dt1_max=max(dt1_max,rtv_cool/cdts)
      endif
!
    endsubroutine calc_heat_cool_RTV
!***********************************************************************
    function get_lnQ(lnTT)
!
!  input: lnTT in SI units
!  output: lnP  [p]=W/s * m^3
!
      real, parameter, dimension (37) :: intlnT = (/ &
          8.74982, 8.86495, 8.98008, 9.09521, 9.21034, 9.44060, 9.67086 &
          , 9.90112, 10.1314, 10.2465, 10.3616, 10.5919, 10.8221, 11.0524 &
          , 11.2827, 11.5129, 11.7432, 11.9734, 12.2037, 12.4340, 12.6642 &
          , 12.8945, 13.1247, 13.3550, 13.5853, 13.8155, 14.0458, 14.2760 &
          , 14.5063, 14.6214, 14.7365, 14.8517, 14.9668, 15.1971, 15.4273 &
          ,  15.6576,  69.0776 /)
      real, parameter, dimension (37) :: intlnQ = (/ &
          -93.9455, -91.1824, -88.5728, -86.1167, -83.8141, -81.6650 &
          , -80.5905, -80.0532, -80.1837, -80.2067, -80.1837, -79.9765 &
          , -79.6694, -79.2857, -79.0938, -79.1322, -79.4776, -79.4776 &
          , -79.3471, -79.2934, -79.5159, -79.6618, -79.4776, -79.3778 &
          , -79.4008, -79.5159, -79.7462, -80.1990, -80.9052, -81.3196 &
          , -81.9874, -82.2023, -82.5093, -82.5477, -82.4172, -82.2637 &
          , -0.66650 /)
!
      real, parameter, dimension (16) :: intlnT1 = (/ &
          8.98008,    9.44060,    9.90112,    10.3616,    10.8221,    11.2827 &
         ,11.5129,    11.8583,    12.4340,    12.8945,    13.3550,    13.8155 &
         ,14.2760,    14.9668,    15.8878,    18.4207 /)
      real, parameter, dimension (16) :: intlnQ1 = (/ &
          -83.9292,   -81.2275,   -80.0532,   -80.1837,   -79.6694,   -79.0938 &
         ,-79.1322,   -79.4776,   -79.2934,   -79.6618,   -79.3778,   -79.5159 &
         ,-80.1990,   -82.5093,   -82.1793,   -78.6717 /)
!
      real, dimension(9) :: pars=(/2.12040e+00,3.88284e-01,2.02889e+00, &
          3.35665e-01,6.34343e-01,1.94052e-01,2.54536e+00,7.28306e-01, &
          -2.40088e+01/)
!
      real, dimension (nx) :: lnTT,get_lnQ
      real, dimension (nx) :: slope,ordinate
      real, dimension (nx) :: logT_SI,logQ
      integer :: i,cool_type=4
!
!  select type for cooling fxunction
!  1: 10 points interpolation
!  2: 37 points interpolation
!  3: four gaussian fit
!
      get_lnQ=-1000.
!
      select case(cool_type)
      case(1)
        do i=1,15
          where(lnTT .ge. intlnT1(i) .and. lnTT .lt. intlnT1(i+1))
            slope=(intlnQ1(i+1)-intlnQ1(i))/(intlnT1(i+1)-intlnT1(i))
            ordinate = intlnQ1(i) - slope*intlnT1(i)
            get_lnQ = slope*lnTT + ordinate
          endwhere
        enddo
!
      case(2)
        do i=1,36
          where(lnTT .ge. intlnT(i) .and. lnTT .lt. intlnT(i+1))
            slope=(intlnQ(i+1)-intlnQ(i))/(intlnT(i+1)-intlnT(i))
            ordinate = intlnQ(i) - slope*intlnT(i)
            get_lnQ = slope*lnTT + ordinate
          endwhere
        enddo
!
      case(3)
        call fatal_error('get_lnQ','this invokes epx() to often')
        lnTT  = lnTT*alog10(exp(1.))
        get_lnQ  = -1000.
        !
        get_lnQ = pars(1)*exp(-(lnTT-4.3)**2/pars(2)**2)  &
            +pars(3)*exp(-(lnTT-4.9)**2/pars(4)**2)  &
            +pars(5)*exp(-(lnTT-5.35)**2/pars(6)**2) &
            +pars(7)*exp(-(lnTT-5.85)**2/pars(8)**2) &
            +pars(9)
        !
        get_lnQ = get_lnQ * (20.*(-tanh((lnTT-3.7)*10.))+21)
        get_lnQ = get_lnQ+(tanh((lnTT-6.9)*3.1)/2.+0.5)*3.
        !
        get_lnQ = (get_lnQ +19.-32)*alog(10.)
!
      case(4)
        logT_SI = lnTT*0.43429448+alog(real(unit_temperature))
        where(logT_SI<=3.928)
          logQ =  -7.155e1 + 9*logT_SI
        elsewhere(logT_SI>3.93.and.logT_SI<=4.55)
          logQ = +4.418916e+04 &
              -5.157164e+04 * logT_SI &
              +2.397242e+04 * logT_SI**2 &
              -5.553551e+03 * logT_SI**3 &
              +6.413137e+02 * logT_SI**4 &
              -2.953721e+01 * logT_SI**5
        elsewhere(logT_SI>4.55.and.logT_SI<=5.09)
          logQ = +8.536577e+02 &
              -5.697253e+02 * logT_SI &
              +1.214799e+02 * logT_SI**2 &
              -8.611106e+00 * logT_SI**3
        elsewhere(logT_SI>5.09.and.logT_SI<=5.63)
          logQ = +1.320434e+04 &
              -7.653183e+03 * logT_SI &
              +1.096594e+03 * logT_SI**2 &
              +1.241795e+02 * logT_SI**3 &
              -4.224446e+01 * logT_SI**4 &
              +2.717678e+00 * logT_SI**5
        elsewhere(logT_SI>5.63.and.logT_SI<=6.48)
          logQ = -2.191224e+04 &
              +1.976923e+04 * logT_SI &
              -7.097135e+03 * logT_SI**2 &
              +1.265907e+03 * logT_SI**3 &
              -1.122293e+02 * logT_SI**4 &
              +3.957364e+00 * logT_SI**5
        elsewhere(logT_SI>6.48.and.logT_SI<=6.62)
          logQ = +9.932921e+03 &
              -4.519940e+03 * logT_SI &
              +6.830451e+02 * logT_SI**2 &
              -3.440259e+01 * logT_SI**3
        elsewhere(logT_SI>6.62)
          logQ = -3.991870e+01 + 6.169390e-01 * logT_SI
        endwhere
        get_lnQ = (logQ+19.-32)*2.30259
      case default
        call fatal_error('get_lnQ','wrong type')
      endselect
!
    endfunction get_lnQ
!***********************************************************************
    subroutine calc_artif_heating(df,p)
!
!  30-jan-08/bing: coded
!
      use EquationOfState, only: gamma
      use Sub, only: cubic_step, notanumber
!
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (nx) :: heatinput
      real :: z_Mm
      type (pencil_case) :: p
      integer :: i
!     
      do i=1,3 
        select case(iheattype(i))
        case ('nothing')
          if (headtt) print*,'iheattype:',iheattype(i)
!
        case ('sven')
          ! Volumetric heating rate as it can be found
          ! in the thesis by bingert.
          !
          ! Get height in Mm.
          z_Mm = z(n)*unit_length*1e-6
          !
          ! Compute volumetric heating rate in [W/m^3] as 
          ! found in Bingert's thesis.
          heatinput=heatamp*(1e3*exp(-z_Mm/0.2)+1e-4*exp(-z_Mm/10.))
          !
          ! Convert to pencil units.
          heatinput=heatinput/unit_density/unit_velocity**3*unit_length
          !
          df(l1:l2,m,n,ilnTT) = df(l1:l2,m,n,ilnTT)+ &
              p%TT1*p%rho1*gamma*p%cp1*heatinput*cubic_step(t*unit_time,300.,300.)
!
        case ('exp')
          ! heat_par_exp(1) should be 530 w/m2 (flux,F)
          ! heat_par_exp(2) should be 0.3 Mm (scale height)
          !
          if (headtt) print*,'iheattype:',iheattype(i) 
          z_Mm = z(n)*unit_length*1e-6
          heatinput=heat_par_exp(1)*exp(-z_Mm/heat_par_exp(2))
          ! Convert to pencil units if needed:
          heatinput=heatinput/unit_density/unit_velocity**3*unit_length
          df(l1:l2,m,n,ilnTT) = df(l1:l2,m,n,ilnTT)+ &
              p%TT1*p%rho1*gamma*p%cp1*heatinput*cubic_step(t*unit_time,300.,300.)
!                    
        case ('gauss')
          ! heat_par_gauss(1) is Center (z in Mm)
          ! heat_par_gauss(2) is Width (sigma)
          ! heat_par_gauss(3) is the amplitude (Flux)
          !
          if (headtt) print*,'iheattype:',iheattype(i) 
          z_Mm = z(n)*unit_length*1e-6
          !
          heatinput=heat_par_gauss(3)*exp(-((z_Mm-heat_par_gauss(1))**2/ &
              2*heat_par_gauss(2)**2))
          ! Convert to pencil units if needed:
          heatinput=heatinput/unit_density/unit_velocity**3*unit_length
          df(l1:l2,m,n,ilnTT) = df(l1:l2,m,n,ilnTT)+ &              
              p%TT1*p%rho1*gamma*p%cp1*heatinput*cubic_step(t*unit_time,300.,300.)
          !          
        case default
          if (headtt) call fatal_error('calc_artif_heating', &
              'Please provide correct iheattype')
        endselect
      enddo
!
!      if (lfirst.and.ldt) then
!        dt1_max=max(dt1_max,heatinput/cdts)
!      endif
!
    endsubroutine calc_artif_heating
!***********************************************************************
    subroutine setdrparams(lstarting)
!
      logical :: lstarting
!
! Every granule has 6 values associated with it: data(1-6).
! These contain,  x-position, y-position,
!    current amplitude, amplitude at t=t_0, t_0, and life_time.
!
! Gives intergranular area / (granular+intergranular area)
      ig=0.3
!
! Gives average radius of granule + intergranular lane
! (no smaller than 6 grid points across)
!     here radius of granules is 0.8 Mm or bigger (3 times dx)
!
      if (unit_system.eq.'SI') then
        granr=max(0.8*1.e6/unit_length,3*dx,3*dy)
      elseif  (unit_system.eq.'cgs') then
        granr=max(0.8*1.e8/unit_length,3*dx,3*dy)
      endif
!
! Fractional difference in granule power
      pd=0.15
!
! Gives exponential power of evolvement. Higher power faster growth/decay.
      pow=2
!
! Fractional distance, where after emergence, no granule can emerge
! whithin this radius.(In order to not 'overproduce' granules).
! This limit is unset when granule reaches t_0.
      avoid=0.8
!
! Lifetime of granule
! Now also resolution dependent(5 min for granular scale)
!
      life_t=(60.*5./unit_time)
      !*(granr/(0.8*1e8/u_l))**2
      !  removed since the life time was about 20 min !
!
      dxdy2=dx**2+dy**2
!
! Typical central velocity of granule(1.5e5 cm/s=1.5km/s)
! Has to be multiplied by the smallest distance, since velocity=ampl/dist
! should now also be dependant on smallest granluar scale resolvable.
!
      if (unit_system.eq.'SI') then
        ampl=sqrt(dxdy2)/granr*0.28e4/unit_velocity
      elseif (unit_system.eq.'cgs') then
        ampl=sqrt(dxdy2)/granr*0.28e6/unit_velocity
      endif
!
! fraction of current amplitude to maximum amplitude to the beginning
! and when the granule disapears
      thresh=0.78
!
      xrange=min(nint(1.5*granr*(1+ig)/dx),nint(nxgrid/2.0)-1)
      yrange=min(nint(1.5*granr*(1+ig)/dy),nint(nygrid/2.0)-1)
!
      if (lroot) then
        print*,'| solar_corona: settings for granules'
        print*,'-----------------------------------'
        print*,'| radius [Mm]:',granr*unit_length*1e-6
        print*,'| lifetime [min]',life_t*unit_time/60.
        print*,'| amplitude [km/s]',ampl*unit_velocity*1e-3
        print*,'-----------------------------------'
      endif
!
! Don't reset if RELOAD is used
      if (lstarting) then
        if (associated(first)) nullify(first)
        if (associated(current)) nullify(current)
        if (associated(previous)) nullify(previous)
        if (associated(firstlev)) nullify(firstlev)
        if (associated(secondlev)) nullify(secondlev)
        if (associated(thirdlev)) nullify(thirdlev)
!
        points_rstate(:)=0.
!
        tsnap_uu = t + dsnap
        isnap = 1
!
      endif
!
    endsubroutine setdrparams
!***********************************************************************
    subroutine uudriver(f)
!
! This routine replaces the external computing of granular velocity
! pattern initially written by B. Gudiksen (2004)
!
! It is invoked by setting lgranulation=T in run.in
! additional parameters are
!         Bavoid =0.01 : the magn. field strenght in Tesla at which
!                        no granule is allowed
!         nvod = 5.    : the strength by which the vorticity is
!                        enhanced
!
!  11-may-10/bing: coded
!
      use EquationOfState, only: gamma_inv,get_cp1,gamma_m1,lnrho0,cs20
      use General, only: random_seed_wrapper
      use Mpicomm, only: mpisend_real, mpirecv_real
      use Sub, only: cubic_step
!
      real, dimension(mx,my,mz,mfarray) :: f
      integer :: i,j,ipt
      real, dimension(nx,ny) :: pp_tmp,BB2_local,beta,quench
      real :: cp1,dA
      integer, dimension(2) :: dims=(/nx,ny/)
      integer, dimension(mseed) :: global_rstate
!
! save global random number seed, will be restored after granulation
! is done
      call random_seed_wrapper(GET=global_rstate)
      call random_seed_wrapper(PUT=points_rstate)
!
      call set_B2(f,BB2_local)
!
! set sum(abs(Bz)) to  a given flux
      if (Bz_flux/=0) then
        if (nxgrid/=1.and.nygrid/=1) then
          dA=dx*dy*unit_length**2
        elseif (nygrid==1) then
          dA=dx*unit_length
        elseif (nxgrid==1) then
          dA=dy*unit_length
        endif
       f(l1:l2,m1:m2,n1,iax:iay) = f(l1:l2,m1:m2,n1,iax:iay) * &
            Bz_flux/(Bzflux*dA*unit_magnetic)
      endif
!
      if (lroot) then
        Ux=0.0
        Uy=0.0
!
        call multi_drive3
!
! compute uz to force mass conservation at the zref
!
        do i=0,nprocx-1
          do j=0,nprocy-1
            ipt = i+nprocx*j
            if (ipt.ne.0) then
              call mpisend_real(Ux(i*nx+1:i*nx+nx,j*ny+1:j*ny+ny),dims,ipt,312+ipt)
              call mpisend_real(Uy(i*nx+1:i*nx+nx,j*ny+1:j*ny+ny),dims,ipt,313+ipt)
            else
              ux_local = Ux(i*nx+1:i*nx+nx,j*ny+1:j*ny+ny)
              uy_local = Uy(i*nx+1:i*nx+nx,j*ny+1:j*ny+ny)
            endif
          enddo
        enddo
      else
        call mpirecv_real(ux_local,dims,0,312+iproc)
        call mpirecv_real(uy_local,dims,0,313+iproc)
      endif
!
! for footpoint quenching compute pressure
!
      call get_cp1(cp1)
!
      if (lquench) then
        if (ltemperature) then
          if (ldensity_nolog) then
            call fatal_error('solar_corona', &
                'uudriver only implemented for ltemperature=true')
          else
            pp_tmp =gamma_m1*gamma_inv/cp1 * &
                exp(f(l1:l2,m1:m2,irefz,ilnrho)+f(l1:l2,m1:m2,irefz,ilnrho))
          endif
        else
          if (headt.and.lroot) call warning('solar_corona', &
              'uudriver only implemented for ltemperature=true')
          pp_tmp=gamma_inv*cs20*exp(lnrho0)
        endif
!
        beta =  pp_tmp/max(tini,BB2_local)*2*mu0
!
!  quench velocities to one percent of the granule velocities
        do i=1,ny
          quench(:,i) = cubic_step(beta(:,i),q0,qw)*(1.-dq)+dq
        enddo
!
        ux_local = ux_local * quench
        uy_local = uy_local * quench
      endif
!
      if (luse_ext_vel_field) then
        ux_local = ux_local + ux_ext_local
        uy_local = uy_local + uy_ext_local
      endif
!
      f(l1:l2,m1:m2,irefz,iuz) = 0.
!
! restore global seed and save seed list of the granulation
      call random_seed_wrapper(GET=points_rstate)
      call random_seed_wrapper(PUT=global_rstate)
!
    endsubroutine uudriver
!***********************************************************************
  subroutine multi_drive3
!
    integer,parameter :: gg=3
    real,parameter :: ldif=2.0
    real,dimension(gg),save :: amplarr,granrarr,life_tarr
    integer,dimension(gg),save :: xrangearr,yrangearr
    integer :: k
!
    if (.not.associated(firstlev)) then
      granrarr(1)=granr
      granrarr(2)=granr*ldif
      granrarr(3)=granr*ldif*ldif
!
      amplarr(1)=ampl
      amplarr(2)=ampl/ldif
      amplarr(3)=ampl/(ldif*ldif)
!
      life_tarr(1)=life_t
      life_tarr(2)=ldif**2*life_t
      life_tarr(3)=ldif**4*life_t
!
      xrangearr(1)=xrange
      xrangearr(2)=min(nint(ldif*xrange),nint(nxgrid/2.-1.))
      xrangearr(3)=min(nint(ldif*ldif*xrange),nint(nxgrid/2.-1.))
      yrangearr(1)=yrange
      yrangearr(2)=min(nint(ldif*yrange),nint(nygrid/2-1.))
      yrangearr(3)=min(nint(ldif*ldif*yrange),nint(nygrid/2-1.))
!
! create first entries of the 3 lists
!
      allocate(firstlev)
      if (associated(firstlev%next)) nullify(firstlev%next)
      allocate(secondlev)
      if (associated(secondlev%next)) nullify(secondlev%next)
      allocate(thirdlev)
      if (associated(thirdlev%next)) nullify(thirdlev%next)
    endif
!
    do k=1,nglevel
      select case (k)
      case (1)
        if (associated(first)) nullify(first)
        first => firstlev
        current => firstlev
        if (associated(firstlev%next)) then
          first%next => firstlev%next
          current%next => firstlev%next
        endif
        nullify(previous)
      case (2)
        if (associated(first)) nullify(first)
        first => secondlev
        current => secondlev
        if (associated(secondlev%next)) then
          first%next => secondlev%next
          current%next => secondlev%next
        endif
        nullify(previous)
      case (3)
        if (associated(first)) nullify(first)
        first => thirdlev
        current => thirdlev
        if (associated(thirdlev%next)) then
          first%next => thirdlev%next
          current%next => thirdlev%next
        endif
        nullify(previous)
      end select
!
      ampl=amplarr(k)
      granr=granrarr(k)
      life_t=life_tarr(k)
      xrange=xrangearr(k)
      yrange=yrangearr(k)
!
      call drive3(k)
!
      select case (k)
      case (1)
        if (.NOT. associated(firstlev,first)) firstlev => first
        if (.NOT. associated(firstlev%next,first%next)) &
            firstlev%next=>first%next
      case (2)
        if (.NOT. associated(secondlev,first)) secondlev => first
        if (.NOT. associated(secondlev%next,first%next)) &
            secondlev%next=>first%next
      case (3)
        if (.NOT. associated(thirdlev,first)) thirdlev => first
        if (.NOT. associated(thirdlev%next,first%next)) &
            thirdlev%next=>first%next
      end select
!
    enddo
!
    endsubroutine multi_drive3
!***********************************************************************
    subroutine drive3(level)
!
      use Syscalls, only: file_exists
!
      real :: vrms,vtot
      real,dimension(nxgrid,nygrid) :: wscr,wscr2
      integer, intent(in) :: level
      logical :: lstop=.false.
!
      call resetarr
      call fill_B_avoidarr
!
      if (.not.associated(current%next)) then
        call rdpoints(level)
        if (.not.associated(current%next)) then
          call driveinit
          call wrpoints(level,0)
          call wrpoints(level)
        endif
      else
        call updatepoints
        call drawupdate
        do
          if (associated(current%next)) then
            call gtnextpoint
            call drawupdate
          else
            exit
          endif
        enddo
        do
          if (minval(avoidarr).eq.1) exit
          call addpoint
          call make_newpoint
          call drawupdate
        enddo
        call reset
      endif
!
! Move granule centers according to external velocity
! field. Needed to be done only once per timestep for each level
      if (luse_ext_vel_field.and.itsub.eq.itorder) call evolve_granules()
!
! Using lower boundary Uy,Uz as temp memory
      Ux = Ux+vx
      Uy = Uy+vy
!
! When last level is done normalize to given rms velocity and
! enhance the vorticity of the flow
      if (level.eq.nglevel) then
!
! Putting sum of velocities back into vx,vy
        vx=Ux
        vy=Uy
!
! Calculating and enhancing rotational part by factor 5
        if (lrotin) then
          call helmholtz(wscr,wscr2)
          !* war vorher 5 ; zum testen auf  50
          ! nvor is now keyword !!!
          vx=(vx+nvor*wscr )
          vy=(vy+nvor*wscr2)
        endif
!
! Normalize to given total rms-velocity
        vrms=sqrt(sum(vx**2+vy**2)/(nxgrid*nygrid))+tini
!
        if (unit_system.eq.'SI') then
          vtot=3.*1e3/unit_velocity
        elseif (unit_system.eq.'cgs') then
          vtot=3.*1e5/unit_velocity
        else
          vtot=0.
          call fatal_error('solar_corona','define a valid unit system')
        endif
!
! Reinserting rotationally enhanced velocity field
!
        Ux=vx*vtot/vrms
        Uy=vy*vtot/vrms
      endif
!
      if (t >= tsnap_uu) then
        call wrpoints(level,isnap)
        if (level.eq.nglevel) then
          tsnap_uu = tsnap_uu + dsnap
          isnap  = isnap + 1
        endif
      endif
      if (itsub .eq. 3) &
          lstop = file_exists('STOP')
      if (lstop.or.t>=tmax .or. it.eq.nt.or. &
          mod(it,isave).eq.0.or.dt<dtmin) &
          call wrpoints(level)
!
    endsubroutine drive3
!***********************************************************************
    subroutine resetarr
!
      w(:,:)=0.0
      vx(:,:)=0.0
      vy(:,:)=0.0
      avoidarr(:,:)=0.0
!
    endsubroutine resetarr
!***********************************************************************
    subroutine rdpoints(level)
!
      real, dimension(6) :: tmppoint
      integer :: iost,rn,iol
      integer, intent(in) :: level
      logical :: ex
      character(len=20) :: filename
!
      write (filename,'("driver/pts_",I1.1,".dat")') level
!
      inquire(file=filename,exist=ex)
!
      if (ex) then
        inquire(IOLENGTH=iol) dy
        print*,'Reading granule level ',level,':',filename
        open(10,file=filename,status="unknown",access="direct",recl=6*iol)
        iost=0
!
        rn=1
        do
          read(10,iostat=iost,rec=rn) tmppoint
          if (iost.eq.0) then
            current%pos(:) =tmppoint(1:2)
            current%data(:)=tmppoint(3:6)
            call addpoint
            call drawupdate
            rn=rn+1
          else
            nullify(previous%next)
            deallocate(current)
            current => previous
            exit
         endif
        enddo
!
        close(10)
        print*,'read ',rn-1,' points'
        call reset
!
        if (level==nglevel) then
          write (filename,'("driver/seed.dat")')
          inquire(file=filename,exist=ex)
          if (ex) then
            open(10,file=filename,status="unknown",access="direct",recl=mseed*iol)
            read(10,rec=1) points_rstate
            close(10)
          else
            call fatal_error('rdpoints','cant find seed list for granules')
          endif
        endif
!
      endif
!
    endsubroutine rdpoints
!***********************************************************************
    subroutine wrpoints(level,issnap)
!
      integer :: rn,iol
      integer, optional, intent(in) :: issnap
      integer,intent(in) :: level
      real,dimension(6) :: posdata
      character(len=20) :: filename
!
      inquire(IOLENGTH=iol) dy
!
      if (present(issnap)) then
        write (filename,'("driver/pts_",I1.1,"_",I3.3,".dat")') level,issnap
      else
        write (filename,'("driver/pts_",I1.1,".dat")') level
      endif
!
      open(10,file=filename,status="replace",access="direct",recl=6*iol)
!
      rn=1
      do
        posdata(1:2)=current%pos
        posdata(3:6)=current%data
!
        write(10,rec=rn) posdata
        if (.not.associated(current%next)) exit
        call gtnextpoint
        rn=rn+1
      enddo
!
      close(10)
!
! save seed list if the last level is stored
!
      if (level.eq.nglevel) then
        if (present(issnap)) then
          write (filename,'("driver/seed_",I3.3,".dat")') issnap
        else
          write (filename,'("driver/seed.dat")')
        endif
!
        open(10,file=filename,status="replace",access="direct",recl=mseed*iol)
        write(10,rec=1) points_rstate
        close(10)
      endif
!
      call reset
!
    endsubroutine wrpoints
!***********************************************************************
    subroutine addpoint
!
      type(point),pointer :: newpoint
!
      allocate(newpoint)
!
! the next after the last is not defined
      if (associated(newpoint%next)) nullify(newpoint%next)
!
! the actual should have the new point as the next in the list
      current%next => newpoint
!
! the current will be the previous
      previous => current
!
! make the new point as the current one
      current => newpoint
!
    endsubroutine addpoint
!***********************************************************************
    subroutine rmpoint
!
      if (associated(current%next)) then
! current is NOT the last one
        if (associated(first,current)) then
! but current is the first point,
! check which level it is
          if (associated(firstlev,first)) firstlev => current%next
          if (associated(secondlev,first)) secondlev => current%next
          if (associated(thirdlev,first)) thirdlev => current%next
          first => current%next
          deallocate(current)
          current => first
          nullify(previous)
        else
! we are in between
          previous%next => current%next
          deallocate(current)
          current => previous%next
        endif
      else
! we are at the end
        deallocate(current)
        current => previous
        nullify(previous)
! BE AWARE THAT PREVIOUS IS NOT NOT ALLOCATED TO THE RIGHT POSITION
      endif
!
    endsubroutine rmpoint
!***********************************************************************
    subroutine gtnextpoint
!
      previous => current
      current => current%next
!
    endsubroutine gtnextpoint
!***********************************************************************
    subroutine reset
!
      current => first
      previous => first
!
      if (associated(previous)) nullify(previous)
!
    endsubroutine reset
!***********************************************************************
    subroutine driveinit
!
      use General, only: random_number_wrapper
!
      real :: rand
!
      call make_newpoint
      do
        if (minval(avoidarr).eq.1) exit
!
        call addpoint
        call make_newpoint
!
! Set randomly some points t0 to the past so they already decay
!
        call random_number_wrapper(rand)
        current%data(3)=t+(rand*2-1)*current%data(4)* &
            (-alog(thresh*ampl/current%data(2)))**(1./pow)
!
        current%data(1)=current%data(2)*exp(-((t-current%data(3))/current%data(4))**pow)
!
! Update arrays with new data
!
        call drawupdate
!
      enddo
!
! And reset
!
      call reset
!
    endsubroutine driveinit
!***********************************************************************
    subroutine helmholtz(frx_r,fry_r)
!
! extracts the rotational part of a 2d vector field
! to increase vorticity of the velocity field
!
      use Fourier, only: fourier_transform_other
!
      real, dimension(nxgrid,nygrid) :: kx,ky,k2,filter
      real, dimension(nxgrid,nygrid) :: fvx_r,fvy_r,fvx_i,fvy_i
      real, dimension(nxgrid,nygrid) :: frx_r,fry_r,frx_i,fry_i
      real, dimension(nxgrid,nygrid) :: fdx_r,fdy_r,fdx_i,fdy_i
      real :: k20
!
      fvx_r=vx
      fvx_i=0.
      call fourier_transform_other(fvx_r,fvx_i)
!
      fvy_r=vy
      fvy_i=0.
      call fourier_transform_other(fvy_r,fvy_i)
!
! Reference frequency is half the Nyquist frequency.
      k20 = (kx_ny/2.)**2.
!
      kx =spread(kx_fft,2,nygrid)
      ky =spread(ky_fft,1,nxgrid)
!
      k2 =kx**2 + ky**2 + tini
!
      frx_r = +ky*(ky*fvx_r - kx*fvy_r)/k2
      frx_i = +ky*(ky*fvx_i - kx*fvy_i)/k2
!
      fry_r = -kx*(ky*fvx_r - kx*fvy_r)/k2
      fry_i = -kx*(ky*fvx_i - kx*fvy_i)/k2
!
      fdx_r = +kx*(kx*fvx_r + ky*fvy_r)/k2
      fdx_i = +kx*(kx*fvx_i + ky*fvy_i)/k2
!
      fdy_r = +ky*(kx*fvx_r + ky*fvy_r)/k2
      fdy_i = +ky*(kx*fvx_i + ky*fvy_i)/k2
!
! Filter out large wave numbers.
      filter = exp(-(k2/k20)**2)
!
      frx_r = frx_r*filter
      frx_i = frx_i*filter
!
      fry_r = fry_r*filter
      fry_i = fry_i*filter
!
      fdx_r = fdx_r*filter
      fdx_i = fdx_i*filter
!
      fdy_r = fdy_r*filter
      fdy_i = fdy_i*filter
!
      call fourier_transform_other(fdx_r,fdx_i,linv=.true.)
      vx=fdx_r
      call fourier_transform_other(fdy_r,fdy_i,linv=.true.)
      vy=fdy_r
!
      call fourier_transform_other(frx_r,frx_i,linv=.true.)
      call fourier_transform_other(fry_r,fry_i,linv=.true.)
!
    endsubroutine helmholtz
!***********************************************************************
    subroutine drawupdate
!
      real :: xdist,ydist,dist2,dist,wtmp,vv
      integer :: i,ii,j,jj
      real :: dist0,tmp
!
! Update weight and velocity for new granule
!
      do jj=int(current%pos(2))-yrange,int(current%pos(2))+yrange
        j = 1+mod(jj-1+nygrid,nygrid)
        do ii=int(current%pos(1))-xrange,int(current%pos(1))+xrange
          i = 1+mod(ii-1+nxgrid,nxgrid)
          xdist=dx*(ii-current%pos(1))
          ydist=dy*(jj-current%pos(2))
          dist2=max(xdist**2+ydist**2,dxdy2)
          dist=sqrt(dist2)
!
          if (dist.lt.avoid*granr.and.t.lt.current%data(3)) avoidarr(i,j)=1
!
          wtmp=current%data(1)/dist
!
          dist0 = 0.53*granr
          tmp = (dist/dist0)**2
!
          vv=exp(1.)*current%data(1)*tmp*exp(-tmp)
!
          if (wtmp.gt.w(i,j)*(1-ig)) then
            if (wtmp.gt.w(i,j)*(1+ig)) then
              ! granular area
              vx(i,j)=vv*xdist/dist
              vy(i,j)=vv*ydist/dist
              w(i,j) =wtmp
            else
              ! intergranular area
              vx(i,j)=vx(i,j)+vv*xdist/dist
              vy(i,j)=vy(i,j)+vv*ydist/dist
              w(i,j) =max(w(i,j),wtmp)
            end if
          endif
          if (w(i,j) .gt. ampl/(granr*(1+ig))) avoidarr(i,j)=1
        enddo
      enddo
!
    endsubroutine drawupdate
!***********************************************************************
    subroutine make_newpoint
!
      use General, only: random_number_wrapper
!
      integer :: kfind,count,ipos,jpos,i,j
      integer,dimension(nxgrid,nygrid) :: k
      real :: rand
!
      k(:,:)=0; ipos=0; jpos=0
!
      where (avoidarr.eq.0) k=1
!
! Choose and find location of one of them
!
      call random_number_wrapper(rand)
      kfind=int(rand*sum(k))+1
      count=0
      do i=1,nxgrid
        do j=1,nygrid
          if (k(i,j).eq.1) then
            count=count+1
            if (count.eq.kfind) then
              ipos=i
              jpos=j
            endif
          endif
        enddo
      enddo
!
! Create new data for new point
!
      current%pos(1)=ipos
      current%pos(2)=jpos
!
      call random_number_wrapper(rand)
      current%data(2)=ampl*(1+(2*rand-1)*pd)
!
      call random_number_wrapper(rand)
      current%data(4)=life_t*(1+(2*rand-1)/10.)
!
      current%data(3)=t+current%data(4)* &
          (-alog(thresh*ampl/current%data(2)))**(1./pow)
!
      current%data(1)=current%data(2)* &
          exp(-((t-current%data(3))/current%data(4))**pow)
!
    endsubroutine make_newpoint
!***********************************************************************
    subroutine updatepoints
!
      use Sub, only: notanumber
!
      do
        if (notanumber(current%data)) &
            call fatal_error('update points','NaN found')
!
! update amplitude
        current%data(1)=current%data(2)* &
            exp(-((t-current%data(3))/current%data(4))**pow)
!
! remove point if amplitude is less than threshold
        if (current%data(1)/ampl.lt.thresh) call rmpoint
!
! check if last point is reached
        if (.not. associated(current%next)) exit
!
! if not go to next point
        call gtnextpoint
      end do
!
      call reset
!
    endsubroutine updatepoints
!***********************************************************************
    subroutine set_B2(f,BB2_local)
!
      use Mpicomm, only: mpisend_real, mpirecv_real
!
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(nx,ny) :: bbx,bby,bbz
      real, dimension(nx,ny) :: fac,BB2_local,tmp
      integer :: i,j,ipt
      integer, dimension(2) :: dims=(/nx,ny/)
      real :: temp
!
      intent(in) :: f
      intent(out) :: BB2_local
!
! compute B = curl(A) for irefz layer
!
      if (nygrid/=1) then
        fac=(1./60)*spread(dy_1(m1:m2),1,nx)
        bbx= fac*(+ 45.0*(f(l1:l2,m1+1:m2+1,irefz,iaz)-f(l1:l2,m1-1:m2-1,irefz,iaz)) &
            -  9.0*(f(l1:l2,m1+2:m2+2,irefz,iaz)-f(l1:l2,m1-2:m2-2,irefz,iaz)) &
            +      (f(l1:l2,m1+3:m2+3,irefz,iaz)-f(l1:l2,m1-3:m2-3,irefz,iaz)))
      else
        if (ip<=5) print*, 'set_B2: Degenerate case in y-direction'
      endif
      if (nzgrid/=1) then
        fac=(1./60)*spread(spread(dz_1(irefz),1,nx),2,ny)
        bbx= bbx -fac*(+ 45.0*(f(l1:l2,m1:m2,irefz+1,iay)-f(l1:l2,m1:m2,irefz-1,iay)) &
            -  9.0*(f(l1:l2,m1:m2,irefz+2,iay)-f(l1:l2,m1:m2,irefz-2,iay)) &
            +      (f(l1:l2,m1:m2,irefz+3,iay)-f(l1:l2,m1:m2,irefz-2,iay)))
      else
        if (ip<=5) print*, 'set_B2: Degenerate case in z-direction'
      endif
!
      if (nzgrid/=1) then
        fac=(1./60)*spread(spread(dz_1(irefz),1,nx),2,ny)
        bby= fac*(+ 45.0*(f(l1:l2,m1:m2,irefz+1,iax)-f(l1:l2,m1:m2,irefz-1,iax)) &
            -  9.0*(f(l1:l2,m1:m2,irefz+2,iax)-f(l1:l2,m1:m2,irefz-2,iax)) &
            +      (f(l1:l2,m1:m2,irefz+3,iax)-f(l1:l2,m1:m2,irefz-3,iax)))
      else
        if (ip<=5) print*, 'set_B2: Degenerate case in z-direction'
      endif
      if (nxgrid/=1) then
        fac=(1./60)*spread(dx_1(l1:l2),2,ny)
        bby=bby-fac*(+45.0*(f(l1+1:l2+1,m1:m2,irefz,iaz)-f(l1-1:l2-1,m1:m2,irefz,iaz)) &
            -  9.0*(f(l1+2:l2+2,m1:m2,irefz,iaz)-f(l1-2:l2-2,m1:m2,irefz,iaz)) &
            +      (f(l1+3:l2+3,m1:m2,irefz,iaz)-f(l1-3:l2-3,m1:m2,irefz,iaz)))
      else
        if (ip<=5) print*, 'set_B2: Degenerate case in x-direction'
      endif
      if (nxgrid/=1) then
        fac=(1./60)*spread(dx_1(l1:l2),2,ny)
        bbz= fac*(+ 45.0*(f(l1+1:l2+1,m1:m2,irefz,iay)-f(l1-1:l2-1,m1:m2,irefz,iay)) &
            -  9.0*(f(l1+2:l2+2,m1:m2,irefz,iay)-f(l1-2:l2-2,m1:m2,irefz,iay)) &
            +      (f(l1+3:l2+3,m1:m2,irefz,iay)-f(l1-3:l2-3,m1:m2,irefz,iay)))
      else
        if (ip<=5) print*, 'set_B2: Degenerate case in x-direction'
      endif
      if (nygrid/=1) then
        fac=(1./60)*spread(dy_1(m1:m2),1,nx)
        bbz=bbz-fac*(+45.0*(f(l1:l2,m1+1:m2+1,irefz,iax)-f(l1:l2,m1-1:m2-1,irefz,iax)) &
            -  9.0*(f(l1:l2,m1+2:m2+2,irefz,iax)-f(l1:l2,m1-2:m2-2,irefz,iax)) &
            +      (f(l1:l2,m1+3:m2+3,irefz,iax)-f(l1:l2,m1-3:m2-3,irefz,iax)))
      else
        if (ip<=5) print*, 'set_B2: Degenerate case in y-direction'
      endif
!
      BB2_local = bbx*bbx + bby*bby + bbz*bbz
      Bzflux = sum(abs(bbz))
!
! communicate to root processor
!
      if (iproc.eq.0) then
        BB2(1:nx,1:ny) = BB2_local
        do i=0,nprocx-1
          do j=0,nprocy-1
            ipt = i+nprocx*j
            if (ipt.ne.0) then
              call mpirecv_real(tmp,dims,ipt,555+ipt)
              BB2(i*nx+1:i*nx+nx,j*ny+1:j*ny+ny)  = tmp
              call mpirecv_real(temp,1,ipt,556+ipt)
              Bzflux = Bzflux+temp
            endif
          enddo
        enddo
      else
        call mpisend_real(BB2_local,dims,0,555+iproc)
        call mpisend_real(Bzflux,1,0,556+iproc)
      endif
!
    endsubroutine set_B2
!***********************************************************************
    subroutine fill_B_avoidarr
!
      integer :: i,j,itmp,jtmp
      integer :: il,ir,jl,jr
      integer :: ii,jj
!
      if (nxgrid==1) then
        itmp = 0
      else
        itmp = nint(granr*(1-ig)/dx)
      endif
      if (nygrid==1) then
        jtmp = 0
      else
        jtmp = nint(granr*(1-ig)/dy)
      endif
!
      do i=1,nxgrid
        do j=1,nygrid
          if (BB2(i,j).gt.(Bavoid/unit_magnetic)**2) then
            il=max(1,i-itmp); ir=min(nxgrid,i+itmp)
            jl=max(1,j-jtmp); jr=min(nygrid,j+jtmp)
!
            do ii=il,ir
              do jj=jl,jr
                if ((ii-i)**2+(jj-j)**2.lt.itmp**2+jtmp**2) then
                  avoidarr(ii,jj)=1
                endif
              enddo
            enddo
          endif
        enddo
      enddo
!
    endsubroutine fill_B_avoidarr
!***********************************************************************
    subroutine read_ext_vel_field()
!
      use Mpicomm, only: mpisend_real, mpirecv_real, stop_it_if_any
!
      real, dimension (:,:), save, allocatable :: uxl,uxr,uyl,uyr
      real, dimension (:,:), allocatable :: tmpl,tmpr
      integer :: tag_x=321,tag_y=322
      integer :: tag_tl=345,tag_tr=346,tag_dt=347
      integer :: lend=0,ierr,i=0,stat,px,py
      real, save :: tl=0.,tr=0.,delta_t=0.
!
      character (len=*), parameter :: vel_times_dat = 'driver/vel_times.dat'
      character (len=*), parameter :: vel_field_dat = 'driver/vel_field.dat'
      integer :: unit=1
!
      ierr = 0
      stat = 0
      if (.not.allocated(uxl))  allocate(uxl(nx,ny),stat=ierr)
      if (.not.allocated(uxr))  allocate(uxr(nx,ny),stat=stat)
      ierr = max(stat,ierr)
      if (.not.allocated(uyl))  allocate(uyl(nx,ny),stat=stat)
      ierr = max(stat,ierr)
      if (.not.allocated(uyr))  allocate(uyr(nx,ny),stat=stat)
      ierr = max(stat,ierr)
      allocate(tmpl(nxgrid,nygrid),stat=stat); ierr = max(stat,ierr)
      allocate(tmpr(nxgrid,nygrid),stat=stat); ierr = max(stat,ierr)
!
      if (ierr>0) call stop_it_if_any(.true.,'uu_driver: '// &
          'Could not allocate memory for all variable, please check')
!
!  Read the time table
!
      if ((t*unit_time<tl+delta_t) .or. (t*unit_time>=tr+delta_t)) then
        !
        if (lroot) then
          inquire(IOLENGTH=lend) tl
          open (unit,file=vel_times_dat,form='unformatted',status='unknown',recl=lend,access='direct')
!
          ierr = 0
          i=0
          do while (ierr == 0)
            i=i+1
            read (unit,rec=i,iostat=ierr) tl
            read (unit,rec=i+1,iostat=ierr) tr
            if (ierr /= 0) then
              ! EOF is reached => read again
              i=1
              delta_t = t*unit_time
              read (unit,rec=i,iostat=ierr) tl
              read (unit,rec=i+1,iostat=ierr) tr
              ierr=-1
            else
              ! test if correct time step is reached
              if (t*unit_time>=tl+delta_t.and.t*unit_time<tr+delta_t) ierr=-1
            endif
          enddo
          close (unit)
!
          do px=0, nprocx-1
            do py=0, nprocy-1
              if ((px == 0) .and. (py == 0)) cycle
              call mpisend_real (tl, 1, px+py*nprocx, tag_tl)
              call mpisend_real (tr, 1, px+py*nprocx, tag_tr)
              call mpisend_real (delta_t, 1, px+py*nprocx, tag_dt)
            enddo
          enddo
        else
          if (lfirst_proc_z) then
            call mpirecv_real (tl, 1, 0, tag_tl)
            call mpirecv_real (tr, 1, 0, tag_tr)
            call mpirecv_real (delta_t, 1, 0, tag_dt)
          endif
        endif
!
! Read velocity field
!
       if (lroot) then
          open (unit,file=vel_field_dat,form='unformatted',status='unknown',recl=lend*nxgrid*nygrid,access='direct')
!
          read (unit,rec=2*i-1) tmpl
          read (unit,rec=2*i+1) tmpr
          if (tr /= tl) then
            Ux_ext  = (t*unit_time - (tl+delta_t)) * (tmpr - tmpl) / (tr - tl) + tmpl
          else
            Ux_ext = tmpr
          endif
          Ux_ext = Ux_ext/unit_velocity
!
          read (unit,rec=2*i)   tmpl
          read (unit,rec=2*i+2) tmpr
          if (tr /= tl) then
            Uy_ext  = (t*unit_time - (tl+delta_t)) * (tmpr - tmpl) / (tr - tl) + tmpl
          else
            Uy_ext = tmpr
          endif
          Uy_ext = Uy_ext/unit_velocity
!
          do px=0, nprocx-1
            do py=0, nprocy-1
              if ((px == 0) .and. (py == 0)) cycle
              Ux_ext_local = Ux_ext(px*nx+1:(px+1)*nx,py*ny+1:(py+1)*ny)
              Uy_ext_local = Uy_ext(px*nx+1:(px+1)*nx,py*ny+1:(py+1)*ny)
              call mpisend_real (Ux_ext_local, (/ nx, ny /), px+py*nprocx, tag_x)
              call mpisend_real (Uy_ext_local, (/ nx, ny /), px+py*nprocx, tag_y)
            enddo
          enddo
!
          Ux_ext_local = Ux_ext(1:nx,1:ny)
          Uy_ext_local = Uy_ext(1:nx,1:ny)
!
          close (unit)
        else
          if (lfirst_proc_z) then
            call mpirecv_real (Ux_ext_local, (/ nx, ny /), 0, tag_x)
            call mpirecv_real (Uy_ext_local, (/ nx, ny /), 0, tag_y)
          endif
        endif
!
      endif
!
      if (allocated(tmpl)) deallocate(tmpl)
      if (allocated(tmpr)) deallocate(tmpr)
!
    endsubroutine read_ext_vel_field
!***********************************************************************
    subroutine force_solar_wind(df,p)
!
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      if (n==n2.and.llast_proc_z) &
          df(l1:l2,m,n2,iuz) = df(l1:l2,m,n2,iuz)-tau_inv*(p%uu(:,3)-u_add)
!
    endsubroutine force_solar_wind
!***********************************************************************
    subroutine get_wind_speed_offset(f)
!
!  Calculates u_0 so that rho*(u+u_0)=massflux.
!  Set 'win' for rho and
!  massflux can be set as fbcz1/2(rho) in run.in.
!
!  18-06-2008/bing: coded
!
      use Mpicomm, only: mpisend_real,mpirecv_real
!
      real, dimension (mx,my,mz,mfarray) :: f
      integer :: i,j,ipt
!      real :: massflux
      real :: local_flux,local_mass
      real :: total_flux,total_mass
      real :: get_lf,get_lm
!
      local_flux=sum(exp(f(l1:l2,m1:m2,n2,ilnrho))*f(l1:l2,m1:m2,n2,iuz))
      local_mass=sum(exp(f(l1:l2,m1:m2,n2,ilnrho)))
!
!  One  processor has to collect the data
!
      if (lfirst_proc_xy) then
        total_flux=local_flux
        total_mass=local_mass
        do i=0,nprocx-1
          do j=0,nprocy-1
            if ((i==0).and.(j==0)) cycle
            ipt = i+nprocx*j+ipz*nprocx*nprocy
            call mpirecv_real(get_lf,1,ipt,111+ipt)
            call mpirecv_real(get_lm,1,ipt,211+ipt)
            total_flux=total_flux+get_lf
            total_mass=total_mass+get_lm
          enddo
        enddo
!
!  Get u0 addition rho*(u+u0) = wind
!  rho*u + u0 *rho =wind
!  u0 = (wind-rho*u)/rho
!
        u_add = (massflux-total_flux) / total_mass
      else
        ! send to first processor at given height
        !
        call mpisend_real(local_flux,1,ipz*nprocx*nprocy,111+iproc)
        call mpisend_real(local_mass,1,ipz*nprocx*nprocy,211+iproc)
      endif
!
!  now distribute u_add
!
      if (lfirst_proc_xy) then
        do i=0,nprocx-1
          do j=0,nprocy-1
            if ((i==0).and.(j==0)) cycle
            ipt = i+nprocx*j+ipz*nprocx*nprocy
            call mpisend_real(u_add,1,ipt,311+ipt)
          enddo
        enddo
      else
        call mpirecv_real(u_add,1,ipz*nprocx*nprocy,311+iproc)
      endif
!
    endsubroutine get_wind_speed_offset
!***********************************************************************
    subroutine evolve_granules()
!
      integer :: xpos,ypos
!
      do
        xpos = int(current%pos(1))
        ypos = int(current%pos(2))
!
        current%pos(1) =  current%pos(1) + Ux_ext(xpos,ypos)*dt
        current%pos(2) =  current%pos(2) + Uy_ext(xpos,ypos)*dt
!
        if (current%pos(1)<0.5) current%pos(1) = current%pos(1) + nxgrid
        if (current%pos(2)<0.5) current%pos(2) = current%pos(2) + nygrid
!
        if (current%pos(1)>nxgrid+0.5) current%pos(1) = current%pos(1) - nxgrid
        if (current%pos(2)>nygrid+0.5) current%pos(2) = current%pos(2) - nygrid
!
        if (associated(current%next)) then
          call gtnextpoint
        else
          exit
        endif
      enddo
      call reset
!
    endsubroutine evolve_granules
!***********************************************************************
!************        DO NOT DELETE THE FOLLOWING       **************
!********************************************************************
!**  This is an automatically generated include file that creates  **
!**  copies dummy routines from nospecial.f90 for any Special      **
!**  routines not implemented in this file                         **
!**                                                                **
    include '../special_dummies.inc'
!********************************************************************
endmodule Special
