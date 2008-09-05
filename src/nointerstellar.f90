! $Id$
!
!  Dummy module
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: linterstellar = .false.
!
!***************************************************************

module Interstellar

  use Cparam
  use Cdata
  use Messages
  use sub, only: keep_compiler_quiet

  implicit none

  include 'interstellar.h'

  !namelist /interstellar_init_pars/ dummy
  !namelist /interstellar_run_pars/ dummy

  contains

!***********************************************************************
    subroutine register_interstellar()
!
!  19-nov-02/tony: coded
!
      use Cdata
      use Mpicomm
      use Sub
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_nointerstellar called twice')
      first = .false.
!
!  identify version number
!
      if (lroot) call cvs_id( &
           "$Id$")
!
!      if (nvar > mvar) then
!        if (lroot) write(0,*) 'nvar = ', nvar, ', mvar = ', mvar
!        call stop_it('Register_nointerstellar: nvar > mvar')
!      endif
!
    endsubroutine register_interstellar
!***********************************************************************
    subroutine initialize_interstellar(lstarting)
!
!  Perform any post-parameter-read initialization eg. set derived
!  parameters
!
!  24-nov-02/tony: coded - dummy
!
      logical :: lstarting
!
! (to keep compiler quiet)
      if (NO_WARN) print*,lstarting
!
    endsubroutine initialize_interstellar
!***********************************************************************
    subroutine input_persistent_interstellar(id,lun,done)
!
!  Read in the stored time of the next SNI
!
      integer :: id,lun
      logical :: done
!
      if (NO_WARN) print*,id,lun,done
!
    endsubroutine input_persistent_interstellar
!***********************************************************************
    subroutine output_persistent_interstellar(lun)
!
!  Writes out the time of the next SNI
!
!
      integer :: lun
!
      if (NO_WARN) print*,lun
!
    endsubroutine output_persistent_interstellar
!***********************************************************************
    subroutine rprint_interstellar(lreset,lwrite)
!
!  reads and registers print parameters relevant to interstellar
!
!   1-jun-02/axel: adapted from magnetic fields
!
      use Cdata
      use Sub
!
!      integer :: iname
      logical :: lreset,lwr
      logical, optional :: lwrite
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
!  write column where which interstellar variable is stored
!
      if (lwr) then
        write(3,*) 'i_taucmin=0'
      endif
!
      if (NO_WARN) print*,lreset
!
    endsubroutine rprint_interstellar
!***********************************************************************
    subroutine get_slices_interstellar(f,slices)
!
!  Write slices for animation of particle variables.
!
!  26-jun-06/tony: dummy
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (slice_data) :: slices
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(slices%ready)
!
    endsubroutine get_slices_interstellar
!!***********************************************************************
    subroutine read_interstellar_init_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) call keep_compiler_quiet(iostat)
      call keep_compiler_quiet(unit)

    endsubroutine read_interstellar_init_pars
!***********************************************************************
    subroutine write_interstellar_init_pars(unit)
      integer, intent(in) :: unit

      call keep_compiler_quiet(unit)

endsubroutine write_interstellar_init_pars
!***********************************************************************
    subroutine read_interstellar_run_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) call keep_compiler_quiet(iostat)
      call keep_compiler_quiet(unit)

    endsubroutine read_interstellar_run_pars
!***********************************************************************
    subroutine write_interstellar_run_pars(unit)
      integer, intent(in) :: unit

      call keep_compiler_quiet(unit)

    endsubroutine write_interstellar_run_pars
!***********************************************************************
    subroutine init_interstellar(f)
!
!  initialise magnetic field; called from start.f90
!  30-jul-2006/tony: dummy routine
!
      use Cdata
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine init_interstellar
!***********************************************************************
    subroutine pencil_criteria_interstellar()
!
!  All pencils that the Interstellar module depends on are specified here.
!
!  26-03-05/tony: coded
!
!
!     DUMMY
!
    endsubroutine pencil_criteria_interstellar
!***********************************************************************
    subroutine interstellar_before_boundary(f)
!
!  This routine calculates and applies the optically thin cooling function
!  together with UV heating.
!
!  01-aug-06/tony: coded
!
      use Cparam
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine interstellar_before_boundary
!***********************************************************************
    subroutine calc_heat_cool_interstellar(f,df,p,Hmax)
!
!  adapted from calc_heat_cool
!
      use Cdata
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
      real, dimension (mx,my,mz,mvar), intent(in) :: df
      type (pencil_case), intent(in) :: p
      real, dimension(nx), intent(in) :: Hmax
!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
      call keep_compiler_quiet(Hmax)
!
    endsubroutine calc_heat_cool_interstellar
!***********************************************************************
    subroutine check_SN(f,df)
!
!  dummy routine for checking for SNe (interstellar)
!
    use Cdata
!
    real, dimension(mx,my,mz,mfarray) :: f
    real, dimension(mx,my,mz,mvar) :: df
!
    call keep_compiler_quiet(f,df)
!
    endsubroutine check_SN
!***********************************************************************
    subroutine calc_snr_unshock(penc)
!
      use Cdata
!
      real, dimension(mx), intent(inout) :: penc
!
      call keep_compiler_quiet(penc)
!
    endsubroutine calc_snr_unshock
!***********************************************************************
    subroutine calc_snr_damping(p)
!
      use Cdata
!
      type (pencil_case) :: p
!
      call keep_compiler_quiet(p)
!
    endsubroutine calc_snr_damping
!***********************************************************************
    subroutine calc_snr_damp_int(int_dt)
!
      use Cdata
      real :: int_dt
!
      call keep_compiler_quiet(int_dt)
!
    endsubroutine calc_snr_damp_int
!***********************************************************************

endmodule interstellar
