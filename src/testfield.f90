! $Id: testfield.f90,v 1.21 2005-11-19 01:18:57 dobler Exp $

!  This modules deals with all aspects of testfield fields; if no
!  testfield fields are invoked, a corresponding replacement dummy
!  routine is used instead which absorbs all the calls to the
!  testfield relevant subroutines listed in here.

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! MVAR CONTRIBUTION 36
! MAUX CONTRIBUTION 0
!
!***************************************************************

module Testfield

  use Cparam
  use Messages

  implicit none

  include 'testfield.h'

  character (len=labellen) :: initaatest='zero'

  ! input parameters
  real, dimension (nx,3) :: bbb
  real :: amplaa=0., kx_aa=1.,ky_aa=1.,kz_aa=1.
  logical :: reinitalize_aatest=.false.
  logical :: xextent=.true.,zextent=.true.,lsoca=.true.,lset_bbtest2=.false.
  integer :: itestfield=1,ktestfield=1
  integer, parameter :: ntestfield=36

  namelist /testfield_init_pars/ &
       xextent,zextent,initaatest

  ! run parameters
  real :: etatest=0.
  namelist /testfield_run_pars/ &
       reinitalize_aatest,xextent,zextent,lsoca, &
       lset_bbtest2,etatest,itestfield,ktestfield

  ! other variables (needs to be consistent with reset list below)
  integer :: idiag_alp11=0,idiag_alp21=0,idiag_alp31=0
  integer :: idiag_alp12=0,idiag_alp22=0,idiag_alp32=0
  integer :: idiag_alp13=0,idiag_alp23=0,idiag_alp33=0
  integer :: idiag_alp11z=0,idiag_alp21z=0,idiag_alp31z=0
  integer :: idiag_alp12z=0,idiag_alp22z=0,idiag_alp32z=0
  integer :: idiag_alp13z=0,idiag_alp23z=0,idiag_alp33z=0
  integer :: idiag_eta111z=0,idiag_eta211z=0,idiag_eta311z=0
  integer :: idiag_eta121z=0,idiag_eta221z=0,idiag_eta321z=0
  integer :: idiag_eta131z=0,idiag_eta231z=0,idiag_eta331z=0
  integer :: idiag_eta113z=0,idiag_eta213z=0,idiag_eta313z=0
  integer :: idiag_eta123z=0,idiag_eta223z=0,idiag_eta323z=0
  integer :: idiag_eta133z=0,idiag_eta233z=0,idiag_eta333z=0
  integer :: idiag_alp11xz=0,idiag_alp21xz=0,idiag_alp31xz=0
  integer :: idiag_alp12xz=0,idiag_alp22xz=0,idiag_alp32xz=0
  integer :: idiag_alp13xz=0,idiag_alp23xz=0,idiag_alp33xz=0
  integer :: idiag_eta111xz=0,idiag_eta211xz=0,idiag_eta311xz=0
  integer :: idiag_eta121xz=0,idiag_eta221xz=0,idiag_eta321xz=0
  integer :: idiag_eta131xz=0,idiag_eta231xz=0,idiag_eta331xz=0
  integer :: idiag_eta113xz=0,idiag_eta213xz=0,idiag_eta313xz=0
  integer :: idiag_eta123xz=0,idiag_eta223xz=0,idiag_eta323xz=0
  integer :: idiag_eta133xz=0,idiag_eta233xz=0,idiag_eta333xz=0
  integer :: idiag_alp11exz=0,idiag_alp21exz=0,idiag_alp31exz=0
  integer :: idiag_alp12exz=0,idiag_alp22exz=0,idiag_alp32exz=0
  integer :: idiag_alp13exz=0,idiag_alp23exz=0,idiag_alp33exz=0

  contains

!***********************************************************************
    subroutine register_testfield()
!
!  Initialise variables which should know that we solve for the vector
!  potential: iaatest, etc; increase nvar accordingly
!
!   3-jun-05/axel: adapted from register_magnetic
!
      use Cdata
      use Mpicomm
      use Sub
!
      logical, save :: first=.true.
      integer :: j
!
      if (.not. first) call stop_it('register_aa called twice')
      first = .false.
!
      ltestfield = .true.
      iaatest = nvar+1          ! indices to access aa
      nvar = nvar+ntestfield    ! added ntestfield variables
!
      if ((ip<=8) .and. lroot) then
        print*, 'register_testfield: nvar = ', nvar
        print*, 'register_testfield: iaatest = ', iaatest
      endif
!
!  Put variable names in array
!
      do j=1,ntestfield
        varname(j) = 'aatest'
      enddo
!
!  identify version number
!
      if (lroot) call cvs_id( &
           "$Id: testfield.f90,v 1.21 2005-11-19 01:18:57 dobler Exp $")
!
      if (nvar > mvar) then
        if (lroot) write(0,*) 'nvar = ', nvar, ', mvar = ', mvar
        call stop_it('register_testfield: nvar > mvar')
      endif
