! $Id: aerosol_init.f90 14802 2010-08-09 22:15:10Z dhruba.mitra $
!
!  This module provide a way for users to specify custom initial
!  conditions.
!
!  The module provides a set of standard hooks into the Pencil Code
!  and currently allows the following customizations:
!
!   Description                               | Relevant function call
!  ------------------------------------------------------------------------
!   Initial condition registration            | register_initial_condition
!     (pre parameter read)                    |
!   Initial condition initialization          | initialize_initial_condition
!     (post parameter read)                   |
!                                             |
!   Initial condition for momentum            | initial_condition_uu
!   Initial condition for density             | initial_condition_lnrho
!   Initial condition for entropy             | initial_condition_ss
!   Initial condition for magnetic potential  | initial_condition_aa
!
!   And a similar subroutine for each module with an "init_XXX" call.
!   The subroutines are organized IN THE SAME ORDER THAT THEY ARE CALLED.
!   First uu, then lnrho, then ss, then aa, and so on.
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: linitial_condition = .true.
!
!***************************************************************
module InitialCondition
!
  use Cdata
  use Cparam
  use Messages
  use Sub, only: keep_compiler_quiet
  use EquationOfState
!
  implicit none
!
  include '../initial_condition.h'
!
     real :: init_ux=0.,init_uy=0.,init_uz=0.
     integer :: imass=1, spot_number=0
     integer :: index_H2O=3
     integer :: index_N2=4
     real :: dYw=1.,dYw1=1.,dYw2=1., init_water1=0., init_water2=0.
     real :: init_x1=0.,init_x2=0.,init_TT1, init_TT2
     real :: X_wind=impossible, spot_size=1.
     real :: AA=0.66e-4, d0=2.4e-6 !, BB0=1.5*1e-16
     real :: dsize_min=0., dsize_max=0., r0=0. 
     real, dimension(ndustspec) :: dsize, dsize0
     logical :: lreinit_water=.false.,lwet_spots=.false.
     logical :: linit_temperature=.false., lcurved=.false.!, linit_density=.false.
     logical :: ltanh_prof=.false.

!
    namelist /initial_condition_pars/ &
     init_ux, init_uy,init_uz,init_x1,init_x2, init_water1, init_water2, &
     lreinit_water, dYw,dYw1, dYw2, X_wind, spot_number, spot_size, lwet_spots, &
     linit_temperature, init_TT1, init_TT2, dsize_min, dsize_max, r0, d0, lcurved, &
     ltanh_prof
!
  contains
!***********************************************************************
    subroutine register_initial_condition()
!
!  Register variables associated with this module; likely none.
!
!  07-may-09/wlad: coded
!
      if (lroot) call svn_id( &
         "$Id: noinitial_condition.f90 14802 2010-08-09 22:15:10Z dhruba.mitra $")
!
    endsubroutine register_initial_condition
!***********************************************************************
    subroutine initialize_initial_condition(f)
!
!  Initialize any module variables which are parameter dependent.
!
!  07-may-09/wlad: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine initialize_initial_condition
!***********************************************************************
    subroutine initial_condition_uu(f)
!
!  Initialize the velocity field.
!
!  07-may-09/wlad: coded
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
      integer :: i,j
      real :: del=10.
!
        if ((init_ux /=0.) .and. (nygrid>1)) then
         do i=1,my
           f(:,i,:,iux)=cos(2.*PI*y(i)/Lxyz(2))*init_ux
         enddo
!
        endif
        if ((init_uy /=0.) .and. (X_wind /= impossible)) then
          do j=1,mx
!            if (x(j)>X_wind-del) then
               
             f(j,:,:,iuy)=f(j,:,:,iuy) &
              +(init_uy+0.)*0.5+((init_uy-0.)*0.5)  &
              *(exp((x(j)+X_wind)/del)-exp(-(x(j)+X_wind)/del)) &
              /(exp((x(j)+X_wind)/del)+exp(-(x(j)+X_wind)/del))

