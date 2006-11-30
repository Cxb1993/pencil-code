! $Id: noradiation.f90,v 1.35 2006-11-30 09:03:36 dobler Exp $


!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
!***************************************************************

module Radiation

  use Cparam
  use Messages
  use Sub, only: keep_compiler_quiet

  implicit none

  include 'radiation.h'

  ! radiation turned off

  !namelist /radiation_init_pars/ dummyuu
  !namelist /radiation_run_pars/  dummyuu

  ! other variables (needs to be consistent with reset list below)
  integer :: idiag_frms=0,idiag_fmax=0,idiag_Erad_rms=0,idiag_Erad_max=0
  integer :: idiag_Egas_rms=0,idiag_Egas_max=0
  real :: DFF_new=0.

  contains

!***********************************************************************
    subroutine register_radiation()
!
!  15-jul-2002/nils: dummy routine
!
      use Cdata
      use Mpicomm
      use Sub
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_rad called twice')
      first = .false.
!
!  identify version number
!
      if (lroot) call cvs_id( &
           "$Id: noradiation.f90,v 1.35 2006-11-30 09:03:36 dobler Exp $")
!
    endsubroutine register_radiation
!***********************************************************************
    subroutine radtransfer(f)
!
!  Integration radioation transfer equation along rays
!
!  24-mar-03/axel+tobi: coded
!
      use Cdata
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      call keep_compiler_quiet(f)

    endsubroutine radtransfer
!***********************************************************************
    subroutine initialize_radiation()
!
!  Perform any post-parameter-read initialization i.e. calculate derived
!  parameters.
!
!  24-nov-02/tony: coded
!
!  do nothing
!
    endsubroutine initialize_radiation
!***********************************************************************
    subroutine radiative_cooling(f,df,p)

!  dummy routine
!
! 25-mar-03/axel+tobi: coded
!
      use Cdata
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
!
    endsubroutine radiative_cooling
!***********************************************************************
    subroutine radiative_pressure(f,df,p)
!
!  dummy routine
!
!  25-mar-03/axel+tobi: coded
!
      use Cdata
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
!
    endsubroutine radiative_pressure
!***********************************************************************
    subroutine output_radiation(lun)
!
      integer, intent(in) :: lun

      call keep_compiler_quiet(lun)

    endsubroutine output_radiation
!***********************************************************************
    subroutine init_rad(f,xx,yy,zz)
!
!  initialise radiation; called from start.f90
!  15-jul-2002/nils: dummy routine
!
      use Cdata
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz)      :: xx,yy,zz
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(xx,yy,zz)

    endsubroutine init_rad
!***********************************************************************
    subroutine pencil_criteria_radiation()
!
!  All pencils that the Radiation module depends on are specified here.
!
!  21-11-04/anders: coded
!
    endsubroutine pencil_criteria_radiation
!***********************************************************************
    subroutine pencil_interdep_radiation(lpencil_in)
!
!  Interdependency among pencils provided by the Radiation module
!  is specified here.
!
!  21-11-04/anders: coded
!
      logical, dimension (npencils) :: lpencil_in
!
      call keep_compiler_quiet(lpencil_in)
!
    endsubroutine pencil_interdep_radiation
!***********************************************************************
    subroutine calc_pencils_radiation(f,p)
!
!  Calculate Radiation pencils.
!  Most basic pencils should come first, as others may depend on them.
!
!  21-11-04/anders: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      intent(in) :: f,p
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(p)
!
    endsubroutine calc_pencils_radiation
!***********************************************************************
   subroutine de_dt(f,df,p,gamma)
!
!  15-jul-2002/nils: dummy routine
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
      real :: gamma
!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
      call keep_compiler_quiet(gamma)
!
    endsubroutine de_dt
!***********************************************************************
    subroutine read_radiation_init_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) call keep_compiler_quiet(iostat)
      call keep_compiler_quiet(unit)

    endsubroutine read_radiation_init_pars
!***********************************************************************
    subroutine write_radiation_init_pars(unit)
      integer, intent(in) :: unit

      call keep_compiler_quiet(unit)

    endsubroutine write_radiation_init_pars
!***********************************************************************
    subroutine read_radiation_run_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) call keep_compiler_quiet(iostat)
      call keep_compiler_quiet(unit)

    endsubroutine read_radiation_run_pars
!***********************************************************************
    subroutine write_radiation_run_pars(unit)
      integer, intent(in) :: unit

      call keep_compiler_quiet(unit)

    endsubroutine write_radiation_run_pars
!*******************************************************************
    subroutine rprint_radiation(lreset,lwrite)
!
!  reads and registers print parameters relevant for radiative part
!
!  16-jul-02/nils: adapted from rprint_hydro
!
      use Cdata
      use Sub
!
      logical :: lreset,lwr
      logical, optional :: lwrite
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
!  write column where which radiative variable is stored
!
      if (lwr) then
        write(3,*) 'i_frms=',idiag_frms
        write(3,*) 'i_fmax=',idiag_fmax
        write(3,*) 'i_Erad_rms=',idiag_Erad_rms
        write(3,*) 'i_Erad_max=',idiag_Erad_max
        write(3,*) 'i_Egas_rms=',idiag_Egas_rms
        write(3,*) 'i_Egas_max=',idiag_Egas_max
        write(3,*) 'nname=',nname
        write(3,*) 'ie=',ie
        write(3,*) 'ifx=',ifx
        write(3,*) 'ify=',ify
        write(3,*) 'ifz=',ifz
        write(3,*) 'iQrad=',iQrad
        write(3,*) 'ikapparho=',ikapparho
        write(3,*) 'iSrad=',iSrad
        write(3,*) 'ikappa=',ikappa
        write(3,*) 'ilnTT=',ilnTT
        write(3,*) 'iFrad=',iFrad
        write(3,*) 'iFradx=',iFradx
        write(3,*) 'iFrady=',iFrady
        write(3,*) 'iFradz=',iFradz
      endif
!
      call keep_compiler_quiet(lreset)

    endsubroutine rprint_radiation
!***********************************************************************
    subroutine get_slices_radiation(f,slices)
!
!  Write slices for animation of radiation variables.
!
!  26-jun-06/tony: dummy
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (slice_data) :: slices
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(slices)
!
    endsubroutine get_slices_radiation
!***********************************************************************
    subroutine  bc_ee_inflow_x(f,topbot)
!
!  Dummy routine
!
!  8-aug-02/nils: coded
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f
!
      if (ip==1) print*,topbot,f  !(to keep compiler quiet)
!
    end subroutine bc_ee_inflow_x
!***********************************************************************
    subroutine  bc_ee_outflow_x(f,topbot)
!
!  Dummy routine
!
!  8-aug-02/nils: coded
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f
!
      if (ip==1) print*,topbot,f  !(to keep compiler quiet)
!
    end subroutine bc_ee_outflow_x
!***********************************************************************
  endmodule Radiation
