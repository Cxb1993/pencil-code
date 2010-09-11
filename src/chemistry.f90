! $Id$
!
!  This modules addes chemical species and reactions.
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lchemistry = .true.
!
! MVAR CONTRIBUTION 1
! MAUX CONTRIBUTION 0
!
! PENCILS PROVIDED cv; cv1; glncp(3);  gXXk(3,nchemspec); gYYk(3,nchemspec)
! PENCILS PROVIDED nu; gradnu(3); rho;
! PENCILS PROVIDED DYDt_reac(nchemspec); DYDt_diff(nchemspec)
! PENCILS PROVIDED lambda; glambda(3)
! PENCILS PROVIDED Diff_penc_add(nchemspec), H0_RT(nchemspec), hhk_full(nchemspec)
! PENCILS PROVIDED ghhk(3,nchemspec), glnpp(3)
!
! PENCILS PROVIDED glnpp(3); del2pp; mu1; gmu1(3); pp; gTT(3); ccondens; ppwater
! PENCILS PROVIDED Ywater
!
!***************************************************************
module Chemistry
!
  use Cdata
  use Cparam
  use EquationOfState
  use Messages
  use Mpicomm, only: stop_it
  use Sub, only: keep_compiler_quiet
!
  implicit none
!
  include 'chemistry.h'
!
     real :: Rgas, Rgas_unit_sys=1.
     real, dimension (mx,my,mz) :: cp_full,cv_full,mu1_full, nu_full, pp_full
     real, dimension (mx,my,mz) :: lambda_full, rho_full, TT_full
     real, dimension (mx,my,mz,nchemspec) :: cv_R_spec_full
 !real, dimension (mx,my,mz) ::  e_int_full,cp_R_spec
 ! parameters for simiplifyed cases
     real :: lambda_const=impossible
     real :: visc_const=impossible
     real :: Diff_coef_const=impossible
     real :: Sc_number=0.7, Pr_number=0.7
     real :: Cp_const=impossible
     real :: Cv_const=impossible
     logical :: lfix_Sc=.false., lfix_Pr=.false., reinitialize_chemistry=.false.
! parameters for initial conditions
     real :: init_x1=-0.2,init_x2=0.2
     real :: init_y1=-0.2,init_y2=0.2
     real :: init_z1=-0.2,init_z2=0.2
     real :: init_TT1=400., init_TT2=2400., init_ux=0., init_uy=0., init_uz=0.
     real :: init_rho2=1.
     real :: init_rho=1.
     real :: str_thick=0.02
     real :: init_pressure=10.13e5
!
     logical :: lone_spec=.false., lfilter_strict=.false.
!
!  parameters related to chemical reactions, diffusion and advection
!
     logical :: lreactions=.true.
     logical :: ladvection=.true.
     logical :: ldiffusion=.true.
!  logical :: lnospec_eqns=.true.
!
     logical :: lheatc_chemistry=.true.
     logical :: lDiff_simple=.false.
     logical :: lThCond_simple=.false.
     logical :: lT_const=.false.
!
     logical :: lfilter=.false.
     logical :: lkreactions_profile=.false., lkreactions_alpha=.false.
     integer :: nreactions=0,nreactions1=0,nreactions2=0
     integer :: ll1,ll2,mm1,mm2,nn1,nn2
     real, allocatable, dimension(:) :: kreactions_profile_width, kreactions_alpha
!
     integer :: mreactions
     integer, allocatable, dimension(:,:) :: stoichio,Sijm,Sijp
     real,    allocatable, dimension(:,:) :: kreactions_z
     real,    allocatable, dimension(:)   :: kreactions_m,kreactions_p
     character (len=30),allocatable, dimension(:) :: reaction_name
     logical :: lT_tanh=.false.
     logical :: ldamp_zone_for_NSCBC=.false.
     logical :: linit_velocity=.false.
     logical :: linit_temperature=.false.,linit_density=.false.
!
! 1step_test case
! possible, will be removed later
!
     logical :: l1step_test=.false., lflame_front=.false.
     integer :: ipr=2
     real :: Tc=440., Tinf=2000., beta=1.09
!
!  hydro-related parameters
!
     real, dimension(nchemspec) :: amplchemk=0.,amplchemk2=0.
     real, dimension(nchemspec) :: chem_diff_prefactor=1.,initial_massfractions
     real :: amplchem=1.,kx_chem=1.,ky_chem=1.,kz_chem=1.,widthchem=1.
     real :: chem_diff=0.
     character (len=labellen), dimension (ninit) :: initchem='nothing'
     character (len=labellen), allocatable, dimension (:) :: kreactions_profile
     character (len=60) :: prerun_directory='nothing'
!
     real, allocatable, dimension(:,:,:,:,:) :: Bin_Diff_coef
     real, allocatable, dimension(:,:,:,:) :: Diff_full, Diff_full_add
     real, dimension (mx,my,mz,nchemspec) :: XX_full
     real, dimension (mx,my,mz,nchemspec) :: species_viscosity
     real, dimension (mx,my,mz,nchemspec), save :: RHS_Y_full
     real, dimension(nchemspec) :: nu_spec=0., mobility=1.
!
!  Chemkin related parameters
!
     logical :: lcheminp=.false., lchem_cdtc=.false.
     logical :: lmobility=.false.
    ! real, dimension(nchemspec,18) :: species_constants
     integer :: imass=1, iTemp1=2,iTemp2=3,iTemp3=4
     integer, dimension(7) :: iaa1,iaa2
     real, allocatable, dimension(:)  :: B_n, alpha_n, E_an
     real, allocatable, dimension(:,:) :: low_coeff,high_coeff,troe_coeff,a_k4
     logical, allocatable, dimension(:) :: Mplus_case
     logical, allocatable, dimension(:) :: photochem_case
     real :: lamb_low,lamb_up
!  real, dimension(nchemspec,7)     :: tran_data
!
!   Atmospheric physics
!
     logical :: latmchem=.false.
     logical :: lcloud=.false.
     integer, SAVE :: index_O2=0., index_N2=0., index_O2N2=0., index_H2O=0.
!
!   Diagnostics
!
    real, allocatable, dimension(:,:) :: net_react_m, net_react_p
    logical :: lchemistry_diag=.false.

!
! input parameters
  namelist /chemistry_init_pars/ &
      initchem, amplchem, kx_chem, ky_chem, kz_chem, widthchem, &
      amplchemk,amplchemk2, chem_diff,nu_spec,lDiff_simple, &
      lThCond_simple,lambda_const, visc_const,Cp_const,Cv_const,Diff_coef_const,&
      init_x1,init_x2,init_y1,init_y2,init_z1,init_z2,init_TT1,init_TT2,init_rho,&
      init_ux,init_uy,init_uz,l1step_test,Sc_number,init_pressure,lfix_Sc, &
      str_thick,lfix_Pr,lT_tanh,lT_const,lheatc_chemistry, &
      ldamp_zone_for_NSCBC,linit_velocity, latmchem, lcloud, prerun_directory,&
      lchemistry_diag,lfilter_strict,linit_temperature, linit_density, init_rho2
!
!
! run parameters
  namelist /chemistry_run_pars/ &
      lkreactions_profile, lkreactions_alpha, &
      chem_diff,chem_diff_prefactor, nu_spec, ldiffusion, ladvection, &
      lreactions,lchem_cdtc,lheatc_chemistry, lchemistry_diag, &
      lmobility,mobility, lfilter,lT_tanh,lDiff_simple,lThCond_simple,&
      visc_const,cp_const,reinitialize_chemistry,lfilter_strict, &
      init_TT1,init_TT2,init_x1,init_x2, linit_temperature, linit_density
!
! diagnostic variables (need to be consistent with reset list below)
!
  integer :: idiag_Y1m=0        ! DIAG_DOC: $\left<Y_1\right>$
  integer :: idiag_Y2m=0        ! DIAG_DOC: $\left<Y_2\right>$
  integer :: idiag_Y3m=0        ! DIAG_DOC: $\left<Y_3\right>$
  integer :: idiag_Y4m=0        ! DIAG_DOC: $\left<Y_4\right>$
  integer :: idiag_Y5m=0        ! DIAG_DOC: $\left<Y_5\right>$
  integer :: idiag_Y6m=0        ! DIAG_DOC: $\left<Y_6\right>$
  integer :: idiag_Y7m=0        ! DIAG_DOC: $\left<Y_7\right>$
  integer :: idiag_Y8m=0        ! DIAG_DOC: $\left<Y_8\right>$
  integer :: idiag_Y9m=0        ! DIAG_DOC: $\left<Y_9\right>$
  integer :: idiag_Y10m=0        ! DIAG_DOC: $\left<Y_10\right>$
  integer :: idiag_Y11m=0        ! DIAG_DOC: $\left<Y_11\right>$
  integer :: idiag_Y12m=0        ! DIAG_DOC: $\left<Y_12\right>$
  integer :: idiag_Y13m=0        ! DIAG_DOC: $\left<Y_12\right>$
  integer :: idiag_Y14m=0        ! DIAG_DOC: $\left<Y_12\right>$
  integer :: idiag_Y15m=0        ! DIAG_DOC: $\left<Y_12\right>$
  integer :: idiag_Y16m=0        ! DIAG_DOC: $\left<Y_12\right>$
  integer :: idiag_Y17m=0        ! DIAG_DOC: $\left<Y_12\right>$
  integer :: idiag_Y18m=0        ! DIAG_DOC: $\left<Y_12\right>$
  integer :: idiag_Y19m=0        ! DIAG_DOC: $\left<Y_12\right>$
  integer :: idiag_dY1m=0        ! DIAG_DOC: $\left<dY_1\right>$
  integer :: idiag_dY2m=0        ! DIAG_DOC: $\left<dY_2\right>$
  integer :: idiag_dY3m=0        ! DIAG_DOC: $\left<dY_3\right>$
  integer :: idiag_dY4m=0        ! DIAG_DOC: $\left<dY_4\right>$
  integer :: idiag_dY5m=0        ! DIAG_DOC: $\left<dY_5\right>$
  integer :: idiag_dY6m=0        ! DIAG_DOC: $\left<dY_6\right>$
  integer :: idiag_dY7m=0        ! DIAG_DOC: $\left<dY_7\right>$
  integer :: idiag_dY8m=0        ! DIAG_DOC: $\left<dY_8\right>$
  integer :: idiag_dY9m=0        ! DIAG_DOC: $\left<dY_9\right>$
  integer :: idiag_dY10m=0        ! DIAG_DOC: $\left<dY_10\right>$
  integer :: idiag_dY11m=0        ! DIAG_DOC: $\left<dY_11\right>$
  integer :: idiag_dY12m=0        ! DIAG_DOC: $\left<dY_12\right>$
  integer :: idiag_dY13m=0        ! DIAG_DOC: $\left<dY_13\right>$
  integer :: idiag_dY14m=0        ! DIAG_DOC: $\left<dY_14\right>$
  integer :: idiag_dY15m=0        ! DIAG_DOC: $\left<dY_15\right>$
  integer :: idiag_dY16m=0        ! DIAG_DOC: $\left<dY_16\right>$
  integer :: idiag_dY17m=0        ! DIAG_DOC: $\left<dY_17\right>$
  integer :: idiag_dY18m=0        ! DIAG_DOC: $\left<dY_18\right>$
  integer :: idiag_dY19m=0        ! DIAG_DOC: $\left<dY_19\right>$
!
  integer :: idiag_Y1mz=0        ! DIAG_DOC: $\left<Y_1\right>_{xy}(z)$
  integer :: idiag_Y2mz=0        ! DIAG_DOC: $\left<Y_2\right>_{xy}(z)$
  integer :: idiag_Y3mz=0        ! DIAG_DOC: $\left<Y_3\right>_{xy}(z)$
  integer :: idiag_Y4mz=0        ! DIAG_DOC: $\left<Y_4\right>_{xy}(z)$
  integer :: idiag_Y5mz=0        ! DIAG_DOC: $\left<Y_5\right>_{xy}(z)$
  integer :: idiag_Y6mz=0        ! DIAG_DOC: $\left<Y_6\right>_{xy}(z)$
  integer :: idiag_Y7mz=0        ! DIAG_DOC: $\left<Y_7\right>_{xy}(z)$
  integer :: idiag_Y8mz=0        ! DIAG_DOC: $\left<Y_8\right>_{xy}(z)$
  integer :: idiag_Y9mz=0        ! DIAG_DOC: $\left<Y_9\right>_{xy}(z)$
  integer :: idiag_Y10mz=0        ! DIAG_DOC: $\left<Y_10\right>_{xy}(z)$
  integer :: idiag_Y11mz=0        ! DIAG_DOC: $\left<Y_11\right>_{xy}(z)$
  integer :: idiag_Y12mz=0        ! DIAG_DOC: $\left<Y_12\right>_{xy}(z)$
  integer :: idiag_Y13mz=0        ! DIAG_DOC: $\left<Y_13\right>_{xy}(z)$
  integer :: idiag_Y14mz=0        ! DIAG_DOC: $\left<Y_14\right>_{xy}(z)$
  integer :: idiag_Y15mz=0        ! DIAG_DOC: $\left<Y_15\right>_{xy}(z)$
  integer :: idiag_Y16mz=0        ! DIAG_DOC: $\left<Y_16\right>_{xy}(z)$
  integer :: idiag_Y17mz=0        ! DIAG_DOC: $\left<Y_17\right>_{xy}(z)$
  integer :: idiag_Y18mz=0        ! DIAG_DOC: $\left<Y_18\right>_{xy}(z)$
  integer :: idiag_Y19mz=0        ! DIAG_DOC: $\left<Y_19\right>_{xy}(z)$
!
  integer :: idiag_h1m=0
  integer :: idiag_h2m=0
  integer :: idiag_h3m=0
  integer :: idiag_h4m=0
  integer :: idiag_h5m=0
  integer :: idiag_h6m=0
  integer :: idiag_h7m=0
  integer :: idiag_h8m=0
  integer :: idiag_h9m=0
  integer :: idiag_h10m=0
  integer :: idiag_h11m=0
  integer :: idiag_h12m=0
  integer :: idiag_h13m=0
  integer :: idiag_h14m=0
  integer :: idiag_h15m=0
  integer :: idiag_h16m=0
  integer :: idiag_h17m=0
  integer :: idiag_h18m=0
  integer :: idiag_h19m=0
!
  integer :: idiag_cpfull=0
  integer :: idiag_cvfull=0
!
  integer :: idiag_cp1m=0
  integer :: idiag_cp2m=0
  integer :: idiag_cp3m=0
  integer :: idiag_cp4m=0
  integer :: idiag_cp5m=0
  integer :: idiag_cp6m=0
  integer :: idiag_cp7m=0
  integer :: idiag_cp8m=0
  integer :: idiag_cp9m=0
  integer :: idiag_cp10m=0
  integer :: idiag_cp11m=0
  integer :: idiag_cp12m=0
  integer :: idiag_cp13m=0
  integer :: idiag_cp14m=0
  integer :: idiag_cp15m=0
  integer :: idiag_cp16m=0
  integer :: idiag_cp17m=0
  integer :: idiag_cp18m=0
  integer :: idiag_cp19m=0
  integer :: idiag_e_intm=0
!
  integer :: idiag_lambdam=0
  integer :: idiag_num=0
  integer :: idiag_diff1m=0
  integer :: idiag_diff2m=0
  integer :: idiag_diff3m=0
  integer :: idiag_diff4m=0
  integer :: idiag_diff5m=0
  integer :: idiag_diff6m=0
  integer :: idiag_diff7m=0
  integer :: idiag_diff8m=0
  integer :: idiag_diff9m=0
  integer :: idiag_diff10m=0
  integer :: idiag_diff11m=0
  integer :: idiag_diff12m=0
  integer :: idiag_diff13m=0
  integer :: idiag_diff14m=0
  integer :: idiag_diff15m=0
  integer :: idiag_diff16m=0
  integer :: idiag_diff17m=0
  integer :: idiag_diff18m=0
  integer :: idiag_diff19m=0
!
  contains
!
!***********************************************************************
    subroutine register_chemistry()
!
!  Configure pre-initialised (i.e. before parameter read) variables
!  which should be know to be able to evaluate
!
!  13-aug-07/steveb: coded
!   8-jan-08/axel: added modifications analogously to dustdensity
!   5-mar-08/nils: Read thermodynamical data from chem.inp
!
      use FArrayManager
!
      integer :: k, ichemspec_tmp
      character (len=20) :: input_file='chem.inp'
!
!  Initialize some index pointers
!
      iaa1(1)=5;iaa1(2)=6;iaa1(3)=7;iaa1(4)=8
      iaa1(5)=9;iaa1(6)=10;iaa1(7)=11
!
      iaa2(1)=12;iaa2(2)=13;iaa2(3)=14;iaa2(4)=15
      iaa2(5)=16;iaa2(6)=17;iaa2(7)=18
!
!  Set ichemistry to consecutive numbers nvar+1, nvar+2, ..., nvar+nchemspec.
!
      call farray_register_pde('chemspec',ichemspec_tmp,vector=nchemspec)
      do k=1,nchemspec
        ichemspec(k)=ichemspec_tmp+k-1
      enddo
!
!  Read species to be used from chem.inp (if the file exists).
!
      inquire(FILE=input_file, EXIST=lcheminp)
      if (lcheminp) call read_species(input_file)
!
!  Read data on the thermodynamical properties of the different species.
!  All these data are stored in the array species_constants.
!
      if (lcheminp) call read_thermodyn(input_file)
!
!  Write all data on species and their thermodynamics to file.
!
      if (lcheminp) call write_thermodyn()
!
!  Identify version number (generated automatically by SVN).
!
      if (lroot) call svn_id( &
          "$Id$")
!
    endsubroutine register_chemistry
!***********************************************************************
    subroutine initialize_chemistry(f)
!
!  called by run.f90 after reading parameters, but before the time loop
!
!  13-aug-07/steveb: coded
!  19-feb-08/axel: reads in chemistry.dat file
!
      real, dimension (mx,my,mz,mfarray) :: f
      logical :: data_file_exit=.false.
      logical :: exist,exist1,exist2
      character (len=15) :: file1='chemistry_m.dat',file2='chemistry_p.dat'
      integer :: ind_glob,ind_chem, stat
      logical :: found_specie=.false.
!
!  initialize chemistry
!
      if (lcheminp) then
        if (unit_temperature /= 1) then
          call fatal_error('initialize_chemistry', &
              'unit_temperature must be unity when using chemistry!')
        endif
!
!  calculate universal gas constant based on Boltzmann constant
!  and the proton mass
!
        if (unit_system == 'cgs') then
          Rgas_unit_sys = k_B_cgs/m_u_cgs
          Rgas=Rgas_unit_sys/unit_energy
        endif
      endif
!
      if (nchemspec==1) then
        lone_spec=.true.
        lreactions=.false.
        ladvection=.false.
        ldiffusion=.false.
      endif
!
!  check for the existence of chemistry input files
!
      inquire(file=file1,exist=exist1)
      inquire(file=file2,exist=exist2)
      inquire(file='chemistry.dat',exist=exist)
!
!  Read in data file in ChemKin format
!
      if (lcheminp) then
        call chemkin_data(f)
        data_file_exit=.true.
       if (latmchem) then
         call find_species_index('O2',ind_glob,ind_chem,found_specie)
         if (found_specie) then
          index_O2=ind_chem
         else
             call fatal_error('initialize_chemistry',&
                       'no O2 has been found')
         endif
         call find_species_index('N2',ind_glob,ind_chem,found_specie)
         if (found_specie) then
          index_N2=ind_chem
         else
             call fatal_error('initialize_chemistry',&
                       'no N2 has been found')
         endif
         call find_species_index('O2N2',ind_glob,ind_chem,found_specie)
         if (found_specie) then
          index_O2N2=ind_chem
         else
             call fatal_error('initialize_chemistry',&
                       'no O2N2 has been found')
         endif
         call find_species_index('H2O',ind_glob,ind_chem,found_specie)
         if (found_specie) then
          index_H2O=ind_chem
         else
             call fatal_error('initialize_chemistry',&
                       'no H2O has been found')
         endif
       endif
       if (lcloud) then
         call find_species_index('H2O',ind_glob,ind_chem,found_specie)
         if (found_specie) then
          index_H2O=ind_chem
         else
             call fatal_error('initialize_chemistry',&
                       'no H2O has been found')
         endif
       endif
      endif
!
!  Alternatively, read in stoichiometric matrices in explicit format.
!  For historical reasons this is referred to as "astrobiology_data"
!
      if (exist1 .and. exist2) then
        call astrobiology_data(f)
        data_file_exit=.true.
      endif
!
      if (exist) then
        call astrobiology_data(f)
        data_file_exit=.true.
      endif
!
! check the existence of a data file
!
      if (.not. data_file_exit) then
        call stop_it('initialize_chemistry: there is no chemistry data file')
      endif
!
!
      if ((nxgrid==1) .and. (nygrid==1) .and. (nzgrid==1)) then
       ll1=1; ll2=mx; mm1=m1; mm2=m2; nn1=n1; nn2=n2
      else
      if (nxgrid==1) then
       ll1=l1; ll2=l2
      else
       ll1=1; ll2=mx
      endif
!
      if (nygrid==1) then
       mm1=m1; mm2=m2
      else
       mm1=1; mm2=my
      endif
!
      if (nzgrid==1) then
       nn1=n1; nn2=n2
      else
       nn1=1;  nn2=mz
      endif
     endif
!
!  Reinitialize if required
!
      if (reinitialize_chemistry) then
        print*,'Reinitializing chemistry.'
        call init_chemistry(f)
      endif
!
!  allocate memory for net_reaction diagnostics
!
      if (lchemistry_diag) then
        allocate(net_react_p(nchemspec,nreactions),STAT=stat)
          if (stat>0) call stop_it("Couldn't allocate memory for net_react_p")
          net_react_p=0.
        allocate(net_react_m(nchemspec,nreactions),STAT=stat)
          if (stat>0) call stop_it("Couldn't allocate memory for net_react_m")
          net_react_m=0.
      endif
