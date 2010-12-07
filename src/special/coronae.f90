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
  use Messages
  use Sub, only: keep_compiler_quiet, cubic_step
!
  implicit none
!
  real :: Kpara=0.,Kperp=0.
  real :: cool_RTV=0.,exp_RTV=0.,cubic_RTV=0.,tanh_RTV=0.,width_RTV=0.
  real :: hyper3_chi=0.
  real :: tau_inv_newton=0.,exp_newton=0.,tanh_newton=0.,cubic_newton=0.
  real :: width_newton=0.,gauss_newton=0.
  logical :: lgranulation=.false.,luse_ext_vel_field
  real :: increase_vorticity=15.,Bavoid=huge1
  real :: Bz_flux=0.,quench=0.
  real :: init_time=0.,init_width=0.,hcond_grad=0.
  real :: dampuu=0.,wdampuu,pdampuu
!
  character (len=labellen), dimension(3) :: iheattype='nothing'
  real, dimension(2) :: heat_par_exp=(/0.,1./)
  real, dimension(2) :: heat_par_exp2=(/0.,1./)
  real, dimension(3) :: heat_par_gauss=(/0.,1.,0./)
!
  namelist /special_run_pars/ &
      Kpara,Kperp, &
      cool_RTV,exp_RTV,cubic_RTV,tanh_RTV,width_RTV,gauss_newton, &
      tau_inv_newton,exp_newton,tanh_newton,cubic_newton,width_newton, &
      lgranulation,luse_ext_vel_field,increase_vorticity,hyper3_chi, &
      Bavoid,Bz_flux,init_time,init_width,quench,dampuu,wdampuu,pdampuu, &
      iheattype,heat_par_exp,heat_par_exp2,heat_par_gauss,hcond_grad
!
! variables for print.in
!
  integer :: idiag_dtchi2=0   ! DIAG_DOC: $\delta t / [c_{\delta t,{\rm v}}\,
                              ! DIAG_DOC:   \delta x^2/\chi_{\rm max}]$
                              ! DIAG_DOC:   \quad(time step relative to time
                              ! DIAG_DOC:   step based on heat conductivity;
                              ! DIAG_DOC:   see \S~\ref{time-step})
  integer :: idiag_dtrad=0    ! DIAG_DOC: radiative loss from RTV
  integer :: idiag_dtnewt=0
  integer :: idiag_dtgran=0
!
!  variables for video slices:
!
  real, target, dimension (nx,ny) :: spitzer_xy,spitzer_xy2,spitzer_xy3,spitzer_xy4
  real, target, dimension (nx,nz) :: spitzer_xz
  real, target, dimension (ny,nz) :: spitzer_yz
  real, target, dimension (nx,ny) :: rtv_xy,rtv_xy2,rtv_xy3,rtv_xy4
  real, target, dimension (nx,nz) :: rtv_xz
  real, target, dimension (ny,nz) :: rtv_yz
!
!  variables for granulation driver
!
  TYPE point
    real, dimension(6) :: data
    type(point),pointer :: next
    integer :: number
  end TYPE point
!
  Type(point), pointer :: first
  Type(point), pointer :: previous
  Type(point), pointer :: current
  Type(point), pointer, save :: firstlev
  Type(point), pointer, save :: secondlev
  Type(point), pointer, save :: thirdlev
!
  integer, parameter :: n_gran_level=3
  real, save, dimension(n_gran_level) :: xrange_arr, yrange_arr
  real, save, dimension(n_gran_level) :: granr_arr
  real, save, dimension(n_gran_level) :: ampl_arr, lifet_arr
  real, save :: ig, avoid, dxdy2, thresh, pd
  integer, save :: pow
  integer, save, dimension(mseed) :: points_rstate
  real, dimension(nx,ny) :: Ux,Uy,b2
  real, dimension(nx,ny) :: Ux_ext,Uy_ext
  real, dimension(nx,ny) :: vx,vy,w,avoidarr
!
!  miscellaneous variables
  real, save, dimension (mz) :: lnTT_init_prof,lnrho_init_prof
  real :: Bzflux
!
  contains
!
!***********************************************************************
  subroutine register_special()
!
!  Set up indices for variables in special modules and write svn id.
!
!  10-sep-10/bing: coded
!
    if (lroot) call svn_id( &
        "$Id$")
!
  endsubroutine register_special
!***********************************************************************
  subroutine initialize_special(f,lstarting)
!
!  Called by start.f90 together with lstarting=.true.   and then
!  called by run.f90   together with lstarting=.false.  after reading
!  parameters, but before the time loop.
!
!  13-sep-10/bing: coded
!
    real, dimension (mx,my,mz,mfarray), intent(inout) :: f
    logical, intent(in) :: lstarting
    real, dimension (mz) :: ztmp
    character (len=*), parameter :: filename='/strat.dat'
    integer :: lend,unit=12
    real :: dummy=1.
    logical :: exists
!
    call keep_compiler_quiet(f)
!
    inquire(IOLENGTH=lend) dummy