!
!  Writing files for use with IDL
!
      if (lroot) then
        if (maux == 0) then
          if (nvar < mvar) write(4,*) ',aa $'
          if (nvar == mvar) write(4,*) ',aa'
        else
          write(4,*) ',aa $'
        endif
        write(15,*) 'aa = fltarr(mx,my,mz,3)*one'
      endif
!
    endsubroutine register_testfield
!***********************************************************************
    subroutine initialize_testfield(f)
!
!  Perform any post-parameter-read initialization
!
!   2-jun-05/axel: adapted from magnetic
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!
!  set to zero and then rescale the testfield
!  (in future, could call something like init_aa_simple)
!
      if (reinitalize_aatest) then
        f(:,:,:,iaatest:iaatest+ntestfield-1)=0.
      endif
!
!  write testfield information to a file (for convenient post-processing)
!
      if (lroot) then
        open(1,file=trim(datadir)//'/testfield_info.dat',STATUS='unknown')
        write(1,'(a,i1)') 'xextent=',merge(1,0,xextent)
        write(1,'(a,i1)') 'zextent=',merge(1,0,zextent)
        write(1,'(a,i1)') 'lsoca='  ,merge(1,0,lsoca)
        write(1,'(a,i2)') 'itestfield=',itestfield
        write(1,'(a,i2)') 'ktestfield=',ktestfield
        close(1)
      endif
!
    endsubroutine initialize_testfield
!***********************************************************************
    subroutine init_aatest(f,xx,yy,zz)
!
!  initialise testfield; called from start.f90
!
!   2-jun-05/axel: adapted from magnetic
!
      use Cdata
      use Mpicomm
      use Density
      use Gravity, only: gravz
      use Sub
      use Initcond
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz)      :: xx,yy,zz,tmp,prof
      real, dimension (nx,3) :: bb
      real, dimension (nx) :: b2,fact
      real :: beq2
!
      select case(initaatest)

      case('zero', '0'); f(:,:,:,iaatest:iaatest+26)=0.

      case default
        !
        !  Catch unknown values
        !
        if (lroot) print*, 'init_aatest: check initaatest: ', trim(initaatest)
        call stop_it("")

      endselect
!
    endsubroutine init_aatest
!***********************************************************************
    subroutine pencil_criteria_testfield()
!
!   All pencils that the Testfield module depends on are specified here.
!
!  26-jun-05/anders: adapted from magnetic
!
      use Cdata
!
      lpenc_requested(i_uu)=.true.
!
    endsubroutine pencil_criteria_testfield
!***********************************************************************
    subroutine pencil_interdep_testfield(lpencil_in)
!
!  Interdependency among pencils from the Testfield module is specified here.
!
!  26-jun-05/anders: adapted from magnetic
!
      use Cdata
!
      logical, dimension(npencils) :: lpencil_in
!
    endsubroutine pencil_interdep_testfield
!***********************************************************************
    subroutine read_testfield_init_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) then
        read(unit,NML=testfield_init_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=testfield_init_pars,ERR=99)
      endif

99    return
    endsubroutine read_testfield_init_pars
!***********************************************************************
    subroutine write_testfield_init_pars(unit)
      integer, intent(in) :: unit

      write(unit,NML=testfield_init_pars)

    endsubroutine write_testfield_init_pars
!***********************************************************************
    subroutine read_testfield_run_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) then
        read(unit,NML=testfield_run_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=testfield_run_pars,ERR=99)
      endif

99    return
    endsubroutine read_testfield_run_pars
!***********************************************************************
    subroutine write_testfield_run_pars(unit)
      integer, intent(in) :: unit

      write(unit,NML=testfield_run_pars)

    endsubroutine write_testfield_run_pars
!***********************************************************************
    subroutine daatest_dt(f,df,p)
!
!  testfield evolution
!  calculate da^(q)/dt=uxB^(q)+eta*del2A^(q), where q=1,...,9
!
!   3-jun-05/axel: coded
!
      use Cdata
      use Sub
      use Mpicomm, only: stop_it
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p

      real, dimension (nx,3) :: bb,aa,uxB,bbtest,btest,uxbtest,duxbtest
      real, dimension (nx,3) :: del2Atest
      real :: fnamez_mean
      integer :: jtest,jfnamez,j
!
      intent(in)     :: f,p
      intent(inout)  :: df     
!
!  identify module and boundary conditions
!
      if (headtt.or.ldebug) print*,'daatest_dt: SOLVE'
      if (headtt) then
        if (iaxtest /= 0) call identify_bcs('Axtest',iaxtest)
        if (iaytest /= 0) call identify_bcs('Aytest',iaytest)
        if (iaztest /= 0) call identify_bcs('Aztest',iaztest)
      endif