!              f(j,:,:,iuy)=f(j,:,:,iuy)+init_uy
!            else
!              f(j,:,:,iuy)=f(j,:,:,iuy)
!            endif
          enddo
        endif
        if ((init_uy /=0.) .and. (X_wind == impossible)) then
          f(:,:,:,iuy)=f(:,:,:,iuy)+init_uy
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
!
      call keep_compiler_quiet(f)
!
    endsubroutine initial_condition_uu
!***********************************************************************
    subroutine initial_condition_lnrho(f)
!
!  Initialize logarithmic density. init_lnrho will take care of
!  converting it to linear density if you use ldensity_nolog.
!
!  07-may-09/wlad: coded
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
!
!  SAMPLE IMPLEMENTATION
!
      call keep_compiler_quiet(f)
!
    endsubroutine initial_condition_lnrho
!***********************************************************************
    subroutine initial_condition_ss(f)
!
!  Initialize entropy.
!
!  07-may-09/wlad: coded
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
!
!  SAMPLE IMPLEMENTATION
!
      call keep_compiler_quiet(f)
!
    endsubroutine initial_condition_ss
!***********************************************************************
    subroutine initial_condition_chemistry(f)
!
!  Initialize chemistry.
!
!  07-may-09/wlad: coded
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
      real, dimension (my,mz) :: init_water1,init_water2
      !real, dimension (mx,my,mz), intent(inout) :: f
      real, dimension (ndustspec) ::  lnds
      real :: ddsize, ddsize0, del, air_mass, PP
      integer :: i, ii_max
      logical :: lstop=.true.
!

      ddsize=(alog(dsize_max)-alog(dsize_min))/(max(ndustspec,2)-1)
      do i=0,(ndustspec-1)
        lnds(i+1)=alog(dsize_min)+i*ddsize
        dsize(i+1)=exp(lnds(i+1))
        if (lstop) then
          if (dsize(i+1)>r0) then
            ii_max=i+1; lstop=.false.
          endif
        endif
      enddo

      call air_field_local(f, air_mass, PP)
      if (nxgrid>1) then
        do i=l1,l2
          call calc_boundary_water(f, air_mass, ii_max, PP, &
                             init_water1,init_water2, i)
        enddo
      endif

      call reinitialization(f, air_mass, PP, ii_max,init_water1,init_water2)
!
    endsubroutine initial_condition_chemistry
!***********************************************************************
    subroutine initial_condition_uud(f)
!
!  Initialize dust fluid velocity.
!
!  07-may-09/wlad: coded
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine initial_condition_uud
!***********************************************************************
    subroutine initial_condition_nd(f)
!
!  Initialize dust fluid density.
!
!  07-may-09/wlad: coded
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine initial_condition_nd
!***********************************************************************
    subroutine initial_condition_uun(f)
!
!  Initialize neutral fluid velocity.
!
!  07-may-09/wlad: coded
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine initial_condition_uun
!***********************************************************************
    subroutine read_initial_condition_pars(unit,iostat)
!
!  07-may-09/wlad: coded
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

!
      if (present(iostat)) then
        read(unit,NML=initial_condition_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=initial_condition_pars,ERR=99)
      endif
!
      99    return
!
    endsubroutine read_initial_condition_pars
!***********************************************************************
    subroutine write_initial_condition_pars(unit)
!
!  07-may-09/wlad: coded
!
      integer, intent(in) :: unit
!
     write(unit,NML=initial_condition_pars)
!
      call keep_compiler_quiet(unit)
!
    endsubroutine write_initial_condition_pars
!***********************************************************************
!***********************************************************************
    subroutine air_field_local(f, air_mass, PP)
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz) :: sum_Y!, psat
!      real, dimension (mx,my,mz) :: init_water1_,init_water2_
!      real, dimension (mx,my,mz,ndustspec) :: psf
!      real , dimension (my) :: init_x1_ar, init_x2_ar, del_ar, del_ar1, del_ar2
!
      logical :: emptyfile=.true.
      logical :: found_specie
      integer :: file_id=123, ind_glob, ind_chem
      character (len=80) :: ChemInpLine
      character (len=10) :: specie_string
      character (len=1)  :: tmp_string
      integer :: i,j,k=1,index_YY, j1,j2,j3, iter
      real :: YY_k, air_mass, TT=300.
      real, intent(out) :: PP ! (in dynes = 1atm)
      real, dimension(nchemspec)    :: stor2
      integer, dimension(nchemspec) :: stor1