!
!  write array dimension to chemistry diagnostics file
!
      open(1,file=trim(datadir)//'/net_reactions.dat',position='append')
      write(1,*) nchemspec,nreactions
      close(1)
!
    endsubroutine initialize_chemistry
!***********************************************************************
    subroutine init_chemistry(f)
!
!  initialise chemistry initial condition; called from start.f90
!
!  13-aug-07/steveb: coded
!
      use Initcond
!
      real, dimension (mx,my,mz,mfarray) :: f
      integer :: j,k
      logical :: lnothing, air_exist
!
      intent(inout) :: f
!
!  different initializations of nd (called from start)
!
      lnothing=.false.
      do j=1,ninit
        select case (initchem(j))
!
        case ('nothing')
          if (lroot .and. .not. lnothing) print*, 'initchem: nothing '
          lnothing=.true.
        case ('constant')
          do k=1,nchemspec
            f(:,:,:,ichemspec(k))=amplchemk(k)
          enddo
        case ('positive-noise')
          do k=1,nchemspec
            call posnoise(amplchemk(k),f,ichemspec(k))
          enddo
        case ('positive-noise-rel')
          do k=1,nchemspec
            call posnoise_rel(amplchemk(k),amplchemk2(k),f,ichemspec(k))
          enddo
        case ('innerbox')
          do k=1,nchemspec
            call innerbox(amplchemk(k),amplchemk2(k),f,ichemspec(k),widthchem)
          enddo
        case ('cos2x_cos2y_cos2z')
          do k=1,nchemspec
            call cos2x_cos2y_cos2z(amplchemk(k),f,ichemspec(k))
          enddo
        case ('coswave-x')
          do k=1,nchemspec
            call coswave(amplchem,f,ichemspec(k),kx=kx_chem)
          enddo
        case ('gaussian-x')
          do k=1,nchemspec
            call gaussian(amplchem,f,ichemspec(k),kx=kx_chem)
          enddo
        case ('gaussian-pos')
          do k=1,nchemspec
            call gaussianpos(amplchemk(k),f,ichemspec(k),widthchem,kx_chem,ky_chem,kz_chem)
            print*,"c(",x(l1),",",y(m1),",",z(n1),")=", f(l1,m1,n1,ichemspec(k))
          enddo
        case ('hatwave-x')
          do k=1,nchemspec
            call hatwave(amplchem,f,ichemspec(k),widthchem,kx=kx_chem)
          enddo
        case ('hatwave-y')
          do k=1,nchemspec
            call hatwave(amplchem,f,ichemspec(k),widthchem,ky=ky_chem)
          enddo
        case ('hatwave-z')
          do k=1,nchemspec
            call hatwave(amplchem,f,ichemspec(k),widthchem,kz=kz_chem)
          enddo
        case ('air')
          if (lroot ) print*, 'init_chem: air '
           inquire(file='air.dat',exist=air_exist)
           if (air_exist) then
            call air_field(f)
           else
            call stop_it('there is no air.dat file')
           endif
        case ('flame_front')
          call flame_front(f)
        case ('flame')
          if (lroot) print*, 'initchem: flame '
          call flame(f)
        case ('flame_blob')
          call flame_blob(f)
        case ('prerun_1D')          
          call prerun_1D(f,prerun_directory)
        case default
!
!  Catch unknown values
!
          if (lroot) print*, 'initchem: No such value for initchem: ', &
              trim(initchem(j))
          call stop_it('')
!
        endselect
      enddo
!
!  Interface for user's own initial condition
!
!AB:  if (linitial_condition) call initial_condition_chemistry(f)
!
!   The following lines are kept temporally
!
!      if (lone_spec) then
!        f(:,:,:,ichemspec(1))=1.
!        if (lroot) print*, 'initchem: this is one specie case'
!      endif
!
    endsubroutine init_chemistry
!***********************************************************************
    subroutine pencil_criteria_chemistry()
!
!  All pencils that this chemistry module depends on are specified here.
!
!  13-aug-07/steveb: coded
!
      lpenc_requested(i_gXXk)=.true.
      lpenc_requested(i_gYYk)=.true.
      lpenc_requested(i_ghhk)=.true.
!
      lpenc_requested(i_DYDt_reac)=.true.
      lpenc_requested(i_DYDt_diff)=.true.
!
      if (ldiffusion .and. lDiff_simple) then
        lpenc_requested(i_Diff_penc_add)=.true.
      endif
!
       if (lcheminp) then
         lpenc_requested(i_rho)=.true.
         lpenc_requested(i_cv)=.true.
         lpenc_requested(i_cv1)=.true.
         lpenc_requested(i_H0_RT)=.true.
         lpenc_requested(i_nu)=.true.
         lpenc_requested(i_gradnu)=.true.
!
         if (lreactions) lpenc_requested(i_hhk_full)=.true.
         if (lThCond_simple) lpenc_requested(i_glncp)=.true.
!
         if (lheatc_chemistry) then
           lpenc_requested(i_lambda)=.true.
           lpenc_requested(i_glambda)=.true.
         endif

         if (latmchem .or. lcloud) then
           lpenc_requested(i_ppwater)=.true.
           lpenc_requested(i_Ywater)=.true.
         endif
       endif
!
    endsubroutine pencil_criteria_chemistry
!***********************************************************************
    subroutine pencil_interdep_chemistry(lpencil_in)
!
!  Interdependency among pencils provided by this module are specified here
!
!  02-03-08/Natalia: coded
!
      logical, dimension(npencils) :: lpencil_in
!
        if (lpencil_in(i_cv1))    lpencil_in(i_cv)=.true.
        if (lpencil_in(i_glambda))  lpencil_in(i_lambda)=.true.
!
         if (lpencil_in(i_H0_RT))  then
            lpencil_in(i_TT)=.true.
            lpencil_in(i_TT_2)=.true.
            lpencil_in(i_TT_3)=.true.
            lpencil_in(i_TT_4)=.true.
            lpencil_in(i_TT1)=.true.
         endif
         if (lpencil_in(i_DYDt_reac))  then
            lpencil_in(i_TT)=.true.
            lpencil_in(i_TT1)=.true.
            lpencil_in(i_TT_2)=.true.
            lpencil_in(i_TT_3)=.true.
            lpencil_in(i_TT_4)=.true.
            lpencil_in(i_lnTT)=.true.
            lpencil_in(i_H0_RT)=.true.
            lpencil_in(i_mu1)=.true.
            lpencil_in(i_rho)=.true.
         endif
         if (lpencil_in(i_hhk_full))  then
            lpencil_in(i_H0_RT)=.true.
            lpencil_in(i_TT)=.true.
         endif
         if (lpencil_in(i_ghhk))  then
            lpencil_in(i_glnTT)=.true.
            lpencil_in(i_TT)=.true.
         endif
         if (lpencil_in(i_ppwater))  then
            lpencil_in(i_TT)=.true.
            lpencil_in(i_rho)=.true.
         endif
!
      call keep_compiler_quiet(lpencil_in)
!
    endsubroutine pencil_interdep_chemistry
!***********************************************************************
    subroutine calc_pencils_chemistry(f,p)
!
!  Calculate chemistry pencils.
!  Most basic pencils should come first, as others may depend on them.
!
!   13-aug-07/steveb: coded
!
      use Sub, only : grad
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
      real, dimension (nx,3) :: gXX_tmp, glncp_tmp!, ghhk_tmp
!
      intent(in) :: f
      intent(inout) :: p
      integer :: k,i
      integer :: ii1=1,ii2=2,ii3=3,ii4=4,ii5=5,ii6=6
      real :: T_low,T_up, T_mid
      real, dimension(nx) :: T_loc
!
!  Mass fraction YY
!
!      if (lpencil(i_YY) .and. lreactions ) then
!        do k=1,nchemspec;  p%YY(:,k)=f(l1:l2,m,n,ichemspec(k)); enddo
!      endif
!
      if (lpencil(i_gYYk) .and. ldiffusion) then
       do k=1,nchemspec
         call grad(f(:,:,:,ichemspec(k)),gXX_tmp)
         do i=1,3; p%gYYk(:,i,k)=gXX_tmp(:,i); enddo
       enddo
      endif
!
      if (lpencil(i_gXXk) .and. ldiffusion) then
       do k=1,nchemspec
         call grad(XX_full(:,:,:,k),gXX_tmp)
         do i=1,3; p%gXXk(:,i,k)=gXX_tmp(:,i); enddo
       enddo
      endif
!
      if (lcheminp) then
!
        if (lpencil(i_glncp) .and. lThCond_simple) then
          call grad(cp_full,glncp_tmp)
          do i=1,3
           p%glncp(:,i)=glncp_tmp(:,i)/cp_full(l1:l2,m,n)
          enddo
        endif
!
!  Specific heat at constant volume (i.e. density)
!
        if (lpencil(i_cv)) p%cv = cv_full(l1:l2,m,n)
!
        if (lpencil(i_cv1)) p%cv1=1./p%cv
!
!  Viscosity of a mixture
!
         if (lpencil(i_nu)) then
          if (visc_const<impossible) then
           p%nu=visc_const
          else
           p%nu=nu_full(l1:l2,m,n)
          endif
           if (lpencil(i_gradnu)) then
             if (visc_const<impossible) then
               p%gradnu=0.
             else
               call grad(nu_full,p%gradnu)
             endif
           endif
         endif
!
      endif
!
!  Dimensionless Standard-state molar enthalpy H0/RT
!
        if (lpencil(i_H0_RT)) then
!         if (.not. lT_const) then
!AB: Natalia, maybe we should ask earlier for lentropy?
          if ((.not. lT_const).and.(ilnTT/=0)) then
            do k=1,nchemspec
              T_low=species_constants(k,iTemp1)
              T_mid=species_constants(k,iTemp2)
              T_up= species_constants(k,iTemp3)
!
! Natalia:pencil_check
! if lpencil_check and full compiler settings then
! the problem appears for T_loc= p%TT
! Does anybody know why it is so?
! While this problem is not resolved 
! I use T_loc= exp(f(l1:l2,m,n,ilnTT))
! 
              T_loc= exp(f(l1:l2,m,n,ilnTT))
              where (T_loc <= T_mid)
                p%H0_RT(:,k)=species_constants(k,iaa2(ii1)) &
                    +species_constants(k,iaa2(ii2))*T_loc/2 &
                    +species_constants(k,iaa2(ii3))*p%TT_2/3 &
                    +species_constants(k,iaa2(ii4))*p%TT_3/4 &
                    +species_constants(k,iaa2(ii5))*p%TT_4/5 &
                    +species_constants(k,iaa2(ii6))/T_loc
              elsewhere
                p%H0_RT(:,k)=species_constants(k,iaa1(ii1)) &
                    +species_constants(k,iaa1(ii2))*T_loc/2 &
                    +species_constants(k,iaa1(ii3))*p%TT_2/3 &
                    +species_constants(k,iaa1(ii4))*p%TT_3/4 &
                    +species_constants(k,iaa1(ii5))*p%TT_4/5 &
                    +species_constants(k,iaa1(ii6))/T_loc
              endwhere
            enddo
          endif
!
!  Enthalpy flux
!
          if (lpencil(i_hhk_full) .and.lreactions) then
            do k=1,nchemspec
              if (species_constants(k,imass)>0.)  then
                p%hhk_full(:,k)=p%H0_RT(:,k)*Rgas*p%TT&
                    /species_constants(k,imass)
              endif
            enddo
          endif
!
          if (lpencil(i_ghhk) .and. lreactions) then
            do k=1,nchemspec
              if (species_constants(k,imass)>0.)  then
                !  call grad(hhk_full(:,:,:,k),ghhk_tmp)
                do i=1,3
                  p%ghhk(:,i,k)=(cv_R_spec_full(l1:l2,m,n,k)+1) &
                      /species_constants(k,imass)*Rgas*p%glnTT(:,i)*p%TT(:)
                enddo
              endif
            enddo
          endif
        endif
!
! Calculate the reaction term and the corresponding pencil
!
      if (lreactions .and. lpencil(i_DYDt_reac)) then
        call calc_reaction_term(f,p)
      else
        p%DYDt_reac=0.
      endif
!
! Calculate the diffusion term and the corresponding pencil
!
! There are 2 cases:
! 1) the case of simplifyed expression for the difusion coef. (Oran paper,)
! 2) the case of the constant diffusion coefficient
!
       if (ldiffusion .and. lpencil(i_Diff_penc_add)) then
       if  ((Diff_coef_const<impossible) .or. (lDiff_simple) ) then
         if (lDiff_simple) then
           if (Diff_coef_const>impossible*0.99)  Diff_coef_const=10.
           do k=1,nchemspec
             p%Diff_penc_add(:,k)=Diff_coef_const &
               *(p%TT(:)/p%TT(1)*p%rho(1)/p%rho(:))**0.7  &
               *species_constants(k,imass)/unit_mass*mu1_full(l1:l2,m,n)
           enddo
         elseif ((.not. lDiff_simple) .and. (Diff_coef_const<impossible)) then
           p%Diff_penc_add(:,:)=Diff_coef_const
         endif
      endif
      endif
!
      if (ldiffusion .and. lpencil(i_DYDt_diff)) then
        call calc_diffusion_term(f,p)
      else
        p%DYDt_diff=0.
      endif
!
      if (latmchem) then
      RHS_Y_full(l1:l2,m,n,:)=p%DYDt_diff
      else
      RHS_Y_full(l1:l2,m,n,:)=p%DYDt_reac+p%DYDt_diff
      endif
!
! Calculate the thermal diffusivity
!
      if (lpencil(i_lambda) .and. lheatc_chemistry) then
      if ((lThCond_simple) .or. (lambda_const<impossible))then
        if (lThCond_simple) then
          if (lambda_const>impossible*0.99) lambda_const=1e4
          p%lambda=lambda_const &
             *(p%TT(:)/p%TT(1))**0.7*cp_full(l1:l2,m,n)/cp_full(l1,m,n)
          if (lpencil(i_glambda))  then
           do i=1,3
            p%glambda(:,i)=p%lambda(:)*(0.7*p%glnTT(:,i)+p%glncp(:,i))
           enddo
          endif
        elseif ((.not. lThCond_simple) .and. (lambda_const<impossible)) then
          p%lambda=lambda_const
          if (lpencil(i_glambda)) p%glambda=0.
        endif
      else
       p%lambda=lambda_full(l1:l2,m,n)
       if (lpencil(i_glambda)) call grad(lambda_full,p%glambda)
      endif
      endif
!
      if (lpencil(i_ppwater)) then
        if (index_H2O>0) then
         p%ppwater=p%rho*Rgas*p%TT*f(l1:l2,m,n,ichemspec(index_H2O))
        endif
      endif
      if (lpencil(i_Ywater)) then
        if (index_H2O>0) then
         p%Ywater=f(l1:l2,m,n,ichemspec(index_H2O))
        endif
      endif
!
    endsubroutine calc_pencils_chemistry
!***********************************************************************
      subroutine flame_front(f)
!
! 06.05.2009/Nils Erland L. Haugen: adapted from similar
!                                   routine in special/chem_stream.f90
! This routine set up the initial profiles used in 1D flame speed measurments
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      integer :: i,j,k
!
      real :: mO2=0., mH2=0., mN2=0., mH2O=0., mCH4=0., mCO2=0.
      real :: log_inlet_density, del
      integer :: i_H2, i_O2, i_H2O, i_N2, ichem_H2, ichem_O2, ichem_N2, ichem_H2O
      integer :: i_CH4, i_CO2, ichem_CH4, ichem_CO2
      real :: initial_mu1, final_massfrac_O2
      real :: init_H2,init_O2,init_N2,init_H2O,init_CO2,init_CH4
      logical :: lH2,lO2,lN2,lH2O,lCH4,lCO2
!
      lflame_front=.true.
!
      call air_field(f)
!
      if (ltemperature_nolog) f(:,:,:,ilnTT)=log(f(:,:,:,ilnTT))
!
! Initialize some indexes
!
      call find_species_index('H2' ,i_H2 ,ichem_H2 ,lH2)
      if (lH2) then
        mH2 =species_constants(ichem_H2 ,imass)
        init_H2=initial_massfractions(ichem_H2)
      endif
      call find_species_index('O2' ,i_O2 ,ichem_O2 ,lO2)
      if (lO2) then
        mO2 =species_constants(ichem_O2 ,imass)
        init_O2=initial_massfractions(ichem_O2)
      endif
      call find_species_index('N2' ,i_N2 ,ichem_N2 ,lN2)
      if (lN2) then
        mN2 =species_constants(ichem_N2 ,imass)
        init_N2=initial_massfractions(ichem_N2)
      endif
      call find_species_index('H2O',i_H2O,ichem_H2O,lH2O)
      if (lH2O) then
        mH2O =species_constants(ichem_H2O ,imass)
        init_H2O=initial_massfractions(ichem_H2O)
      endif
      call find_species_index('CH4',i_CH4,ichem_CH4,lCH4)
      if (lCH4) then
        mCH4 =species_constants(ichem_CH4 ,imass)
        init_CH4=initial_massfractions(ichem_CH4)
      endif
      call find_species_index('CO2',i_CO2,ichem_CO2,lCO2)
      if (lCO2) then
        mCO2 =species_constants(ichem_CO2 ,imass)
        init_CO2=initial_massfractions(ichem_CO2)
      endif
!
! Find approximate value for the mass fraction of O2 after the flame front
!
     final_massfrac_O2=0.

     if (mO2>0) final_massfrac_O2 = init_O2
     if (mH2>0) final_massfrac_O2 = &
                final_massfrac_O2 - init_H2/(2.*mH2)*mO2
     if (mCH4>0) final_massfrac_O2 = &
                 final_massfrac_O2 - init_CH4*2/(mCH4)*mO2
!
     if (final_massfrac_O2<0.) final_massfrac_O2=0.
!
!  Initialize temperature and species
!
      do k=1,mx
!
!  Initialize temperature
!
        if (lT_tanh) then
          del=init_x2-init_x1
          f(k,:,:,ilnTT)=f(k,:,:,ilnTT)+log((init_TT2+init_TT1)*0.5  &
              +((init_TT2-init_TT1)*0.5)  &
              *(exp(x(k)/del)-exp(-x(k)/del))/(exp(x(k)/del)+exp(-x(k)/del)))
        else
          if (x(k)<=init_x1) then
            f(k,:,:,ilnTT)=log(init_TT1)
          endif
          if (x(k)>=init_x2) then
            f(k,:,:,ilnTT)=log(init_TT2)
          endif
          if (x(k)>init_x1 .and. x(k)<init_x2) then
            f(k,:,:,ilnTT)=&
                log((x(k)-init_x1)/(init_x2-init_x1) &
                *(init_TT2-init_TT1)+init_TT1)
          endif
        endif
!
!  Initialize steam and hydrogen
!
        if (lT_tanh) then
          del=(init_x2-init_x1)
          f(k,:,:,i_H2)=(0.+f(l1,:,:,i_H2))*0.5  &
              +(0.-f(l1,:,:,i_H2))*0.5  &
              *(exp(x(k)/del)-exp(-x(k)/del))/(exp(x(k)/del)+exp(-x(k)/del))
!
          f(k,:,:,i_H2O)=(f(l1,:,:,i_H2)/2.*18.+f(l1,:,:,i_H2O))*0.5  &
              +((f(l1,:,:,i_H2)/2.*18.-f(l1,:,:,i_H2O))*0.5)  &
              *(exp(x(k)/del)-exp(-x(k)/del))/(exp(x(k)/del)+exp(-x(k)/del))
!
        else
          if (x(k)>init_x1) then
            if (lH2) then
              f(k,:,:,i_H2)=init_H2*(exp(f(k,:,:,ilnTT))-init_TT2) &
                  /(init_TT1-init_TT2)
            endif
            if (lCH4) then
              f(k,:,:,i_CH4)=init_CH4*(exp(f(k,:,:,ilnTT))-init_TT2) &
                  /(init_TT1-init_TT2)
            endif
          endif
        endif
!
!  Initialize oxygen
!
         if (lT_tanh) then
          del=(init_x2-init_x1)
          f(k,:,:,i_O2)=(f(l2,:,:,i_O2)+f(l1,:,:,i_O2))*0.5  &
              +((f(l2,:,:,i_O2)-f(l1,:,:,i_O2))*0.5)  &
              *(exp(x(k)/del)-exp(-x(k)/del))/(exp(x(k)/del)+exp(-x(k)/del))
         else
!
          if (x(k)>init_x2) then
            f(k,:,:,i_O2)=final_massfrac_O2
          endif
          if (x(k)>init_x1 .and. x(k)<init_x2) then
            f(k,:,:,i_O2)=(x(k)-init_x2)/(init_x1-init_x2) &
                *(init_O2-final_massfrac_O2)&
                +final_massfrac_O2
          endif
         endif
        enddo
!
! Initialize steam and CO2
!
        if (.not. lT_tanh) then
          do k=1,mx
            if (x(k)>=init_x1) then
              if (final_massfrac_O2>0.) then
                f(k,:,:,i_H2O)=initial_massfractions(ichem_H2)/mH2*mH2O &
                    *(exp(f(k,:,:,ilnTT))-init_TT1) &
                    /(init_TT2-init_TT1)+init_H2O
              else
                if (x(k)>=init_x2) then
                  if (lCO2) f(k,:,:,i_CO2)=init_CO2+(init_CH4-f(k,:,:,i_CH4))
                  f(k,:,:,i_H2O)=1.-f(k,:,:,i_N2)-f(k,:,:,i_H2)-f(k,:,:,i_O2)
                  if (lCH4) f(k,:,:,i_H2O)=f(k,:,:,i_H2O)-f(k,:,:,i_CH4)
                  if (lCO2) f(k,:,:,i_H2O)=f(k,:,:,i_H2O)-f(k,:,:,i_CO2)
                else
                  f(k,:,:,i_H2O)=(x(k)-init_x1)/(init_x2-init_x1) &
                      *((1.-f(l2,:,:,i_N2)-f(l2,:,:,i_H2)) &
                       -initial_massfractions(ichem_H2O)) &
                       +initial_massfractions(ichem_H2O)
                endif
!
              endif
            endif
          enddo
        endif
!
         if (unit_system == 'cgs') then
          Rgas_unit_sys = k_B_cgs/m_u_cgs
          Rgas=Rgas_unit_sys/unit_energy
         endif
!
!  Find logaritm of density at inlet
!
         initial_mu1&
             =initial_massfractions(ichem_H2)/(mH2)&
             +initial_massfractions(ichem_O2)/(mO2)&
             +initial_massfractions(ichem_H2O)/(mH2O)&
             +initial_massfractions(ichem_N2)/(mN2)
         if (lCO2) initial_mu1=initial_mu1+init_CO2/(mCO2)
         if (lCH4) initial_mu1=initial_mu1+init_CH4/(mCH4)
         log_inlet_density=&
             log(init_pressure)-log(Rgas)-log(init_TT1)-log(initial_mu1)
!
       call getmu_array(f,mu1_full)
!
!  Initialize density
!
      f(l1:l2,m1:m2,n1:n2,ilnrho)=log(init_pressure)-log(Rgas)  &
          -f(l1:l2,m1:m2,n1:n2,ilnTT)-log(mu1_full(l1:l2,m1:m2,n1:n2))
!
!  Initialize velocity
!
      f(l1:l2,m1:m2,n1:n2,iux)=f(l1:l2,m1:m2,n1:n2,iux)+init_ux
!
!
!  Check if we want nolog of density or nolog of temperature
!
      if (ldensity_nolog) &
          f(l1:l2,m1:m2,n1:n2,irho)=exp(f(l1:l2,m1:m2,n1:n2,ilnrho))
      if (ltemperature_nolog) &
          f(l1:l2,m1:m2,n1:n2,iTT)=exp(f(l1:l2,m1:m2,n1:n2,ilnTT))
!
! Renormalize all species too be sure that the sum of all mass fractions
! are unity
!
      do i=1,mx
      do j=1,my
      do k=1,mz
        f(i,j,k,ichemspec)=f(i,j,k,ichemspec)/sum(f(i,j,k,ichemspec))
      enddo
      enddo      
      enddo
!
    endsubroutine flame_front
!***********************************************************************
      subroutine flame(f)
!
! 06.05.2009/Nils Erland L. Haugen: adapted from similar
!                                   routine in special/chem_stream.f90
! This routine set up the initial profiles used in 1D flame speed measurments
! NILS: This routine is essentially the samw as flame_front, but I leave
! NILS: flame_front as it is for now for backwards compatibility.
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      integer :: i,j,k
!
      real :: mO2, mH2, mN2, mH2O, mCH4, mCO2
      real :: log_inlet_density, del
      integer :: i_H2, i_O2, i_H2O, i_N2, ichem_H2, ichem_O2, ichem_N2, ichem_H2O
      integer :: i_CH4, i_CO2, ichem_CH4, ichem_CO2
      real :: initial_mu1, final_massfrac_O2
      real :: init_H2,init_O2,init_N2,init_H2O,init_CO2,init_CH4
      logical :: lH2,lO2,lN2,lH2O,lCH4,lCO2
!
      lflame_front=.true.
!
      call air_field(f)
!
      if (ltemperature_nolog) f(:,:,:,ilnTT)=log(f(:,:,:,ilnTT))
!
! Initialize some indexes
!
      call find_species_index('H2' ,i_H2 ,ichem_H2 ,lH2)
      if (lH2) then
        mH2 =species_constants(ichem_H2 ,imass)
        init_H2=initial_massfractions(ichem_H2)
      endif
      call find_species_index('O2' ,i_O2 ,ichem_O2 ,lO2)
      if (lO2) then
        mO2 =species_constants(ichem_O2 ,imass)
        init_O2=initial_massfractions(ichem_O2)
      endif
      call find_species_index('N2' ,i_N2 ,ichem_N2 ,lN2)
      if (lN2) then
        mN2 =species_constants(ichem_N2 ,imass)
        init_N2=initial_massfractions(ichem_N2)
      endif
      call find_species_index('H2O',i_H2O,ichem_H2O,lH2O)
      if (lH2O) then
        mH2O =species_constants(ichem_H2O ,imass)
        init_H2O=initial_massfractions(ichem_H2O)
      endif
      call find_species_index('CH4',i_CH4,ichem_CH4,lCH4)
      if (lCH4) then
        mCH4 =species_constants(ichem_CH4 ,imass)
        init_CH4=initial_massfractions(ichem_CH4)
      endif
      call find_species_index('CO2',i_CO2,ichem_CO2,lCO2)
      if (lCO2) then
        mCO2 =species_constants(ichem_CO2 ,imass)
        init_CO2=initial_massfractions(ichem_CO2)
      endif
!
! Find approximate value for the mass fraction of O2 after the flame front
!
      final_massfrac_O2&
          =(init_O2/mO2&
          -init_H2/(2.*mH2)&
          -init_CH4*2/(mCH4))*mO2
!
     if (final_massfrac_O2<0.) final_massfrac_O2=0.
!
!  Initialize temperature and species
!
      do k=1,mx
!
!  Initialize temperature
!
        if (lT_tanh) then
          del=init_x2-init_x1
          f(k,:,:,ilnTT)=f(k,:,:,ilnTT)+log((init_TT2+init_TT1)*0.5  &
              +((init_TT2-init_TT1)*0.5)  &
              *(exp(x(k)/del)-exp(-x(k)/del))/(exp(x(k)/del)+exp(-x(k)/del)))
        else
          if (x(k)<=init_x1) then
            f(k,:,:,ilnTT)=log(init_TT1)
          endif
          if (x(k)>=init_x2) then
            f(k,:,:,ilnTT)=log(init_TT2)
          endif
          if (x(k)>init_x1 .and. x(k)<init_x2) then
            f(k,:,:,ilnTT)=&
                log((x(k)-init_x1)/(init_x2-init_x1) &
                *(init_TT2-init_TT1)+init_TT1)
          endif
        endif
!
!  Initialize steam and hydrogen
!
        if (lT_tanh) then
          del=(init_x2-init_x1)
          if (lH2) then
            f(k,:,:,i_H2)=(0.+f(l1,:,:,i_H2))*0.5  &
                +(0.-f(l1,:,:,i_H2))*0.5  &
                *(exp(x(k)/del)-exp(-x(k)/del))/(exp(x(k)/del)+exp(-x(k)/del))
            f(k,:,:,i_H2O)=(f(l1,:,:,i_H2)/2.*18.+f(l1,:,:,i_H2O))*0.5  &
                +((f(l1,:,:,i_H2)/2.*18.-f(l1,:,:,i_H2O))*0.5)  &
                *(exp(x(k)/del)-exp(-x(k)/del))/(exp(x(k)/del)+exp(-x(k)/del))
          endif
          if (lCH4) then
            f(k,:,:,i_CH4)=init_CH4*0.5  &
                -init_CH4*0.5  &
                *(exp(x(k)/del)-exp(-x(k)/del))/(exp(x(k)/del)+exp(-x(k)/del))
            f(k,:,:,i_H2O)=init_H2O+(init_CH4-f(k,:,:,i_CH4))*2.*mH2O/mCH4
            f(k,:,:,i_CO2)=init_CO2+(init_CH4-f(k,:,:,i_CH4))*1.*mCO2/mCH4
            f(k,:,:,i_O2) =init_O2 -(init_CH4-f(k,:,:,i_CH4))*2.*mO2 /mCH4
          endif
        else
          if (x(k)>init_x1) then
            if (lH2) then
              f(k,:,:,i_H2)=init_H2*(exp(f(k,:,:,ilnTT))-init_TT2) &
                  /(init_TT1-init_TT2)
            endif
            if (lCH4) then
              f(k,:,:,i_CH4)=init_CH4*(exp(f(k,:,:,ilnTT))-init_TT2) &
                  /(init_TT1-init_TT2)
            endif
          endif
        endif
!
!  Initialize oxygen
!
        if (lT_tanh) then
!!$          del=(init_x2-init_x1)
!!$          f(k,:,:,i_O2)=(f(l2,:,:,i_O2)+f(l1,:,:,i_O2))*0.5  &
!!$              +((f(l2,:,:,i_O2)-f(l1,:,:,i_O2))*0.5)  &
!!$              *(exp(x(k)/del)-exp(-x(k)/del))/(exp(x(k)/del)+exp(-x(k)/del))
         else
           if (x(k)>init_x2) then
             f(k,:,:,i_O2)=final_massfrac_O2
           endif
           if (x(k)>init_x1 .and. x(k)<init_x2) then
             f(k,:,:,i_O2)=(x(k)-init_x2)/(init_x1-init_x2) &
                 *(init_O2-final_massfrac_O2)&
                 +final_massfrac_O2
           endif
         endif
       enddo
!
! Initialize steam and CO2
!
       if (.not. lT_tanh) then
         do k=1,mx
           if (x(k)>=init_x1) then
             if (final_massfrac_O2>0.) then
               f(k,:,:,i_H2O)=initial_massfractions(ichem_H2)/mH2*mH2O &
                   *(exp(f(k,:,:,ilnTT))-init_TT1) &
                   /(init_TT2-init_TT1)+init_H2O
             else
               if (x(k)>=init_x2) then
                 if (lCO2) f(k,:,:,i_CO2)=init_CO2+(init_CH4-f(k,:,:,i_CH4))
                 f(k,:,:,i_H2O)=1.-f(k,:,:,i_N2)-f(k,:,:,i_H2)-f(k,:,:,i_O2)
                 if (lCH4) f(k,:,:,i_H2O)=f(k,:,:,i_H2O)-f(k,:,:,i_CH4)
                 if (lCO2) f(k,:,:,i_H2O)=f(k,:,:,i_H2O)-f(k,:,:,i_CO2)
               else
                 f(k,:,:,i_H2O)=(x(k)-init_x1)/(init_x2-init_x1) &
                     *((1.-f(l2,:,:,i_N2)-f(l2,:,:,i_H2)) &
                     -initial_massfractions(ichem_H2O)) &
                     +initial_massfractions(ichem_H2O)
               endif
              endif
            endif
          enddo
        else
!!$          if (lCH4) f(k,:,:,i_H2O)=f(k,:,:,i_H2O)-f(k,:,:,i_CH4)
!!$          if (lCO2) f(k,:,:,i_H2O)=f(k,:,:,i_H2O)-f(k,:,:,i_CO2)
        endif