!
!  do each of the 9 test fields at a time
!  but exclude redundancies, e.g. if the averaged field lacks x extent.
!
      do jtest=1,12
        if ((jtest>= 1.and.jtest<= 3)&
        .or.(jtest>= 4.and.jtest<= 6.and.xextent)&
        .or.(jtest>=10.and.jtest<=12.and.xextent.and.(.not.lset_bbtest2))&
        .or.(jtest>= 7.and.jtest<= 9.and.zextent)) then
          iaxtest=iaatest+3*(jtest-1)
          iaztest=iaxtest+2
          call del2v(f,iaxtest,del2Atest)
          select case(itestfield)
            case(1); call set_bbtest(bbtest,jtest,ktestfield)
            case(2); call set_bbtest2(bbtest,jtest)
            case(3); call set_bbtest3(bbtest,jtest)
            case(4); call set_bbtest4(bbtest,jtest)
          endselect
          call cross_mn(p%uu,bbtest,uxB)
          if (lsoca) then
            df(l1:l2,m,n,iaxtest:iaztest)=df(l1:l2,m,n,iaxtest:iaztest) &
              +uxB+etatest*del2Atest
          else
            call curl(f,iaxtest,btest)
            call cross_mn(p%uu,btest,uxbtest)
!
!  subtract average emf
!
            do j=1,3
              jfnamez=idiag_alp11z+3*(jtest-1)+(j-1)
!TEST         duxbtest(:,j)=uxbtest(:,j)-fnamez_copy(n-nghost,ipz+1,jfnamez)
! wd: if you do not run this test, you must at least initialize duxbtest:
              duxbtest(:,j) = 0.
            enddo
!
!  advance test field equation
!
            df(l1:l2,m,n,iaxtest:iaztest)=df(l1:l2,m,n,iaxtest:iaztest) &
              +uxB+etatest*del2Atest+duxbtest
          endif