!      logical :: spot_exist=.true., lmake_spot, lline_profile=.false.
!      real, dimension (ndustspec) ::  lnds
!      real :: ddsize,ddsize0,del
!      integer :: ii_max
!
      integer :: StartInd,StopInd,StartInd_1,StopInd_1
      integer :: iostat, i1,i2,i3
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
      if (emptyFile)  call fatal_error("air_field", "I can only set existing fields")
      air_mass=1./air_mass
!
      do j=1,k-1
        f(:,:,:,ichemspec(stor1(j)))=stor2(j)*0.01
      enddo
!
      sum_Y=0.
!
      do j=1,nchemspec
        sum_Y=sum_Y+f(:,:,:,ichemspec(j))
      enddo
      do j=1,nchemspec
        f(:,:,:,ichemspec(j))=f(:,:,:,ichemspec(j))/sum_Y
      enddo
!
      if (mvar < 5) then
        call fatal_error("air_field", "I can only set existing fields")
      endif
        if (ltemperature_nolog) then
          f(:,:,:,iTT)=TT
        else
          f(:,:,:,ilnTT)=alog(TT)!+f(:,:,:,ilnTT)
        endif
        if (ldensity_nolog) then
          f(:,:,:,ilnrho)=(PP/(k_B_cgs/m_u_cgs)*&
            air_mass/TT)/unit_mass*unit_length**3
        else
          f(:,:,:,ilnrho)=alog((PP/(k_B_cgs/m_u_cgs)*&
            air_mass/TT)/unit_mass*unit_length**3)
        endif
!
        if (ltemperature_nolog) then
          f(:,:,:,iTT)=TT
        else
          f(:,:,:,ilnTT)=alog(TT)!+f(:,:,:,ilnTT)
        endif
        if (ldensity_nolog) then
          f(:,:,:,ilnrho)=(PP/(k_B_cgs/m_u_cgs)*&
            air_mass/TT)/unit_mass*unit_length**3
        else
          f(:,:,:,ilnrho)=alog((PP/(k_B_cgs/m_u_cgs)*&
            air_mass/TT)/unit_mass*unit_length**3)
        endif
!

      if (lroot) print*, 'local:Air temperature, K', TT
      if (lroot) print*, 'local:Air pressure, dyn', PP
      if (lroot) print*, 'local:Air density, g/cm^3:'
      if (lroot) print '(E10.3)',  PP/(k_B_cgs/m_u_cgs)*air_mass/TT
      if (lroot) print*, 'local:Air mean weight, g/mol', air_mass
      if (lroot) print*, 'local:R', k_B_cgs/m_u_cgs
!
      close(file_id)
!!
    endsubroutine air_field_local
!*************************************!***********************************************************************
    subroutine reinitialization(f, air_mass, PP, ii_max,init_water1_min,init_water2_max)
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz) :: sum_Y, psat, air_mass_ar
      real, dimension (mx,my,mz) :: init_water1_,init_water2_
      real, dimension (my,mz) :: init_water1_min,init_water2_max
      real, dimension (mx,my,mz,ndustspec) :: psf
      real , dimension (my) :: init_x1_ar, init_x2_ar, del_ar, del_ar1, del_ar2
!
      integer :: i,j,k, j1,j2,j3, iter, ii_max
      real :: YY_k, air_mass,  PP, del 
      logical :: spot_exist=.true., lmake_spot, lline_profile=.false.
!

!  Reinitialization of T, water => rho
!
      if (linit_temperature) then
