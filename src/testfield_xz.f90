! $Id: testfield_xz.f90,v 1.6 2007-09-03 14:55:14 brandenb Exp $

!  This modules deals with all aspects of testfield fields; if no
!  testfield fields are invoked, a corresponding replacement dummy
!  routine is used instead which absorbs all the calls to the
!  testfield relevant subroutines listed in here.

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! MVAR CONTRIBUTION 6
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
  real, dimension(3) :: B_ext=(/0.,0.,0./)
  real, dimension (nx,3) :: bbb
  real :: amplaa=0., kx_aa=1.,ky_aa=1.,kz_aa=1.
  logical :: reinitalize_aatest=.false.
  logical :: zextent=.true.,lsoca=.true.,lset_bbtest2=.false.
  character (len=labellen) :: itestfield='B11-B21'
  real :: ktestfield=1.
  integer, parameter :: njtest=2,ntestfield=3*njtest

  namelist /testfield_init_pars/ &
       B_ext,zextent,initaatest

  ! run parameters
  real :: etatest=0.
  namelist /testfield_run_pars/ &
       B_ext,reinitalize_aatest,zextent,lsoca, &
       lset_bbtest2,etatest,itestfield,ktestfield

  ! other variables (needs to be consistent with reset list below)
  integer :: idiag_E111z=0      ! DIAG_DOC: ${\cal E}_1^{11}$
  integer :: idiag_E211z=0      ! DIAG_DOC: ${\cal E}_2^{11}$
  integer :: idiag_E311z=0      ! DIAG_DOC: ${\cal E}_3^{11}$
  integer :: idiag_E121z=0      ! DIAG_DOC: ${\cal E}_1^{21}$
  integer :: idiag_E221z=0      ! DIAG_DOC: ${\cal E}_2^{21}$
  integer :: idiag_E321z=0      ! DIAG_DOC: ${\cal E}_3^{21}$
  integer :: idiag_alp11=0      ! DIAG_DOC: $\alpha_{11}$
  integer :: idiag_alp21=0      ! DIAG_DOC: $\alpha_{21}$
  integer :: idiag_eta11=0      ! DIAG_DOC: $\eta_{113}k$
  integer :: idiag_eta21=0      ! DIAG_DOC: $\eta_{213}k$
  integer :: idiag_b11rms=0     ! DIAG_DOC: $\left<b_{11}^2\right>$
  integer :: idiag_b21rms=0     ! DIAG_DOC: $\left<b_{21}^2\right>$

  real, dimension (mz,3,ntestfield/3) :: uxbtestm

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
           "$Id: testfield_xz.f90,v 1.6 2007-09-03 14:55:14 brandenb Exp $")
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
      real, dimension (mx,my,mz,mfarray) :: f
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
        write(1,'(a,i1)') 'zextent=',merge(1,0,zextent)
        write(1,'(a,i1)') 'lsoca='  ,merge(1,0,lsoca)
        write(1,'(3a)') "itestfield='",trim(itestfield)//"'"
        write(1,'(a,f3.0)') 'ktestfield=',ktestfield
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
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz)      :: xx,yy,zz,tmp,prof
      real, dimension (nx,3) :: bb
      real, dimension (nx) :: b2,fact
      real :: beq2
!
      select case(initaatest)

      case('zero', '0'); f(:,:,:,iaatest:iaatest+ntestfield-1)=0.

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
!  testfield evolution:
!
!  calculate da^(pq)/dt=Uxb^(pq)+uxB^(pq)+uxb-<uxb>+eta*del2A^(pq),
!    where p=1,2 and q=1
!
!   3-jun-05/axel: coded
!
      use Cdata
      use Sub
      use Mpicomm, only: stop_it
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p

      real, dimension (nx,3) :: bb,aa,uxB,bbtest,btest,uxbtest,duxbtest
      real, dimension (nx,3,njtest) :: Eipq,bpq
      real, dimension (nx,3) :: del2Atest
      real, dimension (nx) :: bpq2
      real, dimension(mz), save :: cz,sz
      integer :: jtest,jfnamez,j
      logical,save :: first=.true.

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
!  Note: the same block of lines occurs again further down in the file.
!
      do jtest=1,njtest
        iaxtest=iaatest+3*(jtest-1)
        iaztest=iaxtest+2
        call del2v(f,iaxtest,del2Atest)
        select case(itestfield)
          case('B11-B21'); call set_bbtest(bbtest,jtest,ktestfield)
        endselect
