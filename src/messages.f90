! $Id: messages.f90,v 1.10 2006-11-30 09:03:35 dobler Exp $
!
!  This module takes care of messages.
!
module Messages

  use Cdata
  use Mpicomm

  implicit none

  private

  public :: cvs_id
  public :: initialize_messages
  public :: information, warning, error
  public :: fatal_error, not_implemented
  public :: fatal_error_local, fatal_error_local_collect
  public :: life_support_on, life_support_off
!
  integer, public, parameter :: iterm_DEFAULT   = 0
  integer, public, parameter :: iterm_BRIGHT    = 1
  integer, public, parameter :: iterm_UNDERLINE = 4
  integer, public, parameter :: iterm_FLASH     = 5
  integer, public, parameter :: iterm_FG_BLACK  = 30
  integer, public, parameter :: iterm_FG_RED    = 31
  integer, public, parameter :: iterm_FG_GREEN  = 32
  integer, public, parameter :: iterm_FG_YELLOW = 33
  integer, public, parameter :: iterm_FG_BLUE   = 34
  integer, public, parameter :: iterm_FG_MAGENTA= 35
  integer, public, parameter :: iterm_FG_CYAN   = 36
  integer, public, parameter :: iterm_FG_WHITE  = 37
  integer, public, parameter :: iterm_BG_BLACK  = 40
  integer, public, parameter :: iterm_BG_RED    = 41
  integer, public, parameter :: iterm_BG_GREEN  = 42
  integer, public, parameter :: iterm_BG_YELLOW = 43
  integer, public, parameter :: iterm_BG_BLUE   = 44
  integer, public, parameter :: iterm_BG_MAGENTA= 45
  integer, public, parameter :: iterm_BG_CYAN   = 46
!
  integer, public, parameter :: iip_EVERYTHING  = 0
  integer, public, parameter :: iip_DEFAULT     = 0
!
  integer, parameter :: iwarning_ip     = 1000
  integer, parameter :: iinformation_ip = 1000
!
  integer :: warnings=0
  integer :: errors=0
  integer :: fatal_errors=0, fatal_errors_total=0
!
  logical :: ldie_onwarning=.false.
  logical :: ldie_onerror=.true.
  logical :: ldie_onfatalerror=.true.
  logical :: llife_support=.false.
!
  logical :: ltermcap_color=.false.
!
  interface cvs_id              ! Overload the cvs_id function
    module procedure cvs_id_1
    module procedure cvs_id_3
  endinterface
!
  contains
!***********************************************************************
    subroutine initialize_messages
!
! Set a flag if colored output has been requested.
!
        inquire(FILE="COLOR", EXIST=ltermcap_color)
!
    endsubroutine initialize_messages
!***********************************************************************
    subroutine not_implemented(location)
!
      character(len=*) :: location
!
      if (.not.llife_support) then
        errors=errors+1
!
        call terminal_highlight_error()
        write (*,'(A18)',ADVANCE='NO') "NOT IMPLEMENTED: "
        call terminal_defaultcolor()
        write (*,*) &
            "Attempted to use a routine that is not capable of handling the "
        write (*,*) "current parameters at the location '"//trim(location)//"'"
!
        if (ldie_onfatalerror) call die_gracefully
!
      endif
!
    endsubroutine not_implemented
!***********************************************************************
    subroutine fatal_error(location,message)
!
      character(len=*) :: location
      character(len=*) :: message
!
      if (.not.llife_support) then
        errors=errors+1
!
        call terminal_highlight_fatal_error()
        write (*,'(A13)',ADVANCE='NO') "FATAL ERROR: "
        call terminal_defaultcolor()
        write (*,*) trim(message)//" occurred at "//trim(location)
!
        if (ldie_onfatalerror) call die_gracefully
!
      endif
!
    endsubroutine fatal_error
!***********************************************************************
    subroutine fatal_error_local(location,message)
!
!  Register a fatal error happening at one processor. The code will die
!  at the end of the time-step.
!
!  17-may-2006/anders: coded
!
      character(len=*) :: location
      character(len=*) :: message
!
      if (.not.llife_support) then
        fatal_errors=fatal_errors+1
!
        call terminal_highlight_fatal_error()
        write (*,'(A13)',ADVANCE='NO') "FATAL ERROR: "
        call terminal_defaultcolor()
        write (*,*) trim(message)//" occurred at "//trim(location)
