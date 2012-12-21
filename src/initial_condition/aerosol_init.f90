! $Id$
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
  use Cparam
  use Cdata
  use General, only: keep_compiler_quiet
  use Messages
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
     integer :: index_O2=3
     integer :: index_H2=1
     real :: dYw=1.,dYw1=1.,dYw2=1., init_water1=0., init_water2=0.
     real :: init_x1=0.,init_x2=0.,init_TT1, init_TT2
     real, dimension(nchemspec) :: init_Yk_1, init_Yk_2
     real :: X_wind=impossible, spot_size=1.
     real :: AA=0.66e-4, d0=2.4e-6 , BB0=1.5*1e-16
     real :: dsize_min=0., dsize_max=0., r0=0., r02=0.,  Period=2. 
     real, dimension(ndustspec) :: dsize, dsize0
     logical :: lreinit_water=.false.,lwet_spots=.false.
     logical :: linit_temperature=.false., lcurved_xz=.false.
     logical :: ltanh_prof_xy=.false.,ltanh_prof_xz=.false.
     logical :: llog_distribution=.true., lcurved_xy=.false.

!
    namelist /initial_condition_pars/ &
     init_ux, init_uy,init_uz,init_x1,init_x2, init_water1, init_water2, &
     lreinit_water, dYw,dYw1, dYw2, X_wind, spot_number, spot_size, lwet_spots, &
     linit_temperature, init_TT1, init_TT2, dsize_min, dsize_max, r0, r02, d0, lcurved_xz, lcurved_xy, &
     ltanh_prof_xz,ltanh_prof_xy, Period, BB0
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
         "$Id$")
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
           f(:,i,:,iux)=cos(Period*PI*y(i)/Lxyz(2))*init_ux
         enddo
        endif
        if ((init_uz /=0.) .and. (nzgrid>1)) then
         do i=1,mz
           f(:,:,i,iux)=cos(Period*PI*z(i)/Lxyz(3))*init_ux
         enddo
        endif
!
        if ((init_uy /=0.) .and. (X_wind /= impossible)) then
          do j=1,mx
             f(j,:,:,iuy)=f(j,:,:,iuy) &
              +(init_uy+0.)*0.5+((init_uy-0.)*0.5)  &
              *(exp((x(j)+X_wind)/del)-exp(-(x(j)+X_wind)/del)) &
              /(exp((x(j)+X_wind)/del)+exp(-(x(j)+X_wind)/del))

!            if (x(j)>X_wind) then
!              f(j,:,:,iuy)=f(j,:,:,iuy)+init_uy
!            else
!              f(j,:,:,iuy)=f(j,:,:,iuy)
!            endif
          enddo
        endif
!
        if ((init_uz /=0.) .and. (X_wind /= impossible)) then
          do j=1,mx
             f(j,:,:,iuz)=f(j,:,:,iuz) &
              +(init_uz+0.)*0.5+((init_uz-0.)*0.5)  &
              *(exp((x(j)+X_wind)/del)-exp(-(x(j)+X_wind)/del)) &
              /(exp((x(j)+X_wind)/del)+exp(-(x(j)+X_wind)/del))
          enddo
         endif
!
        if ((init_uy /=0.) .and. (X_wind == impossible)) then
          f(:,:,:,iuy)=f(:,:,:,iuy)+init_uy
        endif
        if ((init_uz /=0.) .and. (X_wind == impossible)) then
          f(:,:,:,iuz)=f(:,:,:,iuz)+init_uz
        endif

!
!        if (init_uz /=0.) then
!          do i=1,mz
!          if (z(i)>0) then
!            f(:,:,i,iuz)=f(:,:,i,iuz) &
!                        +init_uz*(2.*z(i)/Lxyz(3))**2
!          else
!            f(:,:,i,iuz)=f(:,:,i,iuz) &
!                        -init_uz*(2.*z(i)/Lxyz(3))**2
!          endif
!          enddo
!        endif
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
      real, dimension (my,mz) :: init_water1,init_water2, &
               init_water1_tmp,init_water2_tmp
      !real, dimension (mx,my,mz), intent(inout) :: f
      real, dimension (ndustspec) ::  lnds
      real :: ddsize, ddsize0, del, air_mass, PP
      integer :: i, ii
      logical ::  lstart1=.false., lstart2=.false.