!
!  calculate alpha, begin by calculating uxbtest (if not already done above)
!
          if (ldiagnos) then
            if (lsoca) then
              call curl(f,iaxtest,btest)
              call cross_mn(p%uu,btest,uxbtest)
            endif
            select case(jtest)
            case(1)
              if (idiag_alp11/=0) call sum_mn_name(uxbtest(:,1),idiag_alp11)
              if (idiag_alp21/=0) call sum_mn_name(uxbtest(:,2),idiag_alp21)
              if (idiag_alp31/=0) call sum_mn_name(uxbtest(:,3),idiag_alp31)
              if (idiag_alp11z/=0) call xysum_mn_name_z(uxbtest(:,1),idiag_alp11z)
              if (idiag_alp21z/=0) call xysum_mn_name_z(uxbtest(:,2),idiag_alp21z)
              if (idiag_alp31z/=0) call xysum_mn_name_z(uxbtest(:,3),idiag_alp31z)
              if (idiag_alp11xz/=0) call ysum_mn_name_xz(uxbtest(:,1),idiag_alp11xz)
              if (idiag_alp21xz/=0) call ysum_mn_name_xz(uxbtest(:,2),idiag_alp21xz)
              if (idiag_alp31xz/=0) call ysum_mn_name_xz(uxbtest(:,3),idiag_alp31xz)
            case(2)
              if (idiag_alp12/=0) call sum_mn_name(uxbtest(:,1),idiag_alp12)
              if (idiag_alp22/=0) call sum_mn_name(uxbtest(:,2),idiag_alp22)
              if (idiag_alp32/=0) call sum_mn_name(uxbtest(:,3),idiag_alp32)
              if (idiag_alp12z/=0) call xysum_mn_name_z(uxbtest(:,1),idiag_alp12z)
              if (idiag_alp22z/=0) call xysum_mn_name_z(uxbtest(:,2),idiag_alp22z)
              if (idiag_alp32z/=0) call xysum_mn_name_z(uxbtest(:,3),idiag_alp32z)
              if (idiag_alp12xz/=0) call ysum_mn_name_xz(uxbtest(:,1),idiag_alp12xz)
              if (idiag_alp22xz/=0) call ysum_mn_name_xz(uxbtest(:,2),idiag_alp22xz)
              if (idiag_alp32xz/=0) call ysum_mn_name_xz(uxbtest(:,3),idiag_alp32xz)
            case(3)
              if (idiag_alp13/=0) call sum_mn_name(uxbtest(:,1),idiag_alp13)
              if (idiag_alp23/=0) call sum_mn_name(uxbtest(:,2),idiag_alp23)
              if (idiag_alp33/=0) call sum_mn_name(uxbtest(:,3),idiag_alp33)
              if (idiag_alp13z/=0) call xysum_mn_name_z(uxbtest(:,1),idiag_alp13z)
              if (idiag_alp23z/=0) call xysum_mn_name_z(uxbtest(:,2),idiag_alp23z)
              if (idiag_alp33z/=0) call xysum_mn_name_z(uxbtest(:,3),idiag_alp33z)
              if (idiag_alp13xz/=0) call ysum_mn_name_xz(uxbtest(:,1),idiag_alp13xz)
              if (idiag_alp23xz/=0) call ysum_mn_name_xz(uxbtest(:,2),idiag_alp23xz)
              if (idiag_alp33xz/=0) call ysum_mn_name_xz(uxbtest(:,3),idiag_alp33xz)
            case(4)
              if (idiag_eta111z/=0) call xysum_mn_name_z(uxbtest(:,1),idiag_eta111z)
              if (idiag_eta211z/=0) call xysum_mn_name_z(uxbtest(:,2),idiag_eta211z)
              if (idiag_eta311z/=0) call xysum_mn_name_z(uxbtest(:,3),idiag_eta311z)
              if (idiag_eta111xz/=0) call ysum_mn_name_xz(uxbtest(:,1),idiag_eta111xz)
              if (idiag_eta211xz/=0) call ysum_mn_name_xz(uxbtest(:,2),idiag_eta211xz)
              if (idiag_eta311xz/=0) call ysum_mn_name_xz(uxbtest(:,3),idiag_eta311xz)
            case(5)
              if (idiag_eta121z/=0) call xysum_mn_name_z(uxbtest(:,1),idiag_eta121z)
              if (idiag_eta221z/=0) call xysum_mn_name_z(uxbtest(:,2),idiag_eta221z)
              if (idiag_eta321z/=0) call xysum_mn_name_z(uxbtest(:,3),idiag_eta321z)
              if (idiag_eta121xz/=0) call ysum_mn_name_xz(uxbtest(:,1),idiag_eta121xz)
              if (idiag_eta221xz/=0) call ysum_mn_name_xz(uxbtest(:,2),idiag_eta221xz)
              if (idiag_eta321xz/=0) call ysum_mn_name_xz(uxbtest(:,3),idiag_eta321xz)
            case(6)
              if (idiag_eta131z/=0) call xysum_mn_name_z(uxbtest(:,1),idiag_eta131z)
              if (idiag_eta231z/=0) call xysum_mn_name_z(uxbtest(:,2),idiag_eta231z)
              if (idiag_eta331z/=0) call xysum_mn_name_z(uxbtest(:,3),idiag_eta331z)
              if (idiag_eta131xz/=0) call ysum_mn_name_xz(uxbtest(:,1),idiag_eta131xz)
              if (idiag_eta231xz/=0) call ysum_mn_name_xz(uxbtest(:,2),idiag_eta231xz)
              if (idiag_eta331xz/=0) call ysum_mn_name_xz(uxbtest(:,3),idiag_eta331xz)
            case(7)
              if (idiag_eta113z/=0) call xysum_mn_name_z(uxbtest(:,1),idiag_eta113z)
              if (idiag_eta213z/=0) call xysum_mn_name_z(uxbtest(:,2),idiag_eta213z)
              if (idiag_eta313z/=0) call xysum_mn_name_z(uxbtest(:,3),idiag_eta313z)
              if (idiag_eta113xz/=0) call ysum_mn_name_xz(uxbtest(:,1),idiag_eta113xz)
              if (idiag_eta213xz/=0) call ysum_mn_name_xz(uxbtest(:,2),idiag_eta213xz)
              if (idiag_eta313xz/=0) call ysum_mn_name_xz(uxbtest(:,3),idiag_eta313xz)
            case(8)
              if (idiag_eta123z/=0) call xysum_mn_name_z(uxbtest(:,1),idiag_eta123z)
              if (idiag_eta223z/=0) call xysum_mn_name_z(uxbtest(:,2),idiag_eta223z)
              if (idiag_eta323z/=0) call xysum_mn_name_z(uxbtest(:,3),idiag_eta323z)
              if (idiag_eta123xz/=0) call ysum_mn_name_xz(uxbtest(:,1),idiag_eta123xz)
              if (idiag_eta223xz/=0) call ysum_mn_name_xz(uxbtest(:,2),idiag_eta223xz)
              if (idiag_eta323xz/=0) call ysum_mn_name_xz(uxbtest(:,3),idiag_eta323xz)
            case(9)
              if (idiag_eta133z/=0) call xysum_mn_name_z(uxbtest(:,1),idiag_eta133z)
              if (idiag_eta233z/=0) call xysum_mn_name_z(uxbtest(:,2),idiag_eta233z)
              if (idiag_eta333z/=0) call xysum_mn_name_z(uxbtest(:,3),idiag_eta333z)
              if (idiag_eta133xz/=0) call ysum_mn_name_xz(uxbtest(:,1),idiag_eta133xz)
              if (idiag_eta233xz/=0) call ysum_mn_name_xz(uxbtest(:,2),idiag_eta233xz)
              if (idiag_eta333xz/=0) call ysum_mn_name_xz(uxbtest(:,3),idiag_eta333xz)
            case(10)
              if (idiag_alp11exz/=0) call ysum_mn_name_xz(uxbtest(:,1),idiag_alp11exz)
              if (idiag_alp21exz/=0) call ysum_mn_name_xz(uxbtest(:,2),idiag_alp21exz)
              if (idiag_alp31exz/=0) call ysum_mn_name_xz(uxbtest(:,3),idiag_alp31exz)
            case(11)
              if (idiag_alp12exz/=0) call ysum_mn_name_xz(uxbtest(:,1),idiag_alp12exz)
              if (idiag_alp22exz/=0) call ysum_mn_name_xz(uxbtest(:,2),idiag_alp22exz)
              if (idiag_alp32exz/=0) call ysum_mn_name_xz(uxbtest(:,3),idiag_alp32exz)
            case(12)
              if (idiag_alp13exz/=0) call ysum_mn_name_xz(uxbtest(:,1),idiag_alp13exz)
              if (idiag_alp23exz/=0) call ysum_mn_name_xz(uxbtest(:,2),idiag_alp23exz)
              if (idiag_alp33exz/=0) call ysum_mn_name_xz(uxbtest(:,3),idiag_alp33exz)
            end select
          endif
        endif
      enddo
