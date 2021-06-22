#!/usr/bin/env python

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
spectra = pd.read_csv(delimiter='\t', filepath_or_buffer=result_file)

notes = pd.read_csv(input_file, delimiter='\t')
note_ons = notes[notes['note-type'] == 'note_on']
plt.figure()
for i in range(len(note_ons)):
    note = note_ons.iloc[i]
    plt.plot([note['note-time']-50, note['note-time']+50],[note['note'], note['note']], color='b')

i_max = spectra['acorr'].idxmax(1)
shift_max = spectra['shift'].iloc[i_max]

for i in range(len(note_ons)):
    note = note_ons.iloc[i]
    plt.plot([note['note-time']-50+shift_max, note['note-time']+50+shift_max],[note['note'], note['note']], color='r')

file_noext = os.path.splitext(os.path.basename(input_file))[0]
fig_basename = f"{file_noext}_shifted{os.path.extsep}png"
fig_path = os.path.join(os.path.dirname(input_file), fig_basename)
plt.savefig(fig_path)