!
        if (lcurved) then
          do j=1,my         
            init_x1_ar(j)=init_x1*(1-0.1*sin(4.*PI*y(j)/Lxyz(2)))
            init_x2_ar(j)=init_x2*(1+0.1*sin(4.*PI*y(j)/Lxyz(2)))
          enddo
          del_ar1(:)=(init_x2-init_x1)*0.2*(1-0.1*sin(4.*PI*y(:)/Lxyz(2)))
          del_ar2(:)=(init_x2-init_x1)*0.2*(1+0.1*sin(4.*PI*y(:)/Lxyz(2)))
        else
          init_x1_ar=init_x1
          init_x2_ar=init_x2
          del_ar1(:)=(init_x2-init_x1)*0.2
          del_ar2(:)=(init_x2-init_x1)*0.2
        endif
!
          del=(init_x2-init_x1)*0.2
        do i=1,mx
          if (x(i)<0) then
            del_ar=del_ar1
          else
            del_ar=del_ar2 
          endif
        do j=1,my
          if (ltanh_prof) then
            
            f(i,j,:,ilnTT)=log((init_TT2+init_TT1)*0.5  &
                             +((init_TT2-init_TT1)*0.5)  &
              *(exp(x(i)/del_ar(j))-exp(-x(i)/del_ar(j))) &
              /(exp(x(i)/del_ar(j))+exp(-x(i)/del_ar(j))))
          else
          if (x(i)<=init_x1_ar(j)) then
            f(i,j,:,ilnTT)=alog(init_TT1)
          endif
          if (x(i)>=init_x2_ar(j)) then
            f(i,j,:,ilnTT)=alog(init_TT2)
          endif
          if (x(i)>init_x1_ar(j) .and. x(i)<init_x2_ar(j)) then
            if (init_x1_ar(j) /= init_x2_ar(j)) then
              f(i,j,:,ilnTT)=&
               alog((x(i)-init_x1_ar(j))/(init_x2_ar(j)-init_x1_ar(j)) &
               *(init_TT2-init_TT1)+init_TT1)
            endif
          endif
          endif
        enddo
        enddo
!        
        if (ldensity_nolog) then
          f(:,:,:,ilnrho)=(PP/(k_B_cgs/m_u_cgs)*&
            air_mass/exp(f(:,:,:,ilnTT)))/unit_mass*unit_length**3
        else
          f(:,:,:,ilnrho)=alog((PP/(k_B_cgs/m_u_cgs)*&
            air_mass/exp(f(:,:,:,ilnTT)))/unit_mass*unit_length**3)
        endif
      endif
!
       if (lreinit_water) then
!
         psat=6.035e12*exp(-5938./exp(f(:,:,:,ilnTT))) 
!          
         do k=1,ndustspec
           psf(:,:,:,k)=psat(:,:,:) &
               *exp(AA/exp(f(:,:,:,ilnTT))/2./dsize(k) &
               -10.7*d0**3/(8.*dsize(k)**3))
!                -1.5e-16/(8.*dsize(k)**3))
         enddo
!
         if ((init_water1/=0.) .or. (init_water2/=0.)) lline_profile=.true.
         if ((init_x1/=0.) .or. (init_x2/=0.)) lline_profile=.true.
!     
         do iter=1,3
           if (iter==1) then
             lmake_spot=.true.
             air_mass_ar=air_mass
           elseif (iter>1) then
             lmake_spot=.false.
!  Recalculation of air_mass becuase of changing of N2
               sum_Y=0.
               do k=1,nchemspec
                 if (ichemspec(k)/=ichemspec(index_N2)) &
                   sum_Y=sum_Y+f(:,:,:,ichemspec(k))
               enddo
                 f(:,:,:,ichemspec(index_N2))=1.-sum_Y
                 air_mass_ar=0.
               do k=1,nchemspec
                 air_mass_ar(:,:,:)=air_mass_ar(:,:,:)+f(:,:,:,ichemspec(k)) &
                    /species_constants(k,imass)
               enddo
                 air_mass_ar=1./air_mass_ar
           endif 
!
           if (iter < 3) then
!
!  Different profiles
!
           if (lline_profile) then
             call line_profile(f,PP,psf(:,:,:,ii_max),air_mass_ar, &
                            init_water1,init_water2,init_x1,init_x2,del,init_water1_min,init_water2_max)
           elseif (lwet_spots) then
              call spot_init(f,PP,air_mass_ar,psf(:,:,:,ii_max),lmake_spot)
