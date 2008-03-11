! $Id: general.f90,v 1.69 2008-03-11 14:59:19 wlyra Exp $

module General

!  Module with general utility subroutines
!  (Used for example in Sub and Mpicomm)

  use Cparam
  use Messages

  implicit none

  private

  public :: safe_character_assign,safe_character_append, chn
  public :: random_seed_wrapper
  public :: random_number_wrapper, random_gen
  public :: parse_filename

  public :: setup_mm_nn
  public :: input_persistent_general, output_persistent_general

  public :: spline,tridag,complex_phase,erfcc,besselj_nu_int

  include 'record_types.h'

  interface random_number_wrapper   ! Overload this function
    module procedure random_number_wrapper_0
    module procedure random_number_wrapper_1
    module procedure random_number_wrapper_3
  endinterface

  interface safe_character_append   ! Overload this function
    module procedure safe_character_append_2
    module procedure safe_character_append_3 ! add more if you like..
  endinterface
!
!  state and default generator of random numbers
!
  integer, save, dimension(mseed) :: rstate=0
  character (len=labellen) :: random_gen='min_std'

  contains
!***********************************************************************
    subroutine setup_mm_nn()
!
!  Produce index-array for the sequence of points to be worked through:
!  Before the communication has been completed, the nghost=3 layers next
!  to the processor boundary (m1, m2, n1, or n2) cannot be used yet.
!  In the mean time we can calculate the interior points sufficiently far
!  away from the boundary points. Here we calculate the order in which
!  m and n are executed. At one point, necessary(imn)=.true., which is
!  the moment when all communication must be completed.
!
      use Cparam
      use Cdata, only: mm,nn,imn_array,necessary,lroot
!
      integer :: imn,m,n
      integer :: min_m1i_m2,max_m2i_m1
!
!  For non-parallel runs simply go through m and n from bottom left to to right.
!
      if (ncpus==1) then
        imn=1
        necessary(1)=.true.
        do n=n1,n2
          do m=m1,m2
            mm(imn)=m
            nn(imn)=n
            imn_array(m,n)=imn
            imn=imn+1
          enddo
        enddo
      else
        imn=1
        do n=n1i+2,n2i-2
          do m=m1i+2,m2i-2
            mm(imn)=m
            nn(imn)=n
            imn_array(m,n)=imn
            imn=imn+1
          enddo
        enddo
        necessary(imn)=.true.
!
!  do the upper stripe in the n-direction
!
        do n=max(n2i-1,n1+1),n2
          do m=m1i+2,m2i-2
            mm(imn)=m
            nn(imn)=n
            imn_array(m,n)=imn
            imn=imn+1
          enddo
        enddo
!
!  lower stripe in the n-direction
!
        do n=n1,min(n1i+1,n2)
          do m=m1i+2,m2i-2
            mm(imn)=m
            nn(imn)=n
            imn_array(m,n)=imn
            imn=imn+1
          enddo
        enddo
!
!  left and right hand boxes
!  NOTE: need to have min(m1i,m2) instead of just m1i, and max(m2i,m1)
!  instead of just m2i, to make sure the case ny=1 works ok, and
!  also that the same m is not set in both loops.
!  ALSO: need to make sure the second loop starts not before the
!  first one ends; therefore max_m2i_m1+1=max(m2i,min_m1i_m2+1).
!
        min_m1i_m2=min(m1i+1,m2)
        max_m2i_m1=max(m2i-1,min_m1i_m2+1)
!
        do n=n1,n2
          do m=m1,min_m1i_m2
            mm(imn)=m
            nn(imn)=n
            imn_array(m,n)=imn
            imn=imn+1
          enddo
          do m=max_m2i_m1,m2
            mm(imn)=m
            nn(imn)=n
            imn_array(m,n)=imn
            imn=imn+1
          enddo
        enddo
      endif
!
!  Debugging output to be analysed with $PENCIL_HOME/utils/check-mm-nn.
!  Uncommenting manually, since we can't use ip here (as it is not yet
!  read from run.in).
!
      if (.false.) then
        if (lroot) then
          do imn=1,ny*nz
            if (necessary(imn)) write(*,'(A)') '==MM==NN==> Necessary'
            write(*,'(A,I5,I5)') '==MM==NN==> m,n= ', mm(imn), nn(imn)
          enddo
        endif
      endif