!
         if (unit_system == 'cgs') then
           Rgas_unit_sys = k_B_cgs/m_u_cgs
           Rgas=Rgas_unit_sys/unit_energy
         endif
!
!  Find logaritm of density at inlet
!
         initial_mu1&
             =initial_massfractions(ichem_H2)/(mH2)&
             +initial_massfractions(ichem_O2)/(mO2)&
             +initial_massfractions(ichem_H2O)/(mH2O)&
             +initial_massfractions(ichem_N2)/(mN2)
         if (lCO2) initial_mu1=initial_mu1+init_CO2/(mCO2)
         if (lCH4) initial_mu1=initial_mu1+init_CH4/(mCH4)
         log_inlet_density=&
             log(init_pressure)-log(Rgas)-log(init_TT1)-log(initial_mu1)
!
       call getmu_array(f,mu1_full)
!
!  Initialize density
!
      f(l1:l2,m1:m2,n1:n2,ilnrho)=log(init_pressure)-log(Rgas)  &
          -f(l1:l2,m1:m2,n1:n2,ilnTT)-log(mu1_full(l1:l2,m1:m2,n1:n2))
!
!  Initialize velocity
!
      f(l1:l2,m1:m2,n1:n2,iux)=f(l1:l2,m1:m2,n1:n2,iux)+init_ux
!
!
!  Check if we want nolog of density or nolog of temperature
!
      if (ldensity_nolog) &
          f(l1:l2,m1:m2,n1:n2,irho)=exp(f(l1:l2,m1:m2,n1:n2,ilnrho))
      if (ltemperature_nolog) &
          f(l1:l2,m1:m2,n1:n2,iTT)=exp(f(l1:l2,m1:m2,n1:n2,ilnTT))
!
! Renormalize all species too be sure that the sum of all mass fractions
! are unity
!
      do i=1,mx
      do j=1,my
      do k=1,mz
        f(i,j,k,ichemspec)=f(i,j,k,ichemspec)/sum(f(i,j,k,ichemspec))
      enddo
      enddo      
      enddo
!
    endsubroutine flame
!***********************************************************************
    subroutine flame_blob(f)
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz) :: mu1
      integer :: j1,j2,j3
!
      real :: mO2, mH2, mN2, mH2O
      integer :: i_H2, i_O2, i_H2O, i_N2, ichem_H2, ichem_O2, ichem_N2, ichem_H2O
      real :: initial_mu1, final_massfrac_O2
      logical :: found_specie
!
      real :: Rad, sz1,sz2
!
     lflame_front=.true.
!
      call air_field(f)
!
! Initialize some indexes
!
      call find_species_index('H2' ,i_H2 ,ichem_H2 ,found_specie)
      call find_species_index('O2' ,i_O2 ,ichem_O2 ,found_specie)
      call find_species_index('N2' ,i_N2 ,ichem_N2 ,found_specie)
      call find_species_index('H2O',i_H2O,ichem_H2O,found_specie)
      mO2 =species_constants(ichem_O2 ,imass)
      mH2 =species_constants(ichem_H2 ,imass)
      mH2O=species_constants(ichem_H2O,imass)
      mN2 =species_constants(ichem_N2 ,imass)
!
! Find approximate value for the mass fraction of O2 after the flame front
!
      final_massfrac_O2&
          =(initial_massfractions(ichem_O2)/mO2&
          -initial_massfractions(ichem_H2)/(2*mH2))*mO2
!
!  Initialize temperature and species in air_field(f)
!
      if (unit_system == 'cgs') then
          Rgas_unit_sys = k_B_cgs/m_u_cgs
          Rgas=Rgas_unit_sys/unit_energy
      endif
!
!  Find logaritm of density at inlet
!
      initial_mu1&
          =initial_massfractions(ichem_H2)/(mH2)&
          +initial_massfractions(ichem_O2)/(mO2)&
          +initial_massfractions(ichem_H2O)/(mH2O)&
          +initial_massfractions(ichem_N2)/(mN2)
!
       call getmu_array(f,mu1_full)
!
       do j3=1,mz
       do j2=1,my
       do j1=1,mx
!
  !     do j3=1,nxgrid+8
  !    do j2=1,nygrid+8
  !    do j1=1,nzgrid+8
!
        Rad=0.
       if (nxgrid >1) then
        Rad=x(j1)**2
       endif
       if (nygrid>1) then
        Rad=Rad+y(j2)**2
       endif
       if (nzgrid>1) then
        Rad=Rad+z(j3)**2
       endif
!
       Rad=(Rad)**0.5
!
       !  if (Rad<0.2) then
!          f(j1,j2,j3,ilnTT)=log(init_TT1+(init_TT2-init_TT1)*((0.06-Rad)/0.06)**2)
          ! f(j1,j2,j3,ilnTT)=log(init_TT1)+log(3.5)*((0.2-Rad)/0.2)**2
           f(j1,j2,j3,ilnTT)=log((init_TT2-init_TT1)*exp(-(Rad/0.04)**2)+init_TT1)
       !  else
       !   f(j1,j2,j3,ilnTT)=log(init_TT1)
       !  endif
!
         ! f(j1,j2,j3,ilnTT)=log((init_TT2-init_TT1)*exp(-((0.2-Rad)/0.2)**2)+init_TT1)
          mu1(j1,j2,j3)=f(j1,j2,j3,i_H2)/(2.*mH2)+f(j1,j2,j3,i_O2)/(2.*mO2) &
              +f(j1,j2,j3,i_H2O)/(2.*mH2+mO2)+f(j1,j2,j3,i_N2)/(2.*mN2)
!
         f(j1,j2,j3,ilnrho)=log(init_pressure)-log(Rgas)-f(j1,j2,j3,ilnTT)  &
              -log(mu1_full(j1,j2,j3))
!
      !  f(j1,j2,j3,ilnrho)=log(init_pressure)-log(Rgas)-f(l1,m1,n1,ilnTT)  &
      !      -log(mu1_full(l1,m1,n1))
      !  f(j1,j2,j3,ilnrho)=log(init_pressure)-log(Rgas)  &
    !        -f(j1,j2,j3,ilnTT)-log(mu1_full(j1,j2,j3))
!
!
!  Initialize velocity
!
            f(j1,j2,j3,iux)=f(j1,j2,j3,iux)  &
                +init_ux!*exp(log_inlet_density)/exp(f(j1,j2,j3,ilnrho))
            f(j1,j2,j3,iuy)=f(j1,j2,j3,iuy)+ init_uy
            f(j1,j2,j3,iuz)=f(j1,j2,j3,iuz)+ init_uz
!
           if (nxgrid==1) f(j1,j2,j3,iux)=0.
           if (nygrid==1) f(j1,j2,j3,iuy)=0.
           if (nzgrid==1) f(j1,j2,j3,iuz)=0.
!
           if (nxgrid/=1) then
            sz1=(xyz0(1)+Lxyz(1)*0.15)
            sz2=(xyz0(1)+Lxyz(1)*(1.-0.15))
            if ((x(j1)<sz1) .or. (sz2<x(j1))) then
         !     f(j1,j2,j3,iux)=0.
            endif
           endif
!
          if (nygrid/=1)   then
            sz1=(xyz0(2)+Lxyz(2)*0.15)
            sz2=(xyz0(2)+Lxyz(2)*(1.-0.15))
            if ((y(j2)<sz1) .or. (y(j2)>sz2)) then
          !     f(j1,j2,j3,iuy)=0.
            endif
          endif
!
          if (nzgrid/=1)  then
           sz1=(xyz0(3)+Lxyz(3)*0.15)
           sz2=(xyz0(3)+Lxyz(3)*(1.-0.15))
           if ((z(j3)<sz1) .or. (z(j3)>sz2)) then
           !   f(j1,j2,j3,iuz)=0.
           endif
          endif
!
       enddo
       enddo
       enddo
!
!  Check if we want nolog of density
!
      if (ldensity_nolog) f(:,:,:,irho)=exp(f(:,:,:,ilnrho))
!
    endsubroutine flame_blob
!***********************************************************************
    subroutine calc_for_chem_mixture(f)
!
!  Calculate quantities for a mixture
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx) ::  tmp_sum,tmp_sum2, nu_dyn,nuk_nuj,Phi
      real, dimension (mx) :: cp_R_spec,T_loc,T_loc_2,T_loc_3,T_loc_4
!
      intent(in) :: f
      integer :: k,j,j2,j3
      real :: T_up, T_mid, T_low
      real :: mk_mj
      real :: EE=0.,TT=0.,yH=1.
!
      logical :: tran_exist=.false.
      logical,save :: lwrite=.true.
!
      character (len=20) :: output_file="./data/mix_quant.out"
      integer :: file_id=123
      integer :: ii1=1,ii2=2,ii3=3,ii4=4,ii5=5
!
!  Density and temperature
!
!     call timing('calc_for_chem_mixture','entered')
      call getdensity(f,EE,TT,yH,rho_full)
      call gettemperature(f,TT_full)
!
! Now this routine is only for chemkin data !!!
!
      if (lcheminp) then
!
        if (unit_system == 'cgs') then
!
          Rgas_unit_sys = k_B_cgs/m_u_cgs
          Rgas=Rgas_unit_sys/unit_energy
!
          call getmu_array(f,mu1_full)
!
          if (l1step_test) then
             species_constants(:,imass)=1.
             mu1_full=1.
          endif
!
!  Mole fraction XX
!
          do k=1,nchemspec
          if (species_constants(k,imass)>0.) then
          do j2=mm1,mm2
          do j3=nn1,nn2
             XX_full(:,j2,j3,k)=f(:,j2,j3,ichemspec(k))*unit_mass &
                /(species_constants(k,imass)*mu1_full(:,j2,j3))
          enddo
          enddo
          endif
          enddo
!
          call  getpressure(pp_full)
!
!  Specific heat at constant pressure
!
          if ((Cp_const<impossible) .or. (Cv_const<impossible)) then
!
            if (Cp_const<impossible) then
              cp_full=Cp_const*mu1_full
              cv_full=(Cp_const-Rgas)*mu1_full
            endif
!
            if (Cv_const<impossible) then
              cv_full=Cv_const*mu1_full
            endif
          else
          cp_full=0.
          cv_full=0.
            do j3=nn1,nn2
            do j2=mm1,mm2
              T_loc=TT_full(:,j2,j3)
              T_loc_2=T_loc*T_loc
              T_loc_3=T_loc_2*T_loc
              T_loc_4=T_loc_3*T_loc
              do k=1,nchemspec
               if (species_constants(k,imass)>0.) then
                T_low=species_constants(k,iTemp1)-1.
                T_mid=species_constants(k,iTemp2)
                T_up= species_constants(k,iTemp3)
!
!!$                  if (j1<=l1 .or. j2>=l2) then
!!$                    T_low=0.
!!$                    T_up=1e10
!!$                  endif
!
                  if (j2<=m1 .or. j2>=m2) then
                    T_low=0.
                    T_up=1e10
                  endif
!
                  if (j3<=n1 .or. j3>=n2) then
                    T_low=0.
                    T_up=1e10
                  endif
!
                  if (lcloud) T_low=0.
                  where (T_loc >=T_low .and. T_loc <= T_mid)
                   cp_R_spec=species_constants(k,iaa2(ii1)) &
                          +species_constants(k,iaa2(ii2))*T_loc &
                          +species_constants(k,iaa2(ii3))*T_loc_2 &
                          +species_constants(k,iaa2(ii4))*T_loc_3 &
                          +species_constants(k,iaa2(ii5))*T_loc_4
                  elsewhere (T_loc >=T_mid .and. T_loc<= T_up)
                   cp_R_spec=species_constants(k,iaa1(ii1)) &
                          +species_constants(k,iaa1(ii2))*T_loc &
                          +species_constants(k,iaa1(ii3))*T_loc_2 &
                          +species_constants(k,iaa1(ii4))*T_loc_3 &
                          +species_constants(k,iaa1(ii5))*T_loc_4
                 endwhere
                 cv_R_spec_full(:,j2,j3,k)=cp_R_spec-1.
!
! Check if the temperature are within bounds
!
                 if (maxval(T_loc)>T_up .or. minval(T_loc)<T_low) then
                   print*,'TT_full(:,j2,j3)=',T_loc
                   print*,'j2,j3=',j2,j3
                   call fatal_error('calc_for_chem_mixture',&
                       'TT_full(:,j2,j3) is outside range')
                 endif
        
!
! Find cp and cv for the mixture for the full domain
!
                 cp_full(:,j2,j3)=cp_full(:,j2,j3)+f(:,j2,j3,ichemspec(k))  &
                  *cp_R_spec/species_constants(k,imass)*Rgas
                 cv_full(:,j2,j3)=cv_full(:,j2,j3)+f(:,j2,j3,ichemspec(k))  &
                  *cv_R_spec_full(:,j2,j3,k)/species_constants(k,imass)*Rgas
               endif
             enddo
           enddo
           enddo
         endif
!
!  Binary diffusion coefficients
!
          inquire(file='tran.dat',exist=tran_exist)
!
          if (tran_exist) then
            call calc_diff_visc_coef(f)
          endif
!
!  Viscosity of a mixture
!
       if (visc_const>impossible*0.99) then
!
        do j3=nn1,nn2
        do j2=mm1,mm2
!
          if  (lone_spec) then
            nu_full(:,j2,j3)=species_viscosity(:,j2,j3,1)/rho_full(:,j2,j3)
          else
            nu_dyn=0.
            do k=1,nchemspec
             if (species_constants(k,imass)>0.) then
              tmp_sum2=0.
              do j=1,k
                mk_mj=species_constants(k,imass) &
                    /species_constants(j,imass)
                nuk_nuj=species_viscosity(:,j2,j3,k) &
                    /species_viscosity(:,j2,j3,j)
                Phi=1./sqrt(8.)*1./sqrt(1.+mk_mj) &
                    *(1.+sqrt(nuk_nuj)*mk_mj**(-0.25))**2
                tmp_sum2=tmp_sum2 &
                                  +XX_full(:,j2,j3,j)*Phi
              enddo
              nu_dyn=nu_dyn+XX_full(:,j2,j3,k)*&
                  species_viscosity(:,j2,j3,k)/tmp_sum2
             endif
            enddo
              nu_full(:,j2,j3)=nu_dyn/rho_full(:,j2,j3)
          endif
!
        enddo
        enddo
       endif
!
!  Diffusion coeffisient of a mixture
!
       if (.not. lDiff_simple) then
!
         do j3=nn1,nn2
         do j2=mm1,mm2
!
            Diff_full(:,j2,j3,:)=0.
            if (.not. lone_spec) then
!
             if (lfix_Sc) then
              do k=1,nchemspec
               if (species_constants(k,imass)>0.) then
               Diff_full(:,j2,j3,k)=species_viscosity(:,j2,j3,k) &
                   /rho_full(:,j2,j3)/Sc_number
               endif
              enddo
             elseif (ldiffusion) then
!
! The mixture diffusion coefficient as described in eq. 5-45 of the Chemkin
! manual. Previously eq. 5-44 was used, but due to problems in the limit
! when the mixture becomes a pure specie we changed to the more robust eq. 5-45.
!
              do k=1,nchemspec
                tmp_sum=0.
                tmp_sum2=0.
                do j=1,nchemspec
                 if (species_constants(k,imass)>0.) then
                 if (j /= k) then
                   tmp_sum=tmp_sum &
                        +XX_full(:,j2,j3,j)/Bin_Diff_coef(:,j2,j3,j,k)
                   tmp_sum2=tmp_sum2 &
                       +XX_full(:,j2,j3,j)*species_constants(j,imass)
!
                 endif
                 endif
                enddo
                 Diff_full(:,j2,j3,k)=mu1_full(:,j2,j3)*tmp_sum2&
                     /tmp_sum
              enddo
             endif
            endif
             do k=1,nchemspec
              if (species_constants(k,imass)>0.) then
              Diff_full_add(:,j2,j3,k)=Diff_full(:,j2,j3,k)*&
                  species_constants(k,imass)/unit_mass &
                  *mu1_full(:,j2,j3)
              endif
             enddo
         enddo
         enddo
       endif
!
!  Thermal diffusivity
!
        if (lheatc_chemistry .and. (.not. lThCond_simple)) then
          call calc_therm_diffus_coef(f)
        endif
        else
          call stop_it('This case works only for cgs units system!')
        endif
      endif
!
      if (lwrite) then
        open(file_id,file=output_file)
        write(file_id,*) 'Mixture quantities'
        write(file_id,*) '*******************'
        write(file_id,*) ''
        write(file_id,*) 'Mass, g/mole'
        write(file_id,'(7E12.4)') 1./maxval(mu1_full/unit_mass)
        write(file_id,*) ''
        write(file_id,*) 'Density, g/cm^3'
        write(file_id,'(7E12.4)') rho_full(l1,m1,n1)*unit_mass/unit_length**3, &
                                  rho_full(l2,m2,n2)*unit_mass/unit_length**3
        write(file_id,*) ''
        write(file_id,*) 'Themperature, K'
         ! Commented the next line out because
         ! samples/2d-tests/chemistry_GrayScott apparently has no f(:,:,:,5)
        if (ilnTT>0) write(file_id,'(7E12.4)')  &
        exp(f(l1,m1,n1,ilnTT))*unit_temperature, &
        exp(f(l2,m2,n2,ilnTT))*unit_temperature
        write(file_id,*) ''
        write(file_id,*) 'Cp,  erg/mole/K'
        write(file_id,'(7E12.4)') cp_full(l1,m1,n1)/Rgas*&
            Rgas_unit_sys/mu1_full(l1,m1,n1)/unit_mass,cp_full(l2,m2,n2)/Rgas*&
            Rgas_unit_sys/mu1_full(l2,m2,n2)/unit_mass
        write(file_id,*) ''
        write(file_id,*) 'cp, erg/g/K'
        write(file_id,'(7E12.4)') cp_full(l1,m1,n1)/Rgas*Rgas_unit_sys,cp_full(l2,m2,n2)/Rgas*Rgas_unit_sys
        write(file_id,*) ''
        write(file_id,*) 'gamma,max,min'
        write(file_id,'(7E12.4)') cp_full(l1,m1,n1)/cv_full(l1,m1,n1),&
            cp_full(l2,m2,n2)/cv_full(l2,m2,n2)
        write(file_id,*) ''
        write(file_id,*) 'Species viscosity, g/cm/s,'
        do k=1,nchemspec
        write(file_id,'(7E12.4)') species_viscosity(l1,m1,n1,k),  &
                                  species_viscosity(l2-1,m1,n1,k)
        enddo
        write(file_id,*) ''
        write(file_id,*) 'Thermal cond, erg/(cm K s),'
        write(file_id,'(7E12.4)') (lambda_full(l1,m1,n1)*&
            unit_energy/unit_time/unit_length/unit_temperature), &
                        (lambda_full(l2,m2,n2)*&
            unit_energy/unit_time/unit_length/unit_temperature)
        write(file_id,*) ''
        write(file_id,*) 'Species  Diffusion coefficient, cm^2/s'
        if (.not. ldiff_simple) then
          do k=1,nchemspec
            write(file_id,'(7E12.4)')&
                Diff_full(l1,m1,n1,k)*unit_length**2/unit_time, &
                Diff_full(l2,m2,n2,k)*unit_length**2/unit_time
          enddo
        endif
        write(file_id,*) ''
        if (lroot) print*,'calc_for_chem_mixture: writing mix_quant.out file'
        close(file_id)
        lwrite=.false.
      endif
!
      call timing('calc_for_chem_mixture','finished')
!
    endsubroutine calc_for_chem_mixture
!***********************************************************************
    subroutine astrobiology_data(f)
!
!  Proceedure to read in stoichiometric matrices in explicit format for
!  forward and backward reations. For historical reasons this is referred
!  to as "astrobiology_data".
!
!  28-feb-08/axel: coded
!
      character (len=80) :: chemicals=''
      ! Careful, limits the absolut size of the input matrix !!!
      character (len=15) :: file1='chemistry_m.dat',file2='chemistry_p.dat'
!      character (len=20) :: input_file='chem.inp'
      real, dimension (mx,my,mz,mfarray) :: f
      real :: dummy
      logical :: exist,exist1,exist2
      integer :: i,j,stat
      integer :: nchemspectemp
      character :: tmpchar
      logical :: inside
!
!
!  Find number of reactions by reading how many lines we have in file2
!
      j=1
      open(19,file=file2)
      read(19,*) chemicals
      do while (.true.)
        read(19,*,end=996) dummy
        j=j+1
      enddo
996   close(19)
      mreactions=j-1
      if (lroot) print*,'Number of reactions=',mreactions
!
!  Find number of compounds by reading how many columns we have in file1
!
      open(19,file=file1)
      read(19,fmt="(a80)") chemicals
      nchemspectemp=0
      inside=.true.
      do i=1,len_trim(chemicals)
        tmpchar=chemicals(i:i)
        if (tmpchar == ' ') then
          if (.not. inside) then
            inside = .true.
            nchemspectemp=nchemspectemp+1
          endif
        else
          inside=.false.
        endif
      enddo
      if (inside) nchemspectemp=nchemspectemp-1
      close(19)
      if (lroot) print*,'Number of compounds=',nchemspectemp
      if (nchemspectemp>nchemspec) call &
          stop_it("Too many chemicals! Change NCHEMSPEC in src/cparam.local")

!
!  Allocate reaction arrays (but not during reloading!)
!
      if (.not.lreloading) then
        allocate(stoichio(nchemspec,mreactions),STAT=stat)
        if (stat>0) call stop_it("Couldn't allocate memory for stoichio")
        allocate(Sijm(nchemspec,mreactions),STAT=stat)
        if (stat>0) call stop_it("Couldn't allocate memory for Sijm")
        allocate(Sijp(nchemspec,mreactions),STAT=stat)
        if (stat>0) call stop_it("Couldn't allocate memory for Sijp")
        allocate(kreactions_z(mz,mreactions),STAT=stat)
        if (stat>0) call stop_it("Couldn't allocate memory for kreactions_z")
        allocate(kreactions_p(mreactions),STAT=stat)
        if (stat>0) call stop_it("Couldn't allocate memory for kreactions_p")
        allocate(kreactions_m(mreactions),STAT=stat)
        if (stat>0) call stop_it("Couldn't allocate memory for kreactions_m")
        allocate(reaction_name(mreactions),STAT=stat)
        if (stat>0) call stop_it("Couldn't allocate memory for reaction_name")
        allocate(kreactions_profile(mreactions),STAT=stat)
        if (stat>0) call stop_it("Couldn't allocate memory for kreactions_profile")
        allocate(kreactions_profile_width(mreactions),STAT=stat)
        if (stat>0) call stop_it("Couldn't allocate memory for kreactions_profile_width")
        allocate(kreactions_alpha(mreactions),STAT=stat)
        if (stat>0) call stop_it("Couldn't allocate memory for kreactions_alpha")
      endif
!
!  Initialize data
!
      kreactions_z=1.
      Sijp=0
      Sijm=0
!
!  read chemistry data
!
      inquire(file=file1,exist=exist1)
      inquire(file=file2,exist=exist2)
!
      if (exist1.and.exist2) then
!
!  if both chemistry1.dat and chemistry2.dat are present,
!  then read Sijp and Sijm, and calculate their sum
!
!  file1
!
        open(19,file=file1)
        read(19,*) chemicals
        do j=1,mreactions
          read(19,*,end=994) kreactions_m(j),(Sijm(i,j),i=1,nchemspectemp)
        enddo
994     close(19)
        nreactions1=j-1
!
!  file2
!
        open(19,file=file2)
        read(19,*) chemicals
        do j=1,mreactions
          if (lkreactions_profile) then
            if (lkreactions_alpha) then
              read(19,*) kreactions_p(j),(Sijp(i,j),i=1,nchemspectemp),kreactions_profile(j),&
                  kreactions_profile_width(j),kreactions_alpha(j)
            else
              read(19,*) kreactions_p(j),(Sijp(i,j),i=1,nchemspectemp),kreactions_profile(j),&
                  kreactions_profile_width(j)
            endif
          else
            if (lkreactions_alpha) then
              read(19,*) kreactions_p(j),(Sijp(i,j),i=1,nchemspectemp),kreactions_alpha(j)
            else
              read(19,*) kreactions_p(j),(Sijp(i,j),i=1,nchemspectemp)
            endif
          endif
        enddo
        close(19)
        nreactions2=j-1
!
!  calculate stoichio and nreactions
!
        if (nreactions1==nreactions2) then
          nreactions=nreactions1
          stoichio=Sijp-Sijm
        else
          call stop_it('nreactions1/=nreactions2')
        endif
        if (nreactions /= mreactions) call stop_it('nreactions/=mreactions')
!
      else
!
!  old method: read chemistry data, if present
!
        inquire(file='chemistry.dat',exist=exist)
        if (exist) then
          open(19,file='chemistry.dat')
          read(19,*) chemicals
          do j=1,mreactions
            read(19,*,end=990) kreactions_p(j),(stoichio(i,j),i=1,nchemspec)
          enddo
990       close(19)
          nreactions=j-1
          Sijm=-min(stoichio,0)
          Sijp=+max(stoichio,0)
        else
          if (lroot) print*,'no chemistry.dat file to be read.'
          lreactions=.false.
        endif
      endif
!
!  print input data for verification
!
      if (lroot) then
!        print*,'chemicals=',chemicals
        print*,'kreactions_m=',kreactions_m(1:nreactions)
        print*,'kreactions_p=',kreactions_p(1:nreactions)
        print*,'Sijm:'
        do i=1,nreactions
          print*,Sijm(:,i)
        enddo
        print*,'Sijp:'
        do i=1,nreactions
          print*,Sijp(:,i)
        enddo
        print*,'stoichio='
        do i=1,nreactions
          print*,stoichio(:,i)
        enddo
      endif
!
!  possibility of z-dependent kreactions_z profile
!
      if (lkreactions_profile) then
        do j=1,nreactions
          if (kreactions_profile(j)=='cosh') then
            do n=1,mz
              kreactions_z(n,j)=1./cosh(z(n)/kreactions_profile_width(j))**2
            enddo
          elseif (kreactions_profile(j)=='gauss') then
            do n=1,mz
              kreactions_z(n,j)=exp(-((z(n)/kreactions_profile_width(j))**2))
            enddo
          elseif (kreactions_profile(j)=='square') then
            do n=1,mz
              if (n < mz/2) then
                kreactions_z(n,j)=kreactions_profile_width(j)
              else
                kreactions_z(n,j)=0.
              endif
            enddo
          elseif (kreactions_profile(j)=='saw') then
            do n=1,mz
              kreactions_z(n,j)=0.51+(sin(pi*z(n)/kreactions_profile_width(j))&
                  +sin(2*pi*z(n)/kreactions_profile_width(j))/2&
                  +sin(3*pi*z(n)/kreactions_profile_width(j))/3&
                  +sin(4*pi*z(n)/kreactions_profile_width(j))/4)/3
            enddo
          elseif (kreactions_profile(j)=='sin') then
            do n=1,mz
              kreactions_z(n,j)=0.5*(1+cos(pi*z(n)/kreactions_profile_width(j)))
            enddo
          elseif (kreactions_profile(j)=='sin-bg') then
            do n=1,mz
              kreactions_z(n,j)=0.5*(1.1+cos(pi*z(n)/kreactions_profile_width(j)))
            enddo
          elseif (kreactions_profile(j)=='spike') then
            do n=1,mz
              if (cos(pi*z(n)/kreactions_profile_width(j)) > 0.99) then
                kreactions_z(n,j)=1
              else
                kreactions_z(n,j)=0
              endif
            enddo
          endif
        enddo
      endif