!
      endif
!
    endsubroutine fatal_error_local
!***********************************************************************
    subroutine fatal_error_local_collect()
!
!  Collect fatal errors from processors and die if there are any.
!
!  17-may-2006/anders: coded
!
      if (.not.llife_support) then
        call mpireduce_sum_int(fatal_errors,fatal_errors_total)
        call mpibcast_int(fatal_errors_total,1)
!
        if (fatal_errors_total/=0) then
          if (lroot) then
            print*, 'DYING - there was ', fatal_errors_total, ' errors.'
            print*, 'This is probably due to one or more fatal errors that'
            print*, 'have occurred only on a single processor.'
          endif
          if (ldie_onfatalerror) call die_gracefully
        endif
!
        fatal_errors=0
        fatal_errors_total=0
!
      endif
!
    endsubroutine fatal_error_local_collect
!***********************************************************************
    subroutine error(location,message)
!
      character(len=*) :: location
      character(len=*) :: message

      if (.not.llife_support) then
        errors=errors+1
!
        call terminal_highlight_error()
        write (*,'(A7)',ADVANCE='NO') "ERROR: "
        call terminal_defaultcolor()
        write (*,*) trim(message)//" occurred at "//trim(location)
!
        if (ldie_onerror) call die_gracefully
!
      endif
!
    endsubroutine error
!***********************************************************************
    subroutine warning(location,message,ip)
!
!  Print out colored warning.
!
!  30-jun-05/tony: coded
!
      character (len=*) :: message,location
      integer, optional :: ip
!
      if (.not.llife_support) then
        call terminal_highlight_warning()
        write (*,'(A9)',ADVANCE='NO') "WARNING:"
        call terminal_defaultcolor()
        write (*,*) trim(message)//" occurred at "//trim(location)
!
        if (ldie_onwarning) call die_gracefully
!
      endif
!
      if (NO_WARN) print*, ip
!
    endsubroutine warning
!***********************************************************************
    subroutine information(location,message,level)
!
!  Print out colored warning.
!
!  30-jun-05/tony: coded
!
      use Cdata, only: ip
!
      character (len=*) :: message,location
      integer, optional :: level
      integer :: level_ = iinformation_ip
!
      if (present(level)) level_=level
!
      if (ip<=level_) write (*,*) trim(location)//":"//trim(message)
!
    endsubroutine information
!***********************************************************************
    subroutine cvs_id_1(cvsid)
!
!  print CVS Revision info in a compact, yet structured form
!  Expects the standard CVS Id: line as argument
!  25-jun-02/wolf: coded
!
      character (len=*) :: cvsid
      character (len=20) :: rcsfile, revision, author, date
      character (len=200) :: fmt
      character (len=20) :: tmp1,tmp2,tmp3,tmp4
      integer :: ir0,ir1,iv0,iv1,id0,id2,ia0,ia1
      integer :: rw=18, vw=12, aw=10, dw=19 ! width of individual fields

      !
      !  rcs file name
      !
      ir0 = index(cvsid, ":") + 2
      ir1 = ir0 + index(cvsid(ir0+1:), ",") - 1
      rcsfile = cvsid(ir0:ir1)
      !
      !  version number
      !
      iv0 = ir1 + 4
      iv1 = iv0 + index(cvsid(iv0+1:), " ") - 1
      revision = cvsid(iv0:iv1)
      !
      !  date
      !
      id0 = iv1 + 2             ! first char of date
      ! id1 = iv1 + 12            ! position of space
      id2 = iv1 + 20            ! last char of time
      date = cvsid(id0:id2)
      !
      !  author
      !
      ia0 = id2 + 2
      ia1 = ia0 + index(cvsid(ia0+1:), " ") - 1
      author = cvsid(ia0:ia1)
      !
      !  constuct format
      !
      write(tmp1,*) rw
      write(tmp2,*) 6+rw
      write(tmp3,*) 6+rw+4+vw
      write(tmp4,*) 6+rw+4+vw+2+aw
