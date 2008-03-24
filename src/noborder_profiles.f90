! $Id: noborder_profiles.f90,v 1.10 2008-03-24 22:57:17 wlyra Exp $
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lborder_profiles = .false.
!
! PENCILS PROVIDED rborder_mn
!
!***************************************************************

module BorderProfiles

  use Cparam
  use Cdata

  implicit none

  private

  include 'border_profiles.h'
!

  contains

!***********************************************************************
    subroutine initialize_border_profiles()
!
!  Position-dependent quenching factor that multiplies rhs of pde
!  by a factor that goes gradually to zero near the boundaries.
!  border_frac is a 3-D array, separately for all three directions.
!  border_frac=1 would affect everything between center and border.
!
      use Messages
!
      if (border_frac_x(1)/=0.0.or.border_frac_x(2)/=0.0) then
        if (lroot) then
          print*, 'initialize_border_profiles: must use '// &
              'BORDER_PROFILES =   border_profiles'
          print*, '                            for border_frac_x'
        endif
        call fatal_error('initialize_border_profiles','')
      endif
      if (border_frac_y(1)/=0.0.or.border_frac_y(2)/=0.0) then
        if (lroot) then
          print*, 'initialize_border_profiles: must use '// &
              'BORDER_PROFILES =   border_profiles'
          print*, '                            for border_frac_y'
        endif
        call fatal_error('initialize_border_profiles','')
      endif
      if (border_frac_z(1)/=0.0.or.border_frac_z(2)/=0.0) then
        if (lroot) then
          print*, 'initialize_border_profiles: must use '// &
              'BORDER_PROFILES =   border_profiles'
          print*, '                            for border_frac_z'
        endif
        call fatal_error('initialize_border_profiles','')
      endif
!
    endsubroutine initialize_border_profiles
!***********************************************************************
    subroutine pencil_criteria_borderprofiles()
!
!  All pencils that this module depends on are specified here.
!
!  DUMMY ROUTINE
!
    endsubroutine pencil_criteria_borderprofiles
!***********************************************************************
    subroutine calc_pencils_borderprofiles(f,p)
!
      use Sub, only: keep_compiler_quiet
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      if (lpencil(i_rborder_mn))  p%rborder_mn=0.
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(p)
!
    endsubroutine calc_pencils_borderprofiles
!***********************************************************************
    subroutine border_driving(f,df,p,f_target,j)
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (nx) :: f_target
      integer :: j
!
!  Dummy routine
!
      if (NO_WARN) print*,j,f,p,df,f_target
!
    endsubroutine border_driving
!***********************************************************************
    subroutine border_quenching(df,j)
!
      real, dimension (mx,my,mz,mvar) :: df
      integer :: j
!
!  Dummy routine
!
      if (NO_WARN) print*,j,df
!
    endsubroutine border_quenching
!***********************************************************************
endmodule BorderProfiles