!
      call keep_compiler_quiet(f)
!
    endsubroutine astrobiology_data
!***********************************************************************
    subroutine chemkin_data(f)
!
!  if the file with chemkin data exists
!  reading the Chemkin data
!
      character (len=20) :: input_file='chem.inp'
      real, dimension (mx,my,mz,mfarray) :: f
      integer :: stat,k,i
      logical :: tran_exist
      character (len=20) :: input_file2="./data/stoich.out"
      integer :: file_id=123
!
!
      inquire(file='tran.dat',exist=tran_exist)
!
!  Allocate binary diffusion coefficient array
!
      if (.not.lreloading) then
        if (.not. lfix_Sc .and. (.not. lDiff_simple)) then
!NILS: Since Bin_diff_coeff is such a huge array we must check if it
!NILS: required to define it for the full domain!!!!!!
          allocate(Bin_Diff_coef(mx,my,mz,nchemspec,nchemspec),STAT=stat)
          if (stat>0) call stop_it("Couldn't allocate memory "//&
              "for binary diffusion coefficients")
!
          allocate(Diff_full(mx,my,mz,nchemspec),STAT=stat)
          allocate(Diff_full_add(mx,my,mz,nchemspec),STAT=stat)
          if (stat>0) call stop_it("Couldn't allocate memory "//&
              "for binary diffusion coefficients")
!
!
        endif
      endif
!
      if (tran_exist) then
        if (lroot) then
          print*,'tran.dat file with transport data is found.'
        endif
        call read_transport_data
        !call calc_diff_visc_coef(f)
      else
        if (lroot) then
          print*,'tran.dat file with transport data is not found.'
          print*,'Now diffusion coefficients is ',chem_diff
          print*,'Now species viscosity is ',nu_spec
        endif
        Bin_Diff_coef=chem_diff/(unit_length**2/unit_time)
        do k=1,nchemspec
          species_viscosity(:,:,:,k)=nu_spec(k)/&
              (unit_mass/unit_length/unit_time)
        enddo
      endif
!
!  Find number of ractions
!
      call read_reactions(input_file,NrOfReactions=mreactions)
      if (lroot) print*,'Number of reactions=',mreactions
      if (lroot) print*,'Number of species=',nchemspec
      nreactions=mreactions
!
!  Allocate reaction arrays
!
      if (.not.lreloading) then
        allocate(stoichio(nchemspec,mreactions),STAT=stat)
        if (stat>0) call stop_it("Couldn't allocate memory for stoichio")
        allocate(Sijm(nchemspec,mreactions),STAT=stat)
        if (stat>0) call stop_it("Couldn't allocate memory for Sijm")
        allocate(Sijp(nchemspec,mreactions),STAT=stat)
        if (stat>0) call stop_it("Couldn't allocate memory for Sijp")
        allocate(reaction_name(mreactions),STAT=stat)
        if (stat>0) call stop_it("Couldn't allocate memory for reaction_name")
        allocate(B_n(mreactions),STAT=stat)
        if (stat>0) call stop_it("Couldn't allocate memory for B_n")
        B_n=0.
        allocate(alpha_n(mreactions),STAT=stat)
        if (stat>0) call stop_it("Couldn't allocate memory for alpha_n")
        alpha_n=0.
        allocate(E_an(mreactions),STAT=stat)
        if (stat>0) call stop_it("Couldn't allocate memory for E_an")
        E_an=0.
!
        allocate(low_coeff(3,nreactions),STAT=stat)
        low_coeff=0.
        if (stat>0) call stop_it("Couldn't allocate memory for low_coeff")
        allocate(high_coeff(3,nreactions),STAT=stat)
        high_coeff=0.
        if (stat>0) call stop_it("Couldn't allocate memory for high_coeff")
        allocate(troe_coeff(3,nreactions),STAT=stat)
        troe_coeff=0.
        if (stat>0) call stop_it("Couldn't allocate memory for troe_coeff")
        allocate(a_k4(nchemspec,nreactions),STAT=stat)
        a_k4=impossible
        if (stat>0) call stop_it("Couldn't allocate memory for troe_coeff")
        allocate(Mplus_case (nreactions),STAT=stat)
        Mplus_case=.false.
        allocate(photochem_case (nreactions),STAT=stat)
        photochem_case=.false.
        if (stat>0) call stop_it("Couldn't allocate memory for photochem_case")
      endif
!
!  Initialize data
!
      Sijp=0
      Sijm=0
!
!  read chemistry data
!
      call read_reactions(input_file)
      call write_reactions()
!
!  calculate stoichio and nreactions
!
      stoichio=Sijp-Sijm
!
!  print input data for verification
!
      if (lroot .and. nreactions>0) then
!
        open(file_id,file=input_file2,POSITION='rewind',FORM='FORMATTED')
         write(file_id,*) 'STOICHIOMETRIC MATRIX'
!
         write(file_id,*),'Sijm'
         do i=1,nreactions
          write(file_id,100),i,Sijm(:,i)
         enddo
         write(file_id,*),'Sijp:'
         do i=1,nreactions
          write(file_id,100),i,Sijp(:,i)
         enddo
         write(file_id,*),'stoichio='
         do i=1,nreactions
          write(file_id,100),stoichio(:,i)
         enddo
        close(file_id)
      endif
!
100   format(16i4)
!
      call keep_compiler_quiet(f)
!
    endsubroutine chemkin_data
!***********************************************************************
    subroutine dchemistry_dt(f,df,p)
!
!  calculate right hand side of ONE OR MORE extra coupled PDEs
!  along the 'current' Pencil, i.e. f(l1:l2,m,n) where
!  m,n are global variables looped over in equ.f90
!
!  Due to the multi-step Runge Kutta timestepping used one MUST always
!  add to the present contents of the df array.  NEVER reset it to zero.
!
!  several precalculated Pencils of information are passed if for
!  efficiency.
!
!   13-aug-07/steveb: coded
!    8-jan-08/natalia: included advection/diffusion
!   20-feb-08/axel: included reactions
!
      use Diagnostics
      use Sub, only: grad,dot_mn
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (nx,3) :: gchemspec, dk_D
      real, dimension (nx) :: ugchemspec, sum_DYDT
      real, dimension (nx) :: sum_dk_ghk,dk_dhhk,sum_hhk_DYDt_reac
      type (pencil_case) :: p
      real, dimension (nx) :: RHS_T_full
!
!  indices
!
      integer :: j,k,i
      integer :: i1=1,i2=2,i3=3,i4=4,i5=5,i6=6,i7=7,i8=8,i9=9,i10=10
      integer :: i11=11,i12=12,i13=13,i14=14,i15=15,i16=16,i17=17,i18=18,i19=19
!
      intent(in) :: p,f
      intent(inout) :: df
!
!  identify module and boundary conditions
!
      call timing('dchemistry_dt','entered',mnloop=.true.)
      if (headtt.or.ldebug) print*,'dchemistry_dt: SOLVE dchemistry_dt'
!     !if (headtt) call identify_bcs('ss',iss)
!
!  loop over all chemicals
!
!
      do k=1,nchemspec
!
!  advection terms
!
        if (lhydro.and.ladvection) then
          call grad(f,ichemspec(k),gchemspec)
          call dot_mn(p%uu,gchemspec,ugchemspec)
          if (lmobility) ugchemspec=ugchemspec*mobility(k)
          df(l1:l2,m,n,ichemspec(k))=df(l1:l2,m,n,ichemspec(k))-ugchemspec
        endif
!
!  diffusion operator
!
!  Temporary we check the existence of chem.imp data,
!  further one should check the existence of a file with
!  binary diffusion coefficients!
!
        if (ldiffusion) then
          df(l1:l2,m,n,ichemspec(k))=df(l1:l2,m,n,ichemspec(k))+&
              p%DYDt_diff(:,k)
        endif
!
!  chemical reactions:
!  multiply with stoichiometric matrix with reaction speed
!  d/dt(x_i) = S_ij v_j
!
        if (lreactions) then
          df(l1:l2,m,n,ichemspec(k))=df(l1:l2,m,n,ichemspec(k))+&
              p%DYDt_reac(:,k)
        endif 
!
!  Add filter for negative consentrations
!
        if (lfilter .and. .not. lfilter_strict) then
          do i=1,mx
            if ((f(i,m,n,ichemspec(k))+df(i,m,n,ichemspec(k))*dt)<-1e-25 ) df(i,m,n,ichemspec(k))=-1e-25*dt
            if ((f(i,m,n,ichemspec(k))+df(i,m,n,ichemspec(k))*dt)>1. ) df(i,m,n,ichemspec(k))=1.*dt
          enddo
        endif
!
!  Add strict filter for negative consentrations
!
        if (lfilter_strict) then
          do i=1,mx
            if ((f(i,m,n,ichemspec(k))+df(i,m,n,ichemspec(k))*dt)<0.0 ) then
              if (df(i,m,n,ichemspec(k))<0.) df(i,m,n,ichemspec(k))=0.
            endif
            if ((f(i,m,n,ichemspec(k))+df(i,m,n,ichemspec(k))*dt)>1. ) then
              df(i,m,n,ichemspec(k))=1.*dt
            endif
          enddo
        endif
!
    enddo
!
      if (ldensity .and. lcheminp) then
!
       if (l1step_test) then
        sum_DYDt=0.
        do i=1,nx
!
        sum_DYDt(i)=-p%rho(1)*(p%TT(i)-Tinf)*p%TT1(i) &
           *Cp_const/lambda_const*beta*(beta-1.)*f(l1,m,n,iux)**2
!
      !   if (p%TT(i)>Tc) then
      !     if (x(i)>0.) then
!
    !        sum_DYDt(i)=f(l1,m,n,iux)**2*(Tinf-p%TT(i))/p%TT(i) & !(-p%TT(i)+Tinf)
    !        *Cp_const/lambda_const*p%rho(1)*beta*(beta-1.)* &
    !        (1.-f(l1-1+i,m,n,ichemspec(ipr)))
      !   endif
        enddo
       else
        sum_DYDt=0.
        sum_hhk_DYDt_reac=0.
        sum_dk_ghk=0.
!
        do k=1,nchemspec
        if (species_constants(k,imass)>0.) then
          sum_DYDt=sum_DYDt+Rgas/species_constants(k,imass)&
              *(p%DYDt_reac(:,k)+p%DYDt_diff(:,k))
          if (lreactions) then
           sum_hhk_DYDt_reac=sum_hhk_DYDt_reac-p%hhk_full(:,k)*p%DYDt_reac(:,k)
          endif
!
         if (ldiffusion) then
          if (lDiff_simple) then
           do i=1,3
            dk_D(:,i)=(p%gXXk(:,i,k) &
             +(XX_full(l1:l2,m,n,k)-f(l1:l2,m,n,ichemspec(k)))*p%glnpp(:,i)) &
             *p%Diff_penc_add(:,k)
           enddo
          else
           do i=1,3
            dk_D(:,i)=(p%gXXk(:,i,k) &
             +(XX_full(l1:l2,m,n,k)-f(l1:l2,m,n,ichemspec(k)))*p%glnpp(:,i)) &
             *Diff_full_add(l1:l2,m,n,k)
           enddo
          endif
           call dot_mn(dk_D,p%ghhk(:,:,k),dk_dhhk)
           sum_dk_ghk=sum_dk_ghk+dk_dhhk
         endif
!
        endif
        enddo
       endif
!
        if (l1step_test) then
          RHS_T_full=sum_DYDt(:)
        else
          if (ltemperature_nolog) then
           call stop_it('ltemperature_nolog case does not work now!')
          else
            RHS_T_full=(sum_DYDt(:)-Rgas*p%mu1*p%divu)*p%cv1 &
             +sum_dk_ghk*p%TT1(:)*p%cv1+sum_hhk_DYDt_reac*p%TT1(:)*p%cv1
          endif
        endif
!
        if (.not. lT_const) then
         df(l1:l2,m,n,ilnTT) = df(l1:l2,m,n,ilnTT) + RHS_T_full
        endif
!
        if (lheatc_chemistry) call calc_heatcond_chemistry(f,df,p)
!
      endif
!
!  Atmosphere case
!
      if (lcloud) then
!
! commented for the testing. Sould be used later
!
          df(l1:l2,m,n,ichemspec(index_H2O))=df(l1:l2,m,n,ichemspec(index_H2O)) &
              - p%ccondens
          df(l1:l2,m,n,ilnTT) = df(l1:l2,m,n,ilnTT) &
              + 2.5e10/1.005e7*p%ccondens*p%TT1*0.

        do i=1,mx
            if ((f(i,m,n,ichemspec(index_H2O))+df(i,m,n,ichemspec(index_H2O))*dt)>=1. ) &
              df(i,m,n,ichemspec(index_H2O))=0.
            if ((f(i,m,n,ichemspec(index_H2O))+df(i,m,n,ichemspec(index_H2O))*dt)<0. ) &
              df(i,m,n,ichemspec(index_H2O))=0.
        enddo
      endif
!
! this damping zone is needed in a case of NSCBC
!
!
      if (ldamp_zone_for_NSCBC) call damp_zone_for_NSCBC(f,df)
!      if (ldamp_zone_NSCBCy) call damp_zone_for_NSCBC(f,df,2)
!      if (ldamp_zone_NSCBCz) call damp_zone_for_NSCBC(f,df,3)
!
!  For the timestep calculation, need maximum diffusion
!
      if (lfirst.and. ldt) then
        if (.not. lcheminp) then
          diffus_chem=chem_diff*maxval(chem_diff_prefactor)*dxyz_2
        else
          do j=1,nx
            if (ldiffusion .and. .not. ldiff_simple) then
!
!--------------------------------------
!  This expression should be discussed
!--------------------------------------
!
              diffus_chem(j)=diffus_chem(j)+&
                  maxval(Diff_full(l1+j-1,m,n,1:nchemspec))*dxyz_2(j)
            else
              diffus_chem(j)=0.
            endif
          enddo
        endif
      endif
!
! NB: it should be discussed
!
      if (lfirst .and. ldt) then
        if (lreactions) then
!
!  calculate maximum of *relative* reaction rate if decaying,
!  or maximum of absolute rate, if growing.
!
          if (lchem_cdtc) then
            reac_chem=0.
            do k=1,nchemspec
              reac_chem=max(reac_chem, &
                  abs(p%DYDt_reac(:,k)/max(f(l1:l2,m,n,ichemspec(k)),.001)))
            enddo
!
          elseif (lcheminp) then
            reac_chem=0.
            !sum_reac_rate=0.
            do k=1,nchemspec
              reac_chem=reac_chem+abs(p%DYDt_reac(:,k)/f(l1:l2,m,n,ichemspec(k)))
              !sum_reac_rate=sum_reac_rate+p%DYDt_reac(:,k)
            enddo
            if (maxval(reac_chem)>1e11) then
              reac_chem=1e11
            endif
          endif
        endif
      endif
!
!  Calculate diagnostic quantities
!
      call timing('dchemistry_dt','before ldiagnos',mnloop=.true.)
      if (ldiagnos) then
!
!  WL: instead of hardcoding Y1-Y9, wouldn't it be possible
!      to have them all in the same array? The particles_nbody
!      module, for instance, has idiag_xxspar and idiag_vvspar, which
!      allows the user to add output the positions and velocities
!      of as many particle he/she wants.
!  RP: Totally agree... I still have to expand manually these hard-coded
!       Y1-Y9 and chemspec-chemspec9 when needed, but this is just work-around...
!
        if (idiag_Y1m/=0) call sum_mn_name(f(l1:l2,m,n,ichemspec(i1)),idiag_Y1m)
        if (idiag_Y2m/=0) call sum_mn_name(f(l1:l2,m,n,ichemspec(i2)),idiag_Y2m)
        if (idiag_Y3m/=0) call sum_mn_name(f(l1:l2,m,n,ichemspec(i3)),idiag_Y3m)
        if (idiag_Y4m/=0) call sum_mn_name(f(l1:l2,m,n,ichemspec(i4)),idiag_Y4m)
        if (idiag_Y5m/=0) call sum_mn_name(f(l1:l2,m,n,ichemspec(i5)),idiag_Y5m)
        if (idiag_Y6m/=0) call sum_mn_name(f(l1:l2,m,n,ichemspec(i6)),idiag_Y6m)
        if (idiag_Y7m/=0) call sum_mn_name(f(l1:l2,m,n,ichemspec(i7)),idiag_Y7m)
        if (idiag_Y8m/=0) call sum_mn_name(f(l1:l2,m,n,ichemspec(i8)),idiag_Y8m)
        if (idiag_Y9m/=0) call sum_mn_name(f(l1:l2,m,n,ichemspec(i9)),idiag_Y9m)
        if (idiag_Y10m/=0) call sum_mn_name(f(l1:l2,m,n,ichemspec(i10)),idiag_Y10m)
        if (idiag_Y11m/=0) call sum_mn_name(f(l1:l2,m,n,ichemspec(i11)),idiag_Y11m)
        if (idiag_Y12m/=0) call sum_mn_name(f(l1:l2,m,n,ichemspec(i12)),idiag_Y12m)
        if (idiag_Y13m/=0) call sum_mn_name(f(l1:l2,m,n,ichemspec(i13)),idiag_Y13m)
        if (idiag_Y14m/=0) call sum_mn_name(f(l1:l2,m,n,ichemspec(i14)),idiag_Y14m)
        if (idiag_Y15m/=0) call sum_mn_name(f(l1:l2,m,n,ichemspec(i15)),idiag_Y15m)
        if (idiag_Y16m/=0) call sum_mn_name(f(l1:l2,m,n,ichemspec(i16)),idiag_Y16m)
        if (idiag_Y17m/=0) call sum_mn_name(f(l1:l2,m,n,ichemspec(i17)),idiag_Y17m)
        if (idiag_Y18m/=0) call sum_mn_name(f(l1:l2,m,n,ichemspec(i18)),idiag_Y18m)
        if (idiag_Y19m/=0) call sum_mn_name(f(l1:l2,m,n,ichemspec(i19)),idiag_Y19m)
!
        if (idiag_cpfull/=0) call sum_mn_name(cp_full(l1:l2,m,n),idiag_cpfull)
        if (idiag_cvfull/=0) call sum_mn_name(cv_full(l1:l2,m,n),idiag_cvfull)
!
        if (idiag_lambdam/=0) call sum_mn_name(lambda_full(l1:l2,m,n),&
                             idiag_lambdam)
        if (idiag_num/=0) call sum_mn_name(nu_full(l1:l2,m,n),&
                             idiag_num)
        if (idiag_diff1m/=0) call sum_mn_name(diff_full(l1:l2,m,n,i1),&
                             idiag_diff1m)
        if (idiag_diff2m/=0) call sum_mn_name(diff_full(l1:l2,m,n,i2),&
                             idiag_diff2m)
        if (idiag_diff3m/=0) call sum_mn_name(diff_full(l1:l2,m,n,i3),&
                             idiag_diff3m)
        if (idiag_diff4m/=0) call sum_mn_name(diff_full(l1:l2,m,n,i4),&
                             idiag_diff4m)
        if (idiag_diff5m/=0) call sum_mn_name(diff_full(l1:l2,m,n,i5),&
                             idiag_diff5m)
        if (idiag_diff6m/=0) call sum_mn_name(diff_full(l1:l2,m,n,i6),&
                             idiag_diff6m)
        if (idiag_diff7m/=0) call sum_mn_name(diff_full(l1:l2,m,n,i7),&
                             idiag_diff7m)
        if (idiag_diff8m/=0) call sum_mn_name(diff_full(l1:l2,m,n,i8),&
                             idiag_diff8m)
        if (idiag_diff9m/=0) call sum_mn_name(diff_full(l1:l2,m,n,i9),&
                             idiag_diff9m)
        if (idiag_diff10m/=0) call sum_mn_name(diff_full(l1:l2,m,n,i10),&
                             idiag_diff10m)
        if (idiag_diff11m/=0) call sum_mn_name(diff_full(l1:l2,m,n,i11),&
                             idiag_diff11m)
        if (idiag_diff12m/=0) call sum_mn_name(diff_full(l1:l2,m,n,i12),&
                             idiag_diff12m)
        if (idiag_diff13m/=0) call sum_mn_name(diff_full(l1:l2,m,n,i13),&
                             idiag_diff13m)
        if (idiag_diff14m/=0) call sum_mn_name(diff_full(l1:l2,m,n,i14),&
                             idiag_diff14m)
        if (idiag_diff15m/=0) call sum_mn_name(diff_full(l1:l2,m,n,i15),&
                             idiag_diff15m)
        if (idiag_diff16m/=0) call sum_mn_name(diff_full(l1:l2,m,n,i16),&
                             idiag_diff16m)
        if (idiag_diff17m/=0) call sum_mn_name(diff_full(l1:l2,m,n,i17),&
                             idiag_diff17m)
        if (idiag_diff18m/=0) call sum_mn_name(diff_full(l1:l2,m,n,i18),&
                             idiag_diff18m)
        if (idiag_diff19m/=0) call sum_mn_name(diff_full(l1:l2,m,n,i19),&
                             idiag_diff19m)
!
      endif
!
!  1d-averages. Happens at every it1d timesteps, NOT at every it1
!
      if (l1davgfirst) then
        if (idiag_Y1mz/=0) call xysum_mn_name_z(f(l1:l2,m,n,ichemspec(i1)),idiag_Y1mz)
        if (idiag_Y2mz/=0) call xysum_mn_name_z(f(l1:l2,m,n,ichemspec(i2)),idiag_Y2mz)
        if (idiag_Y3mz/=0) call xysum_mn_name_z(f(l1:l2,m,n,ichemspec(i3)),idiag_Y3mz)
        if (idiag_Y4mz/=0) call xysum_mn_name_z(f(l1:l2,m,n,ichemspec(i4)),idiag_Y4mz)
        if (idiag_Y5mz/=0) call xysum_mn_name_z(f(l1:l2,m,n,ichemspec(i5)),idiag_Y5mz)
        if (idiag_Y6mz/=0) call xysum_mn_name_z(f(l1:l2,m,n,ichemspec(i6)),idiag_Y6mz)
        if (idiag_Y7mz/=0) call xysum_mn_name_z(f(l1:l2,m,n,ichemspec(i7)),idiag_Y7mz)
        if (idiag_Y8mz/=0) call xysum_mn_name_z(f(l1:l2,m,n,ichemspec(i8)),idiag_Y8mz)
        if (idiag_Y9mz/=0) call xysum_mn_name_z(f(l1:l2,m,n,ichemspec(i9)),idiag_Y9mz)
        if (idiag_Y10mz/=0) call xysum_mn_name_z(f(l1:l2,m,n,ichemspec(i10)),idiag_Y10mz)
        if (idiag_Y11mz/=0) call xysum_mn_name_z(f(l1:l2,m,n,ichemspec(i11)),idiag_Y11mz)
        if (idiag_Y12mz/=0) call xysum_mn_name_z(f(l1:l2,m,n,ichemspec(i12)),idiag_Y12mz)
        if (idiag_Y13mz/=0) call xysum_mn_name_z(f(l1:l2,m,n,ichemspec(i13)),idiag_Y13mz)
        if (idiag_Y14mz/=0) call xysum_mn_name_z(f(l1:l2,m,n,ichemspec(i14)),idiag_Y14mz)
        if (idiag_Y15mz/=0) call xysum_mn_name_z(f(l1:l2,m,n,ichemspec(i15)),idiag_Y15mz)
        if (idiag_Y16mz/=0) call xysum_mn_name_z(f(l1:l2,m,n,ichemspec(i16)),idiag_Y16mz)
        if (idiag_Y17mz/=0) call xysum_mn_name_z(f(l1:l2,m,n,ichemspec(i17)),idiag_Y17mz)
        if (idiag_Y18mz/=0) call xysum_mn_name_z(f(l1:l2,m,n,ichemspec(i18)),idiag_Y18mz)
        if (idiag_Y19mz/=0) call xysum_mn_name_z(f(l1:l2,m,n,ichemspec(i19)),idiag_Y19mz)
      endif
      call timing('dchemistry_dt','finished',mnloop=.true.)
!
    endsubroutine dchemistry_dt
!***********************************************************************
    subroutine read_chemistry_init_pars(unit,iostat)
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (present(iostat)) then
        read(unit,NML=chemistry_init_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=chemistry_init_pars,ERR=99)
      endif
!
99    return
    endsubroutine read_chemistry_init_pars
!***********************************************************************
   subroutine write_chemistry_init_pars(unit)
!
      integer, intent(in) :: unit
!
      write(unit,NML=chemistry_init_pars)
!
    endsubroutine write_chemistry_init_pars
!***********************************************************************
    subroutine read_chemistry_run_pars(unit,iostat)
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (present(iostat)) then
        read(unit,NML=chemistry_run_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=chemistry_run_pars,ERR=99)
      endif
!
99    return
    endsubroutine read_chemistry_run_pars
!***********************************************************************
    subroutine write_chemistry_run_pars(unit)
!
      integer, intent(in) :: unit
!
      write(unit,NML=chemistry_run_pars)
!
    endsubroutine write_chemistry_run_pars
!***********************************************************************
    subroutine rprint_chemistry(lreset,lwrite)
!
!  reads and registers print parameters relevant to chemistry
!
!  13-aug-07/steveb: coded
!
      use Diagnostics, only: parse_name
      use General, only: chn
!
      integer :: iname,inamez
      logical :: lreset,lwr
      logical, optional :: lwrite
      character (len=5) :: schemspec,snd1
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
!  reset everything in case of reset
!  (this needs to be consistent with what is defined above!)
!
      if (lreset) then
        idiag_Y1m=0; idiag_Y2m=0; idiag_Y3m=0; idiag_Y4m=0
        idiag_Y5m=0; idiag_Y6m=0; idiag_Y7m=0; idiag_Y8m=0
        idiag_Y9m=0; idiag_Y10m=0; idiag_Y11m=0; idiag_Y12m=0
        idiag_Y13m=0; idiag_Y14m=0; idiag_Y15m=0; idiag_Y16m=0
        idiag_Y17m=0; idiag_Y18m=0; idiag_Y19m=0
        idiag_dY1m=0; idiag_dY2m=0; idiag_dY3m=0; idiag_dY4m=0
        idiag_dY5m=0; idiag_dY6m=0; idiag_dY7m=0; idiag_dY8m=0
        idiag_dY9m=0; idiag_dY10m=0; idiag_dY11m=0; idiag_dY12m=0
        idiag_dY13m=0; idiag_dY14m=0; idiag_dY15m=0; idiag_dY16m=0
        idiag_dY17m=0; idiag_dY18m=0; idiag_dY19m=0
        idiag_h1m=0; idiag_h2m=0; idiag_h3m=0; idiag_h4m=0;
        idiag_h5m=0; idiag_h6m=0; idiag_h7m=0; idiag_h8m=0;
        idiag_h9m=0; idiag_h10m=0; idiag_h11m=0; idiag_h12m=0;
        idiag_h13m=0; idiag_h14m=0; idiag_h15m=0; idiag_h16m=0;
        idiag_h17m=0; idiag_h18m=0; idiag_h19m=0;
        idiag_cp1m=0; idiag_cp2m=0; idiag_cp3m=0; idiag_cp4m=0;
        idiag_cp5m=0; idiag_cp6m=0; idiag_cp7m=0; idiag_cp8m=0;
        idiag_cp9m=0; idiag_cp10m=0; idiag_cp11m=0; idiag_cp12m=0;
        idiag_cp13m=0; idiag_cp14m=0; idiag_cp15m=0; idiag_cp16m=0;
        idiag_cp17m=0; idiag_cp18m=0; idiag_cp19m=0;
        idiag_cpfull=0; idiag_cvfull=0
        idiag_e_intm=0
        idiag_Y1mz=0; idiag_Y2mz=0; idiag_Y3mz=0; idiag_Y4mz=0
        idiag_Y5mz=0; idiag_Y6mz=0; idiag_Y7mz=0; idiag_Y8mz=0
        idiag_Y9mz=0; idiag_Y10mz=0; idiag_Y11mz=0; idiag_Y12mz=0
        idiag_Y13mz=0; idiag_Y14mz=0; idiag_Y15mz=0; idiag_Y16mz=0
        idiag_Y17mz=0; idiag_Y18mz=0; idiag_Y19mz=0