!
    if (.not.lstarting.and.tau_inv_newton/=0) then

      inquire(FILE=trim(directory_snap)//filename,EXIST=exists)
      if (exists) then
        open(unit,file=trim(directory_snap)//filename, &
            form='unformatted',status='unknown',recl=lend*mz)
        read(unit) ztmp
        read(unit) lnrho_init_prof
        read(unit) lnTT_init_prof
        close(unit)
      else
        lnrho_init_prof = f(l1,m1,:,ilnrho)
        lnTT_init_prof = f(l1,m1,:,ilnTT)
        open(unit,file=trim(directory_snap)//filename, &
            form='unformatted',status='unknown',recl=lend*mz)
        write(unit) z(:)
        write(unit) lnrho_init_prof
        write(unit) lnTT_init_prof
        close(unit)
      endif
    endif
!
    if (.not.lstarting.and.lgranulation.and.ipz==0) then
      if (lhydro) then
        call set_driver_params()
      else
        call fatal_error &
              ('initialize_special','granulation only works for lhydro=T')
      endif
    endif
!
  endsubroutine initialize_special
!***********************************************************************
  subroutine read_special_run_pars(unit,iostat)
!
!  04-sep-10/bing: coded
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
 99    return
!
  endsubroutine read_special_run_pars
!***********************************************************************
  subroutine write_special_run_pars(unit)
!
!  04-sep-10/bing: coded
!
    integer, intent(in) :: unit
!
    write(unit,NML=special_run_pars)
!
  endsubroutine write_special_run_pars
!***********************************************************************
  subroutine pencil_criteria_special()
!
!  All pencils that this special module depends on are specified here.
!
!  04-sep-10/bing: coded
!
    if (Kpara/=0) then
      lpenc_requested(i_bb)=.true.
      lpenc_requested(i_bij)=.true.
      lpenc_requested(i_lnTT)=.true.
      lpenc_requested(i_glnTT)=.true.
      lpenc_requested(i_hlnTT)=.true.
      lpenc_requested(i_lnrho)=.true.
      lpenc_requested(i_glnrho)=.true.
    endif
!
    if (hcond_grad/=0) then
      lpenc_requested(i_glnTT)=.true.
      lpenc_requested(i_hlnTT)=.true.
      lpenc_requested(i_del2lnTT)=.true.
      lpenc_requested(i_glnrho)=.true.
      lpenc_requested(i_cp1)=.true.
    endif
!
    if (cool_RTV/=0) then
      lpenc_requested(i_cp1)=.true.
      lpenc_requested(i_lnTT)=.true.
      lpenc_requested(i_lnrho)=.true.
    endif
!
    if (tau_inv_newton/=0) then
      lpenc_requested(i_lnTT)=.true.
      lpenc_requested(i_lnrho)=.true.
    endif
!
    if (iheattype(1)/='nothing') then
      lpenc_requested(i_TT1)=.true.
      lpenc_requested(i_rho1)=.true.
      lpenc_requested(i_cp1)=.true.
    endif
!
  endsubroutine pencil_criteria_special
!***********************************************************************
  subroutine rprint_special(lreset,lwrite)
!
!  reads and registers print parameters relevant to special
!
!  04-sep-10/bing: coded
!
    use Diagnostics, only: parse_name
!
    integer :: iname
    logical :: lreset,lwr
    logical, optional :: lwrite
!
    intent(in) :: lreset, lwrite
!
    lwr = .false.
    if (present(lwrite)) lwr=lwrite
!
!  reset everything in case of reset
!  (this needs to be consistent with what is defined above!)
!
    if (lreset) then
      idiag_dtchi2=0.
      idiag_dtrad=0.
      idiag_dtnewt=0
      idiag_dtgran=0
    endif
!
!  iname runs through all possible names that may be listed in print.in
!
    do iname=1,nname
      call parse_name(iname,cname(iname),cform(iname),'dtchi2',idiag_dtchi2)
      call parse_name(iname,cname(iname),cform(iname),'dtrad',idiag_dtrad)
      call parse_name(iname,cname(iname),cform(iname),'dtnewt',idiag_dtnewt)
      call parse_name(iname,cname(iname),cform(iname),'dtgran',idiag_dtgran)
    enddo
!
!  write column where which variable is stored
!
    if (lwr) then
      write(3,*) 'i_dtchi2=',idiag_dtchi2
      write(3,*) 'i_dtrad=',idiag_dtrad
      write(3,*) 'i_dtnewt=',idiag_dtnewt
      write(3,*) 'i_dtgran=',idiag_dtgran
    endif
!
  endsubroutine rprint_special
!***********************************************************************
  subroutine get_slices_special(f,slices)
!
!  Write slices for animation of special variables.
!
!  204-sep-10/bing: coded
!
    real, dimension (mx,my,mz,mfarray), intent(in) :: f
    type (slice_data), intent(inout) :: slices
!
!  Loop over slices
!
    select case (trim(slices%name))
!
!  Magnetic vector potential (code variable)
!
    case ('spitzer')
      slices%yz =>spitzer_yz
      slices%xz =>spitzer_xz
      slices%xy =>spitzer_xy
      slices%xy2=>spitzer_xy2
      if (lwrite_slice_xy3) slices%xy3=>spitzer_xy3
      if (lwrite_slice_xy4) slices%xy4=>spitzer_xy4
      slices%ready=.true.
!
    case ('rtv')
      slices%yz =>rtv_yz
      slices%xz =>rtv_xz
      slices%xy =>rtv_xy
      slices%xy2=>rtv_xy2
      if (lwrite_slice_xy3) slices%xy3=>rtv_xy3
      if (lwrite_slice_xy4) slices%xy4=>rtv_xy4
      slices%ready=.true.
!
    endselect
!
    call keep_compiler_quiet(f)
!
  endsubroutine get_slices_special
!***********************************************************************
    subroutine special_before_boundary(f)
!
!  Modify the f array before the boundaries are communicated.
!
!  13-sep-10/bing: coded
!
      use Mpicomm, only: mpisend_real, mpirecv_real
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
      integer :: i,j,ipt
      real :: tmp,dA
!
      if (ipz==0) then
        if ((lgranulation.and.Bavoid<huge1).or.Bz_flux/=0) call set_B2(f)
!
! Set sum(abs(Bz)) to  a given flux.
        if (Bz_flux/=0) then
!
! communicate to root processor
!
          if (iproc.eq.0) then
            do i=0,nprocx-1;  do j=0,nprocy-1
              ipt = i+nprocx*j
              if (ipt.ne.0) then
                call mpirecv_real(tmp,1,ipt,556+ipt)
                Bzflux = Bzflux+tmp
              endif
            enddo; enddo
          else
            call mpisend_real(Bzflux,1,0,556+iproc)
          endif
!  Distribute the result
          if (iproc.eq.0) then
            do i=0,nprocx-1;  do j=0,nprocy-1
              ipt = i+nprocx*j
              if (ipt.ne.0) then
                call mpisend_real(Bzflux,1,ipt,556+ipt)
              endif
            enddo; enddo
          else
            call mpirecv_real(Bzflux,1,0,556+iproc)
          endif
!
          if (nxgrid/=1.and.nygrid/=1) then
            dA=dx*dy*unit_length**2
          elseif (nygrid==1) then
            dA=dx*unit_length
          elseif (nxgrid==1) then
            dA=dy*unit_length
          endif
          f(l1:l2,m1:m2,n1,iax:iaz) = f(l1:l2,m1:m2,n1,iax:iaz) * &
              Bz_flux/(Bzflux*dA*unit_magnetic)
        endif
      endif
!
      if (luse_ext_vel_field) call read_ext_vel_field()
!
!  Compute photospheric granulation.
      if (lgranulation.and.ipz==0.and..not. lpencil_check_at_work) then
        if (itsub==1) then
          call granulation_driver(f)
        endif
!
      endif
!
    endsubroutine special_before_boundary
!***********************************************************************
    subroutine special_calc_hydro(f,df,p)
!
      use Sub, only: cubic_step
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
!
! sponge layer
      if (ipz .eq. nprocz-1) then
        df(l1:l2,m,n,iuz) = df(l1:l2,m,n,iuz) &
            - cubic_step(1.*n,pdampuu,wdampuu)*dampuu*f(l1:l2,m,n,iuz)
      endif
!
    endsubroutine special_calc_hydro
!***********************************************************************
  subroutine special_calc_entropy(f,df,p)
!
! Additional terms to the right hand side of the
! energy equation
!
!  04-sep-10/bing: coded
!
    use Deriv, only: der6
!
    real, dimension (mx,my,mz,mfarray), intent(inout) :: f
    real, dimension (mx,my,mz,mvar), intent(inout) :: df
    type (pencil_case), intent(in) :: p
!
    real, dimension (nx) :: hc,tmp
!
    if (Kpara/=0) call calc_heatcond_spitzer(df,p)
    if (hcond_grad/=0) call calc_heatcond_glnTT_iso(df,p)
    if (cool_RTV/=0) call calc_heat_cool_RTV(df,p)
    if (iheattype(1)/='nothing') call calc_artif_heating(df,p)
    if (tau_inv_newton/=0) call calc_heat_cool_newton(df,p)
 !
    if (hyper3_chi/=0) then
      hc(:) = 0.
      call der6(f,ilnTT,tmp,1,IGNOREDX=.true.)
      hc = hc + tmp
      call der6(f,ilnTT,tmp,2,IGNOREDX=.true.)
      hc = hc + tmp
      call der6(f,ilnTT,tmp,3,IGNOREDX=.true.)
      hc = hc + tmp
      hc = hyper3_chi*hc
      df(l1:l2,m,n,ilnTT) = df(l1:l2,m,n,ilnTT) + hc
!
!  due to ignoredx hyper3_chi has [1/s]
!
      if (lfirst.and.ldt) diffus_chi3=diffus_chi3  &
          + hyper3_chi
    endif
!
  endsubroutine special_calc_entropy
!***********************************************************************
  subroutine calc_heatcond_spitzer(df,p)
!
!  Calculates heat conduction parallel and perpendicular (isotropic)
!  to magnetic field lines.
!
!  See: Solar MHD; Priest 1982
!
!  04-sep-10/bing: coded
!
    use Diagnostics,     only : max_mn_name
    use EquationOfState, only: gamma
    use Sub, only: dot2_mn, multsv_mn, tensor_diffusion_coef
!
    real, dimension (mx,my,mz,mvar), intent(inout) :: df
    type (pencil_case), intent(in) :: p
!
    real, dimension (nx,3) :: gvKpara,gvKperp,tmpv,tmpv2
    real, dimension (nx) :: thdiff,chi_spitzer
    real, dimension (nx) :: vKpara,vKperp
    real, dimension (nx) :: gT2_1,gT2,b2,b2_1
!
    integer ::i,j
!
!  Calculate variable diffusion coefficients along pencils.
!
    call dot2_mn(p%bb,b2)
    b2_1=1./max(tini,b2)
!
    vKpara = Kpara * exp(p%lnTT*3.5)
    vKperp = Kperp * b2_1*exp(2.*p%lnrho+0.5*p%lnTT)
!
!  For time step limitiation we have to find the effective heat flux:
!  abs(K) = [K1.delta_ij + (K0-K1).bi.bj].ei.ej
!
    call dot2_mn(p%glnTT,gT2)
    gT2_1=1./max(tini,gT2)
!
    chi_spitzer=0.
    do i=1,3
      do j=1,3
        chi_spitzer=chi_spitzer+ &
            (vKpara-vKperp)*p%bb(:,i)*p%bb(:,j)*p%glnTT(:,i)*p%glnTT(:,j)*b2_1*gT2_1
        if (i==j) chi_spitzer=chi_spitzer+vKperp*p%glnTT(:,i)*p%glnTT(:,j)*gT2_1
      enddo
    enddo
    chi_spitzer = chi_spitzer*exp(-p%lnTT-p%lnrho)
!
!  Calculate gradient of variable diffusion coefficients.
!
    call multsv_mn(3.5*vKpara,p%glnTT,gvKpara)
!
    do i=1,3
      tmpv(:,i)=0.
      do j=1,3
        tmpv(:,i)=tmpv(:,i) + p%bb(:,j)*p%bij(:,j,i)
      enddo
    enddo
    call multsv_mn(2.*b2_1,tmpv,tmpv2)
    tmpv=2.*p%glnrho+0.5*p%glnTT-tmpv2
    call multsv_mn(vKperp,tmpv,gvKperp)
!
!  Calculate diffusion term.
!
    thdiff = 0.
    call tensor_diffusion_coef(p%glnTT,p%hlnTT,p%bij,p%bb,vKperp,vKpara,thdiff,&
        GVKPERP=gvKperp,GVKPARA=gvKpara)
!
    thdiff = thdiff*exp(-p%lnrho-p%lnTT)
!
!  Add to energy equation.
    if (ltemperature) then
      if (ltemperature_nolog) then
        call fatal_error('calc_heatcond_spitzer','not implented for ltemperature_nolog')
      else
        df(l1:l2,m,n,ilnTT)=df(l1:l2,m,n,ilnTT) + thdiff
      endif
    else if (lentropy) then
      if (pretend_lnTT) then
        df(l1:l2,m,n,ilnTT)=df(l1:l2,m,n,ilnTT) + thdiff
      else
        call fatal_error('calc_heatcond_spitzer','not implented for lentropy and not pretend_lnTT')
      endif
    endif
!
    if (lfirst.and.ldt) then
      diffus_chi=diffus_chi+gamma*chi_spitzer*dxyz_2
      if (ldiagnos.and.idiag_dtchi2/=0) then
        call max_mn_name(diffus_chi/cdtv,idiag_dtchi2,l_dt=.true.)
      endif
    endif
!
  endsubroutine calc_heatcond_spitzer
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
      chi = glnT2*hcond_grad
!
      rhs = 2*tmp+glnT2*(glnT2+p%del2lnTT+glnT_glnr)
!
      df(l1:l2,m,n,ilnTT)=df(l1:l2,m,n,ilnTT) + p%cp1*rhs*gamma*hcond_grad
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
!  Computes the radiative loss in the optical thin corona.
!  Zero order estimation for the electron number densities by
!  computing ionization of hydrogen using Saha-equation.
!
!  Electron Temperature should be used for the radiative loss
!  L = n_e * n_H * Q(T_e)
!
!  04-sep-10/bing: coded
!
    use EquationOfState, only: gamma
    use Diagnostics,     only: max_mn_name
!
    real, dimension (mx,my,mz,mvar), intent(inout) :: df
    type (pencil_case), intent(in) :: p
!
    real, dimension (nx) :: lnQ,rtv_cool,lnTT_SI,lnneni
    real :: unit_lnQ
!
    unit_lnQ=3*alog(real(unit_velocity))+&
        5*alog(real(unit_length))+alog(real(unit_density))
    lnTT_SI = p%lnTT + alog(real(unit_temperature))
!
!  calculate ln(ne*ni) :
!  ln(ne*ni) = ln( 1.17*rho^2/(1.34*mp)^2)
!  lnneni = 2*p%lnrho + alog(1.17) - 2*alog(1.34)-2.*alog(real(m_p))
!
    lnneni = 2.*(p%lnrho+61.4412 +alog(real(unit_mass)))
!
    lnQ   = get_lnQ(lnTT_SI)
!
    rtv_cool = lnQ-unit_lnQ+lnneni-p%lnTT-p%lnrho
    rtv_cool = gamma*p%cp1*exp(rtv_cool)
!
    if (exp_RTV/=0) then
      call warning('cool_RTV','exp_RTV not yet implemented')
    elseif (tanh_RTV/=0) then
      rtv_cool=rtv_cool*cool_RTV* &
          0.5*(1.-tanh(width_RTV*(p%lnrho-tanh_RTV)))
!
    elseif (cubic_RTV/=0) then
      rtv_cool=rtv_cool*cool_RTV* &
          (1.-cubic_step(p%lnrho,cubic_RTV,width_RTV))
!
    endif
!
    rtv_cool = rtv_cool * cubic_step(real(t),init_time,init_width)
!
!     add to temperature equation
!
    if (ltemperature) then
      if (ltemperature_nolog) then
        call fatal_error('calc_heat_cool_RTV','not implemented for ltemperature_nolog')
      else
        df(l1:l2,m,n,ilnTT) = df(l1:l2,m,n,ilnTT)-rtv_cool
      endif
    else if (lentropy) then
      if (pretend_lnTT) then
        df(l1:l2,m,n,ilnTT) = df(l1:l2,m,n,ilnTT)-rtv_cool
      else
        call fatal_error('calc_heat_cool_RTV','not implemented for lentropy')
      endif
    endif
!
     if (lfirst.and.ldt) then
      dt1_max=max(dt1_max,rtv_cool/cdts)
      if (ldiagnos.and.idiag_dtrad/=0) then
        itype_name(idiag_dtrad)=ilabel_max_dt
        call max_mn_name(rtv_cool/cdts,idiag_dtrad,l_dt=.true.)
      endif
    endif
!
  endsubroutine calc_heat_cool_RTV
!***********************************************************************
    function get_lnQ(lnTT)
!
!  input: lnTT in SI units
!  output: lnP  [p]= W * m^3
!
      real, parameter, dimension (37) :: intlnT = (/ &
          8.74982, 8.86495, 8.98008, 9.09521, 9.21034, 9.44060, 9.67086 &
          , 9.90112, 10.1314, 10.2465, 10.3616, 10.5919, 10.8221, 11.0524 &
          , 11.2827, 11.5129, 11.7432, 11.9734, 12.2037, 12.4340, 12.6642 &
          , 12.8945, 13.1247, 13.3550, 13.5853, 13.8155, 14.0458, 14.2760 &
          , 14.5063, 14.6214, 14.7365, 14.8517, 14.9668, 15.1971, 15.4273 &
          ,  15.6576,  69.0776 /)
      real, parameter, dimension (37) :: intlnQ = (/ &
          -100.9455, -93.1824, -88.5728, -86.1167, -83.8141, -81.6650 &
          , -80.5905, -80.0532, -80.1837, -80.2067, -80.1837, -79.9765 &
          , -79.6694, -79.2857, -79.0938, -79.1322, -79.4776, -79.4776 &
          , -79.3471, -79.2934, -79.5159, -79.6618, -79.4776, -79.3778 &
          , -79.4008, -79.5159, -79.7462, -80.1990, -80.9052, -81.3196 &
          , -81.9874, -82.2023, -82.5093, -82.5477, -82.4172, -82.2637 &
          , -0.66650 /)
!
      real, dimension (nx), intent(in) :: lnTT
      real, dimension (nx) :: slope,ordinate,get_lnQ
      integer :: i
!
      get_lnQ=-1000.
!
      do i=1,36
        where(lnTT .ge. intlnT(i) .and. lnTT .lt. intlnT(i+1))
          slope=(intlnQ(i+1)-intlnQ(i))/(intlnT(i+1)-intlnT(i))
          ordinate = intlnQ(i) - slope*intlnT(i)
          get_lnQ = slope*lnTT + ordinate
        endwhere
      enddo
!
    endfunction get_lnQ
!***********************************************************************
    subroutine calc_artif_heating(df,p)
!
!  04-sep-10/bing: coded
!
      use EquationOfState, only: gamma
!
      real, dimension (mx,my,mz,mvar),intent(inout) :: df
      real, dimension (nx) :: heatinput,rhs
      type (pencil_case), intent(in) :: p
      integer :: i
!
      heatinput=0.
!
! Compute volumetric heating rate
!
      do i=1,3
        select case(iheattype(i))
        case ('nothing')
          !
        case ('exp')
          if (headtt) then
            print*,'Amplitude1 =',heat_par_exp(1)*unit_density* &
                unit_velocity**3/unit_length,'[Wm^(-3)]'
            print*,'Scale height1 =',heat_par_exp(2)*unit_length*1e-6,'[Mm]'
          endif
          heatinput=heatinput + &
              heat_par_exp(1)*exp(-z(n)/heat_par_exp(2))
        case ('exp2')
          if (headtt) then
            print*,'Amplitude2=',heat_par_exp2(1)*unit_density* &
                unit_velocity**3/unit_length,'[Wm^(-3)]'
            print*,'Scale height2=',heat_par_exp2(2)*unit_length*1e-6,'[Mm]'
          endif
          heatinput=heatinput + &
              heat_par_exp2(1)*exp(-z(n)/heat_par_exp2(2))
        case default
          call fatal_error('calc_artif_heating','no valid heating function')
        endselect
      enddo
!
      heatinput=heatinput*cubic_step(real(t),init_time,init_width)
!
      rhs = p%TT1*p%rho1*gamma*p%cp1*heatinput
!
      df(l1:l2,m,n,ilnTT) = df(l1:l2,m,n,ilnTT) + rhs
!
      if (lfirst.and.ldt) then
        dt1_max=max(dt1_max,rhs/cdts)
      endif
!
    endsubroutine calc_artif_heating
!***********************************************************************
    subroutine calc_heat_cool_newton(df,p)
!
!  newton cooling dT/dt = -1/tau * (T-T0)
!               dlnT/dt = 1/tau *(1-T0/T-1)
!      where
!        tau = (rho0/rho)^alpha
!
!  13-sep-10/bing: coded
!
      use Diagnostics, only: max_mn_name
      use EquationOfState, only: lnrho0
!
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
!
      real, dimension (nx) :: newton,tau_inv_tmp
!
      if (headtt) print*,'special_calc_entropy: newton cooling',tau_inv_newton
!
!  Get reference temperature
      newton  = exp(lnTT_init_prof(n)-p%lnTT)-1.
!
!  Multiply by density dependend time scale
      if (exp_newton/=0) then
        tau_inv_tmp = tau_inv_newton * &
            exp(-exp_newton*(lnrho0-p%lnrho))
!
      elseif (tanh_newton/=0) then
        tau_inv_tmp = tau_inv_newton * &
            0.5*(1+tanh(width_newton*(p%lnrho-tanh_newton)))
!
      elseif (cubic_newton/=0) then
        tau_inv_tmp = tau_inv_newton * &
            cubic_step(p%lnrho,cubic_newton,width_newton)
!
      elseif (gauss_newton/=0) then
        tau_inv_tmp = tau_inv_newton * &
            exp(-(z(n)-gauss_newton)**2/width_newton)
      endif
!
!  Adjust time scale by the initialization time
      tau_inv_tmp = tau_inv_tmp * cubic_step(real(t),init_time,init_width)
!
      newton  = newton * tau_inv_tmp
!
!  Add newton cooling term to entropy
!
      df(l1:l2,m,n,ilnTT) = df(l1:l2,m,n,ilnTT) + newton
!
      if (lfirst.and.ldt) then
        dt1_max=max(dt1_max,tau_inv_tmp/cdts)
        if (ldiagnos.and.idiag_dtnewt/=0) then
          itype_name(idiag_dtnewt)=ilabel_max_dt
          call max_mn_name(tau_inv_tmp,idiag_dtnewt,l_dt=.true.)
        endif
      endif
!
    endsubroutine calc_heat_cool_newton
!***********************************************************************
    subroutine set_driver_params()
!
      real :: granr,ampl,life_time,ldif=2.
      integer :: xrange,yrange
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
      life_time=(60.*5./unit_time)
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
      xrange=min(nint(1.5*granr*(1+ig)/dx),nint(nxgrid/2.0)-1)
      yrange=min(nint(1.5*granr*(1+ig)/dy),nint(nygrid/2.0)-1)
!
      if (lroot) then
        print*,'| solar_corona: settings for granules'
        print*,'-----------------------------------'
        print*,'| radius [Mm]:',granr*unit_length*1e-6
        print*,'| lifetime [min]',life_time*unit_time/60.
!        print*,'| update interval [s]',dt_gran*unit_time
        print*,'-----------------------------------'
      endif
!
! Don't reset if RELOAD is used
      if (.not.lreloading) then
!
        if (associated(first)) nullify(first)
        if (associated(current)) nullify(current)
        if (associated(previous)) nullify(previous)
        if (associated(firstlev)) then
          nullify(firstlev)
        else
          allocate(firstlev)
          if (associated(firstlev%next)) nullify(firstlev%next)
        endif
        if (associated(secondlev)) then
          nullify(secondlev)
        else
          allocate(secondlev)
          if (associated(secondlev%next)) nullify(secondlev%next)
        endif
        if (associated(thirdlev)) then
          nullify(thirdlev)
        else
          allocate(thirdlev)
          if (associated(thirdlev%next)) nullify(thirdlev%next)
        endif
        firstlev%number=0
        secondlev%number=0
        thirdlev%number=0
!
        points_rstate(:)=0.
!
      endif
!
      granr_arr(1)=granr
      granr_arr(2)=granr*ldif
      granr_arr(3)=granr*ldif*ldif
!
      ampl_arr(1)=ampl
      ampl_arr(2)=ampl/ldif
      ampl_arr(3)=ampl/(ldif*ldif)
!
      lifet_arr(1)=life_time
      lifet_arr(2)=ldif**2*life_time
      lifet_arr(3)=ldif**4*life_time
!
      xrange_arr(1)=xrange
      xrange_arr(2)=min(nint(ldif*xrange),nint(nxgrid/2.-1.))
      xrange_arr(3)=min(nint(ldif*ldif*xrange),nint(nxgrid/2.-1.))
      yrange_arr(1)=yrange
      yrange_arr(2)=min(nint(ldif*yrange),nint(nygrid/2-1.))
      yrange_arr(3)=min(nint(ldif*ldif*yrange),nint(nygrid/2-1.))
!
    endsubroutine set_driver_params
!***********************************************************************
    subroutine granulation_driver(f)
!
! This routine replaces the external computing of granular velocity
! pattern initially written by B. Gudiksen (2004)
!
! It is invoked by setting lgranulation=T in run.in
! additional parameters are
!         Bavoid =0.01 : the magn. field strenght in Tesla at which
!                        no granule is allowed
!         nvor = 5.    : the strength by which the vorticity is
!                        enhanced
!
!  11-may-10/bing: coded
!
      use General, only: random_seed_wrapper
      use Mpicomm, only: mpisend_real, mpirecv_real
      use Sub, only: cubic_step
!
      real, dimension(mx,my,mz,mfarray), intent(inout) :: f
      integer, save, dimension(mseed) :: global_rstate
!
      if (.not.lequidist(1).or..not.lequidist(2)) &
          call fatal_error('read_ext_vel_field', &
          'not yet implemented for non-equidistant grids')
!
! Save global random number seed, will be restored after granulation
! is done
      call random_seed_wrapper(GET=global_rstate)
      call random_seed_wrapper(PUT=points_rstate)
!
      Ux=0.0
      Uy=0.0
      call multi_drive3()
!
      if (increase_vorticity/=0) call enhance_vorticity()
      if (quench/=0) call footpoint_quenching(f)
!
      f(l1:l2,m1:m2,n1,iux) = Ux
      f(l1:l2,m1:m2,n1,iuy) = Uy
!
! restore global seed and save seed list of the granulation
      call random_seed_wrapper(GET=points_rstate)
      call random_seed_wrapper(PUT=global_rstate)
!
    endsubroutine granulation_driver
!***********************************************************************
    subroutine multi_drive3()
!
      integer :: level
!
      do level=1,n_gran_level
        if (associated(first)) nullify(first)
!
        select case (level)
        case (1)
          first => firstlev
          current => firstlev
          if (associated(firstlev%next)) then
            first%next => firstlev%next
            current%next => firstlev%next
          endif
        case (2)
          first => secondlev
          current => secondlev
          if (associated(secondlev%next)) then
            first%next => secondlev%next
            current%next => secondlev%next
          endif
        case (3)
          first => thirdlev
          current => thirdlev
          if (associated(thirdlev%next)) then
            first%next => thirdlev%next
            current%next => thirdlev%next
          endif
        endselect
! There is no previous for the first entry
        nullify(previous)
!
        call drive3(level)
!
! In case the first point of a level was deleted
! adjust levelpointer to first entry
!
        select case (level)
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
        endselect
!
      enddo
!
    endsubroutine multi_drive3
!***********************************************************************
    subroutine drive3(level)
!
      integer, intent(in) :: level
!
      call reset_arrays
!
      if (Bavoid<huge1) call fill_B_avoidarr(level)
!
      if (.not.associated(current%next)) then
        call read_points(level)
        if (.not.associated(current%next)) then
          call driver_fill(level,init=.true.)
          call write_points(level) ! compares to var.dat
          call write_points(level,0) ! compares to VAR0
        endif
      else
        call update_points(level)
        call draw_update(level)
        do
          if (associated(current%next)) then
            call get_next_point
            call draw_update(level)
          else
            exit
          endif
        enddo
!
        call driver_fill(level,init=.false.)
!
      endif
!
      Ux = Ux + vx
      Uy = Uy + vy
!
! Move granule centers according to external velocity
! field. Needed to be done for each level
!
      if (luse_ext_vel_field) call evolve_granules()
!
      call reset_pointer
!
    endsubroutine drive3
!***********************************************************************
    subroutine reset_arrays
!
! Reset arrays at the beginning of each call to the levels.
!
! 12-aug-10/bing: coded
!
      w(:,:)=0.0
      vx(:,:)=0.0
      vy(:,:)=0.0
      avoidarr(:,:)=0.0
!
    endsubroutine reset_arrays
!***********************************************************************
    subroutine driver_fill(level,init)
!
      use General, only: random_number_wrapper
      use Mpicomm, only: mpirecv_real, mpisend_real
!
      integer, intent(in) :: level
      logical :: lwait_for_points,init
      real, dimension(6) :: tmppoint,tmppoint_recv
      real :: rand
      integer :: i,j
!
      intent(in) :: init
!
      tmppoint=0.
!
      lwait_for_points = new_points()
!
      do while (lwait_for_points)
        do i=0,nprocxy-1
          if (iproc==i) then
!
! First check if iproc needs a point
!
            if (minval(avoidarr).ne.1) then
              if (current%number == 0) then
                current%number=1
              else
                call add_point
              endif
              call make_new_point(level)
!
! When initialize center randomly around t0=0
              if (init) then
                call random_number_wrapper(rand)
                current%data(5)=t+(rand*2-1)*current%data(6)* &
                    (-alog(thresh*ampl_arr(level)/current%data(4)))**(1./pow)
!
                current%data(3)=current%data(4)* &
                    exp(-((t-current%data(5))/current%data(6))**pow)
              endif
!
              call draw_update(level)
              tmppoint(1) = current%data(1) + ipx*nx
              tmppoint(2) = current%data(2) + ipy*ny
              tmppoint(3:6) = current%data(3:6)
            else
! Create dummy result
              tmppoint(:)=0.
            endif
            do j=0,nprocxy-1
              if (j/=iproc) then
                call mpisend_real(tmppoint,6,j,j+10*i)
              endif
            enddo
          else
            call mpirecv_real(tmppoint_recv,6,i,iproc+10*i)
!  Check if point received from send_proc is filled
            if (sum(tmppoint_recv)/=0.) then
              if (current%number == 0) then
                current%number=1
              else
                call add_point
              endif
              current%data(1)=tmppoint_recv(1)-ipx*nx
              current%data(2)=tmppoint_recv(2)-ipy*ny
              current%data(3:6)=tmppoint_recv(3:6)
              call draw_update(level)
            endif
          endif
!
        enddo
!
! start over if one or more has still place to put a granule
!
        lwait_for_points=new_points()
!
      enddo
!
      call reset_pointer
!
    endsubroutine driver_fill
!***********************************************************************
    subroutine make_new_point(level)
!
      use General, only: random_number_wrapper
      use Sub, only: notanumber
!
      integer, intent(in) :: level
      integer :: kfind,count,ipos,jpos,i,j
      integer,dimension(nx,ny) :: k
      real :: rand
!
      k(:,:)=0; ipos=0; jpos=0
!
      where (avoidarr.eq.0) k(:,:)=1
!
! Choose and find location of one of them
!
      call random_number_wrapper(rand)
      kfind=int(rand*sum(k))+1
      count=0
      do i=1,nx; do j=1,ny
        if (k(i,j).eq.1) then
          count=count+1
          if (count.eq.kfind) then
            ipos=i
            jpos=j
            exit
          endif
        endif
      enddo; enddo
!
! Create new data for new point
!
      current%data(1)=ipos
      current%data(2)=jpos
!
      call random_number_wrapper(rand)
      current%data(4)=ampl_arr(level)*(1+(2*rand-1)*pd)
!
      call random_number_wrapper(rand)
      current%data(6)=lifet_arr(level)*(1+(2*rand-1)*0.1)
!
      current%data(5)=t+current%data(6)* &
          (-alog(thresh*ampl_arr(level)/current%data(4)))**(1./pow)
!
      current%data(3)=current%data(4)* &
            exp(-((t-current%data(5))/current%data(6))**pow)
!
    endsubroutine make_new_point
!***********************************************************************
    subroutine add_point
!
      type(point), pointer :: newpoint
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
      current%number = previous%number + 1
!
    endsubroutine add_point
!***********************************************************************
    subroutine reset_pointer
!
! 14-Sep-10/bing: coded
!
      current => first
      previous => first
!
      if (associated(previous)) nullify(previous)
!
    endsubroutine reset_pointer
!***********************************************************************
    subroutine get_next_point
!
! 14-sep-10/bing: coded
!
      previous => current
      current => current%next
!
    endsubroutine get_next_point
!***********************************************************************
    function new_points()
!
! Collects and broadcasts the logical in the lower plane of procs
!
      use Mpicomm, only: mpisend_logical, mpirecv_logical
!
      logical :: lnew_point
      logical :: new_points,ltmp
      integer :: i,j,ipt
!
! root collects
!
      if (minval(avoidarr).ne.1) then
        lnew_point=.true.
      else
        lnew_point=.false.
      endif
!
      if (iproc==0) then
        new_points=lnew_point
        do i=0,nprocx-1; do j=0,nprocy-1
          ipt = i+nprocx*j
          if (ipt.ne.0) then
            call mpirecv_logical(ltmp,1,ipt,ipt+222)
            if (ltmp) new_points=.true.
          endif
        enddo; enddo
      else
        call mpisend_logical(lnew_point,1,0,iproc+222)
      endif
!
!  root sends
!
      if (iproc==0) then
        do i=0,nprocx-1; do j=0,nprocy-1
          ipt = i+nprocx*j
          if (ipt.ne.0) then
            call mpisend_logical(new_points,1,ipt,ipt+222)
          endif
        enddo; enddo
      else
        call mpirecv_logical(new_points,1,0,iproc+222)
      endif
!
    endfunction new_points
!***********************************************************************
    subroutine draw_update(level)
!
      integer, intent(in) :: level
      real :: xdist,ydist,dist2,dist,wtmp,vv
      integer :: i,ii,j,jj,il,jl
      real :: dist0,tmp,ampl,granr
      integer :: xrange,yrange
      integer :: xpos,ypos
      logical :: loverlapp
!
      xrange=xrange_arr(level)
      yrange=yrange_arr(level)
      ampl=ampl_arr(level)
      granr=granr_arr(level)
!
! Update weight and velocity for new granule
!
! First get global position
!
      xpos = int(current%data(1)+ipx*nx)
!
      loverlapp = .false.
!
      do ii=xpos-xrange,xpos+xrange
!
! Following line ensures periodicity in X of the global field.
        i = 1+mod(ii-1+nxgrid,nxgrid)
        il = i-ipx*nx
        if (il>=1.and.il<=nx) then
!
          ypos = int(current%data(2)+ipy*ny)
!
          do jj=ypos-yrange,ypos+yrange
!
! Following line ensures periodicity in Y of the global field.
            j = 1+mod(jj-1+nygrid,nygrid)
            jl = j-ipy*ny
            if (jl>=1.and.jl<=ny) then
!
              loverlapp = .true.
              xdist=dx*(ii-current%data(1)-ipx*nx)
              ydist=dy*(jj-current%data(2)-ipy*ny)
!
              dist2=max(xdist**2+ydist**2,dxdy2)
              dist=sqrt(dist2)
!
! avoid granules whitin 80% of the maximum size
              if (dist.lt.avoid*granr.and.t.lt.current%data(5)) avoidarr(il,jl)=1
!
              wtmp=current%data(3)/dist
!
              dist0 = 0.53*granr
              tmp = (dist/dist0)**2
!
! replaced exp(1.) by 2.72
              vv=2.72*current%data(3)*tmp*exp(-tmp)
!
              if (wtmp.gt.w(il,jl)*(1-ig)) then
                if (wtmp.gt.w(il,jl)*(1+ig)) then
                  ! granular area
                  vx(il,jl)=vv*xdist/dist
                  vy(il,jl)=vv*ydist/dist
                  w(il,jl) =wtmp
                else
                  ! intergranular area
                  vx(il,jl)=vx(il,jl)+vv*xdist/dist
                  vy(il,jl)=vy(il,jl)+vv*ydist/dist
                  w(il,jl) =max(w(il,jl),wtmp)
                end if
              endif
              if (w(il,jl) .gt. thresh*ampl/(granr*(1+ig))) avoidarr(il,jl)=1
            endif
          enddo
        endif
      enddo
!
!      if (.not.loverlapp.and. it>1) call remove_point
!
    endsubroutine draw_update
!***********************************************************************
    subroutine write_points(level,issnap)
!
!
!  14-sep-10/bing: coded
!
      integer, intent(in) :: level
      integer, optional, intent(in) :: issnap
      integer :: unit=12,lend,rn
      real :: dummy=1.
!
      character (len=64) :: filename
!
      inquire(IOLENGTH=lend) dummy
!
      if (present(issnap)) then
        write (filename,'("/points_",I1.1,"_",I3.3,".dat")') level,issnap
      else
        write (filename,'("/points_",I1.1,".dat")') level
      endif
!
      open(unit,file=trim(directory_snap)//trim(filename),access="direct",recl=6*lend)
!
      rn = 1
      do
!
        write(unit,rec=rn) current%data
        if (.not.associated(current%next)) exit
        call get_next_point
        rn = rn+1
      enddo
!
      close(unit)
!
! Save seed list for each level. Is needed if levels are spread over 3 procs.
!
      if (present(issnap)) then
        write (filename,'("/seed_",I1.1,"_",I3.3,".dat")') level,issnap
      else
        write (filename,'("/seed_",I1.1,".dat")') level
      endif
      !
      open(unit,file=trim(directory_snap)//trim(filename),access="direct",recl=mseed*lend)
      write(unit,rec=1) points_rstate
      close(unit)
!
      call reset_pointer
!
    endsubroutine write_points
!***********************************************************************
    subroutine read_points(level)
!
      integer, intent(in) :: level
      integer :: unit=12,lend,rn,iostat
      real :: dummy=1.
      logical :: ex
!
      character (len=64) :: filename
!
      inquire(IOLENGTH=lend) dummy
!
      write (filename,'("/points_",I1.1,".dat")') level
!
      inquire(file=trim(directory_snap)//trim(filename),exist=ex)
!
      if (ex) then
        open(unit,file=trim(directory_snap)//trim(filename),access="direct",recl=6*lend)
!
        rn=1
        do
          read(unit,iostat=iostat,rec=rn) current%data
          if (iostat.eq.0) then
            call draw_update(level)
            call add_point
            rn=rn+1
          else
            nullify(previous%next)
            deallocate(current)
            current => previous
            exit
          endif
        enddo
        close(unit)
!
        if (ip<14) then
          print*,'Proc',iproc,'read',rn-1
          print*,'points for the granulation driver in level',level
        else
          print*,'Read driver points',iproc,level
        endif
!
        call reset_pointer
!
        if (level==n_gran_level) then
          write (filename,'("/seed_",I1.1,".dat")') level
          inquire(file=trim(directory_snap)//trim(filename),exist=ex)
          if (ex) then
            open(unit,file=trim(directory_snap)//trim(filename), &
                status="unknown",access="direct",recl=mseed*lend)
            read(unit,rec=1) points_rstate
            close(unit)
          else
            call fatal_error('read_points','cant find seed list for granules')
          endif
        endif
      else
        print*,'No points lists were found, creating new driver points'
      endif
!
    endsubroutine read_points
!***********************************************************************
    subroutine update_points(level)
!
! Update the amplitude/weight of a point.
!
! 16-sep-10/bing: coded
!
      use Sub, only: notanumber
!
      integer, intent(in) :: level
!
      do
        if (notanumber(current%data)) &
            call fatal_error('update points','NaN found')
!
! update amplitude
        current%data(3)=current%data(4)* &
            exp(-((t-current%data(5))/current%data(6))**pow)
!
! remove point if amplitude is less than threshold
        if (current%data(3)/ampl_arr(level).lt.thresh &
            .and.t>current%data(5)) then
          call remove_point
        endif
!
! check if last point is reached
        if (.not. associated(current%next)) exit
!
! if not go to next point
        call get_next_point
      end do
!
      call reset_pointer
!
    endsubroutine update_points
!***********************************************************************
    subroutine remove_point
!
! Remove any pointer from the list.
!
! 12-aug-10/bing: coded
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
        nullify(current%next)
        nullify(previous)
! BE AWARE THAT PREVIOUS IS NOT POINTING TO THE RIGHT POSITION
      endif
!
    endsubroutine remove_point
!***********************************************************************
    subroutine set_B2(f)
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
      real, dimension(nx,ny) :: bbx,bby,bbz,fac
      integer :: irefz=n1
!
! compute B = curl(A) for irefz layer
!
! Bx
      if (nygrid/=1) then
        fac=(1./60)*spread(dy_1(m1:m2),1,nx)
        bbx= fac*(+ 45.0*(f(l1:l2,m1+1:m2+1,irefz,iaz)-f(l1:l2,m1-1:m2-1,irefz,iaz)) &
            -  9.0*(f(l1:l2,m1+2:m2+2,irefz,iaz)-f(l1:l2,m1-2:m2-2,irefz,iaz)) &
            +      (f(l1:l2,m1+3:m2+3,irefz,iaz)-f(l1:l2,m1-3:m2-3,irefz,iaz)))
      endif
      if (nzgrid/=1) then
        fac=(1./60)*spread(spread(dz_1(irefz),1,nx),2,ny)
        bbx= bbx -fac*(+ 45.0*(f(l1:l2,m1:m2,irefz+1,iay)-f(l1:l2,m1:m2,irefz-1,iay)) &
            -  9.0*(f(l1:l2,m1:m2,irefz+2,iay)-f(l1:l2,m1:m2,irefz-2,iay)) &
            +      (f(l1:l2,m1:m2,irefz+3,iay)-f(l1:l2,m1:m2,irefz-2,iay)))
      endif
! By
      if (nzgrid/=1) then
        fac=(1./60)*spread(spread(dz_1(irefz),1,nx),2,ny)
        bby= fac*(+ 45.0*(f(l1:l2,m1:m2,irefz+1,iax)-f(l1:l2,m1:m2,irefz-1,iax)) &
            -  9.0*(f(l1:l2,m1:m2,irefz+2,iax)-f(l1:l2,m1:m2,irefz-2,iax)) &
            +      (f(l1:l2,m1:m2,irefz+3,iax)-f(l1:l2,m1:m2,irefz-3,iax)))
      endif
      if (nxgrid/=1) then
        fac=(1./60)*spread(dx_1(l1:l2),2,ny)
        bby=bby-fac*(+45.0*(f(l1+1:l2+1,m1:m2,irefz,iaz)-f(l1-1:l2-1,m1:m2,irefz,iaz)) &
            -  9.0*(f(l1+2:l2+2,m1:m2,irefz,iaz)-f(l1-2:l2-2,m1:m2,irefz,iaz)) &
            +      (f(l1+3:l2+3,m1:m2,irefz,iaz)-f(l1-3:l2-3,m1:m2,irefz,iaz)))
      endif
! Bz
      if (nxgrid/=1) then
        fac=(1./60)*spread(dx_1(l1:l2),2,ny)
        bbz= fac*(+ 45.0*(f(l1+1:l2+1,m1:m2,irefz,iay)-f(l1-1:l2-1,m1:m2,irefz,iay)) &
            -  9.0*(f(l1+2:l2+2,m1:m2,irefz,iay)-f(l1-2:l2-2,m1:m2,irefz,iay)) &
            +      (f(l1+3:l2+3,m1:m2,irefz,iay)-f(l1-3:l2-3,m1:m2,irefz,iay)))
      endif
      if (nygrid/=1) then
        fac=(1./60)*spread(dy_1(m1:m2),1,nx)
        bbz=bbz-fac*(+45.0*(f(l1:l2,m1+1:m2+1,irefz,iax)-f(l1:l2,m1-1:m2-1,irefz,iax)) &
            -  9.0*(f(l1:l2,m1+2:m2+2,irefz,iax)-f(l1:l2,m1-2:m2-2,irefz,iax)) &
            +      (f(l1:l2,m1+3:m2+3,irefz,iax)-f(l1:l2,m1-3:m2-3,irefz,iax)))
      endif
!
      b2 = bbx*bbx + bby*bby + bbz*bbz
      Bzflux = sum(abs(bbz))
!
    endsubroutine set_B2
!***********************************************************************
    subroutine fill_B_avoidarr(level)
!
      integer, intent(in) :: level
!
      integer :: i,j,itmp,jtmp
      integer :: il,ir,jl,jr
      integer :: ii,jj
!
      if (nx==1) then
        itmp = 0
      else
        itmp = nint(granr_arr(level)*(1-ig)/dx)
      endif
      if (nygrid==1) then
        jtmp = 0
      else
        jtmp = nint(granr_arr(level)*(1-ig)/dy)
      endif
!
      do i=1,nx
        do j=1,ny
          if (B2(i,j).gt.(Bavoid/unit_magnetic)**2) then
            il=max(1,i-itmp); ir=min(nx,i+itmp)
            jl=max(1,j-jtmp); jr=min(ny,j+jtmp)
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
    subroutine evolve_granules()
!
      integer :: xpos,ypos
!
      do
        xpos = int(current%data(1))
        ypos = int(current%data(2))
!
        current%data(1) =  current%data(1) + Ux_ext(xpos,ypos)*dt
        current%data(2) =  current%data(2) + Uy_ext(xpos,ypos)*dt
!
        if (current%data(1)+ipx*nx < 0.5) &
            current%data(1) = current%data(1) + nxgrid - ipx*nx
        if (current%data(2)+ipy*ny < 0.5) &
            current%data(2) = current%data(2) + nygrid - ipy*ny
!
        if (current%data(1)+ipx*nx > nxgrid+0.5) &
            current%data(1) = current%data(1) - nxgrid + ipx*nx
        if (current%data(2)+ipy*ny > nygrid+0.5) &
            current%data(2) = current%data(2) - nygrid + ipy*ny
!
        if (associated(current%next)) then
          call get_next_point
        else
          exit
        endif
      enddo
      call reset_pointer
!
    endsubroutine evolve_granules
!***********************************************************************
    subroutine enhance_vorticity()
!
      real, dimension(nx,ny) :: wx,wy
!
! Putting sum of velocities back into vx,vy
        vx=Ux
        vy=Uy
!
! Calculating and enhancing rotational part by factor 5
        call helmholtz(wx,wy)
        vx=(vx+increase_vorticity*wx )
        vy=(vy+increase_vorticity*wy)
!
        Ux = vx
        Uy = vy
!
    endsubroutine enhance_vorticity
!***********************************************************************
    subroutine footpoint_quenching(f)
!
      use EquationofState, only: gamma_m1,gamma_inv,lnrho0,cs20,get_cp1
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
!
      real, dimension(nx,ny) :: q,pp,beta
      real :: cp1=1.
      integer :: i
!
! for footpoint quenching compute pressure
!
      if (leos) call get_cp1(cp1)
!
      if (ltemperature.and..not.ltemperature_nolog) then
        if (ldensity_nolog) then
          call fatal_error('solar_corona', &
              'uudriver only implemented for ltemperature=true')
        else
          pp =gamma_m1*gamma_inv/cp1 * &
              exp(f(l1:l2,m1:m2,n1,ilnrho)+f(l1:l2,m1:m2,n1,ilnrho))
        endif
      else
        pp=gamma_inv*cs20*exp(lnrho0)
      endif
!
      beta =  pp/max(tini,B2)*2.*mu0
!
!  quench velocities to one percent of the granule velocities
      do i=1,ny
        q(:,i) = cubic_step(alog10(beta(:,i)),0.,1.)*(1.-quench)+quench
      enddo
      !
      Ux = Ux * q
      Uy = Uy * q
!
    endsubroutine footpoint_quenching
!***********************************************************************
    subroutine helmholtz(frx_r,fry_r)
!
! Extracts the rotational part of a 2d vector field
! to increase vorticity of the velocity field.
!
! 16-sep-10/bing: coded
!
      use Fourier, only: fft_xy_parallel
!
      real, dimension(nx,ny), intent(out) :: frx_r,fry_r
      real, dimension(nx,ny) :: kx,ky,k2,filter
      real, dimension(nx,ny) :: fvx_r,fvy_r,fvx_i,fvy_i
      real, dimension(nx,ny) :: frx_i,fry_i
      real, dimension(nx,ny) :: fdx_r,fdy_r,fdx_i,fdy_i
      real :: k20
!
      fvx_r=vx
      fvx_i=0.
      call fft_xy_parallel(fvx_r,fvx_i)
!
      fvy_r=vy
      fvy_i=0.
      call fft_xy_parallel(fvy_r,fvy_i)
!
! Reference frequency is half the Nyquist frequency.
      k20 = (kx_ny/2.)**2.
!
      kx =spread(kx_fft(ipx*nx+1:(ipx+1)*nx),2,ny)
      ky =spread(ky_fft(ipy*ny+1:(ipy+1)*ny),1,nx)
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
      call fft_xy_parallel(fdx_r,fdx_i,linv=.true.,lneed_im=.false.)
      vx=fdx_r
      call fft_xy_parallel(fdy_r,fdy_i,linv=.true.,lneed_im=.false.)
      vy=fdy_r
!
      call fft_xy_parallel(frx_r,frx_i,linv=.true.,lneed_im=.false.)
      call fft_xy_parallel(fry_r,fry_i,linv=.true.,lneed_im=.false.)
!
    endsubroutine helmholtz
!***********************************************************************
    subroutine read_ext_vel_field()
!
      use Mpicomm, only: mpisend_real, mpirecv_real, stop_it_if_any
!
      real, dimension (:,:), save, allocatable :: uxl,uxr,uyl,uyr
      real, dimension (:,:), allocatable :: tmpl,tmpr
      real, dimension (:,:), allocatable :: ux_ext_global,uy_ext_global
      integer, parameter :: tag_x=321,tag_y=322
      integer, parameter :: tag_tl=345,tag_tr=346,tag_dt=347
      integer :: lend=0,ierr,i,stat,px,py
      real, save :: tl=0.,tr=0.,delta_t=0.
!
      character (len=*), parameter :: vel_times_dat = 'driver/vel_times.dat'
      character (len=*), parameter :: vel_field_dat = 'driver/vel_field.dat'
      integer :: unit=1
!
      if (.not.lequidist(1).or..not.lequidist(2)) &
          call fatal_error('read_ext_vel_field', &
          'not yet implemented for non-equidistant grids')
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
      allocate(Ux_ext_global(nxgrid,nygrid),stat=stat); ierr = max(stat,ierr)
      allocate(Uy_ext_global(nxgrid,nygrid),stat=stat); ierr = max(stat,ierr)
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
          open (unit,file=vel_times_dat,form='unformatted', &
              status='unknown',recl=lend,access='direct')
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
!
! Read velocity field
!
          open (unit,file=vel_field_dat,form='unformatted', &
              status='unknown',recl=lend*nxgrid*nygrid,access='direct')
!
          read (unit,rec=2*i-1) tmpl
          read (unit,rec=2*i+1) tmpr
          if (tr /= tl) then
            Ux_ext_global  = (t*unit_time - (tl+delta_t)) * (tmpr - tmpl) / (tr - tl) + tmpl
          else
            Ux_ext_global = tmpr
          endif
!
          read (unit,rec=2*i)   tmpl
          read (unit,rec=2*i+2) tmpr
          if (tr /= tl) then
            Uy_ext_global  = (t*unit_time - (tl+delta_t)) * (tmpr - tmpl) / (tr - tl) + tmpl
          else
            Uy_ext_global = tmpr
          endif
!
          do px=0, nprocx-1
            do py=0, nprocy-1
              if ((px == 0) .and. (py == 0)) cycle
              Ux_ext = Ux_ext_global(px*nx+1:(px+1)*nx,py*ny+1:(py+1)*ny)/unit_velocity
              Uy_ext = Uy_ext_global(px*nx+1:(px+1)*nx,py*ny+1:(py+1)*ny)/unit_velocity
              call mpisend_real (Ux_ext, (/ nx, ny /), px+py*nprocx, tag_x)
              call mpisend_real (Uy_ext, (/ nx, ny /), px+py*nprocx, tag_y)
            enddo
          enddo
!
          Ux_ext = Ux_ext_global(1:nx,1:ny)
          Uy_ext = Uy_ext_global(1:nx,1:ny)
!
          close (unit)
        else
          if (lfirst_proc_z) then
            call mpirecv_real (tl, 1, 0, tag_tl)
            call mpirecv_real (tr, 1, 0, tag_tr)
            call mpirecv_real (delta_t, 1, 0, tag_dt)
            call mpirecv_real (Ux_ext, (/ nx, ny /), 0, tag_x)
            call mpirecv_real (Uy_ext, (/ nx, ny /), 0, tag_y)
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
!************        DO NOT DELETE THE FOLLOWING       **************
!********************************************************************
!**  This is an automatically generated include file that creates  **
!**  copies dummy routines from nospecial.f90 for any Special      **
!**  routines not implemented in this file                         **
!**                                                                **
    include '../special_dummies.inc'
!********************************************************************
endmodule Special