!

      if (llog_distribution) then
        ddsize=(alog(dsize_max)-alog(dsize_min))/(max(ndustspec,2)-1)
      else
        ddsize=(dsize_max-dsize_min)/(max(ndustspec,2)-1) 
      endif

      do i=0,(ndustspec-1)
        if (llog_distribution) then
          lnds(i+1)=alog(dsize_min)+i*ddsize
          dsize(i+1)=exp(lnds(i+1))
        else
          lnds(i+1)=dsize_min+i*ddsize
          dsize(i+1)=lnds(i+1)
        endif
      enddo
!
      call air_field_local(f, air_mass, PP)
!
      call reinitialization(f, air_mass, PP)
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
      real, dimension (mx,my,mz) :: sum_Y, tmp!, psat
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
!
      do j=1,nchemspec
       init_Yk_1(j)=f(l1,m1,n1,ichemspec(j))
       init_Yk_2(j)=f(l1,m1,n1,ichemspec(j))
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
          tmp=(PP/(k_B_cgs/m_u_cgs)*&
            air_mass/TT)/unit_mass*unit_length**3
          f(:,:,:,ilnrho)=alog(tmp)
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
          tmp=(PP/(k_B_cgs/m_u_cgs)*&
            air_mass/TT)/unit_mass*unit_length**3
          f(:,:,:,ilnrho)=alog(tmp)
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
    subroutine reinitialization(f, air_mass, PP)
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz) :: sum_Y, air_mass_ar, tmp
      real, dimension (mx,my,mz) :: init_water1_,init_water2_
      real, dimension (my,mz) :: init_water1_min,init_water2_max
      real , dimension (my) :: init_x1_ary, init_x2_ary, del_ary, del_ar1y, del_ar2y
      real , dimension (mz) :: init_x1_arz, init_x2_arz, del_arz, del_ar1z, del_ar2z
!
      integer :: i,j,k, j1,j2,j3, iter
      real :: YY_k, air_mass,  PP, del, psat1, psat2, psf_1, psf_2 
      real :: air_mass_1, air_mass_2, sum1, sum2, init_water_1, init_water_2 
      logical :: spot_exist=.true., lmake_spot, lline_profile=.false.
      real ::  Rgas_loc=8.314472688702992E+7, T_tmp
      real :: aa0= 6.107799961, aa1= 4.436518521e-1
      real :: aa2= 1.428945805e-2, aa3= 2.650648471e-4
      real :: aa4= 3.031240396e-6, aa5= 2.034080948e-8, aa6= 6.136820929e-11

      intent(in) :: air_mass
!

!  Reinitialization of T, water => rho
!
      if (linit_temperature) then
        del=(init_x2-init_x1)*0.2
        if (lcurved_xz) then
          do j=n1,n2         
            init_x1_ary(j)=init_x1*(1-0.1*sin(4.*PI*z(j)/Lxyz(3)))
            init_x2_ary(j)=init_x2*(1+0.1*sin(4.*PI*z(j)/Lxyz(3)))
          enddo
          del_ar1z(:)=del*(1-0.1*sin(4.*PI*z(:)/Lxyz(3)))
          del_ar2z(:)=del*(1+0.1*sin(4.*PI*z(:)/Lxyz(3)))
        elseif (lcurved_xy) then
          do j=m1,m2         
            init_x1_ary(j)=init_x1*(1-0.1*sin(4.*PI*y(j)/Lxyz(2)))
            init_x2_ary(j)=init_x2*(1+0.1*sin(4.*PI*y(j)/Lxyz(2)))
          enddo
          del_ar1y(:)=del*(1-0.1*sin(4.*PI*y(:)/Lxyz(2)))
          del_ar2y(:)=del*(1+0.1*sin(4.*PI*y(:)/Lxyz(2)))
        else
          init_x1_ary=init_x1
          init_x2_ary=init_x2
          init_x1_arz=init_x1
          init_x2_arz=init_x2
          del_ar1y(:)=del
          del_ar2y(:)=del
          del_ar1z(:)=del
          del_ar2z(:)=del
        endif
!
          
        do i=l1,l2
          if (x(i)<0) then
            del_ary=del_ar1y
            del_arz=del_ar1z
          else
            del_ary=del_ar2y 
            del_arz=del_ar2z
          endif