!
        idiag_diff1m=0; idiag_diff2m=0; idiag_diff3m=0; idiag_diff4m=0;
        idiag_diff5m=0; idiag_diff6m=0; idiag_diff7m=0; idiag_diff8m=0;
        idiag_diff9m=0; idiag_diff10m=0; idiag_diff11m=0; idiag_diff12m=0;
        idiag_diff13m=0; idiag_diff14m=0; idiag_diff15m=0; idiag_diff16m=0;
        idiag_diff17m=0; idiag_diff18m=0; idiag_diff19m=0;
        idiag_lambdam=0; idiag_num=0
!
      endif
!
      call chn(nchemspec,schemspec)
!
!  check for those quantities that we want to evaluate online
!
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'Y1m',idiag_Y1m)
        call parse_name(iname,cname(iname),cform(iname),'Y2m',idiag_Y2m)
        call parse_name(iname,cname(iname),cform(iname),'Y3m',idiag_Y3m)
        call parse_name(iname,cname(iname),cform(iname),'Y4m',idiag_Y4m)
        call parse_name(iname,cname(iname),cform(iname),'Y5m',idiag_Y5m)
        call parse_name(iname,cname(iname),cform(iname),'Y6m',idiag_Y6m)
        call parse_name(iname,cname(iname),cform(iname),'Y7m',idiag_Y7m)
        call parse_name(iname,cname(iname),cform(iname),'Y8m',idiag_Y8m)
        call parse_name(iname,cname(iname),cform(iname),'Y9m',idiag_Y9m)
        call parse_name(iname,cname(iname),cform(iname),'Y10m',idiag_Y10m)
        call parse_name(iname,cname(iname),cform(iname),'Y11m',idiag_Y11m)
        call parse_name(iname,cname(iname),cform(iname),'Y12m',idiag_Y12m)
        call parse_name(iname,cname(iname),cform(iname),'Y13m',idiag_Y13m)
        call parse_name(iname,cname(iname),cform(iname),'Y14m',idiag_Y14m)
        call parse_name(iname,cname(iname),cform(iname),'Y15m',idiag_Y15m)
        call parse_name(iname,cname(iname),cform(iname),'Y16m',idiag_Y16m)
        call parse_name(iname,cname(iname),cform(iname),'Y17m',idiag_Y17m)
        call parse_name(iname,cname(iname),cform(iname),'Y18m',idiag_Y18m)
        call parse_name(iname,cname(iname),cform(iname),'Y19m',idiag_Y19m)
        call parse_name(iname,cname(iname),cform(iname),'dY1m',idiag_dY1m)
        call parse_name(iname,cname(iname),cform(iname),'dY2m',idiag_dY2m)
        call parse_name(iname,cname(iname),cform(iname),'dY3m',idiag_dY3m)
        call parse_name(iname,cname(iname),cform(iname),'dY4m',idiag_dY4m)
        call parse_name(iname,cname(iname),cform(iname),'dY5m',idiag_dY5m)
        call parse_name(iname,cname(iname),cform(iname),'dY6m',idiag_dY6m)
        call parse_name(iname,cname(iname),cform(iname),'dY7m',idiag_dY7m)
        call parse_name(iname,cname(iname),cform(iname),'dY8m',idiag_dY8m)
        call parse_name(iname,cname(iname),cform(iname),'dY9m',idiag_dY9m)
        call parse_name(iname,cname(iname),cform(iname),'dY10m',idiag_dY10m)
        call parse_name(iname,cname(iname),cform(iname),'dY11m',idiag_dY11m)
        call parse_name(iname,cname(iname),cform(iname),'dY12m',idiag_dY12m)
        call parse_name(iname,cname(iname),cform(iname),'dY13m',idiag_dY13m)
        call parse_name(iname,cname(iname),cform(iname),'dY14m',idiag_dY14m)
        call parse_name(iname,cname(iname),cform(iname),'dY15m',idiag_dY15m)
        call parse_name(iname,cname(iname),cform(iname),'dY16m',idiag_dY16m)
        call parse_name(iname,cname(iname),cform(iname),'dY17m',idiag_dY17m)
        call parse_name(iname,cname(iname),cform(iname),'dY18m',idiag_dY18m)
        call parse_name(iname,cname(iname),cform(iname),'dY19m',idiag_dY19m)
        call parse_name(iname,cname(iname),cform(iname),'h1m',idiag_h1m)
        call parse_name(iname,cname(iname),cform(iname),'h2m',idiag_h2m)
        call parse_name(iname,cname(iname),cform(iname),'h3m',idiag_h3m)
        call parse_name(iname,cname(iname),cform(iname),'h4m',idiag_h4m)
        call parse_name(iname,cname(iname),cform(iname),'h5m',idiag_h5m)
        call parse_name(iname,cname(iname),cform(iname),'h6m',idiag_h6m)
        call parse_name(iname,cname(iname),cform(iname),'h7m',idiag_h7m)
        call parse_name(iname,cname(iname),cform(iname),'h8m',idiag_h8m)
        call parse_name(iname,cname(iname),cform(iname),'h9m',idiag_h9m)
        call parse_name(iname,cname(iname),cform(iname),'h10m',idiag_h10m)
        call parse_name(iname,cname(iname),cform(iname),'h11m',idiag_h11m)
        call parse_name(iname,cname(iname),cform(iname),'h12m',idiag_h12m)
        call parse_name(iname,cname(iname),cform(iname),'h13m',idiag_h13m)
        call parse_name(iname,cname(iname),cform(iname),'h14m',idiag_h14m)
        call parse_name(iname,cname(iname),cform(iname),'h15m',idiag_h15m)
        call parse_name(iname,cname(iname),cform(iname),'h16m',idiag_h16m)
        call parse_name(iname,cname(iname),cform(iname),'h17m',idiag_h17m)
        call parse_name(iname,cname(iname),cform(iname),'h18m',idiag_h18m)
        call parse_name(iname,cname(iname),cform(iname),'h19m',idiag_h19m)
        call parse_name(iname,cname(iname),cform(iname),'cpfull',idiag_cpfull)
        call parse_name(iname,cname(iname),cform(iname),'cvfull',idiag_cvfull)
        call parse_name(iname,cname(iname),cform(iname),'cp1m',idiag_cp1m)
        call parse_name(iname,cname(iname),cform(iname),'cp2m',idiag_cp2m)
        call parse_name(iname,cname(iname),cform(iname),'cp3m',idiag_cp3m)
        call parse_name(iname,cname(iname),cform(iname),'cp4m',idiag_cp4m)
        call parse_name(iname,cname(iname),cform(iname),'cp5m',idiag_cp5m)
        call parse_name(iname,cname(iname),cform(iname),'cp6m',idiag_cp6m)
        call parse_name(iname,cname(iname),cform(iname),'cp7m',idiag_cp7m)
        call parse_name(iname,cname(iname),cform(iname),'cp8m',idiag_cp8m)
        call parse_name(iname,cname(iname),cform(iname),'cp9m',idiag_cp9m)
        call parse_name(iname,cname(iname),cform(iname),'cp10m',idiag_cp10m)
        call parse_name(iname,cname(iname),cform(iname),'cp11m',idiag_cp11m)
        call parse_name(iname,cname(iname),cform(iname),'cp12m',idiag_cp12m)
        call parse_name(iname,cname(iname),cform(iname),'cp13m',idiag_cp13m)
        call parse_name(iname,cname(iname),cform(iname),'cp14m',idiag_cp14m)
        call parse_name(iname,cname(iname),cform(iname),'cp15m',idiag_cp15m)
        call parse_name(iname,cname(iname),cform(iname),'cp16m',idiag_cp16m)
        call parse_name(iname,cname(iname),cform(iname),'cp17m',idiag_cp17m)
        call parse_name(iname,cname(iname),cform(iname),'cp18m',idiag_cp18m)
        call parse_name(iname,cname(iname),cform(iname),'cp19m',idiag_cp19m)
        call parse_name(iname,cname(iname),cform(iname),'e_intm',idiag_e_intm)
        call parse_name(iname,cname(iname),cform(iname),'lambdam',idiag_lambdam)
        call parse_name(iname,cname(iname),cform(iname),'num',idiag_num)
        call parse_name(iname,cname(iname),cform(iname),'diff1m',idiag_diff1m)
        call parse_name(iname,cname(iname),cform(iname),'diff2m',idiag_diff2m)
        call parse_name(iname,cname(iname),cform(iname),'diff3m',idiag_diff3m)
        call parse_name(iname,cname(iname),cform(iname),'diff4m',idiag_diff4m)
        call parse_name(iname,cname(iname),cform(iname),'diff5m',idiag_diff5m)
        call parse_name(iname,cname(iname),cform(iname),'diff6m',idiag_diff6m)
        call parse_name(iname,cname(iname),cform(iname),'diff7m',idiag_diff7m)
        call parse_name(iname,cname(iname),cform(iname),'diff8m',idiag_diff8m)
        call parse_name(iname,cname(iname),cform(iname),'diff9m',idiag_diff9m)
        call parse_name(iname,cname(iname),cform(iname),'diff10m',idiag_diff10m)
        call parse_name(iname,cname(iname),cform(iname),'diff11m',idiag_diff11m)
        call parse_name(iname,cname(iname),cform(iname),'diff12m',idiag_diff12m)
        call parse_name(iname,cname(iname),cform(iname),'diff13m',idiag_diff13m)
        call parse_name(iname,cname(iname),cform(iname),'diff14m',idiag_diff14m)
        call parse_name(iname,cname(iname),cform(iname),'diff15m',idiag_diff15m)
        call parse_name(iname,cname(iname),cform(iname),'diff16m',idiag_diff16m)
        call parse_name(iname,cname(iname),cform(iname),'diff17m',idiag_diff17m)
        call parse_name(iname,cname(iname),cform(iname),'diff18m',idiag_diff18m)
        call parse_name(iname,cname(iname),cform(iname),'diff19m',idiag_diff19m)
      enddo
!
!  xy-averages
!
      do inamez=1,nnamez
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Y1mz',idiag_Y1mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Y2mz',idiag_Y2mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Y3mz',idiag_Y3mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Y4mz',idiag_Y4mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Y5mz',idiag_Y5mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Y6mz',idiag_Y6mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Y7mz',idiag_Y7mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Y8mz',idiag_Y8mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Y9mz',idiag_Y9mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Y10mz',idiag_Y10mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Y11mz',idiag_Y11mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Y12mz',idiag_Y12mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Y13mz',idiag_Y13mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Y14mz',idiag_Y14mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Y15mz',idiag_Y15mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Y16mz',idiag_Y16mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Y17mz',idiag_Y17mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Y18mz',idiag_Y18mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Y19mz',idiag_Y19mz)
      enddo
!
!  Write chemistry index in short notation
!
      call chn(ichemspec(1),snd1)
      if (lwr) then
        write(3,*) 'ichemspec=indgen('//trim(schemspec)//') + '//trim(snd1)
        write(3,*) 'nchemspec=',nchemspec
      endif
!
    endsubroutine rprint_chemistry
!***********************************************************************
    subroutine get_slices_chemistry(f,slices)
!
!  Write slices for animation of Chemistry variables.
!
!  13-aug-07/steveb: dummy
!  16-may-09/raphael: added more slices
!
      real, dimension (mx,my,mz,mfarray) :: f
      integer :: i1=1,i2=2,i3=3,i4=4,i5=5,i6=6,i7=7,i8=8,i9=9, i10=10
      integer :: i11=11,i12=12,i13=13,i14=14,i15=15,i16=16,i17=17,i18=18,i19=19
      type (slice_data) :: slices
!
!  Loop over slices
!
      select case (trim(slices%name))
!
!  Chemical species mass fractions.
!
        case ('chemspec')
          slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,ichemspec(i1))
          slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,ichemspec(i1))
          slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,ichemspec(i1))
          slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,ichemspec(i1))
          if (lwrite_slice_xy3) &
          slices%xy3=f(l1:l2 ,m1:m2 ,iz3_loc,ichemspec(i1))
          if (lwrite_slice_xy4) &
          slices%xy4=f(l1:l2 ,m1:m2 ,iz4_loc,ichemspec(i1))
          slices%ready=.true.
        case ('chemspec2')
          slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,ichemspec(i2))
          slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,ichemspec(i2))
          slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,ichemspec(i2))
          slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,ichemspec(i2))
          if (lwrite_slice_xy3) &
          slices%xy3=f(l1:l2 ,m1:m2 ,iz3_loc,ichemspec(i2))
          if (lwrite_slice_xy4) &
          slices%xy4=f(l1:l2 ,m1:m2 ,iz4_loc,ichemspec(i2))
          slices%ready=.true.
        case ('chemspec3')
          slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,ichemspec(i3))
          slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,ichemspec(i3))
          slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,ichemspec(i3))
          slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,ichemspec(i3))
          if (lwrite_slice_xy3) &
          slices%xy3=f(l1:l2 ,m1:m2 ,iz3_loc,ichemspec(i3))
          if (lwrite_slice_xy4) &
          slices%xy4=f(l1:l2 ,m1:m2 ,iz4_loc,ichemspec(i3))
          slices%ready=.true.
        case ('chemspec4')
          slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,ichemspec(i4))
          slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,ichemspec(i4))
          slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,ichemspec(i4))
          slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,ichemspec(i4))
          if (lwrite_slice_xy3) &
          slices%xy3=f(l1:l2 ,m1:m2 ,iz3_loc,ichemspec(i4))
          if (lwrite_slice_xy4) &
          slices%xy4=f(l1:l2 ,m1:m2 ,iz4_loc,ichemspec(i4))
          slices%ready=.true.
        case ('chemspec5')
          slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,ichemspec(i5))
          slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,ichemspec(i5))
          slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,ichemspec(i5))
          slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,ichemspec(i5))
          if (lwrite_slice_xy3) &
          slices%xy3=f(l1:l2 ,m1:m2 ,iz3_loc,ichemspec(i5))
          if (lwrite_slice_xy4) &
          slices%xy4=f(l1:l2 ,m1:m2 ,iz4_loc,ichemspec(i5))
          slices%ready=.true.
        case ('chemspec6')
          slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,ichemspec(i6))
          slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,ichemspec(i6))
          slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,ichemspec(i6))
          slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,ichemspec(i6))
          if (lwrite_slice_xy3) &
          slices%xy3=f(l1:l2 ,m1:m2 ,iz3_loc,ichemspec(i6))
          if (lwrite_slice_xy4) &
          slices%xy4=f(l1:l2 ,m1:m2 ,iz4_loc,ichemspec(i6))
          slices%ready=.true.
        case ('chemspec7')
          slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,ichemspec(i7))
          slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,ichemspec(i7))
          slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,ichemspec(i7))
          slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,ichemspec(i7))
          if (lwrite_slice_xy3) &
          slices%xy3=f(l1:l2 ,m1:m2 ,iz3_loc,ichemspec(i7))
          if (lwrite_slice_xy4) &
          slices%xy4=f(l1:l2 ,m1:m2 ,iz4_loc,ichemspec(i7))
          slices%ready=.true.
        case ('chemspec8')
          slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,ichemspec(i8))
          slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,ichemspec(i8))
          slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,ichemspec(i8))
          slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,ichemspec(i8))
          if (lwrite_slice_xy3) &
          slices%xy3=f(l1:l2 ,m1:m2 ,iz3_loc,ichemspec(i8))
          if (lwrite_slice_xy4) &
          slices%xy4=f(l1:l2 ,m1:m2 ,iz4_loc,ichemspec(i8))
          slices%ready=.true.
        case ('chemspec9')
          slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,ichemspec(i9))
          slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,ichemspec(i9))
          slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,ichemspec(i9))
          slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,ichemspec(i9))
          if (lwrite_slice_xy3) &
          slices%xy3=f(l1:l2 ,m1:m2 ,iz3_loc,ichemspec(i9))
          if (lwrite_slice_xy4) &
          slices%xy4=f(l1:l2 ,m1:m2 ,iz4_loc,ichemspec(i9))
          slices%ready=.true.
        case ('chemspec10')
          slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,ichemspec(i10))
          slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,ichemspec(i10))
          slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,ichemspec(i10))
          slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,ichemspec(i10))
          if (lwrite_slice_xy3) &
          slices%xy3=f(l1:l2 ,m1:m2 ,iz3_loc,ichemspec(i10))
          if (lwrite_slice_xy4) &
          slices%xy4=f(l1:l2 ,m1:m2 ,iz4_loc,ichemspec(i10))
          slices%ready=.true.
        case ('chemspec11')
          slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,ichemspec(i11))
          slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,ichemspec(i11))
          slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,ichemspec(i11))
          slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,ichemspec(i11))
          if (lwrite_slice_xy3) &
          slices%xy3=f(l1:l2 ,m1:m2 ,iz3_loc,ichemspec(i11))
          if (lwrite_slice_xy4) &
          slices%xy4=f(l1:l2 ,m1:m2 ,iz4_loc,ichemspec(i11))
          slices%ready=.true.
        case ('chemspec12')
          slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,ichemspec(i12))
          slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,ichemspec(i12))
          slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,ichemspec(i12))
          slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,ichemspec(i12))
          if (lwrite_slice_xy3) &
          slices%xy3=f(l1:l2 ,m1:m2 ,iz3_loc,ichemspec(i12))
          if (lwrite_slice_xy4) &
          slices%xy4=f(l1:l2 ,m1:m2 ,iz4_loc,ichemspec(i12))
          slices%ready=.true.
        case ('chemspec13')
          slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,ichemspec(i13))
          slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,ichemspec(i13))
          slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,ichemspec(i13))
          slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,ichemspec(i13))
          if (lwrite_slice_xy3) &
          slices%xy3=f(l1:l2 ,m1:m2 ,iz3_loc,ichemspec(i13))
          if (lwrite_slice_xy4) &
          slices%xy4=f(l1:l2 ,m1:m2 ,iz4_loc,ichemspec(i13))
          slices%ready=.true.
        case ('chemspec14')
          slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,ichemspec(i14))
          slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,ichemspec(i14))
          slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,ichemspec(i14))
          slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,ichemspec(i14))
          if (lwrite_slice_xy3) &
          slices%xy3=f(l1:l2 ,m1:m2 ,iz3_loc,ichemspec(i14))
          if (lwrite_slice_xy4) &
          slices%xy4=f(l1:l2 ,m1:m2 ,iz4_loc,ichemspec(i14))
          slices%ready=.true.
        case ('chemspec15')
          slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,ichemspec(i15))
          slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,ichemspec(i15))
          slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,ichemspec(i15))
          slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,ichemspec(i15))
          if (lwrite_slice_xy3) &
          slices%xy3=f(l1:l2 ,m1:m2 ,iz3_loc,ichemspec(i15))
          if (lwrite_slice_xy4) &
          slices%xy4=f(l1:l2 ,m1:m2 ,iz4_loc,ichemspec(i15))
          slices%ready=.true.
        case ('chemspec16')
          slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,ichemspec(i16))
          slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,ichemspec(i16))
          slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,ichemspec(i16))
          slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,ichemspec(i16))
          if (lwrite_slice_xy3) &
          slices%xy3=f(l1:l2 ,m1:m2 ,iz3_loc,ichemspec(i16))
          if (lwrite_slice_xy4) &
          slices%xy4=f(l1:l2 ,m1:m2 ,iz4_loc,ichemspec(i16))
          slices%ready=.true.
        case ('chemspec17')
          slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,ichemspec(i17))
          slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,ichemspec(i17))
          slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,ichemspec(i17))
          slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,ichemspec(i17))
          if (lwrite_slice_xy3) &
          slices%xy3=f(l1:l2 ,m1:m2 ,iz3_loc,ichemspec(i17))
          if (lwrite_slice_xy4) &
          slices%xy4=f(l1:l2 ,m1:m2 ,iz4_loc,ichemspec(i17))
          slices%ready=.true.
        case ('chemspec18')
          slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,ichemspec(i18))
          slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,ichemspec(i18))
          slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,ichemspec(i18))
          slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,ichemspec(i18))
          if (lwrite_slice_xy3) &
          slices%xy3=f(l1:l2 ,m1:m2 ,iz3_loc,ichemspec(i18))
          if (lwrite_slice_xy4) &
          slices%xy4=f(l1:l2 ,m1:m2 ,iz4_loc,ichemspec(i18))
          slices%ready=.true.
        case ('chemspec19')
          slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,ichemspec(i19))
          slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,ichemspec(i19))
          slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,ichemspec(i19))
          slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,ichemspec(i19))
          if (lwrite_slice_xy3) &
          slices%xy3=f(l1:l2 ,m1:m2 ,iz3_loc,ichemspec(i19))
          if (lwrite_slice_xy4) &
          slices%xy4=f(l1:l2 ,m1:m2 ,iz4_loc,ichemspec(i19))
          slices%ready=.true.
      endselect
!
    endsubroutine get_slices_chemistry
!***********************************************************************
    subroutine read_reactions(input_file,NrOfReactions)
!
!  This subroutine reads all reaction information from chem.inp
!  See the chemkin manual for more information on
!  the syntax of chem.inp.
!
!  10-mar-08/nils: coded
!
      logical :: IsReaction=.false.,found_new_reaction=.false.
      logical, save :: find_specie, found_specie
      integer, optional :: NrOfReactions
      integer, save :: ind_glob, ind_chem
      integer :: i,k,file_id=123, StartInd, StopInd, StartInd_add
      integer :: StopInd_add, StopInd_add_,StopIndName
      integer :: VarNumber, VarNumber_add, SeparatorInd
      integer :: PlusInd
      integer :: LastLeftCharacter,ParanthesisInd,Mplussind
      integer :: photochemInd
      character (len=120) :: ChemInpLine, ChemInpLine_add
      character (len=*) :: input_file
!
      if (present(NrOfReactions)) NrOfReactions=0
!
      k=1
      open(file_id,file=input_file)
      dataloop3: do
        if (found_new_reaction) then
          ChemInpLine=ChemInpLine_add
        else
          read(file_id,'(80A)',end=1012) ChemInpLine
        endif
        found_new_reaction=.false.
!
!  Check if we are reading a line within the reactions section
!
        if (ChemInpLine(1:9)=="REACTIONS")            IsReaction=.true.
        if (ChemInpLine(1:3)=="END" .and. IsReaction) IsReaction=.false.
!
        if (present(NrOfReactions)) then
!
!  Find number of reactions
!
          if (IsReaction) then
            if (ChemInpLine(1:9) /= "REACTIONS") then
              StartInd=1; StopInd =0
              StopInd=index(ChemInpLine(StartInd:),'=')+StartInd-1
              if (StopInd>0 .and. ChemInpLine(1:1) /= '!') then
                NrOfReactions=NrOfReactions+1
              endif
            endif
          endif
        else
!
!  Read in species
!
          if (IsReaction) then
            if (ChemInpLine(1:9) /= "REACTIONS") then
              StartInd=1; StopInd =0
              StopInd=index(ChemInpLine(StartInd:),'=')+StartInd-1
              if (StopInd>0 .and. ChemInpLine(1:1) /= '!') then
!
! Fill in reaction name
!
                StopIndName=index(ChemInpLine(StartInd:),' ')+StartInd-1
                reaction_name(k)=ChemInpLine(StartInd:StopIndName)
!
! Photochemical case
!
               ParanthesisInd=0
               photochemInd=0
               SeparatorInd=0
               photochemInd=index(ChemInpLine(StartInd:),'hv')
               if (photochemInd>0) then
                 photochem_case (k)=.true.

               ParanthesisInd=index(ChemInpLine(photochemInd:),'(') &
                             +photochemInd-1
!
!
               if ((ParanthesisInd>0) .and. (photochemInd>0)) then
                StopInd=index(ChemInpLine(StartInd:),'lam')
!
                SeparatorInd=index(ChemInpLine(ParanthesisInd:StopInd),'<')
!
                if (SeparatorInd>0) then
                  SeparatorInd=SeparatorInd+ParanthesisInd-1
                  read (unit=ChemInpLine(ParanthesisInd+1:&
                                 SeparatorInd-1),fmt='(E15.8)') lamb_low
                endif
                ParanthesisInd=index(ChemInpLine(StopInd:),')') +StopInd-1
                SeparatorInd=index(ChemInpLine(StopInd:ParanthesisInd),'<') &
                             +StopInd-1
                 if (SeparatorInd>0) then
                   read (unit=ChemInpLine(SeparatorInd+1:&
                                  ParanthesisInd-1),fmt='(E15.8)') lamb_up
                 endif
               endif
               endif
!
!  End of the photochemical case
!
! Find reactant side stoichiometric coefficients
!
                SeparatorInd=index(ChemInpLine(StartInd:),'<=')
                if (SeparatorInd==0) then
                  SeparatorInd=index(ChemInpLine(StartInd:),'=')
                endif
!
                ParanthesisInd=0
                MplussInd=0
!
                ParanthesisInd=index(ChemInpLine(StartInd:),'(+M)')
                MplussInd=index(ChemInpLine(StartInd:),'+M')
!
                found_new_reaction=.false.
                if (ParanthesisInd>0 .or. Mplussind>0) then
                  if (ParanthesisInd>0) then
                    LastLeftCharacter=min(ParanthesisInd,SeparatorInd)-1
                  else
                    LastLeftCharacter=min(MplussInd,SeparatorInd)-1
                  endif
!
!  reading of the additional data for (+M) case
!
100               read(file_id,'(80A)',end=1012) ChemInpLine_add
                  if (ChemInpLine_add(1:1) == ' ') then
!
!
                    if (ParanthesisInd>0) then
                      Mplus_case (k)=.true.
                    endif