!         
           elseif (.not. lwet_spots) then
! Initial conditions for the  0dcase: cond_evap
             f(:,:,:,ichemspec(index_H2O))=psf(:,:,:,ii_max)/(PP*air_mass_ar/18.)*dYw
           endif
           endif
! end of loot do iter=1,2
         enddo
!
         if (ldensity_nolog) then
           f(:,:,:,ilnrho)=(PP/(k_B_cgs/m_u_cgs)&
            *air_mass_ar/exp(f(:,:,:,ilnTT)))/unit_mass*unit_length**3
         else
           f(:,:,:,ilnrho)=alog((PP/(k_B_cgs/m_u_cgs) &
            *air_mass_ar/exp(f(:,:,:,ilnTT)))/unit_mass*unit_length**3) 
         endif
!
         if ((nxgrid>1) .and. (nygrid==1)) then
            f(:,:,:,iux)=f(:,:,:,iux)+init_ux
         endif
!       
         if (lroot) print*, ' Saturation Pressure, Pa   ', maxval(psat)
         if (lroot) print*, ' saturated water mass fraction', maxval(psat)/PP
!         if (lroot) print*, 'New Air density, g/cm^3:'
!         if (lroot) print '(E10.3)',  PP/(k_B_cgs/m_u_cgs)*maxval(air_mass_ar)/TT
         if (lroot) print*, 'New Air mean weight, g/mol', maxval(air_mass_ar)
       endif
!
    endsubroutine reinitialization
!*********************************************************************************************************
    subroutine line_profile(f,PP_,psat_,air_mass_ar_, &
                     init_water1__,init_water2__,init_x1__,init_x2__,del, &
                     init_water1_min,init_water2_max)
!
      real, dimension (mx,my,mz,mfarray) :: f
      integer :: i
      real :: PP_, init_water1__,init_water2__,init_x1__,init_x2__,del
      real, dimension (mx,my,mz) :: air_mass_ar_, psat_
      real, dimension (mx,my,mz) :: init_water1_,init_water2_
      real, dimension (my,mz) :: init_water1_min,init_water2_max
      real, dimension (my,mz) :: init_water1_min_,init_water2_max_
!
         if ((init_water1__/=0.) .or. (init_water2__/=0.)) then
           do i=1,mx
             if (x(i)<=init_x1__) then
                 f(i,:,:,ichemspec(index_H2O))=init_water1__
             endif
             if (x(i)>=init_x2__) then
               f(i,:,:,ichemspec(index_H2O))=init_water2__
             endif
             if (x(i)>init_x1__ .and. x(i)<init_x2__) then
               f(i,:,:,ichemspec(index_H2O))=&
                 (x(i)-init_x1__)/(init_x2__-init_x1__) &
                 *(init_water2__-init_water1__)+init_water1__
             endif
           enddo
         elseif ((init_x1__/=0.) .or. (init_x2__/=0.)) then
!
           init_water1_min_(:,:)= &
                 psat_(l1,:,:)/(PP_*air_mass_ar_(l1,:,:)/18.)*dYw1
           init_water2_max_(:,:)= &
                 psat_(l2,:,:)/(PP_*air_mass_ar_(l2,:,:)/18.)*dYw2
!

