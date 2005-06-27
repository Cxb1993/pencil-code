! Id: nompicomm.f90,v 1.35 2002/08/16 21:23:48 brandenb Exp $

!!!!!!!!!!!!!!!!!!!!!!!
!!!  nompicomm.f90  !!!
!!!!!!!!!!!!!!!!!!!!!!!

!!!  Module with dummy MPI stuff.
!!!  This allows code to be run on single cpu machine

module Mpicomm

  use Cparam
  use Cdata, only: iproc,ipx,ipy,ipz,lroot

  implicit none

  include 'mpicomm.h'

  interface mpibcast_logical
    module procedure mpibcast_logical_scl
    module procedure mpibcast_logical_arr
  endinterface

  interface mpibcast_int
    module procedure mpibcast_int_scl
    module procedure mpibcast_int_arr
  endinterface

  interface mpibcast_real
    module procedure mpibcast_real_scl
    module procedure mpibcast_real_arr
  endinterface

  interface mpibcast_double
    module procedure mpibcast_double_scl
    module procedure mpibcast_double_arr
  endinterface

  interface mpibcast_char
    module procedure mpibcast_char_scl
    module procedure mpibcast_char_arr
  endinterface

  contains

!***********************************************************************
    subroutine mpicomm_init()
!
!  Before the communication has been completed, the nghost=3 layers next
!  to the processor boundary (m1, m2, n1, or n2) cannot be used yet.
!  In the mean time we can calculate the interior points sufficiently far
!  away from the boundary points. Here we calculate the order in which
!  m and n are executed. At one point, necessary(imn)=.true., which is
!  the moment when all communication must be completed.
!
!   6-jun-02/axel: generalized to allow for ny=1
!  23-nov-02/axel: corrected problem with ny=4 or less
!
      use General
      use Cdata, only: lmpicomm,iproc,ipx,ipy,ipz,lroot
!
!  sets iproc in order that we write in the correct directory
!
!  consistency check
!
      if (ncpus > 1) then
        call stop_it("Inconsistency: MPICOMM=nompicomm, but ncpus >= 2")
      endif
!
!  for single cpu machine, set processor to zero
!
      lmpicomm = .false.
      iproc = 0
      lroot = .true.
      ipx = 0
      ipy = 0
      ipz = 0
!
      call setup_mm_nn()
!
    endsubroutine mpicomm_init
!***********************************************************************
    subroutine initiate_isendrcv_bdry(f)
!
      use Cdata
!
!  for one processor, use periodic boundary conditions
!  but in this dummy routine this is done in finalize_isendrcv_bdry
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      if (NO_WARN) print*,f       !(keep compiler quiet)
!
    endsubroutine initiate_isendrcv_bdry
!***********************************************************************
    subroutine finalize_isendrcv_bdry(f)
!
      use Cparam
!
!  apply boundary conditions
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      if (NO_WARN) print*,f       !(keep compiler quiet)
    endsubroutine finalize_isendrcv_bdry
!***********************************************************************
    subroutine initiate_isendrcv_shock(f)
!
      use Cdata
!
!  for one processor, use periodic boundary conditions
!  but in this dummy routine this is done in finalize_isendrcv_bdry
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      if (NO_WARN) print*,f       !(keep compiler quiet)
!
    endsubroutine initiate_isendrcv_shock
!***********************************************************************
    subroutine finalize_isendrcv_uu(f)
!
      use Cparam
!
!  apply boundary conditions
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      if (NO_WARN) print*,f       !(keep compiler quiet)
    endsubroutine finalize_isendrcv_uu
!***********************************************************************
    subroutine initiate_isendrcv_uu(f)
!
      use Cdata
!
!  for one processor, use periodic boundary conditions
!  but in this dummy routine this is done in finalize_isendrcv_bdry
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      if (NO_WARN) print*,f       !(keep compiler quiet)
!
    endsubroutine initiate_isendrcv_uu
!***********************************************************************
    subroutine finalize_isendrcv_shock(f)
!
      use Cparam
