# $Id: tracers.py,v 1.4 2012-03-21 09:55:49 iomsn Exp $
#
# Reads the tracer files, composes a color map
# and reads the fixed point values.
#
# Author: Simon Candelaresi (iomsn@physto.se, iomsn1@googlemail.com).
#
#

import struct
import array
import numpy as np
import os
import pencil as pc
import pylab as plt


def read_tracers(dataDir = 'data/', fileName = 'tracers.dat', zlim = [], head_size = 3, post = False):
    """
    Reads the tracer files, composes a color map.

    call signature::

      tracers, mapping, t = read_tracers(fileName = 'tracers.dat', dataDir = 'data/', zlim = [], head_size = 3)

    Reads from the tracer files and computes the color map according to
    A R Yeates and G Hornig 2011 J. Phys. A: Math. Theor. 44 265501
    doi:10.1088/1751-8113/44/26/265501.
    Returns the tracer values, the color mapping and the times of the snapshots.
    The color mapping can be plotted with:
    pc.animate_interactive(mapping[:,::-1,:,:], t, dimOrder = (2,1,0,3))

    Keyword arguments:

      *dataDir*:
        Data directory.

      *fileName*:
        Name of the tracer file.

      *zlim*:
        The upper limit for the field line mapping at which a field line is considered
        to have reached the upper boundary.

      *head_size*:
        Size of the Fortran header in binary data. Most of the time this is 3.
        For the St Andrews cluster it is 5.
    """
    class data_struct:
        def __init__(self):
            self.xi = []
            self.yi = []
            self.xf = []
            self.yf = []
            self.zf = []
            self.l = []
            self.q = []

    data = []
    data = data_struct()

    # compute the offset in order to skip Fortran's header byte
    if (post):
        head_size = 0
        off = 2
    if (head_size == 3):
        off = 2
    if (head_size == 5):
        off = 3

    # read the cpu structure
    dim = pc.read_dim(datadir = dataDir)
    if (dim.nprocz > 1):
        print ": number of cores in z-direction > 1"
        return -1

    # read the parameters
    params = pc.read_param(datadir = dataDir, quiet = True)

    # read the grid
    grid = pc.read_grid(datadir = dataDir, quiet = True)

    # determine the file structure
    if (post):
        n_proc = 1
        tracer_file = open(dataDir+fileName, 'rb')
        trace_sub = struct.unpack("f", tracer_file.read(4))[0]
        print "trace_sub = ", trace_sub
        tracer_file.close()
        n_times = int(os.path.getsize(dataDir+fileName)/(4*7*int(dim.nx*trace_sub)*int(dim.ny*trace_sub)))
    # sub sampling of the tracers
    if (not(post)):
        n_proc = dim.nprocx*dim.nprocy
        trace_sub = params.trace_sub
        n_times = int(os.path.getsize(dataDir+'proc0/'+fileName)/(4*(head_size + 7*np.floor(dim.nx*trace_sub)*np.floor(dim.ny*trace_sub)/dim.nprocx/dim.nprocy)))

    # prepare the output arrays
    tracers = np.zeros((int(dim.nx*trace_sub), int(dim.ny*trace_sub), n_times, 7))
    mapping = np.zeros((int(dim.nx*trace_sub), int(dim.ny*trace_sub), n_times, 3))

    # temporary arrays for one core
    if (post):
        tracers_core = tracers
        mapping_core = mapping
    else:
        tracers_core = np.zeros((int(dim.nx*trace_sub)/dim.nprocx, int(dim.ny*trace_sub)/dim.nprocy, n_times, 7))
        mapping_core = np.zeros((int(dim.nx*trace_sub)/dim.nprocx, np.floor(dim.ny*trace_sub)/dim.nprocy, n_times, 3))

    # set the upper z-limit to the domain boundary
    if zlim == []:
        zlim = grid.z[-dim.nghostz-1]

    # read the data from all cores
    for i in range(n_proc):
        # read the cpu structure
        if (post):
            dim_core = pc.read_dim(datadir = dataDir, proc = -1)
            dim_core.ipx = 0
            dim_core.ipy = 0
        else:
            dim_core = pc.read_dim(datadir = dataDir, proc = i)
        stride = int(dim_core.nx*trace_sub)*int(dim_core.ny*trace_sub)
        llen = head_size + 7*stride

        if (post):
            tracer_file = open(dataDir+fileName, 'rb')
        else:
            tracer_file = open(dataDir+'proc{0}/'.format(i)+fileName, 'rb')
        tmp = array.array('f')
        tmp.read(tracer_file, int((head_size + 2*post + 7*int(dim_core.nx*trace_sub)*int(dim_core.ny*trace_sub))*n_times))
        tracer_file.close()

        t = []

        for j in range(n_times):
            t.append(tmp[off-1+j*llen])
            data.xi = tmp[off+j*llen          : off+1*stride+j*llen]
            data.yi = tmp[off+1*stride+j*llen : off+2*stride+j*llen]
            data.xf = tmp[off+2*stride+j*llen : off+3*stride+j*llen]
            data.yf = tmp[off+3*stride+j*llen : off+4*stride+j*llen]
            data.zf = tmp[off+4*stride+j*llen : off+5*stride+j*llen]
            data.l  = tmp[off+5*stride+j*llen : off+6*stride+j*llen]
            data.q  = tmp[off+6*stride+j*llen : off+7*stride+j*llen]

            # Squeeze the data into 2d array. This make the visualization much faster.
            for l in range(len(data.xi)):
                tracers_core[l%(int(dim_core.nx*trace_sub)),l/(int(dim_core.nx*trace_sub)),j,:] = \
                [data.xi[l], data.yi[l], data.xf[l], data.yf[l], data.zf[l], data.l[l], data.q[l]]
                if data.zf[l] >= zlim:
                    if (data.xi[l] - data.xf[l]) > 0:
                        if (data.yi[l] - data.yf[l]) > 0:
                            mapping_core[l%(int(dim_core.nx*trace_sub)),l/(int(dim_core.nx*trace_sub)),j,:] = [0,1,0]
                        else:
                            mapping_core[l%(int(dim_core.nx*trace_sub)),l/(int(dim_core.nx*trace_sub)),j,:] = [1,1,0]
                    else:
                        if (data.yi[l] - data.yf[l]) > 0:
                            mapping_core[l%(int(dim_core.nx*trace_sub)),l/(int(dim_core.nx*trace_sub)),j,:] = [0,0,1]
                        else:
                            mapping_core[l%(int(dim_core.nx*trace_sub)),l/(int(dim_core.nx*trace_sub)),j,:] = [1,0,0]
                else:
                    mapping_core[l%(int(dim_core.nx*trace_sub)),l/(int(dim_core.nx*trace_sub)),j,:] = [1,1,1]

            # copy single core data into total data arrays
            if (not(post)):
                tracers[np.round(dim_core.ipx*int(dim_core.nx*trace_sub)):np.round((dim_core.ipx+1)*np.floor(dim_core.nx*trace_sub)), \
                        np.round(dim_core.ipy*int(dim_core.ny*trace_sub)):np.round((dim_core.ipy+1)*np.floor(dim_core.ny*trace_sub)),j,:] = \
                        tracers_core[:,:,j,:]
                mapping[np.round(dim_core.ipx*int(dim_core.nx*trace_sub)):np.round((dim_core.ipx+1)*np.floor(dim_core.nx*trace_sub)), \
                        np.round(dim_core.ipy*int(dim_core.ny*trace_sub)):np.round((dim_core.ipy+1)*np.floor(dim_core.ny*trace_sub)),j,:] = \
                        mapping_core[:,:,j,:]

    # swap axes for post evaluation
    tracers = tracers.swapaxes(0, 1)
    mapping = mapping.swapaxes(0, 1)

    return tracers, mapping, t