!
    endsubroutine daatest_dt
!***********************************************************************
    subroutine set_bbtest(bbtest,jtest,ktestfield)
!
!  set testfield
!
!   3-jun-05/axel: coded
!
      use Cdata
      use Sub
!
      real, dimension (nx,3) :: bbtest
      real, dimension (nx) :: cx,sx,cz,sz
      integer :: jtest,ktestfield
!
      intent(in)  :: jtest,ktestfield
      intent(out) :: bbtest
!
!  xx and zz for calculating diffusive part of emf
!
      cx=cos(ktestfield*x(l1:l2))
      sx=sin(ktestfield*x(l1:l2))
      cz=cos(ktestfield*z(n))
      sz=sin(ktestfield*z(n))
!
!  set bbtest for each of the 9 cases
!
      select case(jtest)
      case(1); bbtest(:,1)=sz; bbtest(:,2)=0.; bbtest(:,3)=0.
      case(2); bbtest(:,1)=0.; bbtest(:,2)=sz; bbtest(:,3)=0.
      case(3); bbtest(:,1)=0.; bbtest(:,2)=0.; bbtest(:,3)=sz
      case(4); bbtest(:,1)=cx; bbtest(:,2)=0.; bbtest(:,3)=0.
      case(5); bbtest(:,1)=0.; bbtest(:,2)=cx; bbtest(:,3)=0.
      case(6); bbtest(:,1)=0.; bbtest(:,2)=0.; bbtest(:,3)=cx
      case(7); bbtest(:,1)=cz; bbtest(:,2)=0.; bbtest(:,3)=0.
      case(8); bbtest(:,1)=0.; bbtest(:,2)=cz; bbtest(:,3)=0.
      case(9); bbtest(:,1)=0.; bbtest(:,2)=0.; bbtest(:,3)=cz
      case(10); bbtest(:,1)=sx; bbtest(:,2)=0.; bbtest(:,3)=0.
      case(11); bbtest(:,1)=0.; bbtest(:,2)=sx; bbtest(:,3)=0.
      case(12); bbtest(:,1)=0.; bbtest(:,2)=0.; bbtest(:,3)=sx
      case default; bbtest(:,:)=0.
      endselect
!
    endsubroutine set_bbtest
!***********************************************************************
    subroutine set_bbtest2(bbtest,jtest)
!
!  set alternative testfield
!
!  10-jun-05/axel: adapted from set_bbtest
!
      use Cdata
      use Sub
!
      real, dimension (nx,3) :: bbtest
      real, dimension (nx) :: cx,sx,cz,sz,xz
      integer :: jtest
!
      intent(in)  :: jtest
      intent(out) :: bbtest
!
!  xx and zz for calculating diffusive part of emf
!
      cx=cos(x(l1:l2))
      sx=sin(x(l1:l2))
      cz=cos(z(n))
      sz=sin(z(n))
      xz=cx*cz
!
!  set bbtest for each of the 9 cases
!
      select case(jtest)
      case(1); bbtest(:,1)=xz; bbtest(:,2)=0.; bbtest(:,3)=0.
      case(2); bbtest(:,1)=0.; bbtest(:,2)=xz; bbtest(:,3)=0.
      case(3); bbtest(:,1)=0.; bbtest(:,2)=0.; bbtest(:,3)=xz
      case(4); bbtest(:,1)=sx; bbtest(:,2)=0.; bbtest(:,3)=0.
      case(5); bbtest(:,1)=0.; bbtest(:,2)=sx; bbtest(:,3)=0.
      case(6); bbtest(:,1)=0.; bbtest(:,2)=0.; bbtest(:,3)=sx
      case(7); bbtest(:,1)=sz; bbtest(:,2)=0.; bbtest(:,3)=0.
      case(8); bbtest(:,1)=0.; bbtest(:,2)=sz; bbtest(:,3)=0.
      case(9); bbtest(:,1)=0.; bbtest(:,2)=0.; bbtest(:,3)=sz
      case default; bbtest(:,:)=0.
      endselect
!
    endsubroutine set_bbtest2
!***********************************************************************
    subroutine set_bbtest4(bbtest,jtest)
!
!  set testfield using constant and linear functions
!
!  15-jun-05/axel: adapted from set_bbtest3
!
      use Cdata
      use Sub