!        
          if (ltanh_prof_xy) then
            do j=m1,m2
              f(i,j,:,ilnTT)=log((init_TT2+init_TT1)*0.5  &
                             +((init_TT2-init_TT1)*0.5)  &
                  *(exp(x(i)/del_ary(j))-exp(-x(i)/del_ary(j))) &
                  /(exp(x(i)/del_ary(j))+exp(-x(i)/del_ary(j))))
            enddo
          elseif (ltanh_prof_xz) then
            do j=n1,n2
            f(i,:,j,ilnTT)=log((init_TT2+init_TT1)*0.5  &
                             +((init_TT2-init_TT1)*0.5)  &
              *(1.-exp(-2.*x(i)/del_arz(j))) &
              /(1.+exp(-2.*x(i)/del_arz(j))))
            enddo
          else
          do j=m1,m2
            if (x(i)<=init_x1_ary(j)) then
              f(i,j,:,ilnTT)=alog(init_TT1)
            endif
            if (x(i)>=init_x2_ary(j)) then
              f(i,j,:,ilnTT)=alog(init_TT2)
            endif
            if (x(i)>init_x1_ary(j) .and. x(i)<init_x2_ary(j)) then
              if (init_x1_ary(j) /= init_x2_ary(j)) then
                f(i,j,:,ilnTT)=&
                   alog((x(i)-init_x1_ary(j))/(init_x2_ary(j)-init_x1_ary(j)) &
                   *(init_TT2-init_TT1)+init_TT1)
              endif
            endif
          enddo
          endif
        enddo
!        
        if (ldensity_nolog) then
!          f(:,:,:,ilnrho)=(PP/(k_B_cgs/m_u_cgs)*&
!            air_mass/exp(f(:,:,:,ilnTT)))/unit_mass*unit_length**3
        else
          tmp=(PP/(k_B_cgs/m_u_cgs)*&
            air_mass/exp(f(:,:,:,ilnTT)))/unit_mass*unit_length**3
          f(:,:,:,ilnrho)=alog(tmp)
        endif
      endif
!
       if (lreinit_water) then
!
       if (init_TT2==0) init_TT2=init_TT1
!
 
!       psat1=6.035e12*exp(-5938./init_TT1)
!       psat2=6.035e12*exp(-5938./init_TT2)
!
        T_tmp=init_TT1-273.15
        psat1=(aa0 + aa1*T_tmp    + aa2*T_tmp**2  &
                   + aa3*T_tmp**3 + aa4*T_tmp**4  &
                   + aa5*T_tmp**5 + aa6*T_tmp**6)*1e3
        T_tmp=init_TT2-273.15
        psat2=(aa0 + aa1*T_tmp    + aa2*T_tmp**2  &
                   + aa3*T_tmp**3 + aa4*T_tmp**4  &
                   + aa5*T_tmp**5 + aa6*T_tmp**6)*1e3
!
        psf_1=psat1 
!          *exp(AA/init_TT1/2./r0-BB0/(8.*r0**3))
        if (r02 /= 0) then
          psf_2=psat2
!            *exp(AA/init_TT2/2./r02-BB0/(8.*r02**3))        
        else
          psf_2=psat2
!            *exp(AA/init_TT2/2./r0-BB0/(8.*r0**3))
        endif
!
! Recalculation of the air_mass for different boundary conditions
!
!           init_Yk_1(index_H2O)=psf_1 &
!               /(exp(f(l1,m1,n1,ilnrho))*Rgas_loc*init_TT1/18.)*dYw1
!           init_Yk_2(index_H2O)=psf_2  & 
!               /(exp(f(l2,m2,n2,ilnrho))*Rgas_loc*init_TT2/18.)*dYw2
!
        air_mass_1=air_mass
        air_mass_2=air_mass

        do iter=1,3
!
!
!print*,'air_mass_1', air_mass_1,iter,PP*air_mass_1/18.
!
          init_Yk_1(index_H2O)=psf_1/(PP*air_mass_1/18.)*dYw1
          init_Yk_2(index_H2O)=psf_2/(PP*air_mass_2/18.)*dYw2
!
           sum1=0.
           sum2=0.
           do k=1,nchemspec
            if (ichemspec(k)/=ichemspec(index_N2)) then
              sum1=sum1+init_Yk_1(k)
              sum2=sum2+init_Yk_2(k)
            endif
           enddo
!
           init_Yk_1(index_N2)=1.-sum1
           init_Yk_2(index_N2)=1.-sum2
