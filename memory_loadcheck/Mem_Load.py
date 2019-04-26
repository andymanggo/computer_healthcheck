# breif: Memory usage calculate
from __future__ import division
import os
import re
import statvfs
import sys

# function for get file usage
def get_filesystem_usage( filepath ):
    # linux system function statvfs
    vfs = os.statvfs( filepath )
    usage = ((vfs[statvfs.F_BLOCKS]-vfs[statvfs.F_BFREE])*vfs[statvfs.F_BSIZE])/1024

    return usage

# function for calculate mem load
def mem_load():
    f = open('/proc/meminfo','r')
    meminfo = f.read()
    mem_arr = []

    # MemTotal
    total = int(re.search(r"MemTotal:[\s]+(\d+)", meminfo).group(1))

    # MemFree
    free = int(re.search(r"MemFree:[\s]+(\d+)", meminfo).group(1))

    # Buffers
    buffers = int(re.search(r"Buffers:[\s]+(\d+)", meminfo).group(1))

    # Cached: return the first position of Cached
    cache = int(re.search(r"Cached:[\s]+(\d+)", meminfo).group(1))

    # SReclaimable
    srecla = int(re.search(r"SReclaimable:[\s]+(\d+)", meminfo).group(1))

    # dev filesystem usage
    udevUsage = get_filesystem_usage('/dev')

    f.close()

    # calculate usage
    mem_usage = total - ((free + buffers + cache + srecla) - udevUsage)
    usage_percentage = ( mem_usage / total ) * 100

    mem_arr.append(total)
    mem_arr.append(mem_usage)
    mem_arr.append(usage_percentage)

    return mem_arr
