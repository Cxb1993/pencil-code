# ts.py
#
# Read time_series.dat and return a TimeSeries class of 1D numpy
# arrrays
#
#
import os.path
import re
import numpy as np
import pylab as plt


def read_ts(*args, **kwargs):
    """Read Pencil Code time series data.
    params:
    string: filename  ='time_series.dat'
    string: datadir   = 'data'
    logical: plot_data = False
    logical: quiet     = False
    """
    return TimeSeries(*args, **kwargs)


class TimeSeries(object):
    """
    TimeSeries -- holds pencil code time series data. Each variable is
    represented by a data member of the class.
    """

    def __init__(self, filename='time_series.dat', datadir='data',
                 quiet=False, plot_data=False, comment_char='#'):
        """
        constructor:
        -----------
        __init__ -- reads Pencil Code time series data.
        Modeled after idl function of same name.

        params:
        ______
         string: filename  ='time_series.dat'
         string: datadir   = 'data'
         logical: plot_data = False
         logical: quiet     = False
        """

        datadir = os.path.expanduser(datadir)
        infile = open(os.path.join(datadir, filename), "r")
        lines = infile.readlines()
        infile.close()

        # need to handle cases where restart AND print.in changes,
        # but not right away
        # idl version uses input_table function with a STOP_AT
        # and FILEPOSITION keywords
        nlines_init = len(lines)
        self.keys = []
        data = np.zeros((nlines_init, len(self.keys)))
        nlines = 0
        for line in lines:
            if re.search("^%s--" % comment_char, line):
                # Read header and create keys for dictionary.
                line = line.strip("%s-\n" % comment_char)
                keys_new = re.split("-+", line)
                if keys_new != self.keys:
                    n_newrows = abs(len(keys_new) - len(self.keys))
                    data = np.append(data, np.zeros((nlines_init, n_newrows)),
                                     axis=1)
                    self.keys = keys_new
            else:
                try:
                    row = np.array(map(float, re.split(" +", line.strip(" \n"))))
                    data[nlines, :] = row
                    nlines += 1
                except ValueError:
                    print "Invalid data on line %i. Skipping." % nlines
        # Clean up data.
        data = np.resize(data, (nlines, len(self.keys)))

        if (not quiet):
            print "Read",nlines,"lines."

        # Assemble into a TimeSeries class.
        for i in range(0, len(self.keys)):
            setattr(self, self.keys[i], data[:,i])

        if hasattr(self,'t') and plot_data: self.plot()


    def plot(self):
        """
          plot:
          ----
            Do two plots:
            Try to plot urms(t), ruzm(t) and brms(t), if any of these
            three is not available or zero, fill the list with the first two
            variables other than `it' and `dt*'
        """
        plt.ioff() # speed up graphics (in connection with an ending plt.show())
        listargs = self.keys    # all data columns of the TimeSeries object
        elim = re.compile(r'^(it|dt.*)')  # columns to drop
        for item in dir(self):
            if re.match(elim, item):
                listargs.remove(item)
        cnt = 0
        if (hasattr(self, 'urms') and self.urms.max() != 0.):
            cnt += 1
            plt.subplot(2, 1, cnt)
            plt.semilogy(self.t, self.urms)
            plt.xlabel('Time')
            plt.ylabel('urms')
            listargs.remove('urms')
        if (hasattr(self, 'brms') and self.brms.max() != 0.):
            cnt += 1
            plt.subplot(2, 1, cnt)
            plt.semilogy(self.t, self.brms)
            plt.xlabel('Time')
            plt.ylabel('brms')
            listargs.remove('brms')
        if (hasattr(self, 'ruzm') and self.ruzm.max() != 0.):
            cnt += 1
            plt.subplot(2, 1, cnt)
            plt.plot(self.t, self.ruzm)
            plt.xlabel('Time')
            plt.ylabel('ruzm')
            listargs.remove('ruzm')
        else:
            listargs.remove('t')
            i = 0
            while cnt <= 1:
                cnt += 1
                plt.subplot(2, 1, cnt)
                plt.plot(self.t, getattr(self, listargs[i]))
                plt.xlabel('Time')
                plt.ylabel(listargs[i])
                i += 1
        plt.show()
        plt.ion()


    def __repr__(self):
        count = len(self.t)
        t_min = self.t.min()
        t_max = self.t.max()
        return "TimeSeries(t=%g..%g, rows=%d): %s" \
            % (t_min, t_max, count, str(self.keys), )


if __name__=='__main__':
    print TimeSeries.__doc__