# keep this for the time being
def read_fixed_points_old(dataDir = 'data/', fileName = 'fixed_points.dat', hm = 1):
    """
    Reads the fixed points files.

    call signature::

      fixed = read_tracers(fileName = 'tracers.dat', dataDir = 'data/', hm = 1)

    Reads from the fixed points files. Returns the fixed points positions.

    Keyword arguments:

      *dataDir*:
        Data directory.

      *fileName*:
        Name of the fixed points file.

      *hm*:
        Header multiplication factor in case Fortran's binary data writes extra large
        header. For most cases hm = 1 is sufficient. For the cluster in St Andrews use hm = 2.
    """


    class data_struct:
        def __init__(self):
            self.t = []
            self.fidx = [] # number of fixed points at this time
            self.x = []
            self.y = []
            self.q = []

    # read the cpu structure
    dim = pc.read_dim()
    if (dim.nprocz > 1):
        print "error: number of cores in z-direction > 1"

    # determine the file structure
    n_proc = dim.nprocx*dim.nprocy

    data = []

    # total number of fixed points
    n_fixed = 0

    # read the data from all cores
    for i in range(n_proc):
        fixed_file = open(dataDir+'proc{0}/'.format(i)+fileName, 'rb')
        tmp = fixed_file.read(4*hm)

        data.append(data_struct())
        eof = 0
        if tmp == '':
            eof = 1
        while (eof == 0):
            data[i].t.append(struct.unpack("<"+str(hm+1)+"f", fixed_file.read(4*(hm+1)))[0])
            n_fixed_core = int(struct.unpack("<"+str(2*hm+1)+"f", fixed_file.read(4*(2*hm+1)))[1+hm/2])
            n_fixed += n_fixed_core
            data[-1].fidx.append(n_fixed_core)

            x = list(np.zeros(n_fixed_core))
            y = list(np.zeros(n_fixed_core))
            q = list(np.zeros(n_fixed_core))
            for j in range(n_fixed_core):
                x[j] = struct.unpack("<"+str(hm+1)+"f", fixed_file.read(4*(hm+1)))[-1]
                y[j] = struct.unpack("<f", fixed_file.read(4))[0]
                q[j] = struct.unpack("<"+str(hm+1)+"f", fixed_file.read(4*(hm+1)))[0]
            data[i].x.append(x)
            data[i].y.append(y)
            data[i].q.append(q)

            tmp = fixed_file.read(4*hm)
            if tmp == '':
                eof = 1

        fixed_file.close()

    fixed = data_struct()
    for i in range(len(data[0].t)):
        fixed.t.append(data[0].t[i])
        x = []; y = []; q = []
        for proc in range(n_proc):
            x = x + data[proc].x[i]
            y = y + data[proc].y[i]
            q = q + data[proc].q[i]
        fixed.x.append(x)
        fixed.y.append(y)
        fixed.q.append(q)

    fixed.t = np.array(fixed.t)
    fixed.x = np.array(fixed.x)
    fixed.y = np.array(fixed.y)
    fixed.q = np.array(fixed.q)

    return fixed