!
!  add an external field, if present
!
        if (B_ext(1)/=0.) bbtest(:,1)=bbtest(:,1)+B_ext(1)
        if (B_ext(2)/=0.) bbtest(:,2)=bbtest(:,2)+B_ext(2)
        if (B_ext(3)/=0.) bbtest(:,3)=bbtest(:,3)+B_ext(3)
!
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
            duxbtest(:,j)=uxbtest(:,j)-uxbtestm(n,j,jtest)
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
        if ((ldiagnos.or.l1ddiagnos).and.lsoca) then
          call curl(f,iaxtest,btest)
          call cross_mn(p%uu,btest,uxbtest)
        endif
        bpq(:,:,jtest)=btest
        Eipq(:,:,jtest)=uxbtest
      enddo
!
!  diffusive time step, just take the max of diffus_eta (if existent)
!  and whatever is calculated here
!
      if (lfirst.and.ldt) then
        diffus_eta=max(diffus_eta,etatest*dxyz_2)
      endif
!
!  in the following block, we have already swapped the 4-6 entries with 7-9
!
      if (ldiagnos) then  
        if (first) then
          cz=cos(z)
          sz=sin(z)
        endif
        first=.false.
!
        if (idiag_E111z/=0) call xysum_mn_name_z(Eipq(:,1,1),idiag_E111z)
        if (idiag_E211z/=0) call xysum_mn_name_z(Eipq(:,2,1),idiag_E211z)
        if (idiag_E311z/=0) call xysum_mn_name_z(Eipq(:,3,1),idiag_E311z)
        if (idiag_E121z/=0) call xysum_mn_name_z(Eipq(:,1,2),idiag_E121z)
        if (idiag_E221z/=0) call xysum_mn_name_z(Eipq(:,2,2),idiag_E221z)
        if (idiag_E321z/=0) call xysum_mn_name_z(Eipq(:,3,2),idiag_E321z)
!
!  alpha and eta
!
        if (idiag_alp11/=0) call sum_mn_name(+cz(n)*Eipq(:,1,1)+sz(n)*Eipq(:,1,2),idiag_alp11)
        if (idiag_alp21/=0) call sum_mn_name(+cz(n)*Eipq(:,2,1)+sz(n)*Eipq(:,2,2),idiag_alp21)
        if (idiag_eta11/=0) call sum_mn_name(-sz(n)*Eipq(:,1,1)+cz(n)*Eipq(:,1,2),idiag_eta11)
        if (idiag_eta21/=0) call sum_mn_name(-sz(n)*Eipq(:,2,1)+cz(n)*Eipq(:,2,2),idiag_eta21)
!
!  rms values of small scales fields bpq in response to the test fields Bpq
!
        if (idiag_b11rms/=0) then
          call dot2(bpq(:,:,1),bpq2)
          call sum_mn_name(bpq2,idiag_b11rms,lsqrt=.true.)
        endif
!
        if (idiag_b21rms/=0) then
          call dot2(bpq(:,:,2),bpq2)
          call sum_mn_name(bpq2,idiag_b21rms,lsqrt=.true.)
        endif
!
      endif
!
!
    endsubroutine daatest_dt
!***********************************************************************
    subroutine calc_ltestfield_pars(f)
!
!  calculate <uxb>, which is needed when lsoca=.false.
!
!  21-jan-06/axel: coded
!
      use Cdata
      use Sub
      use Hydro, only: calc_pencils_hydro
      use Mpicomm, only: stop_it
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      real, dimension (nx,3) :: btest,uxbtest
      integer :: jtest,j,nxy=nx*ny
      logical :: headtt_save
      real :: fac
      type (pencil_case) :: p
!
      intent(in)     :: f
!
!  In this routine we will reset headtt after the first pencil,
!  so we need to reset it afterwards.
!
      headtt_save=headtt
      fac=1./nxy
