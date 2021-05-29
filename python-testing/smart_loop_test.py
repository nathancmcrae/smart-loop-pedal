import scipy as sp
import numpy as np
import mido

"""
This module contains utility functions for use with an automated midi loop 
pedal.

The main data this module operates on are impulse sequences. They are given
as sorted lists of real numbers which represent the times at which an impulse
occurred.

Impulse sequences can also be labelled, in which case another list containing
labels (usually integers) that correspond to the impulse sequence is also 
provided.
"""

# Greatest Lower Bound Index
# returns the index of the largest value in xs that is <= v
# xs must be sorted ascending, strictly increasing.
#
# if v is < xs[0], then return -1
#
# TODO: make this a binary search
def glbi_naive(xs, v):
    for i in range(len(xs)):
        assert(i == 0 or xs[i - 1] <= xs[i])
        if(xs[i] > v):
            assert(i == 0 or xs[i-1] <= v)
            assert(i == len(xs) or xs[i] > v)
            return i - 1
    return len(xs) - 1

def glbi_rec(xs, v, ilow, ihigh):
    #print("ilow: {}, ihigh: {}".format(ilow, ihigh))
    assert(ilow in range(len(xs)))
    assert(ihigh in range(1, len(xs) + 1))
    
    assert(v >= xs[ilow])
    assert(v < xs[ihigh - 1])
    
    # Base case is a 2-element array
    if(ilow == ihigh - 2):
        if(v == xs[ilow + 1]):
            return ilow + 1
        else:
            return ilow
    
    i = int(np.floor((ihigh + ilow) / 2))
    if(not (i >= ilow)):
        breakpoint()
    assert(i < ihigh)
    
    if(v >= xs[i]):
        return glbi_rec(xs, v, i, ihigh)
    else:
        return glbi_rec(xs, v, ilow, i + 1)

def glbi(xs, v):
    #print("glbi, v: {}".format(v))
    ilow = 0
    ihigh = len(xs)
    
    if(v < xs[ilow]):
        return -1
    if(v >= xs[-1]):
        return len(xs) - 1
    
    return glbi_rec(xs, v, ilow, ihigh)

def f(v, w, WINDOW_LEN):
    return max(0, 1 - 2 * np.abs(v - w) / WINDOW_LEN)

# Generate test points for glbi
def testpoints_gen(xs):
    for i in range(len(xs)):
        yield xs[i]
        if(i != len(xs) - 1):
            yield (xs[i] + xs[i + 1])/2

def test_glbi():
    dx = [5.0,4.0,10.0,20.0,30.0,20.0,5.0,4.0,10.0,20.0,30.0,20.0,5.0,4.0]
    x = np.cumsum(dx)
    # Each element in x twice
    stutter = lambda x: [j for k in [[i, i] for i in x] for j in k ]            

    testpoints = [x[0] - 1] + list(testpoints_gen(x)) + [x[-1] + 1]
    test_answers = [-1] + list(stutter(range(0, len(x))))

    answered = [glbi(x, v) for v in testpoints]

    print(answered)
    print(test_answers)
    assert(answered == test_answers)

# For each point in the shifted sequence, get all points in the 
# original sequence within the window. Then take the sum of the 
# objective function between the shifted point and all the original 
# points in its window
#
#   *  *     * *    * **       Original sequence
#      +     + +               Points in window
#    |     V     |             Window for shifted point
#       *  *     * *    * **   Shifted sequence
def self_product_shift(x, shift, WINDOW_LEN):
    product = 0
    for i in range(len(x)):
        v = x[i] + shift
        
        # Get the indices of the window's lower and upper bounds
        
        lbi = glbi(x,v - WINDOW_LEN/2) + 1
        lbi = min(max(0, lbi), len(x) - 1)
        
        assert(lbi == len(x) - 1 or x[lbi] >= v - WINDOW_LEN/2)
        assert(lbi == 0 or x[lbi - 1] <= v - WINDOW_LEN/2)

        ubi = glbi(x, v + WINDOW_LEN/2) + 1
        ubi = min(len(x) - 1, ubi)
        
        assert(ubi == 0 or x[ubi-1] <= v + WINDOW_LEN/2)
        assert(ubi == len(x) - 1 or x[ubi] > v + WINDOW_LEN/2)

        # Caluclate the product for all points that fall in the window
        
        point_product = 0
        for j in range(lbi, min(len(x) - 1, ubi)):
            if(j == i):
                continue
            assert(f(v, x[j], WINDOW_LEN) >= 0) 
            #print("f(x[{}], x[{}] == {}".format(v, x[j], f(v, x[j])))
            point_product = point_product + f(v, x[j], WINDOW_LEN)

        product = product + point_product
    return product

