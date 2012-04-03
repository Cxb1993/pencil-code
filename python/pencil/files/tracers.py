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


def read_tracers(dataDir = 'data/', fileName = 'tracers.dat', zlim = []):
    """
    Reads the tracer files, composes a color map.

    call signature::
    
      tracers, mapping, t = read_tracers(fileName = 'tracers.dat', dataDir = 'data/', zlim)
    
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
    """
    
    class data_struct():
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

    # read the cpu structure
    dim = pc.read_dim(datadir = dataDir)
    if (dim.nprocz > 1):
        print "error: number of cores in z-direction > 1"

    # read the parameters
    params = pc.read_param(datadir = dataDir, quiet = True)
    
    # read the grid
    grid = pc.read_grid(datadir = dataDir, quiet = True)

    # determine the file structure
    n_proc = dim.nprocx*dim.nprocy
    # sub sapling of the tracers
    trace_sub = params.trace_sub
    n_times = os.path.getsize("data/proc0/tracers.dat")/(4*(3 + 7*dim.nx*dim.ny*trace_sub**2/dim.nprocx/dim.nprocy))

    # prepare the output arrays
    tracers = np.zeros((dim.nx*trace_sub, dim.ny*trace_sub, n_times, 7))
    mapping = np.zeros((dim.nx*trace_sub, dim.ny*trace_sub, n_times, 3))

    # temporary arrays for one core                                 
    tracers_core = np.zeros((dim.nx*trace_sub/dim.nprocx, dim.ny*trace_sub/dim.nprocy, n_times, 7))
    mapping_core = np.zeros((dim.nx*trace_sub/dim.nprocx, dim.ny*trace_sub/dim.nprocy, n_times, 3))

    # set the upper z-limit to the domain boundary
    if zlim == []:
        zlim = grid.z[-dim.nghostz-1]
        
    # read the data from all cores
    for i in range(n_proc):
        # read the cpu structure
        dim_core = pc.read_dim(datadir = dataDir, proc = i)
        stride = dim_core.nx*dim_core.ny*trace_sub**2    
        llen = 3 + 7*stride
        
        tracer_file = open(dataDir+'proc{0}/'.format(i)+fileName, 'rb')
        tmp = array.array('f')
        tmp.read(tracer_file, (3 + 7*dim_core.nx*dim_core.ny*trace_sub**2)*n_times)
        tracer_file.close()
        
        t = []
        
        for j in range(n_times):
            t.append(tmp[1+j*llen])
            data.xi = tmp[2+j*llen:2+stride + j*llen]
            data.yi = tmp[2+stride+j*llen:2+2*stride+j*llen]
            data.xf = tmp[2+2*stride+j*llen:2+3*stride+j*llen]
            data.yf = tmp[2+3*stride+j*llen:2+4*stride+j*llen]
            data.zf = tmp[2+4*stride+j*llen:2+5*stride+j*llen]
            data.l = tmp[2+5*stride+j*llen:2+6*stride+j*llen]
            data.q = tmp[2+6*stride+j*llen:2+7*stride+j*llen]

            # Squeeze the data into 2d array. This make the visualization much faster.
            for l in range(len(data.xi)):
                tracers_core[l%(dim_core.nx*trace_sub),l/(dim_core.nx*trace_sub),j,:] = \
                [data.xi[l], data.yi[l], data.xf[l], data.yf[l], data.zf[l], data.l[l], data.q[l]]
                if data.zf[l] >= zlim:
                    if (data.xi[l] - data.xf[l]) > 0:
                        if (data.yi[l] - data.yf[l]) > 0:
                            mapping_core[l%(dim_core.nx*trace_sub),l/(dim_core.nx*trace_sub),j,:] = [0,1,0]
                        else:
                            mapping_core[l%(dim_core.nx*trace_sub),l/(dim_core.nx*trace_sub),j,:] = [1,1,0]
                    else:
                        if (data.yi[l] - data.yf[l]) > 0:
                            mapping_core[l%(dim_core.nx*trace_sub),l/(dim_core.nx*trace_sub),j,:] = [0,0,1]
                        else:
                            mapping_core[l%(dim_core.nx*trace_sub),l/(dim_core.nx*trace_sub),j,:] = [1,0,0]
                else:
                    mapping_core[l%(dim_core.nx*trace_sub),l/(dim_core.nx*trace_sub),j,:] = [1,1,1]

            # copy single core data into total data arrays
            tracers[dim_core.ipx*dim_core.nx:(dim_core.ipx+1)*dim_core.nx, \
                    dim_core.ipy*dim_core.ny:(dim_core.ipy+1)*dim_core.ny,j,:] = \
                    tracers_core[:,:,j,:]
            mapping[dim_core.ipx*dim_core.nx:(dim_core.ipx+1)*dim_core.nx, \
                    dim_core.ipy*dim_core.ny:(dim_core.ipy+1)*dim_core.ny,j,:] = \
                    mapping_core[:,:,j,:]
                    
    return tracers, mapping, t