!
                    i=1
                    do while (i<80)
                      if (ChemInpLine_add(i:i)==' ') then
                        i=i+1
                      elseif (ChemInpLine_add(i:i+2)=='LOW') then
                      !  if (lroot) print*,ChemInpLine_add(i:i+2),&
                      !      '   coefficients for reaction ', &
                      !      reaction_name(k),'number ', k
                        VarNumber_add=1; StartInd_add=i+4; StopInd_add=i+4
                        do while (VarNumber_add<4)
                          StopInd_add=index(ChemInpLine_add(StartInd_add:),&
                              ' ')+StartInd_add-2
                          StopInd_add_=index(ChemInpLine_add(StartInd_add:),&
                              '/')+StartInd_add-2
                          StopInd_add=min(StopInd_add,StopInd_add_)
                          if (StopInd_add==StartInd_add) then
                            StartInd_add=StartInd_add+1
                          else
                            if (VarNumber_add==1) then
                              read (unit=ChemInpLine_add(StartInd_add:&
                                  StopInd_add),fmt='(E15.8)') low_coeff(1,k)
                            elseif (VarNumber_add==2) then
                              read (unit=ChemInpLine_add(StartInd_add:&
                                  StopInd_add),fmt='(E15.8)') low_coeff(2,k)
                            elseif (VarNumber_add==3) then
                              read (unit=ChemInpLine_add(StartInd_add:&
                                  StopInd_add),fmt='(E15.8)') low_coeff(3,k)
                            else
                              call stop_it("No such VarNumber!")
                            endif
                          endif
                          VarNumber_add=VarNumber_add+1
                          !StartInd_add=StopInd_add
                          StartInd_add=verify(ChemInpLine_add(StopInd_add+1:),&
                              ' ')+StopInd_add
                          StopInd_add=StartInd_add
                        enddo
                        i=80
                      elseif (ChemInpLine_add(i:i+3)=='TROE') then
                      !  if (lroot) print*,ChemInpLine_add(i:i+3),&
                      !      '   coefficients for reaction ', reaction_name(k),&
                      !      'number ', k
                        VarNumber_add=1; StartInd_add=i+5; StopInd_add=i+5
                        do while (VarNumber_add<4)
                          StopInd_add=index(ChemInpLine_add(StartInd_add:),&
                              ' ')+StartInd_add-2
                          StopInd_add_=index(ChemInpLine_add(StartInd_add:),&
                              '/')+StartInd_add-2
                          StopInd_add=min(StopInd_add,StopInd_add_)
                          if (StopInd_add==StartInd_add) then
                            StartInd_add=StartInd_add+1
                          else
                            if (VarNumber_add==1) then
                              read (unit=ChemInpLine_add(StartInd_add:&
                                  StopInd_add),fmt='(E15.8)') troe_coeff(1,k)
                            elseif (VarNumber_add==2) then
                              read (unit=ChemInpLine_add(StartInd_add:&
                                  StopInd_add),fmt='(E15.8)') troe_coeff(2,k)
                            elseif (VarNumber_add==3) then
                              read (unit=ChemInpLine_add(StartInd_add:&
                                  StopInd_add),fmt='(E15.8)') troe_coeff(3,k)
                            else
                              call stop_it("No such VarNumber!")
                            endif
                          endif
                          VarNumber_add=VarNumber_add+1
                          !   StartInd_add=StopInd_add
                          StartInd_add=verify(ChemInpLine_add(StopInd_add+1:),&
                              ' ')+StopInd_add
                          StopInd_add=StartInd_add
                        enddo
                        i=80
                      elseif (ChemInpLine_add(i:i+3)=='HIGH') then
                      !  if (lroot) print*,ChemInpLine_add(i:i+3),&
                      !      '   coefficients for reaction ', reaction_name(k),&
                      !      'number ', k
                        VarNumber_add=1; StartInd_add=i+5; StopInd_add=i+5
                        do while (VarNumber_add<4)
                          StopInd_add=index(ChemInpLine_add(StartInd_add:),&
                              ' ')+StartInd_add-2
                          StopInd_add_=index(ChemInpLine_add(StartInd_add:),&
                              '/')+StartInd_add-2
                          StopInd_add=min(StopInd_add,StopInd_add_)
                          if (StopInd_add==StartInd_add) then
                            StartInd_add=StartInd_add+1
                          else
                            if (VarNumber_add==1) then
                              read (unit=ChemInpLine_add(StartInd_add:&
                                  StopInd_add),fmt='(E15.8)') high_coeff(1,k)
                            elseif (VarNumber_add==2) then
                              read (unit=ChemInpLine_add(StartInd_add:&
                                  StopInd_add),fmt='(E15.8)') high_coeff(2,k)
                            elseif (VarNumber_add==3) then
                              read (unit=ChemInpLine_add(StartInd_add:&
                                  StopInd_add),fmt='(E15.8)') high_coeff(3,k)
                            else
                              call stop_it("No such VarNumber!")
                            endif
                          endif
                          VarNumber_add=VarNumber_add+1
                          !   StartInd_add=StopInd_add
                          StartInd_add=verify(ChemInpLine_add(StopInd_add+1:),&
                              ' ')+StopInd_add
                          StopInd_add=StartInd_add
                        enddo
                        i=80
                      else
                        !                a_k4=0.
                        StartInd_add=i; StopInd_add=0; StopInd_add_=0
                        do while (ChemInpLine_add(i:i+1)/='  ')
                          find_specie=.true.
                          do while (StartInd_add/=StopInd_add_)
                            StopInd_add=index(ChemInpLine_add(StartInd_add:),&
                                '/')+StartInd_add-2
                            StopInd_add_=index(ChemInpLine_add(StartInd_add:),&
                                ' ')+StartInd_add-1
                            if (find_specie) then
                              call find_species_index(ChemInpLine_add&
                                  (StartInd_add:StopInd_add),ind_glob,&
                                  ind_chem,found_specie)
                            else
                              if (found_specie) then
                                read (unit=ChemInpLine_add(StartInd_add:&
                                    StopInd_add),fmt='(E15.8)') a_k4(ind_chem,k)
                              else
                                print*,'ChemInpLine=',ChemInpLine_add
                                print*,'Specie=',&
                                    ChemInpLine_add(StartInd_add:StopInd_add)
                                print*,'StartInd_add,StopInd_add=',&
                                    StartInd_add,StopInd_add
                                call stop_it("read_reactions: Did not find specie!")
                              endif
                            endif
                            StartInd_add=StopInd_add+2
                            find_specie=.false.
                          enddo
                          i=StopInd_add_
                          StartInd_add=StartInd_add+1
                        enddo
                        i=80
                        !call find_species_index('N2',&
                        !    ind_glob,ind_chem,found_specie)
                        !if (found_specie) a_k4(ind_chem,k)=1.
                        do ind_chem=1,nchemspec
                          if (a_k4(ind_chem,k)>impossible*0.99) a_k4(ind_chem,k)=1
                        enddo
!
                      endif
                    enddo
                    goto 100
!
!
                  else
                    found_new_reaction=.true.
                  endif
!
                else
                  LastLeftCharacter=SeparatorInd-1
                endif
!
                StartInd=1
                PlusInd=index(ChemInpLine(StartInd:LastLeftCharacter),'+')&
                    +StartInd-1
                do while (PlusInd<LastLeftCharacter .AND. PlusInd>0)
                  StopInd=PlusInd-1
                  call build_stoich_matrix(StartInd,StopInd,k,&
                      ChemInpLine,.false.)
                  StartInd=StopInd+2
                  PlusInd=index(ChemInpLine(StartInd:),'+')+StartInd-1
                enddo
                StopInd=LastLeftCharacter
                call build_stoich_matrix(StartInd,StopInd,k,ChemInpLine,.false.)
!
! Find product side stoichiometric coefficients
!
                StartInd=index(ChemInpLine,'>')+1
                if (StartInd==1) StartInd=index(ChemInpLine,'=')+1
                SeparatorInd=index(ChemInpLine(StartInd:),' ')+StartInd-1
!
                ParanthesisInd=index(ChemInpLine(StartInd:),'(+M)')+StartInd-1
                MplussInd=index(ChemInpLine(StartInd:),'+M')+StartInd-1
!
                if (ParanthesisInd>StartInd) then
                  LastLeftCharacter=min(ParanthesisInd,SeparatorInd)-1
                elseif (MplussInd>StartInd) then
                  LastLeftCharacter=min(MplussInd,SeparatorInd)-1
                else
                  LastLeftCharacter=SeparatorInd-1
                endif
                PlusInd=index(ChemInpLine(StartInd:LastLeftCharacter),'+')&
                    +StartInd-1
                do while (PlusInd<LastLeftCharacter .AND. PlusInd>StartInd)
                  StopInd=PlusInd-1
                  call build_stoich_matrix(StartInd,StopInd,k,&
                      ChemInpLine,.true.)
                  StartInd=StopInd+2
                  PlusInd=index(ChemInpLine(StartInd:),'+')+StartInd-1
                enddo
                StopInd=LastLeftCharacter
                call build_stoich_matrix(StartInd,StopInd,k,ChemInpLine,.true.)
!
! Find Arrhenius coefficients
!
                VarNumber=1; StartInd=1; StopInd =0
                stringloop: do while (VarNumber<4)
                  StopInd=index(ChemInpLine(StartInd:),' ')+StartInd-1
                  StartInd=verify(ChemInpLine(StopInd:),' ')+StopInd-1
                  StopInd=index(ChemInpLine(StartInd:),' ')+StartInd-1
                  if (StopInd==StartInd) then
                    StartInd=StartInd+1
                  else
                    if (VarNumber==1) then
                      read (unit=ChemInpLine(StartInd:StopInd),fmt='(E15.8)')  &
                          B_n(k)
                    elseif (VarNumber==2) then
                      read (unit=ChemInpLine(StartInd:StopInd),fmt='(E15.8)')  &
                          alpha_n(k)
                    elseif (VarNumber==3) then
                      read (unit=ChemInpLine(StartInd:StopInd),fmt='(E15.8)')  &
                          E_an(k)
                    else
                      call stop_it("No such VarNumber!")
                    endif
                    VarNumber=VarNumber+1
                    StartInd=StopInd
                  endif
                  if (StartInd==80) exit
                enddo stringloop
!
! Increase reaction counter by one
!
                k=k+1
              endif
            endif
          endif
        endif
      enddo dataloop3
1012  continue
      close(file_id)
!
    endsubroutine read_reactions
!***********************************************************************
!***********************************************************************
    subroutine build_stoich_matrix(StartInd,StopInd,k,ChemInpLine,product)
!
!  calculation of the stoichoimetric matrix
!
!  10-mar-08/nils: coded
!
      integer, intent(in) :: StartInd,StopInd,k
      character (len=*), intent(in) :: ChemInpLine
      logical, intent(in) :: product
      integer :: StartSpecie,ind_glob,ind_chem,stoi
      logical :: found_specie
!
      if ((ChemInpLine(StartInd:StopInd) /= "M" ) &
          .and. (ChemInpLine(StartInd:StartInd+1) /= "hv" )) then
        StartSpecie=verify(ChemInpLine(StartInd:StopInd),&
            "1234567890")+StartInd-1
        call find_species_index(ChemInpLine(StartSpecie:StopInd),&
            ind_glob,ind_chem,found_specie)
!
        if (.not. found_specie) then
          print*,'ChemInpLine(StartSpecie:StopInd)=',ChemInpLine(StartSpecie:StopInd)
          print*,'ind_glob,ind_chem=',ind_glob,ind_chem
!          if (.not. lpencil_check_small) then
!          if (.not. lpencil_check) then
            call stop_it("build_stoich_matrix: Did not find species!")
!          endif
!          endif
        endif
!        if (found_specie) then
        if (StartSpecie==StartInd) then
          stoi=1
        else
          read (unit=ChemInpLine(StartInd:StartInd),fmt='(I1)') stoi
        endif
        if (product) then
          Sijm(ind_chem,k)=Sijm(ind_chem,k)+stoi
        else
          Sijp(ind_chem,k)=Sijp(ind_chem,k)+stoi
        endif
!        endif
      endif
!
    endsubroutine build_stoich_matrix
!***********************************************************************
    subroutine write_reactions()
!
!  write reaction coefficient in the output file
!
!  11-mar-08/nils: coded
!
      use General, only: chn
!
      integer :: reac,spec
      character (len=80) :: reac_string,product_string,output_string
      character (len=5)  :: Sijp_string,Sijm_string
      character (len=1)  :: separatorp,separatorm
      character (len=20) :: input_file="./data/chem.out"
      integer :: file_id=123
!
      open(file_id,file=input_file,POSITION='APPEND',FORM='FORMATTED')
      write(file_id,*) 'REACTIONS'
      !open(file_id,file=input_file)
!
      do reac=1,mreactions
        reac_string=''
        product_string=''
        separatorp=''
        separatorm=''
!
        do spec=1,nchemspec
          if (Sijp(spec,reac)>0) then
            Sijp_string=''
            if (Sijp(spec,reac)>1) call chn(Sijp(spec,reac),Sijp_string)
            reac_string=trim(reac_string)//trim(separatorp)//&
                trim(Sijp_string)//trim(varname(ichemspec(spec)))
            separatorp='+'
          endif
          if (Sijm(spec,reac)>0) then
            Sijm_string=''
            if (Sijm(spec,reac)>1) call chn(Sijm(spec,reac),Sijm_string)
            product_string=trim(product_string)//trim(separatorm)//&
                trim(Sijm_string)//trim(varname(ichemspec(spec)))
            separatorm='+'
          endif
        enddo
!
        output_string=trim(reac_string)//'='//trim(product_string)
!
       if (.not. photochem_case(reac)) then
        write(unit=output_string(30:45),fmt='(E14.4)') B_n(reac)
        write(unit=output_string(47:62),fmt='(E14.4)') alpha_n(reac)
        write(unit=output_string(64:79),fmt='(E14.4)') E_an(reac)
       endif
        write(file_id,*) trim(output_string)
       if (.not. photochem_case(reac)) then
        if (maxval(abs(low_coeff(:,reac))) > 0.) then
          write(file_id,*) 'LOW/',low_coeff(:,reac)
        elseif (maxval(abs(high_coeff(:,reac))) > 0.) then
          write(file_id,*) 'HIGH/',high_coeff(:,reac)
        endif
        if (maxval(abs(troe_coeff(:,reac))) > 0.) then
          write(file_id,*) 'TROE/',troe_coeff(:,reac)
        endif
        if (minval(a_k4(:,reac))<impossible) then
          write(file_id,*) a_k4(:,reac)
        endif
       else
         write(file_id,*) ' min lambda=',lamb_low,' max lambda=',lamb_up
       endif
!
      enddo
!
      write(file_id,*) 'END'
      write(file_id,*) '(M+) case: ',Mplus_case
      write(file_id,*) 'photochemical case: ',photochem_case
!
      close(file_id)
!
    endsubroutine write_reactions
!***********************************************************************
    subroutine get_reaction_rate(f,vreact_p,vreact_m,p)
!
!  This subroutine calculates forward and reverse reaction rates,
!  if chem.inp file exists.
!  For more details see Chemkin Theory Manual
!
!  NILS: This routine is by far the most CPU intencive routine in the code,
!  NILS: so one should maybe put some effort into optimizing it more.
!
!  17-mar-08/natalia: coded
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (nx,nreactions), intent(out) :: vreact_p, vreact_m
      real, dimension (nx):: mix_conc
!
      type (pencil_case) :: p
      real, dimension (nx) :: dSR=0.,dHRT=0.,Kp,Kc,prod1,prod2
      real, dimension (nx) :: kf=0., kr=0.
      real, dimension (nx) :: rho_cgs,p_atm
      real, dimension (nx,nchemspec) :: S0_R
      real :: Rcal
      integer :: k , reac, i
      real  :: sum_tmp=0., T_low, T_mid, T_up,  ddd
      logical,save :: lwrite=.true., lwrite_first=.true.
      character (len=20) :: input_file="./data/react.out"
      integer :: file_id=123
      integer :: ii1=1,ii2=2,ii3=3,ii4=4,ii5=5,ii7=7
      real :: B_n_0,alpha_n_0,E_an_0
      real, dimension (nx) :: kf_0,Pr,sum_sp
      real, dimension (nx) :: Fcent, ccc, nnn, lnPr, FF,tmpF
      real, dimension (nx) :: TT1_loc
!
!
! Natalia:pencil_check
! the same problem as in calculation of p%H0_RT:
! if lpencil_check and full compiler settings then
! the problem appears for TT1_loc= p%TT1
! Does anybody know why it is so?
! While this problem is not resolved 
! I use TT1_loc=exp(f(l1:l2,m,n,ilnTT))**(-1)
! 
      TT1_loc=exp(f(l1:l2,m,n,ilnTT))**(-1)
!
      if (lwrite_first)  open(file_id,file=input_file)
!
!  p is in atm units; atm/bar=1./10.13
!
      Rcal=Rgas_unit_sys/4.14*1e-7
      rho_cgs=p%rho*unit_mass/unit_length**3
      p_atm=1e6*unit_length**3/unit_energy
      if (lwrite)  write(file_id,*)'T= ',   p%TT
      if (lwrite)  write(file_id,*)'p_atm= ',   p_atm
!
   !   if (lpencil(i_S0_R)) then
!
!  Dimensionless Standard-state molar entropy  S0/R
!
      if (lwrite)  write(file_id,*)'**************************'
      if (lwrite) write(file_id,*)'S0_R'
      if (lwrite)  write(file_id,*)'**************************'
!
!
      do k=1,nchemspec
        if (species_constants(k,imass)>0.) then
          T_low=species_constants(k,iTemp1)
          T_mid=species_constants(k,iTemp2)
          T_up= species_constants(k,iTemp3)
!
!  Check that we are not outside the temperture range
!
            if ((maxval(exp(f(l1:l2,m,n,ilnTT))) > T_up)  &
                .or. (minval(exp(f(l1:l2,m,n,ilnTT))) < T_low-10.)) then
              print*,'m,n=',m,n
              print*,'p%TT=',p%TT
              call fatal_error('get_reaction_rate',&
                  'p%TT(i) is outside range')
            endif
!
!  Find the entropy by using fifth order temperature fitting function
!
          where(p%TT <= T_mid .and. T_low <= p%TT)
            S0_R(:,k)=species_constants(k,iaa2(ii1))*p%lnTT &
                  +species_constants(k,iaa2(ii2))*p%TT &
                  +species_constants(k,iaa2(ii3))*p%TT_2/2 &
                  +species_constants(k,iaa2(ii4))*p%TT_3/3 &
                  +species_constants(k,iaa2(ii5))*p%TT_4/4 &
                  +species_constants(k,iaa2(ii7))
          elsewhere (T_mid <= p%TT .and. p%TT <= T_up)
            S0_R(:,k)=species_constants(k,iaa1(ii1))*p%lnTT &
                  +species_constants(k,iaa1(ii2))*p%TT &
                  +species_constants(k,iaa1(ii3))*p%TT_2/2 &
                  +species_constants(k,iaa1(ii4))*p%TT_3/3 &
                  +species_constants(k,iaa1(ii5))*p%TT_4/4 &
                  +species_constants(k,iaa1(ii7))
          endwhere
        endif
      enddo
!    endif
!
!  calculation of the reaction rate
!
      if (lwrite_first) write(file_id,*)'**************************'
      if (lwrite_first) write(file_id,*)'Reaction rates'
      if (lwrite_first) write(file_id,*)'**************************'
!
      do reac=1,nreactions
!
!  Find the product of the species molar consentrations (where
!  each molar consentration is taken to the power of the number)
!
        prod1=1.
        prod2=1.
        do k=1,nchemspec
          if ((abs(Sijp(k,reac))>0) .and. (species_constants(k,imass)>0.)) then
            prod1=prod1*(f(l1:l2,m,n,ichemspec(k))*rho_cgs(:)&
                /species_constants(k,imass))**Sijp(k,reac)
          endif
        enddo
        do k=1,nchemspec
          if ((abs(Sijm(k,reac))>0) .and. (species_constants(k,imass)>0.)) then
            prod2=prod2*(f(l1:l2,m,n,ichemspec(k))*rho_cgs(:)&
                /species_constants(k,imass))**Sijm(k,reac)
          endif
        enddo
!
!  Find forward rate constant for reaction 'reac'
!
        if (latmchem) then
          do i=1,nx
            if ((B_n(reac)==0.) .and. (alpha_n(reac)==0.)  &
                .and. (E_an(reac)==0.)) then
              call calc_extra_react(f,reac,kf(i),i,m,n,p)
            else
              kf(i)=B_n(reac)*p%TT(i)**alpha_n(reac)*exp(-E_an(reac)*p%TT1(i))
            endif
          enddo
        else
          kf=B_n(reac)*p%TT**alpha_n(reac)*exp(-E_an(reac)/Rcal*TT1_loc)
        endif
!
!  Find backward rate constant for reaction 'reac'
!
        dSR=0.
        dHRT=0.
        sum_tmp=0.
        do k=1,nchemspec
          dSR =dSR+(Sijm(k,reac) -Sijp(k,reac))*S0_R(:,k)
          dHRT=dHRT+(Sijm(k,reac)-Sijp(k,reac))*p%H0_RT(:,k)
          sum_tmp=sum_tmp+(Sijm(k,reac)-Sijp(k,reac))
        enddo
        Kp=exp(dSR-dHRT)
        if (sum_tmp==0.) then
          Kc=Kp
        else
          Kc=Kp*(p_atm*p%TT1/Rgas)**sum_tmp
        endif
        kr=kf/Kc
!
!  Multiply by third body reaction term
!
        if (minval(a_k4(:,reac))<impossible) then
          sum_sp=0.
          do k=1,nchemspec
            if (species_constants(k,imass)>0.) then
              sum_sp=sum_sp+a_k4(k,reac)*f(l1:l2,m,n,ichemspec(k))  &
                  *rho_cgs(:)/species_constants(k,imass)
            endif
          enddo
          mix_conc=sum_sp
        else
          sum_sp=1.
          mix_conc=rho_cgs(:)*p%mu1(:)/unit_mass
        endif
!
!  The Lindstrom approach to the fall of reactions
!
     !   Kc_0=Kc
        if (maxval(abs(low_coeff(:,reac))) > 0.) then
          B_n_0=low_coeff(1,reac)
          alpha_n_0=low_coeff(2,reac)
          E_an_0=low_coeff(3,reac)
          kf_0(:)=B_n_0*p%TT(:)**alpha_n_0*exp(-E_an_0/Rcal*TT1_loc(:))
          Pr=kf_0/kf*mix_conc
          kf=kf*(Pr/(1.+Pr))
        elseif (maxval(abs(high_coeff(:,reac))) > 0.) then
          B_n_0=high_coeff(1,reac)
          alpha_n_0=high_coeff(2,reac)
          E_an_0=high_coeff(3,reac)
          kf_0(:)=B_n_0*p%TT(:)**alpha_n_0*exp(-E_an_0/Rcal*TT1_loc(:))
          Pr=kf_0/kf*mix_conc
          kf=kf*(1./(1.+Pr))
        endif
!
! The Troe approach
!
        if (maxval(abs(troe_coeff(:,reac))) > 0.) then
         Fcent=(1.-troe_coeff(1,reac))*exp(-p%TT(:)/troe_coeff(2,reac)) &
         +troe_coeff(1,reac)*exp(-p%TT(:)/troe_coeff(3,reac))
         ccc=-0.4-0.67*log10(Fcent)
         nnn=0.75-1.27*log10(Fcent)
         ddd=0.14
         lnPr=log10(Pr)
         tmpF=((lnPr+ccc)/(nnn-ddd*(lnPr+ccc)))**2
         tmpF=1./(1.+tmpF)
         FF=tmpF*log10(Fcent)
         FF=10**(FF)
         kf=kf*FF
        endif
!
!  Find forward (vreact_p) and backward (vreact_m) rate of
!  progress variable.
!  (vreact_p - vreact_m) is labeled q in the chemkin manual
!
        if (Mplus_case (reac)) then
          where (prod1 > 0)
            vreact_p(:,reac)=prod1*kf
          elsewhere
            vreact_p(:,reac)=0.
          endwhere
        else
          where (prod1 > 0)
            vreact_p(:,reac)=prod1*kf*sum_sp
          elsewhere
            vreact_p(:,reac)=0.
          endwhere
        endif
!
        if (latmchem) then
          kr=kf!/Kc(i)
        else
          kr=kf/Kc
        endif
        if (Mplus_case (reac)) then
          where (prod2 > 0)
            vreact_m(:,reac)=prod2*kr
          elsewhere
            vreact_m(:,reac)=0.
          endwhere
        else
          where (prod2 > 0)
            vreact_m(:,reac)=prod2*kr*sum_sp
          elsewhere
            vreact_m(:,reac)=0.
          endwhere
        endif
!
! This part calculates forward and reverse reaction rates
! for the test case R->P
! For more details see Doom, et al., J. Comp. Phys., 226, 2007
!
        if (l1step_test) then
          do i=1,nx
            if (p%TT(i) > Tc) then
              vreact_p(i,reac)=f(l1,m,n,iux)**2*p%rho(1)*Cp_const &
                  /lambda_const*beta*(beta-1.) &
                  *(1.-f(l1-1+i,m,n,ichemspec(ipr)))
            else
              vreact_p(i,reac)=0.
            endif
          enddo
          vreact_m(:,reac)=0.
        endif
!
! Write some data to file
!
        if (lwrite_first) write(file_id,*) &
            'Nreact= ',reac,'dSR= ', maxval(dSR), minval(dSR)
        if (lwrite_first) write(file_id,*) &
            'Nreact= ',reac,'dHRT= ', maxval(dHRT), minval(dHRT)
        if (lwrite_first) write(file_id,*)  &
            'Nreact= ',reac,  'kf= ', kf(1), minval(kf)
        if (lwrite_first) write(file_id,*)  &
            'Nreact= ',reac,  'Kc= ', maxval(Kc), minval(Kc)
        if (lwrite_first) write(file_id,*)  &
            'Nreact= ',reac,  'kr= ', kr(1), minval(kr)
        if (lwrite_first) write(file_id,*)'**************************'
      enddo
!
!  Finalize writing to file
!
        if (lwrite_first) write(file_id,*) ''
        if (lwrite_first) write(file_id,*) '*******************'
        if (lwrite_first) print*,'get_reaction_rate: writing react.out file'
        if (lwrite_first) close(file_id)
      ! lwrite=.false.
       lwrite_first=.false.
!
    endsubroutine get_reaction_rate
!***********************************************************************
    subroutine calc_reaction_term(f,p)
!
!  Calculation of the reaction term
!
      use Diagnostics, only: sum_mn_name
!
      real :: alpha
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (nx,mreactions) :: vreactions,vreactions_p,vreactions_m
      real, dimension (nx) :: xdot
      type (pencil_case) :: p
      integer :: k,j
      integer :: i1=1,i2=2,i3=3,i4=4,i5=5,i6=6,i7=7,i8=8,i9=9,i10=10
      integer :: i11=11,i12=12,i13=13,i14=14,i15=15,i16=16,i17=17,i18=18,i19=19
!
      p%DYDt_reac=0.
!
!  if we do reactions, we must calculate the reaction speed vector
!  outside the loop where we multiply it by the stoichiometric matrix
!
      if (.not. lcheminp) then