!
    endsubroutine setup_mm_nn
!***********************************************************************
    subroutine input_persistent_general(id,lun,done)
!
!  Fills a with a random number calculated with one of the generators
!  available with random_gen
!
      use Cparam
      use Cdata, only: seed,nseed
!
      integer :: id,lun
      logical :: done
!
      call random_seed_wrapper(get=seed(1:nseed))
      if (id==id_record_RANDOM_SEEDS) then
        read (lun) seed(1:nseed)
        call random_seed_wrapper(put=seed(1:nseed))
        done=.true.
      endif
!
    endsubroutine input_persistent_general
!***********************************************************************
    subroutine output_persistent_general(lun)
!
!  Fills a with a random number calculated with one of the generators
!  available with random_gen
!
      use Cparam
      use Cdata, only: seed,nseed
!
      integer :: lun
!
      call random_seed_wrapper(get=seed(1:nseed))
      write (lun) id_record_RANDOM_SEEDS
      write (lun) seed(1:nseed)
!
    endsubroutine output_persistent_general
!***********************************************************************
    subroutine random_number_wrapper_0(a)
!
!  Fills a with a random number calculated with one of the generators
!  available with random_gen
!
      real :: a
      real, dimension(1) :: b
!
      intent(out) :: a
!
!     b = a                     ! not needed unless numbers are non-Markovian
!
      call random_number_wrapper(b)
      a = b(1)
!
    endsubroutine random_number_wrapper_0
!***********************************************************************
    subroutine random_number_wrapper_1(a)
!
!  Fills a with an array of random numbers calculated with one of the
!  generators available with random_gen
!
      use Cdata, only: lroot
!
      real, dimension(:) :: a
      integer :: i
!
      intent(out) :: a
!
      select case(random_gen)
!
      case('system')
        call random_number(a)
      case('min_std')
        do i=1,size(a,1)
          a(i)=ran0(rstate(1))
        enddo
      case('nr_f90')
        do i=1,size(a,1)
          a(i)=mars_ran()
        enddo
      case default
        if (lroot) print*, 'No such random number generator: ', random_gen
        STOP 1                ! Return nonzero exit status

     endselect
!
    endsubroutine random_number_wrapper_1
!***********************************************************************
    subroutine random_number_wrapper_3(a)
!
!  Fills a with a matrix of random numbers calculated with one of the
!  generators available with random_gen
!
      use Cdata, only: lroot
!
      real, dimension(:,:,:) :: a
      integer :: i,j,k
!
      intent(out) :: a
!
      select case(random_gen)
!
      case('system')
        call random_number(a)
      case('min_std')
        do i=1,size(a,1); do j=1,size(a,2); do k=1,size(a,3)
          a(i,j,k)=ran0(rstate(1))
        enddo; enddo; enddo
      case('nr_f90')
        do i=1,size(a,1); do j=1,size(a,2); do k=1,size(a,3)
          a(i,j,k)=mars_ran()
        enddo; enddo; enddo
      case default
        if (lroot) print*, 'No such random number generator: ', random_gen
        STOP 1                ! Return nonzero exit status

      endselect
!
    endsubroutine random_number_wrapper_3
!***********************************************************************
    subroutine random_seed_wrapper(size,put,get)
!
!  mimics the f90 random_seed routine
!
      real :: dummy
      integer, optional, dimension(:) :: put,get
      integer, optional :: size
      integer :: nseed
!
      select case(random_gen)
!
      case('system')
        call random_seed(SIZE=nseed)
        if(present(size)) size=nseed
        if(present(get))  call random_seed(GET=get(1:nseed))
        if(present(put))  call random_seed(PUT=put(1:nseed))
      case('min_std')
        nseed=1
        if(present(size)) size=nseed
        if(present(get))  get=rstate(1)
        if(present(put))  rstate(1)=put(1)
      case default ! 'nr_f90'
        nseed=2
        if(present(size)) size=nseed
        if(present(get))  get=rstate(1:nseed)
        if(present(put)) then
          if (put(2)==0) then   ! state cannot be result from previous
                                ! call, so initialize
            dummy = mars_ran(put(1))
          else
            rstate(1:nseed)=put
          endif
        endif
      endselect