# For each point in the shifted label sequence, get all points in the 
# original sequence within the window. Then take the sum of the 
# objective function between the shifted point and all the original 
# points in its window that have the same label
#
#   *  *     * *    * **       Original sequence
#      +     + +               Points in window
#    |     V     |             Window for shifted point
#       *  *     * *    * **   Shifted sequence
def labelled_seq_product(x, l, shift, WINDOW_LEN):
    product = 0
    for i in range(len(x)):
        v = x[i] + shift
        
        lbi = glbi(x,v - WINDOW_LEN/2) + 1
        lbi = min(max(0, lbi), len(x) - 1)
        
        assert(lbi == len(x) - 1 or x[lbi] >= v - WINDOW_LEN/2)
        assert(lbi == 0 or x[lbi - 1] <= v - WINDOW_LEN/2)

        ubi = glbi(x, v + WINDOW_LEN/2) + 1
        ubi = min(len(x) - 1, ubi)
        
        assert(ubi == 0 or x[ubi-1] <= v + WINDOW_LEN/2)
        assert(ubi == len(x) - 1 or x[ubi] > v + WINDOW_LEN/2)

        point_product = 0
        for j in range(lbi, min(len(x) - 1, ubi)):
            if(j == i or l[j] != l[i]):
                continue
            assert(f(v, x[j], WINDOW_LEN) >= 0) 
            point_product = point_product + f(v, x[j], WINDOW_LEN)

        product = product + point_product
    return product

# Given a impulse sequence, return a list of all shifts that would cause a 
# shifted version of the sequence to have at least one impulse overlap with
# the original sequence.
def get_sequence_self_overlaps(x):
    # The main insight needed here is that the finite difference (np.diff(x))
    # gives, for each impulse, how much we would need to shift the sequence for it
    # to overlap with the original, unshifted sequence.
    
    # n[i] is the index of the impulse in the original sequence nearest 
    # 'in front of' the ith impulse of the shifted sequence.
    n =  np.array(range(1,len(x)))
    # d[i] is the distance from the ith shifted impulse to the next original
    # impulse.
    d = np.diff(x)
    
    total_shift = 0

    shifts = []
    # What is the index of the shifted impulse that would come 'next' (i.e. 
    # after the last unshifted index) for this shift?
    next_is = []
    next_i = len(x)
    
    # Find the smallest shift needed for overlap, then update n and d to 
    # reflect that shift.
    while(n[0] < len(x)):
        #print(n[0])
        k = np.argmin(d)
        shift = d[k]
        assert(shift >= 0)
        total_shift = total_shift + shift
        shifts.append(total_shift)

        if(n[k] >= len(x) - 1):
            d[k] = np.inf
            n[k] = len(x)
            next_i = k
        else:
            d[k] = x[n[k] + 1] - x[n[k]]
            n[k] = n[k] + 1
        for l in range(len(d)):
            if(l==k):
                continue

            # Don't bother shifting 
            if(n[l] > len(x) - 1):
                continue
            d[l] = d[l] - shift
            assert(d[l] >= 0)

            if(d[l] == 0):
                if(n[l] >= len(x) - 1):
                    d[l] = np.inf
                    n[l] == len(x)
                    next_i = l
                else:
                    d[l] = x[n[l] + 1] - x[n[l]]
                    n[l] = n[l] + 1
        next_is.append(next_i)
    return shifts, next_is

# Given a midi file, write out a plaintext version to another file.
# The format of the output file is:
# 
#   <note-type>\t<note>\t<note-time>\t<note-velocity
#   ...
#
# <note-type> : "note_on" | "note_off"
# <note> : integer
# <note-time> : integer in ms
# <note-velocity> : [0,255]
#
# The note-on-times are assumed to be strictly monotonically increasing
#
# Note: this is only done with the first track
def copy_midi_plaintext(in_filename, out_filename):
    with open(out_filename, 'w') as out_file:
        mf = mido.MidiFile(in_filename)
        track = mf.tracks[0]
        current_time = 0
        
        us_per_beat = 500000.0
        seconds_per_tick = 1e-6 * us_per_beat / mf.ticks_per_beat
 
        
        for i in range(len(track)):
            current_time = current_time + track[i].time

            if(track[i].type == "note_on" or track[i].type == "note_off"):
                out_file.write(
                    "{}\t{}\t{}\t{}\n".format(
                        track[i].type,
                        track[i].note, 
                        int(current_time * seconds_per_tick * 1000), 
                        track[i].velocity))
                
def process_file(midi_file):
    """
    reads a midi file and returns the shifts that produce impulse overlaps
    and the associated powers of the labelled sequence product (between the
    input impulse sequence and the shifted version of it)
    """
    mf = mido.MidiFile(midi_file)
    track = mf.tracks[0]
    us_per_beat = 500000.0
    seconds_per_tick = 1e-6 * us_per_beat / mf.ticks_per_beat
    current_time = 0
    note_ons = []
    notes = []
    # The index of each note_on message in track
    note_is = []

    for i in range(len(track)):
        current_time = current_time + track[i].time
        #print("{}, time: {}".format(track[i], current_time))
        if(track[i].type == "note_on"):
            note_ons.append(int(current_time * seconds_per_tick * 1000))
            notes.append(track[i].note)
            note_is.append(i)
    
    shifts, next_is = get_sequence_self_overlaps(np.array(note_ons, dtype=float))
    p = [labelled_seq_product(note_ons, notes, s,  100) for s in shifts]
    
    return shifts,p