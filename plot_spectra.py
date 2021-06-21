#! /usr/bin/python3

import io
import matplotlib.pyplot as plt
import os
import pandas as pd
import sys

if(len(sys.argv) < 2):
    exit(1)

input_file = sys.argv[1]
smartloop_exe = "/home/nathanmcrae/personal_root/projects/smart-loop-pedal-test/libsmartloop/main"
result = os.popen(f"{smartloop_exe} {input_file}").read()
result_file = io.StringIO(result)
data = pd.read_csv(delimiter='\t', filepath_or_buffer=result_file)
data.plot(x = 'shift')

file_noext = os.path.splitext(os.path.basename(input_file))[0]
fig_basename = f"{file_noext}_spectra{os.path.extsep}png"
fig_path = os.path.join(os.path.dirname(input_file), fig_basename)
plt.savefig(fig_path)