!
!  do each of the 9 test fields at a time
!  but exclude redundancies, e.g. if the averaged field lacks x extent.
!  Note: the same block of lines occurs again further up in the file.
!
      do jtest=1,njtest
        iaxtest=iaatest+3*(jtest-1)
        iaztest=iaxtest+2
        if (lsoca) then
          uxbtestm(:,:,jtest)=0.
        else
          do n=n1,n2
            uxbtestm(n,:,jtest)=0.
            do m=m1,m2
              call calc_pencils_hydro(f,p)
              call curl(f,iaxtest,btest)
              call cross_mn(p%uu,btest,uxbtest)
              do j=1,3
                uxbtestm(n,j,jtest)=uxbtestm(n,j,jtest)+fac*sum(uxbtest(:,j))
              enddo
              headtt=.false.
            enddo
          enddo
!
!  do communication for array of size mz,3,ntestfield/3=mz*ntestfield
!  (Could do the same in momentum removal procedure.)
!
!  real, dimension (mz,3,ntestfield/3) :: fsum_tmp,fsum
!           fsum_tmp=uxbtestm
!           call mpiallreduce_sum(fsum_tmp,fsum)
!           uxbtestm=fsum
!
        endif
      enddo
!
!  reset headtt
!
      headtt=headtt_save
!
    endsubroutine calc_ltestfield_pars
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
      real, dimension (nx) :: cz,sz
      integer :: jtest
      real :: ktestfield
!
      intent(in)  :: jtest,ktestfield
      intent(out) :: bbtest
!
!  zz for calculating diffusive part of emf
!
      cz=cos(ktestfield*z(n))
      sz=sin(ktestfield*z(n))
!
!  set bbtest for each of the 9 cases
!
      select case(jtest)
      case(1); bbtest(:,1)=cz; bbtest(:,2)=0.; bbtest(:,3)=0.
      case(2); bbtest(:,1)=sz; bbtest(:,2)=0.; bbtest(:,3)=0.
      case default; bbtest(:,:)=0.
      endselect
!
    endsubroutine set_bbtest
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
        idiag_E111z=0; idiag_E211z=0; idiag_E311z=0
        idiag_E121z=0; idiag_E221z=0; idiag_E321z=0
        idiag_alp11=0; idiag_alp21=0
        idiag_eta11=0; idiag_eta21=0
        idiag_b11rms=0; idiag_b21rms=0
      endif
!
!  check for those quantities that we want to evaluate online
! 
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'alp11',idiag_alp11)
        call parse_name(iname,cname(iname),cform(iname),'alp21',idiag_alp21)
        call parse_name(iname,cname(iname),cform(iname),'eta11',idiag_eta11)
        call parse_name(iname,cname(iname),cform(iname),'eta21',idiag_eta21)
        call parse_name(iname,cname(iname),cform(iname),'b11rms',idiag_b11rms)
        call parse_name(iname,cname(iname),cform(iname),'b21rms',idiag_b21rms)
      enddo
!
!  check for those quantities for which we want xy-averages
!
      do inamez=1,nnamez
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E111z',idiag_E111z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E211z',idiag_E211z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E311z',idiag_E311z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E121z',idiag_E121z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E221z',idiag_E221z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E321z',idiag_E321z)
      enddo
!
!  write column, idiag_XYZ, where our variable XYZ is stored
!
      if (lwr) then
        write(3,*) 'idiag_alp11=',idiag_alp11
        write(3,*) 'idiag_alp21=',idiag_alp21
        write(3,*) 'idiag_eta11=',idiag_eta11
        write(3,*) 'idiag_eta21=',idiag_eta21
        write(3,*) 'idiag_b11rms=',idiag_b11rms
        write(3,*) 'idiag_b21rms=',idiag_b21rms
        write(3,*) 'idiag_E111z=',idiag_E111z
        write(3,*) 'idiag_E211z=',idiag_E211z
        write(3,*) 'idiag_E311z=',idiag_E311z
        write(3,*) 'idiag_E121z=',idiag_E121z
        write(3,*) 'idiag_E221z=',idiag_E221z
        write(3,*) 'idiag_E321z=',idiag_E321z
        write(3,*) 'iaatest=',iaatest
        write(3,*) 'nnamez=',nnamez
        write(3,*) 'nnamexy=',nnamexy
        write(3,*) 'nnamexz=',nnamexz
      endif
!
    endsubroutine rprint_testfield

endmodule Testfield