!      fmt = '(A, A' // trim(adjustl(tmp1)) &
      fmt = '(A, A' &
           // ', T' // trim(adjustl(tmp2)) &
           // ', " v. ", A, T' // trim(adjustl(tmp3)) &
           // ', " (", A, T' // trim(adjustl(tmp4)) &
           // ', ") ", A)'
      !
      !  write string
      !
      if (index(cvsid, "$") == 1) then ! starts with `$' --> CVS line
        write(*,fmt) "CVS: ", &
             trim(rcsfile), &
             revision(1:vw), &
             author(1:aw), &
             date(1:dw)
      else                      ! not a CVS line; maybe `[No ID given]'
        write(*,fmt) "CVS: ", &
             '???????', &
             '', &
             '', &
             cvsid(1:dw)
      endif
      !write(*,'(A)') '123456789|123456789|123456789|123456789|123456789|12345'
      !write(*,'(A)') '         1         2         3         4         5'
!
    endsubroutine cvs_id_1
!***********************************************************************
    subroutine cvs_id_3(rcsfile, revision, date)
!
!  print CVS revision info in a compact, yet structured form
!  Old version: expects filename, version and date as three separate arguments
!  17-jan-02/wolf: coded
!
      character (len=*) :: rcsfile, revision, date
      integer :: rcsflen, revlen, datelen

      rcsflen=len(rcsfile)
      revlen =len(revision)
      datelen=len(date)
      write(*,'(A,A,T28," version ",A,T50," of ",A)') "CVS: ", &
           rcsfile(10:rcsflen-4), &
           revision(12:revlen-1), &
           date(8:datelen-1)
!
    endsubroutine cvs_id_3
!***********************************************************************
    subroutine life_support_off
!
!  Allow code to die on errors
!
!  30-jun-05/tony: coded
!
      llife_support=.false.
      call warning('life_support_off','death on error restored')
!
    endsubroutine life_support_off
!***********************************************************************
    subroutine life_support_on
!
!  Prevent the code from dying on errors
!
!  30-jun-05/tony: coded
!
      llife_support=.true.
      call warning('life_support_on','death on error has been suspended')
!
    endsubroutine life_support_on
!***********************************************************************
    subroutine terminal_setfgcolor(col)
!
!  Set foreground color of terminal text
!
!  08-jun-05/tony: coded
!
      integer :: col
!
      if (ltermcap_color) then
        write(*,fmt='(A1,A1,I2,A1)',ADVANCE='no') CHAR(27), '[', col, 'm'
      endif
!
    endsubroutine terminal_setfgcolor
!***********************************************************************
    subroutine terminal_setfgbrightcolor(col)
!
!  Set bright terminal colors
!
!  08-jun-05/tony: coded
!
      integer :: col
!
      if (ltermcap_color) then
        write(*,fmt='(A1,A1,I1,A1,I2,A1)',ADVANCE='no') &
            CHAR(27), '[', iterm_BRIGHT, ';', col, 'm'
      endif
!
    endsubroutine terminal_setfgbrightcolor
!***********************************************************************
    subroutine terminal_defaultcolor
!
!  Set terminal color to default value
!
!  08-jun-05/tony: coded
!
      if (ltermcap_color) then
        write(*,fmt='(A1,A1,I1,A1)',ADVANCE='no') &
            CHAR(27), '[', iterm_DEFAULT, 'm'
      endif
!
    endsubroutine terminal_defaultcolor
!***********************************************************************
    subroutine terminal_highlight_warning
!
!  Change to warning color
!
!  08-jun-05/tony: coded
!
      if (ltermcap_color) then
        write(*,fmt='(A1,A1,I1,A1,I2,A1)',ADVANCE='no') &
            CHAR(27), '[', iterm_BRIGHT, ';', iterm_FG_MAGENTA, 'm'
      endif
!
    endsubroutine terminal_highlight_warning
!***********************************************************************
    subroutine terminal_highlight_error
!
!  Change to warning color
!
!  08-jun-05/tony: coded
!
      if (ltermcap_color) then
        write(*,fmt='(A1,A1,I1,A1,I2,A1)',ADVANCE='no') &
            CHAR(27), '[', iterm_BRIGHT, ';', iterm_FG_RED, 'm'
      endif
!
    endsubroutine terminal_highlight_error
!***********************************************************************
    subroutine terminal_highlight_fatal_error
!
!  Change to warning color
!
!  08-jun-05/tony: coded
!
      if (ltermcap_color) then
        write(*,fmt='(A1,A1,I1,A1,I2,A1)',ADVANCE='no') &
            CHAR(27), '[', iterm_BRIGHT, ';', iterm_FG_RED, 'm'
      endif
!
    endsubroutine terminal_highlight_fatal_error
!***********************************************************************
endmodule Messages