!
!  Axel' case
!
        do j=1,nreactions
          if (lkreactions_alpha) then
            alpha=kreactions_alpha(j)
          else
            alpha=1.
          endif
          vreactions_p(:,j)=alpha*kreactions_p(j)*kreactions_z(n,j)
          vreactions_m(:,j)=alpha*kreactions_m(j)*kreactions_z(n,j)
          do k=1,nchemspec
            vreactions_p(:,j)=vreactions_p(:,j)*&
                f(l1:l2,m,n,ichemspec(k))**Sijm(k,j)
            vreactions_m(:,j)=vreactions_m(:,j)*&
                f(l1:l2,m,n,ichemspec(k))**Sijp(k,j)
          enddo
        enddo
      else
!
!  Chemkin data case
!
         call get_reaction_rate(f,vreactions_p,vreactions_m,p)
      endif
!
!  Calculate rate of progress variable (labeled q in the chemkin manual)
!
      vreactions=vreactions_p-vreactions_m
!
!  Calculate production rate for all species k (called \dot(\omega)_k
!  in the chemkin manual)
!
      do k=1,nchemspec
        xdot=0.
        do j=1,nreactions
          xdot=xdot+stoichio(k,j)*vreactions(:,j)
        enddo
        if (lcheminp) then
         if (l1step_test) then
          xdot=-xdot!/p%rho
         else
          xdot=-xdot*species_constants(k,imass)/p%rho
         endif
        endif
        p%DYDt_reac(:,k)=xdot*unit_time
      enddo

      if (lchemistry_diag) then
        do k=1,nchemspec
        do j=1,nreactions
          net_react_p(k,j)=net_react_p(k,j)+stoichio(k,j) &
             *sum(vreactions_p(:,j))
          net_react_m(k,j)=net_react_m(k,j)+stoichio(k,j) &
             *sum(vreactions_m(:,j))
        enddo
        enddo
      endif
!
! NH:
!
!  Sums for diagnostics
!
      !sum_omega=0.
      !sum_Y=0.
      !do k=1,nchemspec
      !  sum_omega=sum_omega+maxval(p%DYDt_reac(:,k))
      !  sum_Y=sum_Y+maxval(f(l1:l2,m,n,ichemspec(k)))
      !enddo
!
!  Calculate diagnostic quantities
!
      if (ldiagnos) then
        if (idiag_dY1m/=0) call sum_mn_name(p%DYDt_reac(:,i1),idiag_dY1m)
        if (idiag_dY2m/=0) call sum_mn_name(p%DYDt_reac(:,i2),idiag_dY2m)
        if (idiag_dY3m/=0) call sum_mn_name(p%DYDt_reac(:,i3),idiag_dY3m)
        if (idiag_dY4m/=0) call sum_mn_name(p%DYDt_reac(:,i4),idiag_dY4m)
        if (idiag_dY5m/=0) call sum_mn_name(p%DYDt_reac(:,i5),idiag_dY5m)
        if (idiag_dY6m/=0) call sum_mn_name(p%DYDt_reac(:,i6),idiag_dY6m)
        if (idiag_dY7m/=0) call sum_mn_name(p%DYDt_reac(:,i7),idiag_dY7m)
        if (idiag_dY8m/=0) call sum_mn_name(p%DYDt_reac(:,i8),idiag_dY8m)
        if (idiag_dY9m/=0) call sum_mn_name(p%DYDt_reac(:,i9),idiag_dY9m)
        if (idiag_dY10m/=0) call sum_mn_name(p%DYDt_reac(:,i10),idiag_dY10m)
        if (idiag_dY11m/=0) call sum_mn_name(p%DYDt_reac(:,i11),idiag_dY11m)
        if (idiag_dY12m/=0) call sum_mn_name(p%DYDt_reac(:,i12),idiag_dY12m)
        if (idiag_dY13m/=0) call sum_mn_name(p%DYDt_reac(:,i13),idiag_dY13m)
        if (idiag_dY14m/=0) call sum_mn_name(p%DYDt_reac(:,i14),idiag_dY14m)
        if (idiag_dY15m/=0) call sum_mn_name(p%DYDt_reac(:,i15),idiag_dY15m)
        if (idiag_dY16m/=0) call sum_mn_name(p%DYDt_reac(:,i16),idiag_dY16m)
        if (idiag_dY17m/=0) call sum_mn_name(p%DYDt_reac(:,i17),idiag_dY17m)
        if (idiag_dY18m/=0) call sum_mn_name(p%DYDt_reac(:,i18),idiag_dY18m)
        if (idiag_dY19m/=0) call sum_mn_name(p%DYDt_reac(:,i19),idiag_dY19m)
        if (idiag_h1m/=0) call sum_mn_name(p%H0_RT(:,i1)*Rgas*&
            p%TT(:)/species_constants(i1,imass),idiag_h1m)
        if (idiag_h2m/=0) call sum_mn_name(p%H0_RT(:,i2)*Rgas*&
            p%TT(:)/species_constants(i2,imass),idiag_h2m)
        if (idiag_h3m/=0) call sum_mn_name(p%H0_RT(:,i3)*Rgas*&
            p%TT(:)/species_constants(i3,imass),idiag_h3m)
        if (idiag_h4m/=0) call sum_mn_name(p%H0_RT(:,i4)*Rgas*&
            p%TT(:)/species_constants(i4,imass),idiag_h4m)
        if (idiag_h5m/=0) call sum_mn_name(p%H0_RT(:,i5)*Rgas*&
            p%TT(:)/species_constants(i5,imass),idiag_h5m)
        if (idiag_h6m/=0) call sum_mn_name(p%H0_RT(:,i6)*Rgas*&
            p%TT(:)/species_constants(i6,imass),idiag_h6m)
        if (idiag_h7m/=0) call sum_mn_name(p%H0_RT(:,i7)*Rgas*&
            p%TT(:)/species_constants(i7,imass),idiag_h7m)
        if (idiag_h8m/=0) call sum_mn_name(p%H0_RT(:,i8)*Rgas*&
            p%TT(:)/species_constants(i8,imass),idiag_h8m)
        if (idiag_h9m/=0) call sum_mn_name(p%H0_RT(:,i9)*Rgas*&
            p%TT(:)/species_constants(i9,imass),idiag_h9m)
        if (idiag_h10m/=0) call sum_mn_name(p%H0_RT(:,i10)*Rgas*&
            p%TT(:)/species_constants(i10,imass),idiag_h10m)
        if (idiag_h11m/=0) call sum_mn_name(p%H0_RT(:,i11)*Rgas*&
            p%TT(:)/species_constants(i11,imass),idiag_h11m)
        if (idiag_h12m/=0) call sum_mn_name(p%H0_RT(:,i12)*Rgas*&
            p%TT(:)/species_constants(i12,imass),idiag_h12m)
        if (idiag_h13m/=0) call sum_mn_name(p%H0_RT(:,i13)*Rgas*&
            p%TT(:)/species_constants(i13,imass),idiag_h13m)
        if (idiag_h14m/=0) call sum_mn_name(p%H0_RT(:,i14)*Rgas*&
            p%TT(:)/species_constants(i14,imass),idiag_h14m)
        if (idiag_h15m/=0) call sum_mn_name(p%H0_RT(:,i15)*Rgas*&
            p%TT(:)/species_constants(i15,imass),idiag_h15m)
        if (idiag_h16m/=0) call sum_mn_name(p%H0_RT(:,i16)*Rgas*&
            p%TT(:)/species_constants(i16,imass),idiag_h16m)
        if (idiag_h17m/=0) call sum_mn_name(p%H0_RT(:,i17)*Rgas*&
            p%TT(:)/species_constants(i17,imass),idiag_h17m)
        if (idiag_h18m/=0) call sum_mn_name(p%H0_RT(:,i18)*Rgas*&
            p%TT(:)/species_constants(i18,imass),idiag_h18m)
        if (idiag_h19m/=0) call sum_mn_name(p%H0_RT(:,i19)*Rgas*&
            p%TT(:)/species_constants(i19,imass),idiag_h19m)
      endif
!
    endsubroutine calc_reaction_term
!***********************************************************************
    subroutine  write_net_reaction
!
!  write net reactions to file
!
      open(1,file=trim(datadir)//'/net_reactions.dat',position='append')
      write(1,*) t
      write(1,'(8e10.2)') net_react_p, net_react_m
      close(1)
!
    endsubroutine  write_net_reaction
!***********************************************************************
    subroutine  calc_collision_integral(omega,lnTst,Omega_kl)
!
!  Get coefficients for calculating of the collision integral
!  This routind is called from calc_diff_visc_coeff, which again is called from
!  calc_for_chem_mixture, which is why we work on full chunks of arrays here.
!
!  03-apr-08/natalia: coded
!
      character (len=*), intent(in) :: omega
      real,  dimension(mx,my,mz), intent(in)  :: lnTst
      real,  dimension(mx,my,mz), intent(out) :: Omega_kl
      integer :: i
      real, dimension(8) :: aa
!
      select case (omega)
      case ('Omega11')
        aa(1)= 6.96945701E-1
        aa(2)= 3.39628861E-1
        aa(3)= 1.32575555E-2
        aa(4)=-3.41509659E-2
        aa(5)= 7.71359429E-3
        aa(6)= 6.16106168E-4
        aa(7)=-3.27101257E-4
        aa(8)= 2.51567029E-5
      case ('Omega22')
        aa(1)= 6.33225679E-1
        aa(2)= 3.14473541E-1
        aa(3)= 1.78229325E-2
        aa(4)=-3.99489493E-2
        aa(5)= 8.98483088E-3
        aa(6)= 7.00167217E-4
        aa(7)=-3.82733808E-4
        aa(8)= 2.97208112E-5
      case default
        call stop_it('Insert Omega_kl')
      end select
!
      Omega_kl=0.
      do i=1,8
        Omega_kl=Omega_kl+aa(i)*(lnTst)**(i-1)
      enddo
      Omega_kl=1./Omega_kl
!
    endsubroutine  calc_collision_integral
!***********************************************************************
    subroutine calc_diff_visc_coef(f)
!
!  Calculation of the binary diffusion coefficients and the species viscosities.
!  This routind is called from calc_for_chem_mixture,
!  which is why we work on full chunks of arrays here.
!
      real, dimension (mx,my,mz,mfarray) :: f
      intent(in) :: f
      real, dimension (mx,my,mz) :: Omega_kl, prefactor
      real, dimension (mx,my,mz) :: lnTjk,lnTk_array
      integer :: k,j,j2,j3
      real :: eps_jk, sigma_jk, m_jk, delta_jk, delta_st
      real :: Na=6.022E23 ,tmp_local,tmp_local2, delta_jk_star
      character (len=7) :: omega
!
!  Find binary diffusion coefficients
!
      tmp_local=3./16.*(2.*k_B_cgs**3/pi)**0.5
      do j3=nn1,nn2
      do j2=mm1,mm2
        prefactor(ll1:ll2,j2,j3)=tmp_local*(TT_full(ll1:ll2,j2,j3))**0.5&
            *unit_length**3/(Rgas_unit_sys*rho_full(ll1:ll2,j2,j3))
      enddo
      enddo
!
      omega='Omega11'
!
! Check if we use fixed Schmidt number for speeding up calculations
!
      if (.not. lfix_Sc) then
!
! Check if we use simplified version of the binary diffusion calculation
!
        if (ldiffusion .and. (.not. lDiff_simple)) then
!
!  Do non-simplified binary diffusion coefficient
!
          do k=1,nchemspec
            do j=k,nchemspec
!  Account for the difference between eq. 5-4 and 5-31 in the Chemkin theory
!  manual
!
            if (j/=k) then
                eps_jk=(tran_data(j,2)*tran_data(k,2))**0.5
                sigma_jk=0.5*(tran_data(j,3)+tran_data(k,3))*1e-8
                m_jk=(species_constants(j,imass)*species_constants(k,imass)) &
                    /(species_constants(j,imass)+species_constants(k,imass))/Na
                delta_jk=0.5*tran_data(j,4)*tran_data(k,4)*1e-18*1e-18
              else
                eps_jk=tran_data(j,2)
                sigma_jk=tran_data(j,3)*1e-8
                m_jk=species_constants(j,imass)/(2*Na)
                delta_jk=0.5*(tran_data(j,4)*1e-18)**2
              endif
!
! Loop over all grid points
!
              do j3=nn1,nn2
              do j2=mm1,mm2
                if (ltemperature_nolog) then
                  lnTjk(ll1:ll2,j2,j3)=log(f(ll1:ll2,j2,j3,ilnTT)/eps_jk)
                else
                  lnTjk(ll1:ll2,j2,j3)=f(ll1:ll2,j2,j3,ilnTT)-log(eps_jk)
                endif
!
                Omega_kl(ll1:ll2,j2,j3)= &
                    1./(6.96945701E-1   +3.39628861E-1*lnTjk(ll1:ll2,j2,j3) &
                    +1.32575555E-2*lnTjk(ll1:ll2,j2,j3)*lnTjk(ll1:ll2,j2,j3) &
                    -3.41509659E-2*lnTjk(ll1:ll2,j2,j3)**3 &
                    +7.71359429E-3*lnTjk(ll1:ll2,j2,j3)**4 &
                    +6.16106168E-4*lnTjk(ll1:ll2,j2,j3)**5 &
                    -3.27101257E-4*lnTjk(ll1:ll2,j2,j3)**6 &
                    +2.51567029E-5*lnTjk(ll1:ll2,j2,j3)**7)
                delta_jk_star=delta_jk/(eps_jk*k_B_cgs*sigma_jk**3)
!
                Omega_kl(ll1:ll2,j2,j3)=Omega_kl(ll1:ll2,j2,j3)&
                    +0.19*delta_jk_star*delta_jk_star/(TT_full(ll1:ll2,j2,j3)/eps_jk)
               if (j/=k) then
                Bin_Diff_coef(ll1:ll2,j2,j3,k,j)=prefactor(ll1:ll2,j2,j3)/mu1_full(ll1:ll2,j2,j3)&
                    /(sqrt(m_jk)*sigma_jk**2*Omega_kl(ll1:ll2,j2,j3))
               else
                Bin_Diff_coef(ll1:ll2,j2,j3,k,j)=prefactor(ll1:ll2,j2,j3)&
                    /(sqrt(m_jk)*sigma_jk**2*Omega_kl(ll1:ll2,j2,j3))*species_constants(k,imass)
!
               endif
              enddo
              enddo
            enddo
          enddo
!
          do j3=nn1,nn2
          do j2=mm1,mm2
            do k=1,nchemspec
              do j=1,k-1
                Bin_Diff_coef(ll1:ll2,j2,j3,k,j)=Bin_Diff_coef(ll1:ll2,j2,j3,j,k)
              enddo
            enddo
          enddo
          enddo
!
      else
        if (.not. lDiff_simple) then
          Bin_Diff_coef=0.
        endif
      endif
      endif
!
!  Calculate viscosity
!
     if (visc_const>impossible*0.99) then
      omega='Omega22'
      tmp_local=5./16.*(k_B_cgs/(Na*pi))**0.5
!
      do k=1,nchemspec
        tmp_local2=(species_constants(k,imass))**0.5/  &
             (tran_data(k,3)*1e-8)**2*tmp_local
!
! 1 Debye = 10**(-18) esu -> (1e-18*tran_data(k,4))
!
          delta_st=(1e-18*tran_data(k,4))**2/2./ &
             (tran_data(k,2)*k_B_cgs*(tran_data(k,3)*1e-8)**3)
!
          if (ltemperature_nolog) then
            lnTk_array=log(f(:,:,:,ilnTT)/tran_data(k,2))
          else
            lnTk_array=f(:,:,:,ilnTT)-log(tran_data(k,2))
          endif
          call calc_collision_integral(omega,lnTk_array,Omega_kl)
!
          do j3=nn1,nn2
          do j2=mm1,mm2
           species_viscosity(ll1:ll2,j2,j3,k)=TT_full(ll1:ll2,j2,j3)**0.5&
               /(Omega_kl(ll1:ll2,j2,j3) &
               +0.2*delta_st*delta_st/(TT_full(ll1:ll2,j2,j3)  &
               /tran_data(k,2)))*tmp_local2 &
               /(unit_mass/unit_length/unit_time)
          enddo
          enddo
      enddo
      endif
     !
    endsubroutine calc_diff_visc_coef
!***********************************************************************
    subroutine calc_therm_diffus_coef(f)
!
!  Calculate the thermal diffusion coefficient based on equation 5-17 in
!  the Chemkin theory manual
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,nchemspec) :: species_cond
      real, dimension(mx) :: tmp_val,ZZ,FF,tmp_sum, tmp_sum2
      real, dimension(mx) :: AA,BB,  f_tran, f_rot, f_vib
      real, dimension(mx) :: Cv_vib_R,T_st, pi_1_5, pi_2
      real :: Cv_rot_R, Cv_tran_R
      intent(in) :: f
      integer :: j2,j3,k
!
!        call timing('calc_therm_diffus_coef','just entered')
!
        pi_1_5=pi**1.5
        pi_2=pi**2.
!
        do j3=nn1,nn2
        do j2=mm1,mm2
          tmp_sum=0.
          tmp_sum2=0.
          do k=1,nchemspec
!
! Check if the molecule is a single atom (0), linear (1) or non-linear (2).
!
            if (tran_data(k,1)==0.) then
              Cv_tran_R=1.5
              Cv_rot_R=0.
              Cv_vib_R=0.
            elseif (tran_data(k,1)==1.) then
              Cv_tran_R=1.5
              Cv_rot_R=1.
              Cv_vib_R=cv_R_spec_full(:,j2,j3,k)-2.5
            elseif (tran_data(k,1)==2.) then
              Cv_tran_R=1.5
              Cv_rot_R=1.5
              Cv_vib_R=cv_R_spec_full(:,j2,j3,k)-3.
            endif
!
! The rotational and vibrational contributions are zero for the single
! atom molecules but not for the linear or non-linear molecules
!
            if (tran_data(k,1)>0. .and. (.not. lfix_Sc)) then
              tmp_val=Bin_Diff_coef(:,j2,j3,k,k)*rho_full(:,j2,j3)&
                  /species_viscosity(:,j2,j3,k)
              AA=2.5-tmp_val
              T_st=tran_data(k,2)/298.
              FF=1.+pi_1_5/2.*(T_st)**0.5+(pi_2/4.+2.) &
                  *(T_st)+pi_1_5*(T_st)**1.5
              ZZ=tran_data(k,6)*FF
              T_st=tran_data(k,2)/TT_full(:,j2,j3)
              FF=1.+pi_1_5/2.*(T_st)**0.5+(pi_2/4.+2.) &
                  *(T_st)+pi_1_5*(T_st)**1.5
              ZZ=ZZ/FF
              BB=ZZ+2./pi*(5./3.*Cv_rot_R+tmp_val)
              f_tran=2.5*(1.- 2./pi*Cv_rot_R/Cv_tran_R*AA/BB)
              f_rot=tmp_val*(1+2./pi*AA/BB)
              f_vib=tmp_val
            else
              f_tran=2.5
              f_rot =0.0
              f_vib =0.0
            endif
            species_cond(:,j2,j3,k)=(species_viscosity(:,j2,j3,k)) &
                /(species_constants(k,imass)/unit_mass)*Rgas* &
                (f_tran*Cv_tran_R+f_rot*Cv_rot_R  &
                +f_vib*Cv_vib_R)
!
! tmp_sum and tmp_sum2 are used later to find the mixture averaged
! conductivity.
!
            tmp_sum=tmp_sum  &
                +XX_full(:,j2,j3,k)*species_cond(:,j2,j3,k)
            tmp_sum2=tmp_sum2 &
                +XX_full(:,j2,j3,k)/species_cond(:,j2,j3,k)
          enddo
!
! Find the mixture averaged conductivity
!
          where (tmp_sum2<=0.)
            lambda_full(:,j2,j3)=0.
          elsewhere
            lambda_full(:,j2,j3)=0.5*(tmp_sum+1./tmp_sum2)
          endwhere
        enddo
        enddo
!
      call keep_compiler_quiet(f)
      call timing('calc_therm_diffus_coef','just finished')
!
      call keep_compiler_quiet(f)
!
    endsubroutine calc_therm_diffus_coef
!***********************************************************************
    subroutine calc_diffusion_term(f,p)
!
!  Calculate diffusion term, p%DYDt_diff
!
      use Sub, only: del2,grad,dot_mn
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
      real, dimension (nx) :: Xk_Yk
      real, dimension (nx,3) :: gDiff_full_add, gchemspec, gXk_Yk
      real, dimension (nx) :: del2chemspec
      real, dimension (nx) :: diff_op,diff_op1,diff_op2,del2XX,  del2lnpp!del2pp,
      real, dimension (nx) :: glnpp_gXkYk,glnrho_glnpp,gD_glnpp, glnpp_glnpp
      real :: diff_k
      integer :: k,i
!
      intent(in) :: f
!
      p%DYDt_diff=0.
      diff_k=chem_diff
!
!  Loop over all chemical species.
!
      do k=1,nchemspec
!
!  Simple chemistry (not using ChemKin formalism).
!  Eliminate need for p%glnrho if density is not included.
!
        if (.not. lcheminp) then
          if (chem_diff/=0.) then
            diff_k=chem_diff*chem_diff_prefactor(k)
            if (headtt) print*,'dchemistry_dt: k,diff_k=',k,diff_k
            call del2(f,ichemspec(k),del2chemspec)
            call grad(f,ichemspec(k),gchemspec)
            if (ldensity) then
              call dot_mn(p%glnrho,gchemspec,diff_op)
              diff_op=diff_op+del2chemspec
            else
              diff_op=del2chemspec
            endif
            p%DYDt_diff(:,k)=diff_k*diff_op
          endif
        else
!
          if (ldiffusion) then
            call del2(XX_full(:,:,:,k),del2XX)
            call dot_mn(p%glnrho,p%gXXk(:,:,k),diff_op1)
!
            if (lDiff_simple) then
              do i=1,3
                gDiff_full_add(:,i)=species_constants(k,imass)/unit_mass* &
                    p%Diff_penc_add(:,k) &
                    *((p%glnTT(:,i)+p%glnrho(:,i))*(0.7-1.) &
                    *mu1_full(l1:l2,m,n)+p%gmu1(:,i))
              enddo
            else
              call grad(Diff_full_add(:,:,:,k),gDiff_full_add)
            endif
            call dot_mn(gDiff_full_add,p%gXXk(:,:,k),diff_op2)
!
! Neglect terms including pressure gradients for the simplified diffusion
!
           if (.not. lDiff_simple) then
             call dot_mn(p%glnpp,p%glnpp,glnpp_glnpp)
             do i=1,3
               gXk_Yk(:,i)=p%gXXk(:,i,k)-p%gYYk(:,i,k)
             enddo
             del2lnpp=p%del2pp/p%pp-glnpp_glnpp
             Xk_Yk=XX_full(l1:l2,m,n,k)-f(l1:l2,m,n,ichemspec(k))
             call dot_mn(p%glnrho,p%glnpp,glnrho_glnpp)
             call dot_mn(gDiff_full_add,p%glnpp,gD_glnpp)
             call dot_mn(gXk_Yk,p%glnpp,glnpp_gXkYk)
           endif
          endif
!
          if (lDiff_simple) then
! Have removed all terms including pressure gradients as these are supposed
! to be small and not required for such as crude approxiamtion as the simplified
! diffustion method.
           p%DYDt_diff(:,k)=p%Diff_penc_add(:,k)*(del2XX+diff_op1)+diff_op2
          else
           p%DYDt_diff(:,k)=Diff_full_add(l1:l2,m,n,k)*(del2XX+diff_op1)+diff_op2 &
           +Diff_full_add(l1:l2,m,n,k)*Xk_Yk(:)*del2lnpp &
           +Diff_full_add(l1:l2,m,n,k)*Xk_Yk(:)*glnrho_glnpp &
           +Xk_Yk(:)*gD_glnpp+Diff_full_add(l1:l2,m,n,k)*glnpp_gXkYk
          endif
        endif
      enddo
!
    endsubroutine calc_diffusion_term
!***********************************************************************
    subroutine calc_heatcond_chemistry(f,df,p)
!
!  Calculate gamma*chi*(del2lnT+gradlnTT.grad(lnT+lnrho+lncp+lnchi))
!
!  29-feb-08/natalia: coded
!
      use Sub, only: dot
!
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(mx,my,mz,mvar) :: df
      type (pencil_case) :: p
      real, dimension(nx) :: g2TT, g2TTlambda=0., tmp1
!
!
     if (ltemperature_nolog) then
      call dot(p%gTT,p%glambda,g2TTlambda)
     else
      call dot(p%glnTT,p%glambda,g2TTlambda)
      call dot(p%glnTT,p%glnTT,g2TT)
     endif
!
!  Add heat conduction to RHS of temperature equation
!
    !  if (l1step_test) then
    !   tmp1= p%lambda(:)*(p%del2lnTT+g2TT)*p%cv1/p%rho(:)
    !  else
    !   tmp1= (p%lambda(:)*(p%del2lnTT+g2TT)+g2TTlnlambda)*p%cv1/p%rho(:)
    !  endif
      if (l1step_test) then
       tmp1= p%lambda(:)*(p%del2lnTT+g2TT)*p%cv1/p%rho(:)
      else
      if (ltemperature_nolog) then
       tmp1= (p%lambda(:)*p%del2lnTT+g2TTlambda)*p%cv1/p%rho(:)
       df(l1:l2,m,n,iTT) = df(l1:l2,m,n,iTT) + tmp1
      else
       tmp1= (p%lambda(:)*(p%del2lnTT+g2TT)+g2TTlambda)*p%cv1/p%rho(:)
       df(l1:l2,m,n,ilnTT) = df(l1:l2,m,n,ilnTT) + tmp1
      endif
      endif
!
!      df(l1:l2,m,n,ilnTT) = df(l1:l2,m,n,ilnTT) + tmp1
!
!      RHS_T_full(l1:l2,m,n)=RHS_T_full(l1:l2,m,n) + tmp1
!
      call keep_compiler_quiet(f)
!
    endsubroutine calc_heatcond_chemistry
!***********************************************************************
   subroutine get_RHS_Y_full(RHS_Y)
!
      real, dimension (mx,my,mz,nchemspec) :: RHS_Y
      intent(out) :: RHS_Y
!
      RHS_Y=RHS_Y_full
!
    endsubroutine get_RHS_Y_full
!***********************************************************************
   subroutine get_cs2_full(cs2_full)
!
      real, dimension (mx,my,mz) :: cs2_full
      intent(out) :: cs2_full
      integer :: j,k
!
     do j=1,my
     do k=1,mz
      if (minval(cv_full(:,j,k))<=0) then
       cs2_full(:,j,k)=0.
      else
       cs2_full(:,j,k)=cp_full(:,j,k)/cv_full(:,j,k)*mu1_full(:,j,k)*TT_full(:,j,k)*Rgas
      endif
     enddo
     enddo
!
    endsubroutine get_cs2_full
!***********************************************************************
   subroutine get_cs2_slice(slice,dir,index)