!
      if (.false.) print*, dummy ! (keep compiler quiet)
!
    endsubroutine random_seed_wrapper
!***********************************************************************
    function ran0(dummy)
!
!  The 'Minimal Standard' random number generator
!  by Lewis, Goodman and Miller.
!
!  28.08.02/nils: Adapted from Numerical Recipes
!
      integer,parameter :: ia=16807,im=2147483647,iq=127773,ir=2836, &
           mask=123459876
      real, parameter :: am=1./im
      real :: ran0
      integer :: dummy,k
!
      dummy=ieor(dummy,mask)
      k=dummy/iq
      dummy=ia*(dummy-k*iq)-ir*k
      if (dummy.lt.0) dummy=dummy+im
      ran0=am*dummy
      dummy=ieor(dummy,mask)
!
    endfunction ran0

!***********************************************************************
    function mars_ran(init)
!
! 26-sep-02/wolf: Adapted from `Numerical Recipes for F90' ran() routine
!
! "Minimal" random number generator of Park and Miller combined
! with a Marsaglia shift sequence. Returns a uniform random deviate
! between 0.0 and 1.0 (exclusive of the endpoint values).
! Call with (INIT=ival) to initialize.
! The period of this generator is supposed to be about 3.1�10^18.
!
      implicit none
!
      real :: mars_ran
      real, save :: am=impossible    ! will be constant on a given platform
      integer, optional, intent(in) :: init
      integer, parameter :: ia=16807,im=2147483647,iq=127773,ir=2836
      integer :: k,init1=1812   ! default value
      logical, save :: first_call=.true.
!
!ajwm This doesn't appear to always get set!
      if (first_call) then
        am=nearest(1.0,-1.0)/im
        first_call=.false.
      endif
      if (present(init) .or. rstate(1)==0 .or. rstate(2)<=0) then
        !
        ! initialize
        !
        if (present(init)) init1 = init
        am=nearest(1.0,-1.0)/im
        rstate(1)=ieor(777755555,abs(init1))
        rstate(2)=ior(ieor(888889999,abs(init1)),1)
      endif
      !
      ! Marsaglia shift sequence with period 2^32-1
      !
      rstate(1)=ieor(rstate(1),ishft(rstate(1),13))
      rstate(1)=ieor(rstate(1),ishft(rstate(1),-17))
      rstate(1)=ieor(rstate(1),ishft(rstate(1),5))
      !
      ! Park-Miller sequence by Schrage's method, period 2^31-2
      !
      k=rstate(2)/iq
      rstate(2)=ia*(rstate(2)-k*iq)-ir*k
      if (rstate(2) < 0) rstate(2)=rstate(2)+im
      !
      ! combine the two generators with masking to ensure nonzero value
      !
      mars_ran=am*ior(iand(im,ieor(rstate(1),rstate(2))),1)
!
    endfunction mars_ran
!***********************************************************************
    function ran(iseed1)
!
!  (More or less) original routine from `Numerical Recipes in F90'. Not
!  sure we are allowed to distribute this
!
! 28-aug-02/wolf: Adapted from Numerical Recipes
!
      implicit none
!
      integer, parameter :: ikind=kind(888889999)
      integer(ikind), intent(inout) :: iseed1
      real :: ran