!
      real, dimension (nx,3) :: bbtest
      real, dimension (nx) :: xx,zz
      integer :: jtest
!
      intent(in)  :: jtest
      intent(out) :: bbtest
!
!  xx and zz for calculating diffusive part of emf
!
      xx=x(l1:l2)
      zz=z(n)
!
!  set bbtest for each of the 9 cases
!
      select case(jtest)
      case(1); bbtest(:,1)=1.; bbtest(:,2)=0.; bbtest(:,3)=0.
      case(2); bbtest(:,1)=0.; bbtest(:,2)=1.; bbtest(:,3)=0.
      case(3); bbtest(:,1)=0.; bbtest(:,2)=0.; bbtest(:,3)=1.
      case(4); bbtest(:,1)=xx; bbtest(:,2)=0.; bbtest(:,3)=0.
      case(5); bbtest(:,1)=0.; bbtest(:,2)=xx; bbtest(:,3)=0.
      case(6); bbtest(:,1)=0.; bbtest(:,2)=0.; bbtest(:,3)=xx
      case(7); bbtest(:,1)=zz; bbtest(:,2)=0.; bbtest(:,3)=0.
      case(8); bbtest(:,1)=0.; bbtest(:,2)=zz; bbtest(:,3)=0.
      case(9); bbtest(:,1)=0.; bbtest(:,2)=0.; bbtest(:,3)=zz
      case default; bbtest(:,:)=0.
      endselect
!
    endsubroutine set_bbtest4
!***********************************************************************
    subroutine set_bbtest3(bbtest,jtest)
!
!  set alternative testfield
!
!  10-jun-05/axel: adapted from set_bbtest
!
      use Cdata
      use Sub
!
      real, dimension (nx,3) :: bbtest
      real, dimension (nx) :: cx,sx,cz,sz
      integer :: jtest
!
      intent(in)  :: jtest
      intent(out) :: bbtest
!
!  xx and zz for calculating diffusive part of emf
!
      cx=cos(x(l1:l2))
      sx=sin(x(l1:l2))
      cz=cos(z(n))
      sz=sin(z(n))
!
!  set bbtest for each of the 9 cases
!
      select case(jtest)
      case(1); bbtest(:,1)=1.; bbtest(:,2)=0.; bbtest(:,3)=0.
      case(2); bbtest(:,1)=0.; bbtest(:,2)=1.; bbtest(:,3)=0.
      case(3); bbtest(:,1)=0.; bbtest(:,2)=0.; bbtest(:,3)=1.
      case(4); bbtest(:,1)=cx; bbtest(:,2)=0.; bbtest(:,3)=0.
      case(5); bbtest(:,1)=0.; bbtest(:,2)=sx; bbtest(:,3)=0.
      case(6); bbtest(:,1)=0.; bbtest(:,2)=0.; bbtest(:,3)=sx
      case(7); bbtest(:,1)=sz; bbtest(:,2)=0.; bbtest(:,3)=0.
      case(8); bbtest(:,1)=0.; bbtest(:,2)=sz; bbtest(:,3)=0.
      case(9); bbtest(:,1)=0.; bbtest(:,2)=0.; bbtest(:,3)=cz
      case default; bbtest(:,:)=0.
      endselect
!
    endsubroutine set_bbtest3
!***********************************************************************
    subroutine rprint_testfield(lreset,lwrite)
!
!  reads and registers print parameters relevant for testfield fields
!
!   3-jun-05/axel: adapted from rprint_magnetic
!
      use Cdata
      use Sub
!
      integer :: iname,inamez,inamexz
      logical :: lreset,lwr
      logical, optional :: lwrite
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
!  reset everything in case of RELOAD
!  (this needs to be consistent with what is defined above!)
!
      if (lreset) then
        idiag_alp11=0; idiag_alp21=0; idiag_alp31=0
        idiag_alp12=0; idiag_alp22=0; idiag_alp32=0
        idiag_alp13=0; idiag_alp23=0; idiag_alp33=0
        idiag_alp11z=0; idiag_alp21z=0; idiag_alp31z=0
        idiag_alp12z=0; idiag_alp22z=0; idiag_alp32z=0
        idiag_alp13z=0; idiag_alp23z=0; idiag_alp33z=0
        idiag_eta111z=0; idiag_eta211z=0; idiag_eta311z=0
        idiag_eta121z=0; idiag_eta221z=0; idiag_eta321z=0
        idiag_eta131z=0; idiag_eta231z=0; idiag_eta331z=0
        idiag_eta113z=0; idiag_eta213z=0; idiag_eta313z=0
        idiag_eta123z=0; idiag_eta223z=0; idiag_eta323z=0
        idiag_eta133z=0; idiag_eta233z=0; idiag_eta333z=0
        idiag_alp11xz=0; idiag_alp21xz=0; idiag_alp31xz=0
        idiag_alp12xz=0; idiag_alp22xz=0; idiag_alp32xz=0
        idiag_alp13xz=0; idiag_alp23xz=0; idiag_alp33xz=0
        idiag_eta111xz=0; idiag_eta211xz=0; idiag_eta311xz=0
        idiag_eta121xz=0; idiag_eta221xz=0; idiag_eta321xz=0
        idiag_eta131xz=0; idiag_eta231xz=0; idiag_eta331xz=0
        idiag_eta113xz=0; idiag_eta213xz=0; idiag_eta313xz=0
        idiag_eta123xz=0; idiag_eta223xz=0; idiag_eta323xz=0
        idiag_eta133xz=0; idiag_eta233xz=0; idiag_eta333xz=0
        idiag_alp11exz=0; idiag_alp21exz=0; idiag_alp31exz=0
        idiag_alp12exz=0; idiag_alp22exz=0; idiag_alp32exz=0
        idiag_alp13exz=0; idiag_alp23exz=0; idiag_alp33exz=0
      endif
