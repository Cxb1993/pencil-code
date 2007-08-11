! $Id: read_videofiles.f90,v 1.24 2007-08-11 10:04:51 brandenb Exp $

!***********************************************************************
      program rvid_box
!
!  read and combine slices from individual processor directories data
!  /procN, write them to data/, where the can be used by used by
!  rvid_box.pro
!
!  13-nov-02/axel: coded
!
      use Cparam
      use General
!
      implicit none

!
      real, dimension (nxgrid,nygrid) :: xy,xy2
      real, dimension (nxgrid,nzgrid) :: xz
      real, dimension (nygrid,nzgrid) :: yz
!
      real, dimension (nx,ny) :: xy_loc,xy2_loc
      real, dimension (nx,nz) :: xz_loc
      real, dimension (ny,nz) :: yz_loc
!
      integer :: ipx,ipy,ipz,iproc,it,nt=999999,ipz_top,ipz_bottom,ipy_front
      integer :: lun,lun1=1,lun2=2,lun3=3,lun4=4
      integer :: itdebug=2
      logical :: eof=.false.,slice_position_ok=.false.
      logical :: err=.false.,err_timestep=.false.
      real :: t
      real :: slice_xpos=0., slice_ypos=0., slice_zpos=0., slice_z2pos=0.
!
      character (len=120) :: file='',fullname='',wfile=''
      character (len=120) :: datadir='data',path=''
      character (len=5) :: chproc=''
      character (len=20) :: field='lnrho'
      character (len=1) :: slice_position='p'
!
      logical :: exists, lwritten_something=.false.
!
      real :: min_xy_loc,min_xy2_loc,min_xz_loc,min_yz_loc
      real :: max_xy_loc,max_xy2_loc,max_xz_loc,max_yz_loc
!
!  initialize minimum and maximum values for each plane
!
      min_xy_loc=huge(min_xy_loc); max_xy_loc=-huge(max_xy_loc)
      min_xy2_loc=huge(min_xy2_loc); max_xy2_loc=-huge(max_xy2_loc)
      min_xz_loc=huge(min_xz_loc); max_xz_loc=-huge(max_xz_loc)
      min_yz_loc=huge(min_yz_loc); max_yz_loc=-huge(max_yz_loc)
!
!  read name of the field (must coincide with file extension)
!
      !call getarg (1,field)
      write(*,'(a)',ADVANCE='NO') 'enter name of variable (lnrho, uu1, ..., bb3): '
      read*,field
!
!  periphery or middle of the box?
!  This information is now written in a file.
!  If file doesn't exist, read from the input line.
!
      inquire(FILE='data/slice_position.dat',EXIST=exists)
      if (.not.exists) then
        print*,"Slice position data not found"
        goto 999
      endif
      open(1,file='data/slice_position.dat',err=998)
      read(1,*) slice_position
      close(1)
      slice_position_ok=.true.
      write(*,*) 'slice position (from file) is: ',slice_position_ok
998   continue
!
      if (.not.slice_position_ok) then
        write(*,'(a)',ADVANCE='NO') 'periphery (p), middle (m) of box, equator (e)? '
        read*,slice_position
      endif