!
! Find a slice of the speed of sound
!
! 2009.12.10: Nils Erland L. Haugen (coded)
!
      real, dimension (:,:), intent(out) :: slice
      integer, intent(in) :: index, dir
!
      if (dir==1) then
        slice=cp_full(index,m1:m2,n1:n2)/cv_full(index,m1:m2,n1:n2)&
            *mu1_full(index,m1:m2,n1:n2)*TT_full(index,m1:m2,n1:n2)*Rgas
      elseif (dir==2) then
        slice=cp_full(l1:l2,index,n1:n2)/cv_full(l1:l2,index,n1:n2)&
            *mu1_full(l1:l2,index,n1:n2)*TT_full(l1:l2,index,n1:n2)*Rgas
      elseif (dir==3) then
        slice=cp_full(l1:l2,m1:m2,index)/cv_full(l1:l2,m1:m2,index)&
            *mu1_full(l1:l2,m1:m2,index)*TT_full(l1:l2,m1:m2,index)*Rgas
      else
        call fatal_error('get_cs2_slice','No such dir!')
      endif
!
    endsubroutine get_cs2_slice
!***********************************************************************
    subroutine get_gamma_full(gamma_full)
!
      real, dimension (mx,my,mz) :: gamma_full
      intent(out) :: gamma_full
      integer :: j,k
!
      do j=1,my
      do k=1,mz
       if (minval(cv_full(:,j,k))<=0) then
        gamma_full(:,j,k)=0.
       else
        gamma_full(:,j,k)=cp_full(:,j,k)/cv_full(:,j,k)
       endif
      enddo
      enddo
    endsubroutine get_gamma_full
!***********************************************************************
    subroutine get_gamma_slice(slice,dir,index)
!
!  Get a 2D slice of gamma
!
!  2009.12.10: Nils Erland L. Haugen (coded)
!
      real, dimension (:,:), intent(out)  :: slice
      integer, intent(in) :: index, dir
!
      if (dir==1) then
        slice=cp_full(index,m1:m2,n1:n2)/cv_full(index,m1:m2,n1:n2)
      elseif (dir==2) then
        slice=cp_full(l1:l2,index,n1:n2)/cv_full(l1:l2,index,n1:n2)
      elseif (dir==3) then
        slice=cp_full(l1:l2,m1:m2,index)/cv_full(l1:l2,m1:m2,index)
      else
        call fatal_error('get_gamma_slice','No such dir!')
      endif
      !
    endsubroutine get_gamma_slice
!***********************************************************************
    subroutine air_field(f)
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz) :: sum_Y
!
      logical :: emptyfile=.true.
      logical :: found_specie
      integer :: file_id=123, ind_glob, ind_chem
      character (len=80) :: ChemInpLine
      character (len=10) :: specie_string
      character (len=1)  :: tmp_string
      integer :: i,j,k=1
      real :: YY_k, air_mass, TT=300., PP=1.013e6 ! (in dynes = 1atm)
      real, dimension(nchemspec)    :: stor2
      integer, dimension(nchemspec) :: stor1
!
      integer :: StartInd,StopInd,StartInd_1,StopInd_1
      integer :: iostat
!
      air_mass=0.
      StartInd_1=1; StopInd_1 =0
      open(file_id,file="air.dat")
!
      if (lroot) print*, 'the following parameters and '//&
          'species are found in air.dat (volume fraction fraction in %): '
!
      dataloop: do
!
        read(file_id,'(80A)',IOSTAT=iostat) ChemInpLine
        if (iostat < 0) exit dataloop
        emptyFile=.false.
        StartInd_1=1; StopInd_1=0
        StopInd_1=index(ChemInpLine,' ')
        specie_string=trim(ChemInpLine(1:StopInd_1-1))
        tmp_string=trim(ChemInpLine(1:1))
!
        if (tmp_string == '!' .or. tmp_string == ' ') then
        elseif (tmp_string == 'T') then
          StartInd=1; StopInd =0
!
          StopInd=index(ChemInpLine(StartInd:),' ')+StartInd-1
          StartInd=verify(ChemInpLine(StopInd:),' ')+StopInd-1
          StopInd=index(ChemInpLine(StartInd:),' ')+StartInd-1
!
          read (unit=ChemInpLine(StartInd:StopInd),fmt='(E14.7)'), TT
          if (lroot) print*, ' Temperature, K   ', TT
!
        elseif (tmp_string == 'P') then
!
          StartInd=1; StopInd =0
!
          StopInd=index(ChemInpLine(StartInd:),' ')+StartInd-1
          StartInd=verify(ChemInpLine(StopInd:),' ')+StopInd-1
          StopInd=index(ChemInpLine(StartInd:),' ')+StartInd-1
!
          read (unit=ChemInpLine(StartInd:StopInd),fmt='(E14.7)'), PP
          if (lroot) print*, ' Pressure, Pa   ', PP
!
        else
!
          call find_species_index(specie_string,ind_glob,ind_chem,found_specie)
!
          if (found_specie) then
!
            StartInd=1; StopInd =0
!
            StopInd=index(ChemInpLine(StartInd:),' ')+StartInd-1
            StartInd=verify(ChemInpLine(StopInd:),' ')+StopInd-1
            StopInd=index(ChemInpLine(StartInd:),' ')+StartInd-1
            read (unit=ChemInpLine(StartInd:StopInd),fmt='(E15.8)'), YY_k
            if (lroot) print*, ' volume fraction, %,    ', YY_k, &
                species_constants(ind_chem,imass)
!
            if (species_constants(ind_chem,imass)>0.) then
             air_mass=air_mass+YY_k*0.01/species_constants(ind_chem,imass)
            endif
!
            if (StartInd==80) exit
!
            stor1(k)=ind_chem
            stor2(k)=YY_k
            k=k+1
          endif
!
        endif
      enddo dataloop
!
!  Stop if air.dat is empty
!
      if (emptyFile)  call stop_it('The input file tran.dat was empty!')
      air_mass=1./air_mass
!
      do j=1,k-1
        f(:,:,:,ichemspec(stor1(j)))=stor2(j)*0.01
!
      enddo
!
      sum_Y=0.
!
      do j=1,nchemspec
        sum_Y=sum_Y+f(:,:,:,ichemspec(j))
      enddo
      do j=1,nchemspec
        f(:,:,:,ichemspec(j))=f(:,:,:,ichemspec(j))/sum_Y
        initial_massfractions(j)=f(l1,m1,n1,ichemspec(j))
      enddo
!
      if (mvar < 5) then
        call fatal_error("air_field", "I can only set existing fields")
      endif
!
      if (.not. reinitialize_chemistry) then
      if (.not. lflame_front)  then
        if (ltemperature_nolog) then
          f(:,:,:,iTT)=TT
        else
          f(:,:,:,ilnTT)=log(TT)!+f(:,:,:,ilnTT)
        endif
        if (ldensity_nolog) then
          f(:,:,:,ilnrho)=(PP/(k_B_cgs/m_u_cgs)*&
            air_mass/TT)/unit_mass*unit_length**3
        else
          f(:,:,:,ilnrho)=log((PP/(k_B_cgs/m_u_cgs)*&
            air_mass/TT)/unit_mass*unit_length**3)
        endif
        f(:,:,:,iux)=f(:,:,:,iux)+init_ux
      endif
      endif
!
      if (linit_velocity) then
        if (init_ux /=0.) then
!        do i=1,mx
!         f(i,:,:,iux)= &
!          (x(i)-xyz0(1))/Lxyz(1)*(0.-init_ux)+init_ux
!        enddo
         do i=1,my
           f(:,i,:,iux)=sin(2.*PI*y(i)/Lxyz(2))*init_ux
         enddo
!
        endif
        if (init_uy /=0.) then
          do i=1,my
          if (y(i)>0) then
            f(:,i,:,iuy)=f(:,i,:,iuy) &
                        +init_uy*(2.*y(i)/Lxyz(2))**2
          else
            f(:,i,:,iuy)=f(:,i,:,iuy) &
                        -init_uy*(2.*y(i)/Lxyz(2))**2
          endif
          enddo
        endif
        if (init_uz /=0.) then
          do i=1,mz
          if (z(i)>0) then
            f(:,:,i,iuz)=f(:,:,i,iuz) &
                        +init_uz*(2.*z(i)/Lxyz(3))**2
          else
            f(:,:,i,iuz)=f(:,:,i,iuz) &
                        -init_uz*(2.*z(i)/Lxyz(3))**2
          endif
          enddo
        endif
      endif
!
      if (linit_temperature) then
        do i=1,mx
        if (x(i)<=init_x1) then
          f(i,:,:,ilnTT)=log(init_TT1)
        endif
        if (x(i)>=init_x2) then
          f(i,:,:,ilnTT)=log(init_TT2)
        endif
        if (x(i)>init_x1 .and. x(i)<init_x2) then
          f(i,:,:,ilnTT)=&
             log((x(i)-init_x1)/(init_x2-init_x1) &
             *(init_TT2-init_TT1)+init_TT1)
        endif
        enddo
      endif
!
      if (linit_density) then
!        do i=1,mx
!          f(i,:,:,ilnrho)= &
!          (x(i)-xyz0(1))/Lxyz(1)*(alog(init_rho2)-alog(init_rho)) &
!          +alog(init_rho)
!        enddo
        if (ldensity_nolog) then
          f(:,:,:,ilnrho)=(PP/(k_B_cgs/m_u_cgs)*&
            air_mass/exp(f(:,:,:,ilnTT)))/unit_mass*unit_length**3
        else
          f(:,:,:,ilnrho)=log((PP/(k_B_cgs/m_u_cgs)*&
            air_mass/exp(f(:,:,:,ilnTT)))/unit_mass*unit_length**3)
        endif
!
      endif
!
      if (lroot) print*, 'Air temperature, K', TT
      if (lroot) print*, 'Air pressure, dyn', PP
      if (lroot) print*, 'Air density, g/cm^3:'
      if (lroot) print '(E10.3)',  PP/(k_B_cgs/m_u_cgs)*air_mass/TT
      if (lroot) print*, 'Air mean weight, g/mol', air_mass
      if (lroot) print*, 'R', k_B_cgs/m_u_cgs
!
      close(file_id)
!
    endsubroutine air_field
!***********************************************************************
!          NSCBC boundary conditions
!***********************************************************************
    subroutine damp_zone_for_NSCBC(f,df)
!
!   16-jul-06/natalia: coded
!    buffer zone to damp the acustic waves!!!!!!!!!!!
!    important for NSCBC
!
      real, dimension (mx,my,mz,mvar+maux), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      real, dimension (mx) :: func_x
      integer :: j,  sz_l_x,sz_r_x,  sz_l_y,sz_r_y, sz_l_z,sz_r_z,ll1,ll2
      real :: dt1, func_y,func_z, ux_ref,uy_ref,uz_ref,lnTT_ref,lnrho_ref
      real :: del
      logical :: lzone_y=.false.,lzone_z=.false.
!
       dt1=1./dt
       del=0.1
!
       ux_ref=0.
       uy_ref=0.
       uz_ref=0.
!      lnTT_ref=6.39693
       lnTT_ref=log(init_TT1)
!
      lnrho_ref=&
         log(init_pressure)-log(Rgas)-lnTT_ref-log(mu1_full(l1,m1,n1))
!
       sz_r_x=l2-int(del*nxgrid)
       sz_l_x=int(del*nxgrid)+l1
       sz_r_y=m2-int(del*nygrid)
       sz_l_y=int(del*nygrid)+m1
       sz_r_z=n2-int(del*nzgrid)
       sz_l_z=int(del*nzgrid)+n1
       ll1=l1
       ll2=l2

       if (nxgrid/=1) then
!
        if (sz_r_x<=l1) call fatal_error('to use ldamp_zone_NSCBC',&
                  'you should increase nxgrid!')
!
        do j=1,2

         if (j==1) then
          ll1=sz_r_x
          ll2=l2
          func_x(ll1:ll2)=(x(ll1:ll2)-x(ll1))**3/(x(ll2)-x(ll1))**3
         elseif (j==2) then
          ll1=l1+1
          ll2=sz_l_x
          func_x(ll1:ll2)=(x(ll1:ll2)-x(ll2))**3/(x(ll1)-x(ll2))**3
         endif
!
          df(ll1:ll2,m,n,iux)=df(ll1:ll2,m,n,iux)&
            -func_x(ll1:ll2)*(f(ll1:ll2,m,n,iux)-ux_ref)*dt1
          df(ll1:ll2,m,n,iuy)=df(ll1:ll2,m,n,iuy)&
            -func_x(ll1:ll2)*(f(ll1:ll2,m,n,iuy)-uy_ref)*dt1
          df(ll1:ll2,m,n,iuz)=df(ll1:ll2,m,n,iuz)&
            -func_x(ll1:ll2)*(f(ll1:ll2,m,n,iuz)-uz_ref)*dt1
          df(ll1:ll2,m,n,ilnrho)=df(ll1:ll2,m,n,ilnrho)&
            -func_x(ll1:ll2)*(f(ll1:ll2,m,n,ilnrho)-lnrho_ref)*dt1
          df(ll1:ll2,m,n,ilnTT)=df(ll1:ll2,m,n,ilnTT)&
            -func_x(ll1:ll2)*(f(ll1:ll2,m,n,ilnTT)-lnTT_ref)*dt1
!
        enddo
       endif

       if (nygrid/=1) then
!
       if (sz_r_y<=m1) call fatal_error('to use ldamp_zone_NSCBC',&
                  'you should increase nygrid!')
!
       if ((m<=sz_l_y) .and. (m>=m1)) then
        func_y=(y(m)-y(sz_l_y))**3/(y(m1)-y(sz_l_y))**3
        lzone_y=.true.
       elseif ((m>=sz_r_y) .and. (m<=m2)) then
        func_y= (y(m)-y(sz_r_y))**3/(y(m2)-y(sz_r_y))**3
        lzone_y=.true.
       endif

       if (lzone_y) then
        df(sz_l_x:sz_r_x,m,n,iux)=df(sz_l_x:sz_r_x,m,n,iux)&
           -func_y*(f(sz_l_x:sz_r_x,m,n,iux)-ux_ref)*dt1
        df(sz_l_x:sz_r_x,m,n,iuy)=df(sz_l_x:sz_r_x,m,n,iuy)&
           -func_y*(f(sz_l_x:sz_r_x,m,n,iuy)-uy_ref)*dt1
        df(sz_l_x:sz_r_x,m,n,iuz)=df(sz_l_x:sz_r_x,m,n,iuz)&
           -func_y*(f(sz_l_x:sz_r_x,m,n,iuz)-uz_ref)*dt1
        df(sz_l_x:sz_r_x,m,n,ilnrho)=df(sz_l_x:sz_r_x,m,n,ilnrho)&
           -func_y*(f(sz_l_x:sz_r_x,m,n,ilnrho)-lnrho_ref)*dt1
        df(sz_l_x:sz_r_x,m,n,ilnTT)=df(sz_l_x:sz_r_x,m,n,ilnTT)&
           -func_y*(f(sz_l_x:sz_r_x,m,n,ilnTT)-lnTT_ref)*dt1
        lzone_y=.false.
       endif
       endif
!
      if (nzgrid/=1) then
        if (sz_r_z<=n1) call fatal_error('to use ldamp_zone_NSCBC',&
                  'you should increase nzgrid!')

      if ((n<=sz_l_z) .and. (n>=n1)) then
        func_z=(z(n)-z(sz_l_z))**3/(z(n1)-z(sz_l_z))**3
        lzone_z=.true.
       elseif ((n>=sz_r_z) .and. (n<=n2)) then
        func_z= (z(n)-z(sz_r_z))**3/(z(n2)-z(sz_r_z))**3
        lzone_z=.true.
       endif

       if (lzone_z) then
        df(sz_l_x:sz_r_x,m,n,iux)=df(sz_l_x:sz_r_x,m,n,iux)&
           -func_z*(f(sz_l_x:sz_r_x,m,n,iux)-ux_ref)*dt1
        df(sz_l_x:sz_r_x,m,n,iuy)=df(sz_l_x:sz_r_x,m,n,iuy)&
           -func_z*(f(sz_l_x:sz_r_x,m,n,iuy)-uy_ref)*dt1
        df(sz_l_x:sz_r_x,m,n,iuz)=df(sz_l_x:sz_r_x,m,n,iuz)&
           -func_z*(f(sz_l_x:sz_r_x,m,n,iuz)-uz_ref)*dt1
        df(sz_l_x:sz_r_x,m,n,ilnrho)=df(sz_l_x:sz_r_x,m,n,ilnrho)&
           -func_z*(f(sz_l_x:sz_r_x,m,n,ilnrho)-lnrho_ref)*dt1
        df(sz_l_x:sz_r_x,m,n,ilnTT)=df(sz_l_x:sz_r_x,m,n,ilnTT)&
           -func_z*(f(sz_l_x:sz_r_x,m,n,ilnTT)-lnTT_ref)*dt1
        lzone_z=.false.
       endif
       endif
!
     endsubroutine damp_zone_for_NSCBC
!***********************************************************************
    subroutine jacobn(f,jacob)
!
! Compute the jacobian, i.e. the matrix  jacob(nchemspec x nchemspec)
! where jacob(i,j)=dv_i/dc_j
! v is the vector of dimension nchemspec of the rates dc_j/dt
! (the c_j being concentrations, stocked in f among other)
!
!  28-may-09/rplasson: coded
!
!   exchange data
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(mx,my,mz,nchemspec,nchemspec) :: jacob
!
      intent(in) :: f
      intent(out) :: jacob
!   internal data
!
!   indices
      integer :: i,j,k,l,ii
!
!   temporary
      real :: tmp_p,tmp_m
!   Code
!
      jacob=0.
!
!  identify module
!
      if (headtt.or.ldebug) print*,'jacobn: compute the jacobian matrix'
!
      if (lreactions) then
        do n=n1,n2; do m=m1,m2;do l=l1,l2
          do i=1,nchemspec
            do j=1,nchemspec
              ! Compute dv_i/dc_j
!              print*,"dv_",i,"/dc_",j,"="
              do k=1,nreactions
                ! Check if compound i participate in reaction k
                if (Sijp(i,k)/=Sijm(i,k)) then
                  ! Compute the contribution of reaction k to dv_i/dc_j
!                  print*,"+(",(Sijp(i,k)-Sijm(i,k)),"k_",k,"(+/-)"
                  tmp_p=(Sijp(i,k)-Sijm(i,k))*kreactions_p(k)*kreactions_z(n,k)
                  tmp_m=(Sijm(i,k)-Sijp(i,k))*kreactions_m(k)*kreactions_z(n,k)
                  do  ii=1,nchemspec
                    ! Compute the contribution of compound ii in reaction k
!                    print*,"**-",Sijm(ii,k),Sijp(ii,k),"-**"
                    if (ii/=j) then
!                      print*,"c_",ii,"^",Sijm(ii,k)," (/) ","c_",ii,"^",Sijp(ii,k)
                      tmp_p=tmp_p*f(l,m,n,ichemspec(ii))**Sijm(ii,k)
                      tmp_m=tmp_m*f(l,m,n,ichemspec(ii))**Sijp(ii,k)
                    else
                      if (Sijm(ii,k)==0) then
!                        print*,"0*c_",ii
                        tmp_p=0.
                      elseif (Sijm(ii,k)>1) then
!                        print*,Sijm(ii,k),"*c_",ii,"^",(Sijm(ii,k)-1)
                        tmp_p=Sijm(ii,k)*tmp_p*f(l,m,n,ichemspec(ii))**(Sijm(ii,k)-1)
!                      else
!                        print*,"c_",ii,"^0"
                      endif
!                      print*," (/) "
                      if (Sijp(ii,k)==0) then
!                        print*,"0*c_",ii
                        tmp_m=0.
                      elseif (Sijp(ii,k)>1) then
!                        print*,Sijp(ii,k),"*c_",ii,"^",(Sijp(ii,k)-1)
                        tmp_m=Sijp(ii,k)*tmp_m*f(l,m,n,ichemspec(ii))**(Sijp(ii,k)-1)
!                      else
!                        print*,"c_",ii,"^0"
                      endif
                    endif
                  enddo
!                  print*,")"
                  ! Add the contribution of reaction k to dv_i/dc_j
                  jacob(l,m,n,i,j)=jacob(l,m,n,i,j)+tmp_p+tmp_m
!                  print*,"(=",tmp_p," (-) ",tmp_m,")"
                endif
              enddo
            enddo
          enddo
        enddo; enddo; enddo
      endif
!
    endsubroutine jacobn
!***********************************************************************
    subroutine get_mu1_slice(slice,grad_slice,index,sgn,direction)
!
! For the NSCBC boudary conditions the slice of mu1 at the boundary, and
! its gradient, is required.
!
! 2009.12.10: Nils Erland L. Haugen (coded)
!
      use Deriv, only: der_onesided_4_slice_other
!
      real, dimension(:,:), intent(out)   :: slice
      real, dimension(:,:), intent(out) :: grad_slice
      integer, intent(in) :: index, sgn, direction
!
      if (direction==1) then
        slice=mu1_full(index,m1:m2,n1:n2)
        call der_onesided_4_slice_other(mu1_full,sgn,grad_slice,index,direction)
      elseif (direction==2) then
        slice=mu1_full(l1:l2,index,n1:n2)
        call der_onesided_4_slice_other(mu1_full,sgn,grad_slice,index,direction)
      else
        slice=mu1_full(l1:l2,m1:m2,index)
        call der_onesided_4_slice_other(mu1_full,sgn,grad_slice,index,direction)
      endif
!
    end subroutine get_mu1_slice
!***********************************************************************
  subroutine calc_extra_react(f,reac,kf_loc,i,mm,nn,p)
!
   !   character (len=*), intent(in) :: element_name
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case), intent(in) :: p
      integer, intent(in) :: reac, i, mm,nn
      real, intent(out) :: kf_loc
      real :: X_O2, X_N2, X_O2N2, X_M, X_H2O
      real :: K1,K2,K3,K4,KMT06
 !
!
      select case (reaction_name(reac))
      case ('O=O3')
         X_O2=f(l1+i-1,mm,nn,ichemspec(index_O2))*unit_mass &
                /species_constants(index_O2,imass)*p%rho(i)
         X_N2=f(l1+i-1,mm,nn,ichemspec(index_N2))*unit_mass &
                /species_constants(index_N2,imass)*p%rho(i)
         kf_loc=5.60D-34*X_O2*X_N2*((1./300.*p%TT(i))**(-2.6)) &
           +6.00D-34*X_O2**2*((1./300.*p%TT(i))**(-2.6))
       case ('O1D=O')
         X_O2=f(l1+i-1,mm,nn,ichemspec(index_O2))*unit_mass &
                /species_constants(index_O2,imass)*p%rho(i)
         X_N2=f(l1+i-1,mm,nn,ichemspec(index_N2))*unit_mass &
                /species_constants(index_N2,imass)*p%rho(i)
         kf_loc=3.20D-11*X_O2*exp(67.*p%TT1(i))+1.80D-11*X_N2*exp(107.*p%TT1(i))
       case ('OH+CO=HO2')
         X_O2N2=f(l1+i-1,mm,nn,ichemspec(index_O2N2))*unit_mass &
                /species_constants(index_O2N2,imass)*p%rho(i)
         kf_loc=1.30D-13*(1+((0.6*index_O2N2)/(2.652E+19*(300.*p%TT1(i)))))
       case ('2HO2=H2O2')
         X_M=p%rho(i)*mu1_full(l1+i-1,mm,nn)
         X_H2O=f(l1+i-1,mm,nn,ichemspec(index_H2O))*unit_mass &
                /species_constants(index_H2O,imass)*p%rho(i)
         KMT06=1 + (1.4E-21 * EXP(2200.*p%TT1(i)) * X_H2O)
         kf_loc= 2.20D-13*KMT06*EXP(600.*p%TT1(i)) &
                + 1.90D-33*X_M*KMT06*EXP(980.*p%TT1(i))
       case ('OH+HNO3=NO3')
         X_O2N2=f(l1+i-1,mm,nn,ichemspec(index_O2N2))*unit_mass &
                /species_constants(index_O2N2,imass)*p%rho(i)
         K1        =  2.4E-14 * EXP(460.*p%TT1(i))
         K3        =  6.5E-34 * EXP(1335.*p%TT1(i))
         K4        =  2.7E-17 * EXP(2199.*p%TT1(i))
         K2        =  (K3 * X_O2N2) / (1 + (K3*X_O2N2/K4))
         kf_loc= K1 + K2
       case default
        if (lroot) print*,'reaction_name=', reaction_name(reac)
        call stop_it('calc_extra_react: Element not found!')
      end select
!
    endsubroutine calc_extra_react
!***********************************************************************
    subroutine prerun_1D(f,prerun_dir)
!
!  read snapshot file, possibly with mesh and time (if mode=1)
!  11-apr-97/axel: coded
!
      character (len=*) :: prerun_dir
      character (len=100) :: file
      character (len=10) :: processor
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,7,7,mfarray) :: a
      integer :: j,k
!
! NILS: For the time beeing the prerun simulation can not have been run in parallell
! NILS: Should fix this soon.
!
      processor='proc0'
      file=trim(prerun_dir)//'/data/'//trim(processor)//'/var.dat'
      print*,'Reading inlet data from ',file
!
!  Open and read data from file
!
      open(1,FILE=file,FORM='unformatted')
      read(1) a
      close(1)
!
!  Spread the data on the f-array
!
      do j=1,my
        do k=1,mz
          f(:,j,k,iux)=f(:,j,k,iux)+a(:,m1,n1,iux)
          f(:,j,k,iuz+1:mvar)=a(:,m1,n1,iuz+1:mvar)
        enddo
      enddo
!
!  Set the y and z velocities to zero in order to avoid random noise
!
      if (.not. reinitialize_chemistry) then
        f(:,:,:,iuy:iuz)=0
      endif
!
    endsubroutine prerun_1D
!***********************************************************************
  subroutine chemistry_clean_up()
!
  if (allocated(Bin_diff_coef))  deallocate(Bin_diff_coef)
  if (allocated(stoichio))       deallocate(stoichio)
  if (allocated(Sijm))           deallocate(Sijm)
  if (allocated(Sijp))           deallocate(Sijp)
  if (allocated(kreactions_z))   deallocate(kreactions_z)
  if (allocated(kreactions_m))   deallocate(kreactions_m)
  if (allocated(kreactions_p))   deallocate(kreactions_p)
  if (allocated(reaction_name))  deallocate(reaction_name)
  if (allocated(B_n))            deallocate(B_n)
  if (allocated(alpha_n))        deallocate(alpha_n)
  if (allocated(E_an))           deallocate(E_an)
  if (allocated(low_coeff))      deallocate(low_coeff)
  if (allocated(high_coeff))     deallocate(high_coeff)
  if (allocated(troe_coeff))     deallocate(troe_coeff)
  if (allocated(a_k4))           deallocate(a_k4)
  if (allocated(Mplus_case))     deallocate(Mplus_case)
  if (allocated(photochem_case)) deallocate(photochem_case)
  if (allocated(net_react_m))    deallocate(net_react_m)
  if (allocated(net_react_p))    deallocate(net_react_p)
!
  endsubroutine chemistry_clean_up
!***********************************************************************
endmodule Chemistry