!
!  check for those quantities that we want to evaluate online
!
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'alp11',idiag_alp11)
        call parse_name(iname,cname(iname),cform(iname),'alp21',idiag_alp21)
        call parse_name(iname,cname(iname),cform(iname),'alp31',idiag_alp31)
        call parse_name(iname,cname(iname),cform(iname),'alp12',idiag_alp12)
        call parse_name(iname,cname(iname),cform(iname),'alp22',idiag_alp22)
        call parse_name(iname,cname(iname),cform(iname),'alp32',idiag_alp32)
        call parse_name(iname,cname(iname),cform(iname),'alp13',idiag_alp13)
        call parse_name(iname,cname(iname),cform(iname),'alp23',idiag_alp23)
        call parse_name(iname,cname(iname),cform(iname),'alp33',idiag_alp33)
      enddo
!
!  check for those quantities for which we want xy-averages
!
      do inamez=1,nnamez
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'alp11z',idiag_alp11z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'alp21z',idiag_alp21z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'alp31z',idiag_alp31z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'alp12z',idiag_alp12z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'alp22z',idiag_alp22z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'alp32z',idiag_alp32z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'alp13z',idiag_alp13z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'alp23z',idiag_alp23z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'alp33z',idiag_alp33z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'eta111z',idiag_eta111z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'eta211z',idiag_eta211z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'eta311z',idiag_eta311z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'eta121z',idiag_eta121z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'eta221z',idiag_eta221z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'eta321z',idiag_eta321z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'eta131z',idiag_eta131z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'eta231z',idiag_eta231z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'eta331z',idiag_eta331z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'eta113z',idiag_eta113z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'eta213z',idiag_eta213z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'eta313z',idiag_eta313z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'eta123z',idiag_eta123z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'eta223z',idiag_eta223z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'eta323z',idiag_eta323z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'eta133z',idiag_eta133z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'eta233z',idiag_eta233z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'eta333z',idiag_eta333z)
      enddo
!
!  check for those quantities for which we want y-averages
!
      do inamexz=1,nnamexz
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'alp11xz',idiag_alp11xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'alp21xz',idiag_alp21xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'alp31xz',idiag_alp31xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'alp12xz',idiag_alp12xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'alp22xz',idiag_alp22xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'alp32xz',idiag_alp32xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'alp13xz',idiag_alp13xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'alp23xz',idiag_alp23xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'alp33xz',idiag_alp33xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'eta111xz',idiag_eta111xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'eta211xz',idiag_eta211xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'eta311xz',idiag_eta311xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'eta121xz',idiag_eta121xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'eta221xz',idiag_eta221xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'eta321xz',idiag_eta321xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'eta131xz',idiag_eta131xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'eta231xz',idiag_eta231xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'eta331xz',idiag_eta331xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'eta113xz',idiag_eta113xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'eta213xz',idiag_eta213xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'eta313xz',idiag_eta313xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'eta123xz',idiag_eta123xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'eta223xz',idiag_eta223xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'eta323xz',idiag_eta323xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'eta133xz',idiag_eta133xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'eta233xz',idiag_eta233xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'eta333xz',idiag_eta333xz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'alp11exz',idiag_alp11exz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'alp21exz',idiag_alp21exz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'alp31exz',idiag_alp31exz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'alp12exz',idiag_alp12exz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'alp22exz',idiag_alp22exz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'alp32exz',idiag_alp32exz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'alp13exz',idiag_alp13exz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'alp23exz',idiag_alp23exz)
        call parse_name(inamexz,cnamexz(inamexz),cformxz(inamexz),'alp33exz',idiag_alp33exz)
      enddo