!
!  apply boundary conditions
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      if (NO_WARN) print*,f       !(keep compiler quiet)
    endsubroutine finalize_isendrcv_shock
!***********************************************************************
    subroutine initiate_shearing(f)
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!    
      if (NO_WARN) print*,f       !(keep compiler quiet)
    endsubroutine initiate_shearing
!***********************************************************************
    subroutine finalize_shearing(f)
!
  use Cdata
!
!  for one processor, use periodic boundary conditions
!  but in this dummy routine this is done in finalize_isendrcv_bdry
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      double precision    :: deltay_dy, frak, c1, c2, c3, c4, c5, c6
      integer :: displs
!
!  Periodic boundary conditions in x, with shearing sheat
!
      if (nygrid==1) then !If 2D
         f( 1:l1-1,:,:,:) = f(l2i:l2,:,:,:)
         f(l2+1:mx,:,:,:) = f(l1:l1i,:,:,:)
      else
         deltay_dy=deltay/dy
         displs=int(deltay_dy)
         frak=deltay_dy-displs
         c1 = -          (frak+1.)*frak*(frak-1.)*(frak-2.)*(frak-3.)/120.
         c2 = +(frak+2.)          *frak*(frak-1.)*(frak-2.)*(frak-3.)/24.
         c3 = -(frak+2.)*(frak+1.)     *(frak-1.)*(frak-2.)*(frak-3.)/12.
         c4 = +(frak+2.)*(frak+1.)*frak          *(frak-2.)*(frak-3.)/12.
         c5 = -(frak+2.)*(frak+1.)*frak*(frak-1.)          *(frak-3.)/24.
         c6 = +(frak+2.)*(frak+1.)*frak*(frak-1.)*(frak-2.)          /120.
         f( 1:l1-1,m1:m2,:,:)=c1*cshift(f(l2i:l2,m1:m2,:,:),-displs+2,2) &
                             +c2*cshift(f(l2i:l2,m1:m2,:,:),-displs+1,2) &
                             +c3*cshift(f(l2i:l2,m1:m2,:,:),-displs,2) &
                             +c4*cshift(f(l2i:l2,m1:m2,:,:),-displs-1,2) &
                             +c5*cshift(f(l2i:l2,m1:m2,:,:),-displs-2,2) &
                             +c6*cshift(f(l2i:l2,m1:m2,:,:),-displs-3,2)  
         f(l2+1:mx,m1:m2,:,:)=c1*cshift(f(l1:l1i,m1:m2,:,:),displs-2,2) &
                             +c2*cshift(f(l1:l1i,m1:m2,:,:),displs-1,2) &
                             +c3*cshift(f(l1:l1i,m1:m2,:,:),displs,2) &
                             +c4*cshift(f(l1:l1i,m1:m2,:,:),displs+1,2) &
                             +c5*cshift(f(l1:l1i,m1:m2,:,:),displs+2,2) &
                             +c6*cshift(f(l1:l1i,m1:m2,:,:),displs+3,2) 
      end if
    end subroutine finalize_shearing
!***********************************************************************
    subroutine radboundary_zx_recv(mrad,idir,Ibuf_zx)
!
!   2-jul-03/tony: dummy created
!
      integer :: mrad,idir
      real, dimension(mx,mz) :: Ibuf_zx
!
      if (NO_WARN) then
         print*,mrad,idir,Ibuf_zx(1,1)
      endif
!
    endsubroutine radboundary_zx_recv
!***********************************************************************
    subroutine radboundary_xy_recv(nrad,idir,Ibuf_xy)
!
!   2-jul-03/tony: dummy created
!
      integer :: nrad,idir
      real, dimension(mx,my) :: Ibuf_xy
!
      if (NO_WARN) then
         print*,nrad,idir,Ibuf_xy(1,1)
      endif
!
    endsubroutine radboundary_xy_recv
!***********************************************************************
    subroutine radboundary_zx_send(mrad,idir,Ibuf_zx)
