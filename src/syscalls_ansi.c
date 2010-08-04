/*                             syscalls_ansi.c
                              -----------------
*/

/* Date:   19-Mar-2010
   Author: Bourdin.KIS (Bourdin@KIS.Uni-Freiburg.de)
   Description:
 ANSI C and standard library callable function wrappers for use in Fortran.
 Written to compensate for inadequatenesses in the Fortran95/2003 standards.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include "headers_c.h"

/* ---------------------------------------------------------------------- */

void FTNIZE(file_size_c)
     (char *filename, FINT *bytes)
/* Determines the size of a file.
   Returns:
   * positive integer containing the file size of a given file
   * -2 if the file could not be found or opened
   * -1 if retrieving the file size failed
*/
{
  struct stat fileStat;
  int file=-1;

  *bytes=-2;
  file=open(filename, O_RDONLY);
  if(file == -1) return;

  *bytes=-1;
  if(fstat(file, &fileStat) < 0) { close (file); return; }
  close (file);

  *bytes=fileStat.st_size;
}

/* ---------------------------------------------------------------------- */

void FTNIZE(get_pid_c)
     (FINT *pid)
/* Determines the PID of the current process.
   Returns:
   * integer containing the PID of the current process
   * -1 if retrieving the PID failed
*/
{
  pid_t result;

  *pid = -1;
  result = getpid ();
  if (result) *pid = (int) result;
}

/* ---------------------------------------------------------------------- */

void FTNIZE(get_env_var_c)
     (char *name, char *value)
/* Gets the content of an environment variable.
   Returns:
   * string containing the content of the environment variable, if available
   * empty string, if retrieving the environment variable failed
*/
{
  char *env_var;

  env_var = getenv (name);
  if (env_var) strncpy (value, env_var, strlen (env_var));
}

/* ---------------------------------------------------------------------- */