!
!  interpret slice_position
!
      if (slice_position=='p') then
        ipz_top=nprocz-1
        ipz_bottom=0
        ipy_front=0
      elseif (slice_position=='m') then
        ipz_top=nprocz/2
        ipz_bottom=nprocz/2
        ipy_front=nprocy/2
      elseif (slice_position=='e') then
        ipz_top=nprocz/4
        ipz_bottom=0.
        ipy_front=nprocy/2
      elseif (slice_position=='c') then
        call read_ipz_position(trim(datadir)//'/ztop_procnum.dat',ipz_top)
        call read_ipz_position(trim(datadir)//'/zbot_procnum.dat',ipz_bottom)
        ipy_front=0
print*,'ipz_top,ipz_bottom=',ipz_top,ipz_bottom
      elseif (slice_position=='q') then
        ipz_top=0
        ipz_bottom=nprocz-1
        ipy_front=nprocy-1
      else
        print*,'slice_position cannot be interpreted by read_videofiles'
      endif
      print*,'ipz_top,ipz_bottom,ipy_front=',ipz_top,ipz_bottom,ipy_front
!
!  loop through all times
!  reset error to false at each time step
!
      do it=1,nt
        err_timestep=.false.
        lun=10
!
!  Top Xy-plane:
!  need data where ipz=nprocz-1
!
      ipz=ipz_top
      do ipy=0,nprocy-1
        iproc=ipy+nprocy*ipz
        call chn(iproc,chproc,'rvid_box: top xy')
        call safe_character_assign(path,trim(datadir)//'/proc'//chproc)
        call safe_character_assign(file,'/slice_'//trim(field)//'.Xy')
        call safe_character_assign(fullname,trim(path)//trim(file))
        if(it<=itdebug) print*,trim(fullname)
        inquire(FILE=trim(fullname),EXIST=exists)
        if (.not.exists) then
          print*,"Slice not found", fullname
          xy2(:,1+ipy*ny:ny+ipy*ny)=0.
          goto 999
        endif
        call rslice(trim(fullname),xy2_loc,slice_z2pos,nx,ny,t,it,lun,eof,err)
        min_xy2_loc=min(min_xy2_loc,minval(xy2_loc))
        max_xy2_loc=max(max_xy2_loc,maxval(xy2_loc))
        if(eof) goto 999
        xy2(1+ipx*nx:nx+ipx*nx,1+ipy*ny:ny+ipy*ny)=xy2_loc
      enddo
      call safe_character_assign(wfile,trim(datadir)//trim(file))
      err_timestep=err
      if(.not.err_timestep) then
        call wslice(trim(wfile),xy2,slice_z2pos,nxgrid,nygrid,t,it,lun1)
        lwritten_something=.true.
      else
        print*,'skip writing because of error; t=',t
      endif
!
!  Bottom xy-plane:
!  need data where ipz=0
!
      ipz=ipz_bottom
      do ipy=0,nprocy-1
        iproc=ipy+nprocy*ipz
        call chn(iproc,chproc,'rvid_box: bottom xy')
        call safe_character_assign(path,trim(datadir)//'/proc'//chproc)
        call safe_character_assign(file,'/slice_'//trim(field)//'.xy')
        call safe_character_assign(fullname,trim(path)//trim(file))
        if(it<=itdebug) print*,trim(fullname)
        inquire(FILE=trim(fullname),EXIST=exists)
        if (.not.exists) then
          print*,"Slice not found", fullname
          xy(:,1+ipy*ny:ny+ipy*ny)=0.
          goto 999
        endif
        call rslice(trim(fullname),xy_loc,slice_zpos,nx,ny,t,it,lun,eof,err)
        min_xy_loc=min(min_xy_loc,minval(xy_loc))
        max_xy_loc=max(max_xy_loc,maxval(xy_loc))
        if(eof) goto 999
        xy(1+ipx*nx:nx+ipx*nx,1+ipy*ny:ny+ipy*ny)=xy_loc
      enddo
      call safe_character_assign(wfile,trim(datadir)//trim(file))
      err_timestep=err_timestep.or.err
      if(.not.err_timestep) then
        call wslice(trim(wfile),xy,slice_zpos,nxgrid,nygrid,t,it,lun2)
        lwritten_something=.true.
      else
        print*,'skip writing because of error; t=',t
      endif
!
!  Front xz-plane:
!  need data where ipy=0
!
      ipy=ipy_front
      do ipz=0,nprocz-1
        iproc=ipy+nprocy*ipz
        call chn(iproc,chproc,'rvid_box: front xz')
        call safe_character_assign(path,trim(datadir)//'/proc'//chproc)
        call safe_character_assign(file,'/slice_'//trim(field)//'.xz')
        call safe_character_assign(fullname,trim(path)//trim(file))
        if(it<=itdebug) print*,trim(fullname)
        inquire(FILE=trim(fullname),EXIST=exists)
        if (.not.exists) then
          print*,"Slice not found", fullname
          xz(:,1+ipz*nz:nz+ipz*nz)=0.
          goto 999
        endif
        call rslice(trim(fullname),xz_loc,slice_ypos,nx,nz,t,it,lun,eof,err)
        min_xz_loc=min(min_xz_loc,minval(xz_loc))
        max_xz_loc=max(max_xz_loc,maxval(xz_loc))
        if(eof) goto 999
        xz(1+ipx*nx:nx+ipx*nx,1+ipz*nz:nz+ipz*nz)=xz_loc
      enddo
      call safe_character_assign(wfile,trim(datadir)//trim(file))
      err_timestep=err_timestep.or.err
      if(.not.err_timestep) then
        call wslice(trim(wfile),xz,slice_ypos,nxgrid,nzgrid,t,it,lun3)
        lwritten_something=.true.
      else
        print*,'skip writing because of error; t=',t
      endif
!
!  Left side yz-plane:
!  need data where ipx=0 (doesn't matter: we have always nprocx=1)
!
      do ipz=0,nprocz-1
      do ipy=0,nprocy-1
        iproc=ipy+nprocy*ipz
        call chn(iproc,chproc,'rvid_box: left yz')
        call safe_character_assign(path,trim(datadir)//'/proc'//chproc)
        call safe_character_assign(file,'/slice_'//trim(field)//'.yz')
        call safe_character_assign(fullname,trim(path)//trim(file))
        if(it<=itdebug) print*,trim(fullname)
        inquire(FILE=trim(fullname),EXIST=exists)
        if (.not.exists) then
          print*,"Slice not found", fullname
          yz(1+ipy*ny:ny+ipy*ny,1+ipz*nz:nz+ipz*nz)=0.
          goto 999
        endif
        call rslice(trim(fullname),yz_loc,slice_xpos,ny,nz,t,it,lun,eof,err)
        min_yz_loc=min(min_yz_loc,minval(yz_loc))
        max_yz_loc=max(max_yz_loc,maxval(yz_loc))
        if(eof) goto 999
        yz(1+ipy*ny:ny+ipy*ny,1+ipz*nz:nz+ipz*nz)=yz_loc
      enddo
      enddo
      call safe_character_assign(wfile,trim(datadir)//trim(file))
      err_timestep=err_timestep.or.err
      if(.not.err_timestep) then
        call wslice(trim(wfile),yz,slice_xpos,nygrid,nzgrid,t,it,lun4)
        lwritten_something=.true.
      else
        print*,'skip writing because of error; t=',t
      endif
!
      print*,'written full set of slices at t=',t,min_xy_loc,max_xy_loc
      enddo
999   continue
      if (lwritten_something) then
      print*,'last file read: ',trim(fullname)
      print*,'-------------------------------------------------'
      print*,'minimum and maximum values:'
      print*,'xy-plane:',min_xy_loc,max_xy_loc
      print*,'xy2-plane:',min_xy2_loc,max_xy2_loc
      print*,'xz-plane:',min_xz_loc,max_xz_loc
      print*,'yz-plane:',min_yz_loc,max_yz_loc
      print*,'-------------------------------------------------'
      print*,'finished OK'
      endif

      select case (trim(field))
        case ('ux','uy','uz','bx','by','bz','Fradx','Frady','Fradz','ax','ay','az','ox','oy','oz')
          print*,""
          print*,"*****************************************************************************"
          print*,"******                WARNING DEPRECATED SLICE NAME                    ******"
          print*,"*****************************************************************************"
          print*,"*** The slice name '"//trim(field)//"' is deprecated and soon will not be ***"
          print*,"*** supported any longer                                                  ***"
          print*,"*** New slice names are formed by taking the name specified in video.in   ***"
          print*,"*** eg. uu and in the case of vector or other multiple slices appending   ***"
          print*,"*** a number. For example the slice 'ux' is now 'uu1' and the slice 'uz'  ***"
          print*,"*** is now called 'uu3', 'ay'->'aa2' etc. Similarly for aa, bb, oo, uu    ***"
          print*,"*** and Frad slices.                                                      ***"
          print*,"*****************************************************************************"
          print*,""
      endselect

      end
!***********************************************************************
    subroutine read_ipz_position(file,ipz)
!
!  reads just one number from file
!
!  19-nov-06/axel: coded
!
      character (len=*) :: file
      integer :: ipz,lun=1
!
      open(lun,file=file,status='old',err=98)
      read(lun,*) ipz
      close(lun)
      goto 99
!
!  escape procedure of file doesn't exist
!
98    print*,";;;"
      print*,";;; data/z*_procnum.dat files don't exist."
      print*,";;; Type (e.g. by cut+paste):"
      print*,";;;    cp data/proc*/z*_procnum.dat data"
      print*,";;;"
      stop
!
99    end
!***********************************************************************
    subroutine rslice(file,a,pos,ndim1,ndim2,t,it,lun,eof,err)
!
!  appending to an existing slice file
!
!  12-nov-02/axel: coded
!
      integer :: ndim1,ndim2
      character (len=*) :: file
      real, dimension (ndim1,ndim2) :: a
      integer :: it,lun
      logical :: eof,err
      real :: t,pos
!
      if(it==1) open(lun,file=file,status='old',form='unformatted')

      pos=0.  ! By default (i.e. if missing from record)
      read(lun,end=999,err=998) a,t,pos
      lun=lun+1
      goto 900
!
!  error: suspect wrong record length
!
998   read(lun,end=999,err=997) a,t
      lun=lun+1
      goto 900
!
!  still an error, avoid this time
!
997   err=.true.
      goto 900
!
!  when end of file
!
999   eof=.true.
!
900   continue
    endsubroutine rslice
!***********************************************************************
    subroutine wslice(file,a,pos,ndim1,ndim2,t,it,lun)
!
!  appending to an existing slice file
!
!  12-nov-02/axel: coded
!
      integer :: ndim1,ndim2
      character (len=*) :: file
      real, dimension (ndim1,ndim2) :: a
      integer :: it,lun
      real :: t, pos

!
      if(it==1) open(lun,file=file,form='unformatted')
      write(lun) a,t,pos
!
    endsubroutine wslice
!***********************************************************************