!
!   2-jul-03/tony: dummy created
!
      integer :: mrad,idir
      real, dimension(mx,mz) :: Ibuf_zx
!
      if (NO_WARN) then
         print*,mrad,idir,Ibuf_zx(1,1)
      endif
!
    endsubroutine radboundary_zx_send
!***********************************************************************
    subroutine radboundary_xy_send(nrad,idir,Ibuf_xy)
!
!   2-jul-03/tony: dummy created
!
      integer :: nrad,idir
      real, dimension(mx,my) :: Ibuf_xy
!
      if (NO_WARN) then
         print*,nrad,idir,Ibuf_xy(1,1)
      endif
!
    endsubroutine radboundary_xy_send
!***********************************************************************
    subroutine radboundary_zx_periodic_ray(mrad,Qrad_zx,tau_zx,Qrad0_zx)
!
!  6-nov-03/tobi: dummy created
!
      integer, intent(in) :: mrad
      real, dimension(mx,mz) :: Qrad_zx,tau_zx,Qrad0_zx
!
      if (NO_WARN) then
         print*,mrad
         print*,Qrad_zx(1,1),tau_zx(1,1),Qrad0_zx(1,1)
      endif
!
    endsubroutine radboundary_zx_periodic_ray
!***********************************************************************
    subroutine mpibcast_logical_scl(lbcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      logical :: lbcast_array
      integer, optional :: proc
!    
      if (NO_WARN) print*, lbcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_logical_scl
!***********************************************************************
    subroutine mpibcast_logical_arr(lbcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      logical, dimension(nbcast_array) :: lbcast_array
      integer, optional :: proc
!    
      if (NO_WARN) print*, lbcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_logical_arr
!***********************************************************************
    subroutine mpibcast_int_scl(ibcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      integer :: ibcast_array
      integer, optional :: proc
!    
      if (NO_WARN) print*, ibcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_int_scl
!***********************************************************************
    subroutine mpibcast_int_arr(ibcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      integer, dimension(nbcast_array) :: ibcast_array
      integer, optional :: proc
!    
      if (NO_WARN) print*, ibcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_int_arr
!***********************************************************************
    subroutine mpibcast_real_scl(bcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      real :: bcast_array
      integer, optional :: proc
!
      if (NO_WARN) print*, bcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_real_scl
!***********************************************************************
    subroutine mpibcast_real_arr(bcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      real, dimension(nbcast_array) :: bcast_array
      integer, optional :: proc
!
      if (NO_WARN) print*, bcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_real_arr
!***********************************************************************
    subroutine mpibcast_double_scl(bcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      double precision :: bcast_array
      integer, optional :: proc
!
      if (NO_WARN) print*, bcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_double_scl
!***********************************************************************
    subroutine mpibcast_double_arr(bcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      double precision, dimension(nbcast_array) :: bcast_array
      integer, optional :: proc
!
      if (NO_WARN) print*, bcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_double_arr
!***********************************************************************
    subroutine mpibcast_char_scl(cbcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      character :: cbcast_array
      integer, optional :: proc
!
      if (NO_WARN) print*, cbcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_char_scl
!***********************************************************************
    subroutine mpibcast_char_arr(cbcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      character, dimension(nbcast_array) :: cbcast_array
      integer, optional :: proc
!
      if (NO_WARN) print*, cbcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_char_arr
!***********************************************************************
    subroutine mpireduce_max(fmax_tmp,fmax,nreduce)
!
      integer :: nreduce
      real, dimension(nreduce) :: fmax_tmp, fmax
!
      fmax=fmax_tmp
    endsubroutine mpireduce_max
!***********************************************************************
    subroutine mpireduce_min(fmin_tmp,fmin,nreduce)
!
      integer :: nreduce
      real, dimension(nreduce) :: fmin_tmp, fmin
!
      fmin=fmin_tmp
    endsubroutine mpireduce_min
!***********************************************************************
    subroutine mpireduce_sum(fsum_tmp,fsum,nreduce)
!
      integer :: nreduce
      real, dimension(nreduce) :: fsum_tmp,fsum
!
      fsum=fsum_tmp
    endsubroutine mpireduce_sum
!***********************************************************************
    subroutine mpireduce_sum_double(dsum_tmp,dsum,nreduce)
!
      integer :: nreduce
      double precision, dimension(nreduce) :: dsum_tmp,dsum
!
      dsum=dsum_tmp
    endsubroutine mpireduce_sum_double
!***********************************************************************
    subroutine mpireduce_sum_int(fsum_tmp,fsum,nreduce)
!
!  12-jan-05/anders: dummy coded
!
      integer :: nreduce
      integer, dimension(nreduce) :: fsum_tmp,fsum
!
      fsum=fsum_tmp
!
    endsubroutine mpireduce_sum_int
!***********************************************************************
    subroutine start_serialize()
    endsubroutine start_serialize
!***********************************************************************
    subroutine end_serialize()
    endsubroutine end_serialize
!***********************************************************************
    subroutine mpibarrier()
    endsubroutine mpibarrier
!***********************************************************************
    subroutine mpifinalize()
    endsubroutine mpifinalize
!***********************************************************************
    function mpiwtime()
!
!  Mimic the MPI_WTIME() timer function. On many machines, the
!  implementation through system_clock() will overflow after about 50
!  minutes, so MPI_WTIME() is better.
!
!   5-oct-2002/wolf: coded
!
      double precision :: mpiwtime
      integer :: count_rate,time
!
      call system_clock(COUNT_RATE=count_rate)
      call system_clock(COUNT=time)

      if (count_rate /= 0) then
        mpiwtime = (time*1.)/count_rate
      else                      ! occurs with ifc 6.0 after long (> 2h) runs
        mpiwtime = 0
      endif
!
    endfunction mpiwtime
!***********************************************************************
    function mpiwtick()
!
!  Mimic the MPI_WTICK() function for measuring timer resolution.
!
!   5-oct-2002/wolf: coded
!
      double precision :: mpiwtick
      integer :: count_rate
!
      call system_clock(COUNT_RATE=count_rate)
      if (count_rate /= 0) then
        mpiwtick = 1./count_rate
      else                      ! occurs with ifc 6.0 after long (> 2h) runs
        mpiwtick = 0
      endif
!
    endfunction mpiwtick
!***********************************************************************
    subroutine stop_it(msg)
!
!  Print message and stop
!  6-nov-01/wolf: coded
!
      character (len=*) :: msg
!      
      if (lroot) write(0,'(A,A)') 'STOPPED: ', msg
      call mpifinalize
      STOP
    endsubroutine stop_it
!***********************************************************************
    subroutine stop_it_if_any(stop_flag,msg)
!
!  Conditionally print message and stop.
!  22-nov-04/wolf: coded
!
      logical :: stop_flag
      character (len=*) :: msg
!
      if (stop_flag) call stop_it(msg)
!
    endsubroutine stop_it_if_any
!***********************************************************************
    subroutine transp(a,var)
!
!  Doing a transpose (dummy version for single processor)
!
!   5-sep-02/axel: adapted from version in mpicomm.f90
!
      real, dimension(nx,ny,nz) :: a
      real, dimension(nz) :: tmp_z
      real, dimension(ny) :: tmp_y
      integer :: i,j
      character :: var
!
      if (ip<10) print*,'transp for single processor'
!
!  Doing x-y transpose if var='y'
!
if (var=='y') then
!
      if (ny>1) then
        do i=1,ny
          do j=i+1,ny
            tmp_z=a(i,j,:)
            a(i,j,:)=a(j,i,:)
            a(j,i,:)=tmp_z
          enddo
        enddo
      endif
!
!  Doing x-z transpose if var='z'
!
elseif (var=='z') then
!
      if (nz>1) then
        do i=1,nz
          do j=i+1,nz
            tmp_y=a(i,:,j)
            a(i,:,j)=a(j,:,i)
            a(j,:,i)=tmp_y
          enddo
        enddo
      endif
!
endif
!
 end subroutine transp
!***********************************************************************
subroutine transform(a1,a2,a3,b1,b2,b3)
!
!  Subroutine to do fourier transform
!  The routine overwrites the input data
!
!  03-nov-02/nils: coded
!  05-nov-02/axel: added normalization factor
!
  real,dimension(nx,ny,nz) :: a1,a2,a3,b1,b2,b3
!
  if(lroot .AND. ip<10) print*,'doing fft of x-component'
  ! Doing the x field
  call fft(a1,b1, nx*ny*nz, nx, nx      ,-1) ! x-direction
  call fft(a1,b1, nx*ny*nz, ny, nx*ny   ,-1) ! y-direction
  call fft(a1,b1, nx*ny*nz, nz, nx*ny*nz,-1) ! z-direction
  
  ! Doing the y field
  if(lroot .AND. ip<10) print*,'doing fft of y-component'
  call fft(a2,b2, nx*ny*nz, nx, nx      ,-1) ! x-direction
  call fft(a2,b2, nx*ny*nz, ny, nx*ny   ,-1) ! y-direction
  call fft(a2,b2, nx*ny*nz, nz, nx*ny*nz,-1) ! z-direction
  
  ! Doing the z field
  if(lroot .AND. ip<10) print*,'doing fft of z-component'
  call fft(a3,b3, nx*ny*nz, nx, nx      ,-1) ! x-direction
  call fft(a3,b3, nx*ny*nz, ny, nx*ny   ,-1) ! y-direction
  call fft(a3,b3, nx*ny*nz, nz, nx*ny*nz,-1) ! z-direction

  ! Normalize
  a1=a1/nwgrid; a2=a2/nwgrid; a3=a3/nwgrid
  b1=b1/nwgrid; b2=b2/nwgrid; b3=b3/nwgrid

end subroutine transform
!***********************************************************************
subroutine transform_i(a_re,a_im)
!
!  Subroutine to do fourier transform
!  The routine overwrites the input data
!
!  22-oct-02/axel+tarek: adapted from transform
!
  real,dimension(nx,ny,nz) :: a_re,a_im
!
  if(lroot .AND. ip<10) print*,'doing three FFTs'
  call fft(a_re,a_im, nx*ny*nz, nx, nx      ,-1)
  call fft(a_re,a_im, nx*ny*nz, ny, nx*ny   ,-1)
  call fft(a_re,a_im, nx*ny*nz, nz, nx*ny*nz,-1)
!
!  Normalize
!
  a_re=a_re/nwgrid
  a_im=a_im/nwgrid
!
end subroutine transform_i
!***********************************************************************
subroutine transform_cosq(a_re,direction)
!
!  Subroutine to do Fourier transform
!  The routine overwrites the input data
!
!  13-aug-03/axel: adapted from transform_fftpack
!
  real,dimension(nx,ny,nz) :: a_re
  real,dimension(nx) :: ax
  real,dimension(ny) :: ay
  real,dimension(nz) :: az
  real,dimension(4*nx+15) :: wsavex
  real,dimension(4*ny+15) :: wsavey
  real,dimension(4*nz+15) :: wsavez
  logical :: lforward=.true.
  integer,optional :: direction
  integer :: l,m,n

  if (present(direction)) then
    if (direction.eq.-1) lforward=.false.
  endif
!
  if(lroot .AND. ip<10) print*,'doing FFTpack in x, direction =',direction
  call cosqi(nx,wsavex)
  do m=1,ny
  do n=1,nz
    ax=a_re(:,m,n)
    if (lforward) then 
        call cosqf(nx,ax,wsavex)
    else 
        call cosqb(nx,ax,wsavex)
    endif
    a_re(:,m,n)=ax
  enddo
  enddo
!
  if(lroot .AND. ip<10) print*,'doing FFTpack in y, direction =',direction
  call cosqi(ny,wsavey)
  do l=1,nx
  do n=1,nz
    ay=a_re(l,:,n)
    if (lforward) then 
        call cosqf(ny,ay,wsavey)
    else 
        call cosqb(ny,ay,wsavey)
    endif
    a_re(l,:,n)=ay
  enddo
  enddo
!
  if(lroot .AND. ip<10) print*,'doing FFTpack in z, direction =',direction
  call cosqi(nz,wsavez)
  do l=1,nx
  do m=1,ny
    az=a_re(l,m,:)
    if (lforward) then 
       call cosqf(nz,az,wsavez)
    else 
       call cosqb(nz,az,wsavez)
    endif
    a_re(l,m,:)=az
  enddo
  enddo
!
!  Normalize
!

  if (lforward) then 
    a_re=a_re/nwgrid
  endif
!
end subroutine transform_cosq
!***********************************************************************
subroutine transform_fftpack(a_re,a_im,direction)
!
!  Subroutine to do Fourier transform
!  The routine overwrites the input data
!
!  27-oct-02/axel: adapted from transform_i, for fftpack
!
  real,dimension(nx,ny,nz) :: a_re,a_im
  complex,dimension(nx) :: ax
  complex,dimension(ny) :: ay
  complex,dimension(nz) :: az
  real,dimension(4*nx+15) :: wsavex
  real,dimension(4*ny+15) :: wsavey
  real,dimension(4*nz+15) :: wsavez
  logical :: lforward=.true.
  integer,optional :: direction
  integer :: l,m,n

  if (present(direction)) then
    if (direction.eq.-1) lforward=.false.
  endif
!
  if(lroot .AND. ip<10) print*,'doing FFTpack in x, direction =',direction
  call cffti(nx,wsavex)
  do m=1,ny
  do n=1,nz
    ax=cmplx(a_re(:,m,n),a_im(:,m,n))
    if (lforward) then 
        call cfftf(nx,ax,wsavex)
    else 
        call cfftb(nx,ax,wsavex)
    endif
    a_re(:,m,n)=real(ax)
    a_im(:,m,n)=aimag(ax)
  enddo
  enddo
!
  if(lroot .AND. ip<10) print*,'doing FFTpack in y, direction =',direction
  call cffti(ny,wsavey)
  do l=1,nx
  do n=1,nz
    ay=cmplx(a_re(l,:,n),a_im(l,:,n))
    if (lforward) then 
        call cfftf(ny,ay,wsavey)
    else 
        call cfftb(ny,ay,wsavey)
    endif
    a_re(l,:,n)=real(ay)
    a_im(l,:,n)=aimag(ay)
  enddo
  enddo
!
  if(lroot .AND. ip<10) print*,'doing FFTpack in z, direction =',direction
  call cffti(nz,wsavez)
  do l=1,nx
  do m=1,ny
    az=cmplx(a_re(l,m,:),a_im(l,m,:))
    if (lforward) then 
       call cfftf(nz,az,wsavez)
    else 
       call cfftb(nz,az,wsavez)
    endif
    a_re(l,m,:)=real(az)
    a_im(l,m,:)=aimag(az)
  enddo
  enddo
!
!  Normalize
!

  if (lforward) then 
    a_re=a_re/nwgrid
    a_im=a_im/nwgrid
  endif
!
end subroutine transform_fftpack
!***********************************************************************
subroutine transform_fftpack_2d(a_re,a_im,direction)
!
!  Subroutine to do Fourier transform
!  The routine overwrites the input data
!
!  27-oct-02/axel: adapted from transform_i, for fftpack
!
  real,dimension(nx,ny,nz) :: a_re,a_im
  complex,dimension(nx) :: ax
  complex,dimension(nz) :: az
  real,dimension(4*nx+15) :: wsavex
  real,dimension(4*nz+15) :: wsavez
  logical :: lforward=.true.
  integer,optional :: direction
  integer :: l,m,n

  if (present(direction)) then
    if (direction.eq.-1) lforward=.false.
  endif
!
  if(lroot .AND. ip<10) print*,'doing FFTpack in x, direction =',direction
  call cffti(nx,wsavex)
  do m=1,ny
  do n=1,nz
    ax=cmplx(a_re(:,m,n),a_im(:,m,n))
    if (lforward) then 
        call cfftf(nx,ax,wsavex)
    else 
        call cfftb(nx,ax,wsavex)
    endif
    a_re(:,m,n)=real(ax)
    a_im(:,m,n)=aimag(ax)
  enddo
  enddo
!
  if(lroot .AND. ip<10) print*,'doing FFTpack in z, direction =',direction
  call cffti(nz,wsavez)
  do l=1,nx
  do m=1,ny
    az=cmplx(a_re(l,m,:),a_im(l,m,:))
    if (lforward) then 
       call cfftf(nz,az,wsavez)
    else 
       call cfftb(nz,az,wsavez)
    endif
    a_re(l,m,:)=real(az)
    a_im(l,m,:)=aimag(az)
  enddo
  enddo
!
!  Normalize
!
  if (lforward) then 
    a_re=a_re/nwgrid
    a_im=a_im/nwgrid
  endif
!
end subroutine transform_fftpack_2d
!***********************************************************************
subroutine transform_nr(a_re,a_im)
!
!  Subroutine to do Fourier transform using Numerical Recipes routine.
!  Note that this routine requires that nx, ny, and nz are powers of 2.
!  The routine overwrites the input data
!
!  30-oct-02/axel: adapted from transform_fftpack for Numerical Recipes
!
  real,dimension(nx,ny,nz) :: a_re,a_im
  complex,dimension(nx) :: ax
  complex,dimension(ny) :: ay
  complex,dimension(nz) :: az
  integer :: l,m,n
!
!  This Fourier transform would work, but it's very slow!
!  Even the compilation is very slow, so we better get rid of it!  
!
  print*,'fft_nr currently disabled!'
  call stop_it("")
!
  if(lroot .AND. ip<10) print*,'doing FFT_nr in x'
  do m=1,ny
  do n=1,nz
    ax=cmplx(a_re(:,m,n),a_im(:,m,n))
    !call four1(ax,nx,-1)
    a_re(:,m,n)=real(ax)
    a_im(:,m,n)=aimag(ax)
  enddo
  enddo
!
  if(lroot .AND. ip<10) print*,'doing FFT_nr in y'
  do l=1,nx
  do n=1,nz
    ay=cmplx(a_re(l,:,n),a_im(l,:,n))
    !call four1(ay,ny,-1)
    a_re(l,:,n)=real(ay)
    a_im(l,:,n)=aimag(ay)
  enddo
  enddo
!
  if(lroot .AND. ip<10) print*,'doing FFT_nr in z'
  do l=1,nx
  do m=1,ny
    az=cmplx(a_re(l,m,:),a_im(l,m,:))
    !call four1(az,nz,-1)
    a_re(l,m,:)=real(az)
    a_im(l,m,:)=aimag(az)
  enddo
  enddo
!
!  Normalize
!
  a_re=a_re/nwgrid
  a_im=a_im/nwgrid
!
end subroutine transform_nr
!***********************************************************************
subroutine transform_fftpack_1d(a_re,a_im)
!
!  Subroutine to do Fourier transform
!  The routine overwrites the input data
!
!  06-feb-03/nils: adapted from transform_fftpack
!
  real,dimension(nx,ny,nz) :: a_re,a_im
  complex,dimension(nx) :: ax
  real,dimension(4*nx+15) :: wsavex
  integer :: m,n
!
  if(lroot .AND. ip<10) print*,'doing FFTpack in x'
  call cffti(nx,wsavex)
  do m=1,ny
  do n=1,nz
    ax=cmplx(a_re(:,m,n),a_im(:,m,n))
    call cfftf(nx,ax,wsavex)
    a_re(:,m,n)=real(ax)
    a_im(:,m,n)=aimag(ax)
  enddo
  enddo
!
!  Normalize
!
  a_re=a_re/nxgrid
  a_im=a_im/nxgrid
!
end subroutine transform_fftpack_1d
!***********************************************************************
endmodule Mpicomm