!!!! ato sravnit'
!print*,'init_water2_max', init_water1_min_(m1,n1), psat_(l1,m1,n1),PP_,dYw2,air_mass_ar_(l1,m1,n1),6.035e12*exp(-5938./init_TT2)

           do i=1,mx
           if (ltanh_prof) then
             f(i,:,:,ichemspec(index_H2O))= &
                   (init_water2_max(:,:)+init_water1_min(:,:))*0.5  &
                  +((init_water2_max(:,:)-init_water1_min(:,:))*0.5)  &
                  *(exp(x(i)/del)-exp(-x(i)/del)) &
                  /(exp(x(i)/del)+exp(-x(i)/del))
           else
             if (x(i)<=init_x1__) then
               init_water1_(i,:,:)= &
                 psat_(i,:,:)/(PP_*air_mass_ar_(i,:,:)/18.)*dYw1
               f(i,:,:,ichemspec(index_H2O))=init_water1_(i,:,:)
             elseif (x(i)>=init_x2__) then
               init_water2_(i,:,:)= &
                 psat_(i,:,:)/(PP_*air_mass_ar_(i,:,:)/18.)*dYw2
               f(i,:,:,ichemspec(index_H2O))=init_water2_(i,:,:)
             elseif (x(i)>init_x1__ .and. x(i)<init_x2__) then
               f(i,:,:,ichemspec(index_H2O))=&
                 (x(i)-init_x1__)/(init_x2__-init_x1__) &
                 *(init_water2_(mx,:,:)-init_water1_(1,:,:)) &
                 +init_water1_(1,:,:)
             endif
           endif  
           enddo
         endif
!
    endsubroutine line_profile
!***********************************************************************
    subroutine calc_boundary_water(f, air_mass, ii_max, PP, &
                   init_water1,init_water2,ll)
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz) ::  psat
      real, dimension (my,mz), intent(out) :: init_water1,init_water2
      real, dimension (my,mz) :: H2O_yz, N2_yz, sum_Y, air_mass_ar
      
      real :: psf, air_mass, PP, init_TT, dYw
      integer :: iter, ii_max,k 
      integer, intent(in) :: ll
      logical :: lleft_bond=.false.,  lright_bond=.false.
!
       if (x(ll) ==xyz0(1)) then
         lleft_bond=.true.
         init_TT=init_TT1; dYw=dYw1
       else
         lleft_bond=.false.
       endif
       if (x(ll) ==xyz0(1)+Lxyz(1)) then
         lright_bond=.true.
         init_TT=init_TT2; dYw=dYw2
       else
         lright_bond=.false.
       endif
!
       psf=6.035e12*exp(-5938./init_TT)  &
         *exp(AA/init_TT/2./dsize(ii_max) &
         -10.7*d0**3/(8.*dsize(ii_max)**3))
       H2O_yz=f(ll,:,:,ichemspec(index_H2O))
       N2_yz=f(ll,:,:,ichemspec(index_N2))

       do iter=1,3
!  Recalculation of air_mass becuase of changing of N2
        if (iter==1) then
          air_mass_ar=air_mass
        elseif (iter>1) then
               sum_Y=0.
               do k=1,nchemspec
                 if ((ichemspec(k)/=ichemspec(index_N2)) &
                     .and. (ichemspec(k)/=ichemspec(index_H2O))) then
                    sum_Y=sum_Y+f(ll,:,:,ichemspec(k))
                 elseif (ichemspec(k)==ichemspec(index_H2O)) then
                    sum_Y=sum_Y+H2O_yz
                 endif  
        
               enddo
                 N2_yz=1.-sum_Y
                 air_mass_ar=0.
               do k=1,nchemspec
                 if ((ichemspec(k)/=ichemspec(index_N2)) &
                     .and. (ichemspec(k)/=ichemspec(index_N2))) then
                 air_mass_ar(:,:)=air_mass_ar(:,:)+f(ll,:,:,ichemspec(k)) &
                    /species_constants(k,imass)
                 elseif (ichemspec(k)==ichemspec(index_N2)) then
                   air_mass_ar(:,:)=air_mass_ar(:,:)+ N2_yz&
                    /species_constants(k,imass)
                 elseif (ichemspec(k)==ichemspec(index_H2O)) then
                   air_mass_ar(:,:)=air_mass_ar(:,:)+ H2O_yz&
                   /species_constants(k,imass)
                 endif
               enddo
               air_mass_ar=1./air_mass_ar
         endif

           if (iter < 3) H2O_yz=psf/(PP*air_mass_ar(:,:)/18.)*dYw

!if (lright_bond) then
!print*,'samp2', H2O_yz(m1,n1) , air_mass_ar(m1,n1), psf, dYw, PP, 6.035e12*exp(-5938./init_TT2)
!endif