!
!  write column, idiag_XYZ, where our variable XYZ is stored
!
      if (lwr) then
        write(3,*) 'idiag_alp11=',idiag_alp11
        write(3,*) 'idiag_alp21=',idiag_alp21
        write(3,*) 'idiag_alp31=',idiag_alp31
        write(3,*) 'idiag_alp12=',idiag_alp12
        write(3,*) 'idiag_alp22=',idiag_alp22
        write(3,*) 'idiag_alp32=',idiag_alp32
        write(3,*) 'idiag_alp13=',idiag_alp13
        write(3,*) 'idiag_alp23=',idiag_alp23
        write(3,*) 'idiag_alp33=',idiag_alp33
        write(3,*) 'idiag_alp11z=',idiag_alp11z
        write(3,*) 'idiag_alp21z=',idiag_alp21z
        write(3,*) 'idiag_alp31z=',idiag_alp31z
        write(3,*) 'idiag_alp12z=',idiag_alp12z
        write(3,*) 'idiag_alp22z=',idiag_alp22z
        write(3,*) 'idiag_alp32z=',idiag_alp32z
        write(3,*) 'idiag_alp13z=',idiag_alp13z
        write(3,*) 'idiag_alp23z=',idiag_alp23z
        write(3,*) 'idiag_alp33z=',idiag_alp33z
        write(3,*) 'idiag_eta111z=',idiag_eta111z
        write(3,*) 'idiag_eta211z=',idiag_eta211z
        write(3,*) 'idiag_eta311z=',idiag_eta311z
        write(3,*) 'idiag_eta121z=',idiag_eta121z
        write(3,*) 'idiag_eta221z=',idiag_eta221z
        write(3,*) 'idiag_eta321z=',idiag_eta321z
        write(3,*) 'idiag_eta131z=',idiag_eta131z
        write(3,*) 'idiag_eta231z=',idiag_eta231z
        write(3,*) 'idiag_eta331z=',idiag_eta331z
        write(3,*) 'idiag_eta113z=',idiag_eta113z
        write(3,*) 'idiag_eta213z=',idiag_eta213z
        write(3,*) 'idiag_eta313z=',idiag_eta313z
        write(3,*) 'idiag_eta123z=',idiag_eta123z
        write(3,*) 'idiag_eta223z=',idiag_eta223z
        write(3,*) 'idiag_eta323z=',idiag_eta323z
        write(3,*) 'idiag_eta133z=',idiag_eta133z
        write(3,*) 'idiag_eta233z=',idiag_eta233z
        write(3,*) 'idiag_eta333z=',idiag_eta333z
        write(3,*) 'idiag_alp11xz=',idiag_alp11xz
        write(3,*) 'idiag_alp21xz=',idiag_alp21xz
        write(3,*) 'idiag_alp31xz=',idiag_alp31xz
        write(3,*) 'idiag_alp12xz=',idiag_alp12xz
        write(3,*) 'idiag_alp22xz=',idiag_alp22xz
        write(3,*) 'idiag_alp32xz=',idiag_alp32xz
        write(3,*) 'idiag_alp13xz=',idiag_alp13xz
        write(3,*) 'idiag_alp23xz=',idiag_alp23xz
        write(3,*) 'idiag_alp33xz=',idiag_alp33xz
        write(3,*) 'idiag_eta111xz=',idiag_eta111xz
        write(3,*) 'idiag_eta211xz=',idiag_eta211xz
        write(3,*) 'idiag_eta311xz=',idiag_eta311xz
        write(3,*) 'idiag_eta121xz=',idiag_eta121xz
        write(3,*) 'idiag_eta221xz=',idiag_eta221xz
        write(3,*) 'idiag_eta321xz=',idiag_eta321xz
        write(3,*) 'idiag_eta131xz=',idiag_eta131xz
        write(3,*) 'idiag_eta231xz=',idiag_eta231xz
        write(3,*) 'idiag_eta331xz=',idiag_eta331xz
        write(3,*) 'idiag_eta113xz=',idiag_eta113xz
        write(3,*) 'idiag_eta213xz=',idiag_eta213xz
        write(3,*) 'idiag_eta313xz=',idiag_eta313xz
        write(3,*) 'idiag_eta123xz=',idiag_eta123xz
        write(3,*) 'idiag_eta223xz=',idiag_eta223xz
        write(3,*) 'idiag_eta323xz=',idiag_eta323xz
        write(3,*) 'idiag_eta133xz=',idiag_eta133xz
        write(3,*) 'idiag_eta233xz=',idiag_eta233xz
        write(3,*) 'idiag_eta333xz=',idiag_eta333xz
        write(3,*) 'idiag_alp11exz=',idiag_alp11exz
        write(3,*) 'idiag_alp21exz=',idiag_alp21exz
        write(3,*) 'idiag_alp31exz=',idiag_alp31exz
        write(3,*) 'idiag_alp12exz=',idiag_alp12exz
        write(3,*) 'idiag_alp22exz=',idiag_alp22exz
        write(3,*) 'idiag_alp32exz=',idiag_alp32exz
        write(3,*) 'idiag_alp13exz=',idiag_alp13exz
        write(3,*) 'idiag_alp23exz=',idiag_alp23exz
        write(3,*) 'idiag_alp33exz=',idiag_alp33exz
        write(3,*) 'iaatest=',iaatest
        write(3,*) 'nnamez=',nnamez
        write(3,*) 'nnamexy=',nnamexy
        write(3,*) 'nnamexz=',nnamexz
      endif
!
    endsubroutine rprint_testfield

endmodule Testfield