def read_fixed_points(dataDir = 'data/', fileName = 'fixed_points.dat'):
    """
    Reads the fixed points files.

    call signature::
    
      fixed = read_tracers(fileName = 'tracers.dat', dataDir = 'data/')
    
    Reads from the fixed points files. Returns the fixed points positions.
    
    Keyword arguments:
    
      *dataDir*:
        Data directory.
        
      *fileName*:
        Name of the fixed points file.
    """
    

    class data_struct():
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
        tmp = fixed_file.read()
        
        data.append(data_struct())
        
        # The index of the current value for t in the tmp array.
        # Note that each entry has the length 4 bytes.
        m = 4
        eof = 0
        while (eof == 0):
            data[i].t.append(struct.unpack("<f", tmp[m:m+4])[0])
            n_fixed_core = int(struct.unpack("<f", tmp[m+3*4:m+4*4])[0])
            n_fixed += n_fixed_core
            data[-1].fidx.append(n_fixed_core)

            x = list(np.zeros(n_fixed_core))
            y = list(np.zeros(n_fixed_core))
            for j in range(n_fixed_core):
                x[j] = struct.unpack("<f", tmp[m+6*4+j*4*6:m+7*4+j*4*6])[0]
                y[j] = struct.unpack("<f", tmp[m+7*4+j*4*6:m+8*4+j*4*6])[0]
            data[i].x.append(x)
            data[i].y.append(y)
                
            m = m + (n_fixed_core*4 + 7)*4
            if m >= len(tmp):
	        eof = 1

        fixed_file.close()
        
    fixed = data_struct()
    for i in range(len(data[0].t)):
        fixed.t.append(data[0].t[i])
        x = []; y = []
        for proc in range(n_proc):
            x = x + data[proc].x[i]
            y = y + data[proc].y[i]
        fixed.x.append(x)
        fixed.y.append(y)
    
    fixed.t = np.array(fixed.t)
    fixed.x = np.array(fixed.x)
    fixed.y = np.array(fixed.y)
    
    return fixed



def tracer_movie(dataDir = 'data/', tracerFile = 'tracers.dat',
                 fixedFile = 'fixed_points.dat', zlim = [],
                 imageDir = './', movieFile = 'fixed_points.mpg',
                 fps = 5.0, bitrate = 1800):
    """
    Plots the color mapping together with the fixed points.
    Creates a movie file.

    call signature::
    
      tracer_movie(dataDir = 'data/', tracerFile = 'tracers.dat',
                 fixedFile = 'fixed_points.dat', zlim = [],
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
    tracers, mapping, t = read_tracers(dataDir = dataDir, fileName = tracerFile, zlim = zlim)
    fixed = read_fixed_points(dataDir = dataDir, fileName = fixedFile)
    
    # read the parameters for the domain boundaries
    params = pc.read_param(quiet = True)
    domain = [params.xyz0[0], params.xyz0[1], params.xyz1[0], params.xyz1[1]]
    
    # prepare the plot
    width = 6
    height = 6
    plt.rc("figure.subplot", left=(60/72.27)/width)
    plt.rc("figure.subplot", right=(width-20/72.27)/width)
    plt.rc("figure.subplot", bottom=(50/72.27)/height)
    plt.rc("figure.subplot", top=(height-20/72.27)/height)
    figure = plt.figure(figsize=(width, height))

    dots = plt.plot(fixed.x[0,:], fixed.y[0,:], 'o', c='white')
    image = plt.imshow(mapping[::-1,:,0,:], interpolation = 'nearest', extent = domain)
    j = 0
    frameName = imageDir + 'images%06d.png'%j
    imageFiles = []
    imageFiles.append(frameName)
    figure.savefig(frameName)

    for j in range(1,len(fixed.t)):
        #time.sleep(0.5)
        figure.clear()
        dots = plt.plot(fixed.x[j,:], fixed.y[j,:], 'o', c = 'white')
        image = plt.imshow(zip(*mapping[:,::-1,j,:]), interpolation = 'nearest', extent = [-4,4,-4,4])
        #plt.show()
        frameName = imageDir + 'images%06d.png'%j
        imageFiles.append(frameName)
        figure.savefig(frameName)

    # convert the images into a mpg file
    mencodeCommand = "mencoder 'mf://"+imageDir+"images*.png' -mf type=png:fps="+np.str(fps)+" -ovc lavc -lavcopts vcodec=mpeg4:vhq:vbitrate="+np.str(bitrate)+" -ffourcc MP4S -oac copy -o "+movieFile
    os.system(mencodeCommand)
    
    # remove the image files
    for fname in imageFiles:
        os.remove(fname)
    