! end of loot do iter=1,2
         enddo
       
             if (lleft_bond)  init_water1=H2O_yz
             if (lright_bond) init_water2=H2O_yz

!if (lleft_bond)  print*, maxval(init_water1), minval(init_water1)
!if (lright_bond) print*, maxval(init_water2), minval(init_water2)

    endsubroutine  calc_boundary_water
!***********************************************************************
!***********************************************************************
    subroutine spot_init(f,PP_,air_mass_ar_,psat_, lmake_spot_)
!
!  Initialization of the dust spot positions and dust distribution
!
!  10-may-10/Natalia: coded
!
      use General, only: random_number_wrapper
!
      real, dimension (mx,my,mz,mfarray) :: f
      integer :: k, j, j1,j2,j3, lx=0,ly=0,lz=0
      real ::  RR, PP_
      real, dimension (3,spot_number) :: spot_posit
      real, dimension (mx,my,mz) :: air_mass_ar_, psat_
      logical :: spot_exist=.true., lmake_spot_
! 
       f(:,:,:,ichemspec(index_H2O)) = &
           psat_/(PP_*air_mass_ar_/18.)*dYw1
!
      if (lmake_spot_) spot_posit(:,:)=0.0
      do j=1,spot_number
        spot_exist=.true.
        lx=0;ly=0; lz=0
        if (nxgrid/=1) then
          lx=1
          if (lmake_spot_) then
            call random_number_wrapper(spot_posit(1,j))
            spot_posit(1,j)=spot_posit(1,j)*Lxyz(1)
          endif
          if ((spot_posit(1,j)-1.5*spot_size<xyz0(1)) .or. &
            (spot_posit(1,j)+1.5*spot_size>xyz0(1)+Lxyz(1)))  &
            spot_exist=.false.
            print*,'positx',spot_posit(1,j),spot_exist
!          if ((spot_posit(1,j)-1.5*spot_size<xyz0(1)) )  &
!            spot_exist=.false.
!            print*,'positx',spot_posit(1,j),spot_exist
        endif
        if (nygrid/=1) then
          ly=1
          if (lmake_spot_) then
            call random_number_wrapper(spot_posit(2,j))
            spot_posit(2,j)=spot_posit(2,j)*Lxyz(2)
          endif
!          if ((spot_posit(2,j)-1.5*spot_size<xyz0(2)) .or. &
!            (spot_posit(2,j)+1.5*spot_size>xyz0(2)+Lxyz(2)))  &
!            spot_exist=.false.
!            print*,'posity',spot_posit(2,j),spot_exist
        endif
        if (nzgrid/=1) then
          lz=1
          if (lmake_spot_) then
            call random_number_wrapper(spot_posit(3,j))
            spot_posit(3,j)=spot_posit(3,j)*Lxyz(3)
          endif
          if ((spot_posit(3,j)-1.5*spot_size<xyz0(3)) .or. &
           (spot_posit(3,j)+1.5*spot_size>xyz0(3)+Lxyz(3)))  &
           spot_exist=.false.
        endif
             do j1=1,mx; do j2=1,my; do j3=1,mz
               RR= (lx*x(j1)-spot_posit(1,j))**2 &
                   +ly*(y(j2)-spot_posit(2,j))**2 &
                   +lz*(z(j3)-spot_posit(3,j))**2
               RR=sqrt(RR)
!
               if ((RR<spot_size) .and. (spot_exist)) then
                f(j1,j2,j3,ichemspec(index_H2O)) = &
                  psat_(j1,j2,j3)/(PP_*air_mass_ar_(j1,j2,j3)/18.)*dYw2
               endif
             enddo; enddo; enddo
      enddo
!
    endsubroutine spot_init
!***********************************************************************


!***********************************************************************
!
!********************************************************************
!************        DO NOT DELETE THE FOLLOWING       **************
!********************************************************************
!**  This is an automatically generated include file that creates  **
!**  copies dummy routines from noinitial_condition.f90 for any    **
!**  InitialCondition routines not implemented in this file        **
!**                                                                **
    include 'initial_condition_dummies.inc'
!********************************************************************
endmodule InitialCondition