!
!  Recalculation of air_mass 
!
             sum1=0.
             sum2=0.
             do k=1,nchemspec
               sum1=sum1 + init_Yk_1(k)&
                  /species_constants(k,imass)
               sum2=sum2 + init_Yk_2(k)&
                  /species_constants(k,imass)
             enddo
               air_mass_1=1./sum1
               air_mass_2=1./sum2
        enddo

           init_water_1=init_Yk_1(index_H2O)
           init_water_2=init_Yk_2(index_H2O)


!print*,'NATA', init_Yk_1(index_H2O),psf_2, (PP*air_mass_2/18.), dYw1
!
!
! End of Recalculation of the air_mass for different boundary conditions
!
!         do iter=1,3
!           if (iter==1) then
!             lmake_spot=.true.
!             air_mass_ar=air_mass
!           elseif (iter>1) then
!             lmake_spot=.false.
!           endif 
!
!  Different profiles
!
           if (ltanh_prof_xz .or. ltanh_prof_xy) then
             do i=l1,l2
               f(i,:,:,ichemspec(index_H2O))= &
                   (init_water_2+init_water_1)*0.5  &
                 +((init_water_2-init_water_1)*0.5)  &
                   *(exp(x(i)/del)-exp(-x(i)/del)) &
                   /(exp(x(i)/del)+exp(-x(i)/del))
             enddo
           elseif (lwet_spots) then
!              call spot_init(f,PP,air_mass_ar,psf(:,:,:,ii_max),lmake_spot)
!         
           elseif (.not. lwet_spots) then
! Initial conditions for the  0dcase: cond_evap
             f(:,:,:,ichemspec(index_H2O))=init_Yk_1(index_H2O)
           endif
           sum_Y=0.
           do k=1,nchemspec
             if (ichemspec(k)/=ichemspec(index_N2)) &
               sum_Y=sum_Y+f(:,:,:,ichemspec(k))
           enddo
           f(:,:,:,ichemspec(index_N2))=1.-sum_Y
!
           sum_Y=0.
           do k=1,nchemspec
             sum_Y=sum_Y+f(:,:,:,ichemspec(k)) &
               /species_constants(k,imass)
           enddo
           air_mass_ar=1./sum_Y
!
! end of loot do iter=1,2
!         enddo
!
         if (ldensity_nolog) then
           f(:,:,:,ilnrho)=(PP/(k_B_cgs/m_u_cgs)&
            *air_mass_ar/exp(f(:,:,:,ilnTT)))/unit_mass*unit_length**3
         else
           tmp=(PP/(k_B_cgs/m_u_cgs) &
            *air_mass_ar/exp(f(:,:,:,ilnTT)))/unit_mass*unit_length**3
           f(:,:,:,ilnrho)=alog(tmp) 
         endif
!
         if ((nxgrid>1) .and. (nygrid==1).and. (nzgrid==1)) then
            f(:,:,:,iux)=f(:,:,:,iux)+init_ux
         endif
!       
         if (lroot) print*, ' Saturation Pressure, Pa   ', psf_1, psf_2
         if (lroot) print*, ' psf, Pa   ',  psf_1, psf_2
         if (lroot) print*, ' pw1, Pa   ', (exp(f(l1,m1,n1,ilnrho))*Rgas_loc*init_TT1/18.), PP*air_mass_1/18.
         if (lroot) print*, ' pw2, Pa   ', (exp(f(l2,m1,n1,ilnrho))*Rgas_loc*init_TT2/18.), PP*air_mass_2/18.
         if (lroot) print*, ' saturated water mass fraction', psat1/PP, psat2/PP
!         if (lroot) print*, 'New Air density, g/cm^3:'
!         if (lroot) print '(E10.3)',  PP/(k_B_cgs/m_u_cgs)*maxval(air_mass_ar)/TT
         if (lroot) print*, 'New Air mean weight, g/mol', maxval(air_mass_ar)
         if  ((lroot) .and. (nx >1 )) then
            print*, 'density', exp(f(l1,4,4,ilnrho)), exp(f(l2,4,4,ilnrho))
          endif
         if  ((lroot) .and. (nx >1 )) then
            print*, 'temperature', exp(f(l1,4,4,ilnTT)), exp(f(l2,4,4,ilnTT))
          endif
       endif
!
    endsubroutine reinitialization
!*********************************************************************************************************
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
    include '../initial_condition_dummies.inc'
!********************************************************************
endmodule InitialCondition
