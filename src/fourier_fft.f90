! $Id: fourier_fft.f90,v 1.8 2008-03-27 22:26:25 nilshau Exp $
!
!  This module contains FFT wrapper subroutines.
!
module Fourier

  use Cdata
  use Cparam
  use Messages
  use Mpicomm, only: transp

  implicit none

  include 'fourier.h'

  interface fourier_transform_other
    module procedure fourier_transform_other_1
    module procedure fourier_transform_other_2
  endinterface

  contains

!***********************************************************************
    subroutine fourier_transform(a_re,a_im,linv)
!
!  Subroutine to do fourier transform
!  The routine overwrites the input data
!
!  22-oct-02/axel+tarek: adapted from transform
!
      real, dimension(nx,ny,nz) :: a_re,a_im
      logical, optional :: linv
!
      if (present(linv)) then
        if (linv) then
          if (lroot) print*, 'fourier_transform: only implemented for '// &
              'forwards transform!'
          call fatal_error('fourier_transform','')
        endif
      endif
!
      if (lroot .and. ip<10) print*,'transform_i: doing three FFTs'
      call fft(a_re,a_im, nx*ny*nz, nx, nx,-1)
      call transp(a_re,'y')
      call transp(a_im,'y')
      call fft(a_re,a_im, nx*ny*nz, nx, nx,-1)
      call transp(a_re,'z')
      call transp(a_im,'z')
      call fft(a_re,a_im, nx*ny*nz, nx, nx,-1)
!
!  Normalize
!
      a_re=a_re/nwgrid
      a_im=a_im/nwgrid
      if (lroot .and. ip<10) print*,'transform_i: fft has finished'
!
    endsubroutine fourier_transform
!***********************************************************************
    subroutine fourier_transform_xz(a_re,a_im,linv)
!
!  Subroutine to do Fourier transform in the x- and z-directions
!
      real, dimension(nx,ny,nz) :: a_re,a_im
      logical, optional :: linv
!
      call fatal_error('fourier_transform_xz', &
          'this sub is not available in fourier_fft.f90!')
!
      if (NO_WARN) print*, a_re, a_im, linv
!
    endsubroutine fourier_transform_xz
!***********************************************************************
    subroutine fourier_transform_xy(a_re,a_im,linv)
!
!  Subroutine to do Fourier transform in the x- and y-directions
!
      real, dimension(nx,ny) :: a_re,a_im
      logical, optional :: linv
!
      call fatal_error('fourier_transform_xy', &
          'this sub is not available in fourier_fft.f90!')
!
      if (NO_WARN) print*, a_re, a_im, linv
!
    endsubroutine fourier_transform_xy
!***********************************************************************
    subroutine fourier_transform_shear_xy(a_re,a_im,linv)
!
!  Subroutine to do Fourier transform in the x- and y-directions
!
      real, dimension(nx,ny,nz) :: a_re,a_im
      logical, optional :: linv
!
      call fatal_error('fourier_transform_xy_shear', &
          'this sub is not available in fourier_fft.f90!')
!
      if (NO_WARN) print*, a_re, a_im, linv
!
    endsubroutine fourier_transform_shear_xy
!***********************************************************************
    subroutine fourier_transform_xy_xy(a_re,a_im,linv)
!
!  Subroutine to do Fourier transform in the x- and y-directions
!
      real, dimension(nx,ny) :: a_re,a_im
      logical, optional :: linv
!
      call fatal_error('fourier_transform_xy_xy', &
          'this sub is not available in fourier_fft.f90!')
!
      if (NO_WARN) print*, a_re, a_im, linv
!
    endsubroutine fourier_transform_xy_xy
!***********************************************************************
    subroutine fourier_transform_xy_xy_other(a_re,a_im,linv)
!
!  Subroutine to do Fourier transform in the x- and y-directions
!
      real, dimension(nx,ny) :: a_re,a_im
      logical, optional :: linv
!
      call fatal_error('fourier_transform_xy_xy_other', &
          'this sub is not available in fourier_fft.f90!')
!
      if (NO_WARN) print*, a_re, a_im, linv
!
    endsubroutine fourier_transform_xy_xy_other
!***********************************************************************
    subroutine fourier_transform_x(a_re,a_im,linv)
!
!  Subroutine to do Fourier transform in the x-direction.
!
      real, dimension(nx,ny,nz) :: a_re,a_im
      logical, optional :: linv
!
      call fatal_error('fourier_transform_x', &
          'this sub is not available in fourier_fft.f90!')
!
      if (NO_WARN) print*, a_re, a_im, linv
!
    endsubroutine fourier_transform_x
!***********************************************************************
    subroutine fourier_transform_shear(a_re,a_im,linv)
!
!  Subroutine to do Fourier transform in shearing coordinates.
!
      real, dimension(nx,ny,nz) :: a_re,a_im
      logical, optional :: linv
!
      call fatal_error('fourier_transform_shear', &
          'this sub is not available in fourier_fft.f90!')
!
      if (NO_WARN) print*, a_re, a_im, linv
!
    endsubroutine fourier_transform_shear
!***********************************************************************
    subroutine fourier_transform_other_1(a_re,a_im,linv)
!
!  Subroutine to do Fourier transform on a 1-D array of arbitrary size.
!
      real, dimension(:) :: a_re,a_im
      logical, optional :: linv
!
      call fatal_error('fourier_transform_other_1', &
          'this sub is not available in fourier_fft.f90!')
!
      if (NO_WARN) print*, a_re, a_im
!
    endsubroutine fourier_transform_other_1
!***********************************************************************
    subroutine fourier_transform_other_2(a_re,a_im,linv)
!
!  Subroutine to do Fourier transform of a 2-D array of arbitrary size.
!
      real, dimension(:,:) :: a_re,a_im
      logical, optional :: linv
!
      call fatal_error('fourier_transform_other_2', &
          'this sub is not available in fourier_fft.f90!')
!
      if (NO_WARN) print*, a_re, a_im
!
    endsubroutine fourier_transform_other_2
!***********************************************************************
    subroutine fourier_shift_yz_y(a_re,shift_y)
!
!  Performs a periodic shift in the y-direction of an entire y-z plane by
!  the amount shift_y.
!
!  02-oct-07/anders: dummy
!
      real, dimension (ny,nz) :: a_re
      real :: shift_y
!
      call fatal_error('fourier_shift_yz_y', &
          'this sub is not available in fourier_fft.f90!')
!
      if (NO_WARN) print*, a_re, shift_y
!
    endsubroutine fourier_shift_yz_y
!***********************************************************************
    subroutine fourier_shift_y(a_re,shift_y)
!
!  Performs a periodic shift in the y-direction by the amount shift_y.
!
!  04-oct-07/anders: dummy
!
    real, dimension (nx,ny,nz) :: a_re
    real, dimension (nx) :: shift_y
!
    if (NO_WARN) print*, a_re, shift_y
!
  endsubroutine fourier_shift_y
!***********************************************************************
endmodule Fourier