!
      ! "Minimal" random number generator of Park and Miller combined
      ! with a Marsaglia shift sequence. Returns a uniform random deviate
      ! between 0.0 and 1.0 (exclusive of the endpoint values). This fully
      ! portable, scalar generator has the "traditional" (not Fortran 90)
      ! calling sequence with a random deviate as the returned function
      ! value: call with iseed1 a negative integer to initialize;
      ! thereafter, do not alter iseed1 except to reinitialize. The period
      ! of this generator is about 3.1�10^18.

      real, save :: am
      integer(ikind), parameter :: ia=16807,im=2147483647,iq=127773,ir=2836
      integer(ikind), save      :: ix=-1,iy=-1,k

      if (iseed1 <= 0 .or. iy < 0) then   ! Initialize.
        am=nearest(1.0,-1.0)/im
        iy=ior(ieor(888889999,abs(iseed1)),1)
        ix=ieor(777755555,abs(iseed1))
        iseed1=abs(iseed1)+1   ! Set iseed1 positive.
      end if
      ix=ieor(ix,ishft(ix,13))   ! Marsaglia shift sequence with period 2^32-1.
      ix=ieor(ix,ishft(ix,-17))
      ix=ieor(ix,ishft(ix,5))
      k=iy/iq   ! Park-Miller sequence by Schrage's method,
      iy=ia*(iy-k*iq)-ir*k   ! period 231 - 2.
      if (iy < 0) iy=iy+im
      ran=am*ior(iand(im,ieor(ix,iy)),1)   ! Combine the two generators with
                                           ! masking to ensure nonzero value.
    endfunction ran
!***********************************************************************
    subroutine chn(n,ch,label)
!
!  make a character out of a number
!  take care of numbers that have less than 4 digits
!  30-sep-97/axel: coded
!
      character (len=5) :: ch
      character (len=*), optional :: label
      integer :: n
!
      intent(in) :: n
!
      ch='     '
      if (n<0) stop 'chn: lt1'
      if (n<10) then
        write(ch(1:1),'(i1)') n
      elseif (n<100) then
        write(ch(1:2),'(i2)') n
      elseif (n<1000) then
        write(ch(1:3),'(i3)') n
      elseif (n<10000) then
        write(ch(1:4),'(i4)') n
      elseif (n<100000) then
        write(ch(1:5),'(i5)') n
      else
        if (present(label)) print*, 'CHN: <', label, '>'
        print*,'CHN: n=',n
        stop "CHN: n too large"
      endif
!
    endsubroutine chn
!***********************************************************************
    subroutine chk_time(label,time1,time2)
!
      integer :: time1,time2,count_rate
      character (len=*) :: label
!
!  prints time in seconds
!
      call system_clock(count=time2,count_rate=count_rate)
      print*,"chk_time: ",label,(time2-time1)/real(count_rate)
      time1=time2
!
    endsubroutine chk_time
!***********************************************************************
    subroutine parse_filename(filename,dirpart,filepart)
!
!  Split full pathname of a file into directory part and local filename part.
!
!  02-apr-04/wolf: coded
!
      character (len=*) :: filename,dirpart,filepart
      integer :: i
!
      intent(in)  :: filename
      intent(out) :: dirpart,filepart
!
      i = index(filename,'/',BACK=.true.) ! search last slash
      if (i>0) then
        call safe_character_assign(dirpart,filename(1:i-1))
        call safe_character_assign(filepart,trim(filename(i+1:)))
      else
        call safe_character_assign(dirpart,'.')
        call safe_character_assign(filepart,trim(filename))
      endif

    endsubroutine parse_filename
!***********************************************************************
    subroutine safe_character_assign(dest,src)
!
!  Do character string assignement with check against overflow
!
!  08-oct-02/tony: coded
!  25-oct-02/axel: added tag in output to give name of routine
!
      character (len=*), intent(in):: src
      character (len=*), intent(inout):: dest
      integer :: destLen, srcLen

      destLen = len(dest)
      srcLen = len(src)

      if (destLen<srcLen) then
         print *, "safe_character_assign: ", &
              "RUNTIME ERROR: FORCED STRING TRUNCATION WHEN ASSIGNING '" &
               //src//"' to '"//dest//"'"
         dest=src(1:destLen)
      else
         dest=src
      end if

    endsubroutine safe_character_assign
!***********************************************************************
    subroutine safe_character_append_2(str1,str2)
!
!  08-oct-02/wolf: coded
!
      character (len=*), intent(inout):: str1
      character (len=*), intent(in):: str2