def read_fixed_points(dataDir = 'data/', fileName = 'fixed_points.dat', hm = 1):
    """
    Reads the fixed points files.

    call signature::

      fixed = read_tracers(fileName = 'tracers.dat', dataDir = 'data/', hm = 1)

    Reads from the fixed points files. Returns the fixed points positions.

    Keyword arguments:

      *dataDir*:
        Data directory.

      *fileName*:
        Name of the fixed points file.

      *hm*:
        Header multiplication factor in case Fortran's binary data writes extra large
        header. For most cases hm = 1 is sufficient. For the cluster in St Andrews use hm = 2.
    """


    class data_struct:
        def __init__(self):
            self.t = []
            self.fidx = [] # number of fixed points at this time
            self.x = []
            self.y = []
            self.q = []

    # read the cpu structure
    dim = pc.read_dim(datadir = dataDir)
    if (dim.nprocz > 1):
        print "error: number of cores in z-direction > 1"

    # determine the file structure
    n_proc = dim.nprocx*dim.nprocy

    data = []

    # read the data
    fixed_file = open(dataDir+fileName, 'rb')
    tmp = fixed_file.read(4*hm)

    data = data_struct()
    eof = 0
    # length of longest array of fixed points
    fixedMax = 0
    if tmp == '':
        eof = 1
    while (eof == 0):
        data.t.append(struct.unpack("<"+str(hm+1)+"f", fixed_file.read(4*(hm+1)))[0])
        n_fixed = int(struct.unpack("<"+str(2*hm+1)+"f", fixed_file.read(4*(2*hm+1)))[1+hm/2])

        x = list(np.zeros(n_fixed))
        y = list(np.zeros(n_fixed))
        q = list(np.zeros(n_fixed))
        for j in range(n_fixed):
            x[j] = struct.unpack("<"+str(hm+1)+"f", fixed_file.read(4*(hm+1)))[-1]
            y[j] = struct.unpack("<f", fixed_file.read(4))[0]
            q[j] = struct.unpack("<"+str(hm+1)+"f", fixed_file.read(4*(hm+1)))[0]
        data.x.append(x)
        data.y.append(y)
        data.q.append(q)
        data.fidx.append(n_fixed)

        tmp = fixed_file.read(4*hm)
        if tmp == '':
            eof = 1

        if fixedMax < len(x):
            fixedMax = len(x)

    fixed_file.close()

    # add NaN to fill up the times with smaller number of fixed points
    fixed = data_struct()
    for i in range(len(data.t)):
        annex = list(np.zeros(fixedMax - len(data.x[i])) + np.nan)
        fixed.t.append(data.t[i])
        fixed.x.append(data.x[i] + annex)
        fixed.y.append(data.y[i] + annex)
        fixed.q.append(data.q[i] + annex)
        fixed.fidx.append(data.fidx[i])

    fixed.t = np.array(fixed.t)
    fixed.x = np.array(fixed.x)
    fixed.y = np.array(fixed.y)
    fixed.q = np.array(fixed.q)
    fixed.fidx = np.array(fixed.fidx)

    return fixed