!
      call safe_character_assign(str1, trim(str1) // str2)
!
    endsubroutine safe_character_append_2
!***********************************************************************
    subroutine safe_character_append_3(str1,str2,str3)
!
!  08-oct-02/wolf: coded
!
      character (len=*), intent(inout):: str1
      character (len=*), intent(in):: str2,str3
!
      call safe_character_assign(str1, trim(str1) // trim(str2) // trim(str3))
!
    endsubroutine safe_character_append_3
!***********************************************************************
    subroutine input_array(file,a,dimx,dimy,dimz,dimv)
!
!  Generalized form of input, allows specifying dimension
!  27-sep-03/axel: coded
!
      character (len=*) :: file
      integer :: dimx,dimy,dimz,dimv
      real, dimension (dimx,dimy,dimz,dimv) :: a
!
      open(1,FILE=file,FORM='unformatted')
      read(1) a
      close(1)
!
    endsubroutine input_array
!***********************************************************************
    function spline_derivative(z,f)
!
!  computes derivative of a given function using spline interpolation
!
!  01-apr-03/tobi: originally coded by Aake Nordlund
!
      implicit none
      real, dimension(:) :: z
      real, dimension(:), intent(in) :: f
      real, dimension(size(z)) :: w1,w2,w3
      real, dimension(size(z)) :: d,spline_derivative
      real :: c
      integer :: mz,k

      mz=size(z)

      w1(1)=1./(z(2)-z(1))**2
      w3(1)=-1./(z(3)-z(2))**2
      w2(1)=w1(1)+w3(1)
      d(1)=2.*((f(2)-f(1))/(z(2)-z(1))**3 &
                  -(f(3)-f(2))/(z(3)-z(2))**3)
!
! interior points
!
      w1(2:mz-1)=1./(z(2:mz-1)-z(1:mz-2))
      w3(2:mz-1)=1./(z(3:mz)-z(2:mz-1))
      w2(2:mz-1)=2.*(w1(2:mz-1)+w3(2:mz-1))

      d(2:mz-1)=3.*(w3(2:mz-1)**2*(f(3:mz)-f(2:mz-1)) &
           +w1(2:mz-1)**2*(f(2:mz-1)-f(1:mz-2)))

!
! last point
!
      w1(mz)=1./(z(mz-1)-z(mz-2))**2
      w3(mz)=-1./(z(mz)-z(mz-1))**2
      w2(mz)=w1(mz)+w3(mz)
      d(mz)=2.*((f(mz-1)-f(mz-2))/(z(mz-1)-z(mz-2))**3 &
           -(f(mz)-f(mz-1))/(z(mz)-z(mz-1))**3)
!
! eliminate at first point
!
      c=-w3(1)/w3(2)
      w1(1)=w1(1)+c*w1(2)
      w2(1)=w2(1)+c*w2(2)
      d(1)=d(1)+c*d(2)
      w3(1)=w2(1)
      w2(1)=w1(1)
!
! eliminate at last point
!
      c=-w1(mz)/w1(mz-1)
      w2(mz)=w2(mz)+c*w2(mz-1)
      w3(mz)=w3(mz)+c*w3(mz-1)
      d(mz)=d(mz)+c*d(mz-1)
      w1(mz)=w2(mz)
      w2(mz)=w3(mz)
!
! eliminate subdiagonal
!
      do k=2,mz
         c=-w1(k)/w2(k-1)
         w2(k)=w2(k)+c*w3(k-1)
         d(k)=d(k)+c*d(k-1)
      end do
!
! backsubstitute
!
      d(mz)=d(mz)/w2(mz)
      do k=mz-1,1,-1
         d(k)=(d(k)-w3(k)*d(k+1))/w2(k)
      end do

      spline_derivative=d
    end function spline_derivative
!***********************************************************************
    function spline_derivative_double(z,f)
!
!  computes derivative of a given function using spline interpolation
!
!  01-apr-03/tobi: originally coded by Aake Nordlund
!  11-apr-03/axel: double precision version
!
      implicit none
      real, dimension(:) :: z
      double precision, dimension(:), intent(in) :: f
      double precision, dimension(size(z)) :: w1,w2,w3
      double precision, dimension(size(z)) :: d,spline_derivative_double
      double precision :: c
      integer :: mz,k

      mz=size(z)

      w1(1)=1./(z(2)-z(1))**2
      w3(1)=-1./(z(3)-z(2))**2
      w2(1)=w1(1)+w3(1)
      d(1)=2.*((f(2)-f(1))/(z(2)-z(1))**3 &
                  -(f(3)-f(2))/(z(3)-z(2))**3)
!
! interior points
!
      w1(2:mz-1)=1./(z(2:mz-1)-z(1:mz-2))
      w3(2:mz-1)=1./(z(3:mz)-z(2:mz-1))
      w2(2:mz-1)=2.*(w1(2:mz-1)+w3(2:mz-1))

      d(2:mz-1)=3.*(w3(2:mz-1)**2*(f(3:mz)-f(2:mz-1)) &
           +w1(2:mz-1)**2*(f(2:mz-1)-f(1:mz-2)))

!
! last point
!
      w1(mz)=1./(z(mz-1)-z(mz-2))**2
      w3(mz)=-1./(z(mz)-z(mz-1))**2
      w2(mz)=w1(mz)+w3(mz)
      d(mz)=2.*((f(mz-1)-f(mz-2))/(z(mz-1)-z(mz-2))**3 &
           -(f(mz)-f(mz-1))/(z(mz)-z(mz-1))**3)
!
! eliminate at first point
!
      c=-w3(1)/w3(2)
      w1(1)=w1(1)+c*w1(2)
      w2(1)=w2(1)+c*w2(2)
      d(1)=d(1)+c*d(2)
      w3(1)=w2(1)
      w2(1)=w1(1)
!
! eliminate at last point
!
      c=-w1(mz)/w1(mz-1)
      w2(mz)=w2(mz)+c*w2(mz-1)
      w3(mz)=w3(mz)+c*w3(mz-1)
      d(mz)=d(mz)+c*d(mz-1)
      w1(mz)=w2(mz)
      w2(mz)=w3(mz)
!
! eliminate subdiagonal
!
      do k=2,mz
         c=-w1(k)/w2(k-1)
         w2(k)=w2(k)+c*w3(k-1)
         d(k)=d(k)+c*d(k-1)
      end do
!
! backsubstitute
!
      d(mz)=d(mz)/w2(mz)
      do k=mz-1,1,-1
         d(k)=(d(k)-w3(k)*d(k+1))/w2(k)
      end do

      spline_derivative_double=d
    end function spline_derivative_double
!***********************************************************************
    function spline_integral(z,f,q0)
!
!  computes integral of a given function using spline interpolation
!
!  01-apr-03/tobi: originally coded by Aake Nordlund
!
      implicit none
      real, dimension(:) :: z
      real, dimension(:) :: f
      real, dimension(size(z)) :: df,dz
      real, dimension(size(z)) :: q,spline_integral
      real, optional :: q0
      integer :: mz,k

      mz=size(z)

      q(1)=0.
      if (present(q0)) q(1)=q0
      df=spline_derivative(z,f)
      dz(2:mz)=z(2:mz)-z(1:mz-1)

      q(2:mz)=.5*dz(2:mz)*(f(1:mz-1)+f(2:mz)) &
              +(1./12.)*dz(2:mz)**2*(df(1:mz-1)-df(2:mz))

      do k=2,mz
         q(k)=q(k)+q(k-1)
      end do

      spline_integral=q
    end function spline_integral
!***********************************************************************
    function spline_integral_double(z,f,q0)
!
!  computes integral of a given function using spline interpolation
!
!  01-apr-03/tobi: originally coded by Aake Nordlund
!  11-apr-03/axel: double precision version
!
      implicit none
      real, dimension(:) :: z
      double precision, dimension(:) :: f
      real, dimension(size(z)) :: dz
      double precision, dimension(size(z)) :: df
      double precision, dimension(size(z)) :: q,spline_integral_double
      double precision, optional :: q0
      integer :: mz,k

      mz=size(z)

      q(1)=0.
      if (present(q0)) q(1)=q0
      df=spline_derivative_double(z,f)
      dz(2:mz)=z(2:mz)-z(1:mz-1)

      q(2:mz)=.5*dz(2:mz)*(f(1:mz-1)+f(2:mz)) &
              +(1./12.)*dz(2:mz)**2*(df(1:mz-1)-df(2:mz))

      do k=2,mz
         q(k)=q(k)+q(k-1)
      end do

      spline_integral_double=q
    end function spline_integral_double
!***********************************************************************
    subroutine tridag(a,b,c,r,u,err)
!
!  solves tridiagonal system
!
!  01-apr-03/tobi: from numerical recipes
!
      implicit none
      real, dimension(:), intent(in) :: a,b,c,r
      real, dimension(:), intent(out) :: u
      real, dimension(size(b)) :: gam
      logical, intent(out), optional :: err
      integer :: n,j
      real :: bet

      if (present(err)) err=.false.
      n=size(b)
      bet=b(1)
      if (bet.eq.0.) then
         print*,'tridag: Error at code stage 1'
         if (present(err)) err=.true.
         return
      endif

      u(1)=r(1)/bet
      do j=2,n
         gam(j)=c(j-1)/bet
         bet=b(j)-a(j)*gam(j)
         if (bet.eq.0.) then
            print*,'tridag: Error at code stage 2'
            if (present(err)) err=.true.
            return
         endif
         u(j)=(r(j)-a(j)*u(j-1))/bet
      end do
      do j=n-1,1,-1
         u(j)=u(j)-gam(j+1)*u(j+1)
      end do
    endsubroutine tridag
!***********************************************************************
    subroutine tridag_double(a,b,c,r,u,err)
!
!  solves tridiagonal system
!
!  01-apr-03/tobi: from numerical recipes
!  11-apr-03/axel: double precision version
!
      implicit none
      double precision, dimension(:), intent(in) :: a,b,c,r
      double precision, dimension(:), intent(out) :: u
      double precision, dimension(size(b)) :: gam
      logical, intent(out), optional :: err
      integer :: n,j
      double precision :: bet

      if (present(err)) err=.false.
      n=size(b)
      bet=b(1)
      if (bet.eq.0.) then
         print*,'tridag_double: Error at code stage 1'
         if (present(err)) err=.true.
         return
      endif

      u(1)=r(1)/bet
      do j=2,n
         gam(j)=c(j-1)/bet
         bet=b(j)-a(j)*gam(j)
         if (bet.eq.0.) then
            print*,'tridag_double: Error at code stage 2'
            if (present(err)) err=.true.
            return
         endif
         u(j)=(r(j)-a(j)*u(j-1))/bet
      end do
      do j=n-1,1,-1
         u(j)=u(j)-gam(j+1)*u(j+1)
      end do
    endsubroutine tridag_double
!***********************************************************************
    subroutine spline(arrx,arry,x2,S,psize1,psize2,err)
!
!  Interpolates in x2 a natural cubic spline with knots defined by the 1d
!  arrays arrx and arry
!
!  25-mar-05/wlad : coded
!
      integer, intent(in) :: psize1,psize2
      integer :: i,j,ct1,ct2
      real, dimension (psize1) :: arrx,arry,h,h1,a,b,d,sol
      real, dimension (psize2) :: x2,S
      real :: fac=0.1666666
      logical, intent(out), optional :: err

      intent(in)  :: arrx,arry,x2
      intent(out) :: S

      if (present(err)) err=.false.
      ct1 = psize1
      ct2 = psize2
!
! Short-circuit if there is only 1 knot
!
      if (ct1 == 1) then
        S = arry(1)
        return
      endif
!
! Breaks if x is not monotonically increasing
!
      do i=1,ct1-1
        if (arrx(i+1).le.arrx(i)) then
          print*,'spline x:y in x2:y2 : vector x is not monotonically increasing'
          if (present(err)) err=.true.
          return
        endif
      enddo
!
! step h
!
      h(1:ct1-1) = arrx(2:ct1) - arrx(1:ct1-1)
      h(ct1) = h(ct1-1)
      h1=1./h
!
! coefficients for tridiagonal system
!
      a(2:ct1) = h(1:ct1-1)
      a(1) = a(2)
!
      b(2:ct1) = 2*(h(1:ct1-1) + h(2:ct1))
      b(1) = b(2)
!
      !c = h
!
      d(2:ct1-1) = 6*((arry(3:ct1) - arry(2:ct1-1))*h1(2:ct1-1) - (arry(2:ct1-1) - arry(1:ct1-2))*h1(1:ct1-2))
      d(1) = 0. ; d(ct1) = 0.
!
      call tridag(a,b,h,d,sol)
!
! interpolation formula
!
      do j=1,ct2
         do i=1,ct1-1
!
            if ((x2(j).ge.arrx(i)).and.(x2(j).le.arrx(i+1))) then
!
! substitute 1/6. by 0.1666666 to avoid divisions 
!
               S(j) = (fac*h1(i)) * (sol(i+1)*(x2(j)-arrx(i))**3 + sol(i)*(arrx(i+1) - x2(j))**3)  + &
                    (x2(j) - arrx(i))*(arry(i+1)*h1(i) - h(i)*sol(i+1)*fac)                          + &
                    (arrx(i+1) - x2(j))*(arry(i)*h1(i) - h(i)*sol(i)*fac)
            endif
!
         enddo
!
! use border values beyond this interval - should perhaps allow for linear
! interpolation
!
         if (x2(j).le.arrx(1)) then
           S(j) = arry(1)
         elseif (x2(j).ge.arrx(ct1)) then
           S(j) = arry(ct1)
         endif
       enddo
!
    endsubroutine spline
!*****************************************************************************
    function complex_phase(z)
!
!  takes complex number and returns Theta where
!  z = A*exp(i*theta)
!
!  17-may-06/anders+jeff: coded
!
      use Cdata, only: pi
!
      real :: c,re,im,complex_phase
      complex :: z
!
      c=abs(z)
      re=real(z)
      im=aimag(z)
! I
  if ( (re .ge. 0.0) .and. (im .ge. 0.0) ) complex_phase =      asin(im/c)
! II
  if ( (re .lt. 0.0) .and. (im .ge. 0.0) ) complex_phase =   pi-asin(im/c)
! III
  if ( (re .lt. 0.0) .and. (im .lt. 0.0) ) complex_phase =   pi-asin(im/c)
! IV
  if ( (re .ge. 0.0) .and. (im .lt. 0.0) ) complex_phase = 2*pi+asin(im/c)
!
   endfunction complex_phase
!*****************************************************************************
    function erfcc(x)
!  nr routine.
!  12-jul-2005/joishi: added, translated syntax to f90, and pencilized
!  21-jul-2006/joishi: generalized.
       real :: x(:)
       real,dimension(size(x)) :: erfcc,t,z


      z=abs(x)
      t=1./(1.+0.5*z)
      erfcc=t*exp(-z*z-1.26551223+t*(1.00002368+t*(.37409196+t* &
            (.09678418+t*(-.18628806+t*(.27886807+t*(-1.13520398+t*  &
            (1.48851587+t*(-.82215223+t*.17087277)))))))))
      where (x.lt.0.) erfcc=2.-erfcc
      return
    endfunction erfcc
!*****************************************************************************
    subroutine besselj_nu_int(res,nu,arg)
!
      use Cdata, only: pi,pi_1
!
!  Calculate the cylindrical bessel function
!  with integer index. The function in gsl_wrapper.c 
!  only calculates the cylindrical Bessel functions 
!  with real index. The amount of factorials in the 
!  real index Bessel function leads to over and underflows
!  as the index goes only moderately high.
!                 
!                 _ 
!             1  /  pi
!  J_m(z) = ____ |     (cos(z*sin(theta)-m*theta)) dtheta 
!                |  
!            pi _/  0
!
!  The function defines its own theta from 0 to pi for the
!  integration, with the same number of points as the 
!  azimuthal direction. 
!
!  06-03-08/wlad: coded
!
      real, dimension(nygrid) :: angle,a
      real :: arg,res,nygrid1,d_angle
      integer :: i,nu
!
      intent(in)  :: nu,arg
      intent(out) :: res
!
      nygrid1=1.
      if (nygrid/=1) nygrid1=nygrid1/(nygrid-1)
      d_angle=pi*nygrid1

      do i=1,nygrid
        angle(i)=(i-1)*d_angle
      enddo
      a=cos(arg*sin(angle)-nu*angle)
!
      if (nygrid>=3) then
        res=pi_1*d_angle*(sum(a(2:nygrid-1))+.5*(a(1)+a(nygrid)))
      else
        stop 'besselj_nu_int : too few points to integrate'
      endif
!
    endsubroutine besselj_nu_int
!*****************************************************************************
endmodule General