def tracer_movie(dataDir = 'data/', tracerFile = 'tracers.dat',
                 fixedFile = 'fixed_points.dat', zlim = [],
                 head_size = 3, hm = 1,
                 imageDir = './', movieFile = 'fixed_points.mpg',
                 fps = 5.0, bitrate = 1800):
    """
    Plots the color mapping together with the fixed points.
    Creates a movie file.

    call signature::

      tracer_movie(dataDir = 'data/', tracerFile = 'tracers.dat',
                 fixedFile = 'fixed_points.dat', zlim = [],
                 head_size = 3, hm = 1,
                 imageDir = './', movieFile = 'fixed_points.mpg',
                 fps = 5.0, bitrate = 1800)

    Plots the field line mapping together with the fixed points and creates
    a movie file.

      *dataDir*:
        Data directory.

      *tracerFile*:
        Name of the tracer file.

      *fixedFile*:
        Name of the fixed points file.

      *zlim*:
        The upper limit for the field line mapping at which a field line is considered
        to have reached the upper boundary.

      *head_size*:
        Size of the fortran header in binary data. Most of the time this is 3.
        For the St Andrews cluster it is 5.

      *hm*:
        Header multiplication factor in case Fortran's binary data writes extra large
        header. For most cases hm = 1 is sufficient. For the cluster in St Andrews use hm = 2.

      *imageDir*:
        Directory with the temporary png files.

      *movieFile*:
        Output file for the movie. Ending should be 'mpg', since the compression
        format is mpg.

      *fps*:
        Frames per second of the animation.

      *bitrate*:
        Bitrate of the movie file. Set to higher value for higher quality.
    """


    # read the mapping and the fixed point positions
    tracers, mapping, t = read_tracers(dataDir = dataDir, fileName = tracerFile, zlim = zlim, head_size = head_size)
    fixed = read_fixed_points(dataDir = dataDir, fileName = fixedFile, hm = hm)

    # read the parameters for the domain boundaries
    params = pc.read_param(quiet = True)
    domain = [params.xyz0[0], params.xyz1[0], params.xyz0[1], params.xyz1[1]]

    # determine the how much faster the fixed pints have been written out than the color mapping
    advance = np.ceil(float(len(fixed.t))/len(mapping[0,0,:,0]))

    # determine the colors for the fixed points
    colors = np.zeros(np.shape(fixed.q) + (3,))
    colors[:,:,:] = 0.
    print np.shape(colors)
    for j in range(len(colors[:,0,0])):
        for k in range(len(colors[0,:,0])):
            if fixed.q[j,k] >= 0:
                colors[j,k,1] = colors[j,k,2] = (1-fixed.q[j,k]/np.max(np.abs(fixed.q[:,k])))
                colors[j,k,0] = fixed.q[j,k]/np.max(np.abs(fixed.q[:,k]))
            else:
                colors[j,k,0] = colors[j,k,1] = (1+fixed.q[j,k]/np.max(np.abs(fixed.q[:,k])))
                colors[j,k,2] = -fixed.q[j,k]/np.max(np.abs(fixed.q[:,k]))

    # prepare the plot
    width = 6
    height = 6
    plt.rc("figure.subplot", left=(60/72.27)/width)
    plt.rc("figure.subplot", right=(width-20/72.27)/width)
    plt.rc("figure.subplot", bottom=(50/72.27)/height)
    plt.rc("figure.subplot", top=(height-20/72.27)/height)
    figure = plt.figure(figsize=(width, height))

    for k in range(len(fixed.x[0,:])):
        dots = plt.plot(fixed.x[0,k], fixed.y[0,k], 'o', c = colors[0,k,:])
    image = plt.imshow(zip(*mapping[:,::-1,0,:]), interpolation = 'nearest', extent = domain)
    j = 0
    frameName = imageDir + 'images%06d.png'%j
    imageFiles = []
    imageFiles.append(frameName)
    figure.savefig(frameName)

    for j in range(1,len(fixed.t)):
        #time.sleep(0.5)
        figure.clear()
        for k in range(len(fixed.x[j,:])):
            dots = plt.plot(fixed.x[j,k], fixed.y[j,k], 'o', c = colors[j,k,:])
        image = plt.imshow(zip(*mapping[:,::-1,np.floor(j/advance),:]), interpolation = 'nearest', extent = domain)
        frameName = imageDir + 'images%06d.png'%j
        imageFiles.append(frameName)
        figure.savefig(frameName)

    # convert the images into a mpg file
    mencodeCommand = "mencoder 'mf://"+imageDir+"images*.png' -mf type=png:fps="+np.str(fps)+" -ovc lavc -lavcopts vcodec=mpeg4:vhq:vbitrate="+np.str(bitrate)+" -ffourcc MP4S -oac copy -o "+movieFile
    os.system(mencodeCommand)

    # remove the image files
    for fname in imageFiles:
        os.remove(fname)
