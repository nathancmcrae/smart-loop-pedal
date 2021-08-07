# Smart Loop-Pedal

I want a midi loop pedal. When I press it, it will listen to a pattern I play and then will start repeating it as soon as I release it.

* [ ] Potential problem: with long enough sequences that don't actually have any commonality, there could be quite a bit of overlap. How much of a problem is this? Test.

## References

* https://github.com/pure-data/externals-howto
* ~~Python for PD Externals: https://grrrr.org/research/software/py/~~

## Roadmap

* [x] concept testing in python
* [x] basic pd library compilation
* [x] research data architecture
  * How will I store an impulse sequence?
  * Are there libraries that will do my (d)alloc for me so I don't fuck it up?
    * I don't have that much, probably I just want to allocate a single array and have an index into that.
* [x] do basic MIDI recording and playback
* [x] Compile zig lib with a C shim
* [x] Port midimock to zig
* ...
* [ ] write processing library
* [ ] processing library testing setup
* [ ] integration...

## 2020-12-23

When I have multiple inlets and they both receive float messages at the same time, how can I make sure that the 'hot' inlet will trigger using the correct value from the 'cold' inlet?

If I have cold inlets, when the hot inlet is triggered (e.g. via a tick), how do I tell that the cold inlets have been updated other than that the values are different. Could I set the cold inlet values to NaN when I process them?

## 2021-01-01

Build and run in the correct environment

```
make && pd -alsamidi -midiindev 1 -midioutdev 1 -lib midimock.pd_linux mockingbird-test.pd
```

## 2021-01-02

pd-lib-builder generated compilation commands:

```
cc -DPD -I "/usr/include/pd" -DUNIX  -fPIC  -Wall -Wextra -Wshadow -Winline -Wstrict-aliasing -O3 -ffast-math -funroll-loops -fomit-frame-pointer -march=core2 -mfpmath=sse -msse -msse2 -msse3 -o midimock.o -c midimock.c
cc -rdynamic -shared -fPIC -Wl,-rpath,"\$ORIGIN",--enable-new-dtags    -o midimock.pd_linux midimock.o  -lc -lm
```

## 2021-01-03

zig branch still isn't getting past setup. At least try gdb or maybe ltrace to see what's going on. Then if nothing maybe give up and go back to c.

## 2021-01-06

Trying to see if I can use zig code with a c shim. Modifying midimock to test it.

when trying to load midimock with zigimock:

```
midimock.pd_linux: can't load library
    /home/nathanmcrae/personal_root/projects/smart-loop-pedal-test/pd-midi-mockingbird/midimock.pd_linux: /home/nathanmcrae/personal_root/projects/smart-loop-pedal-test/pd-midi-mockingbird/midimock.pd_linux: undefined symbol: __muloti4
 midimock
... couldn't create
```

```
$ objdump -x midimock.pd_linux | grep *UND*
0000000000000000         *UND*	0000000000000000              gensym
0000000000000000  w      *UND*	0000000000000000              _ITM_deregisterTMCloneTable
0000000000000000         *UND*	0000000000000000              pd_new
0000000000000000         *UND*	0000000000000000              class_addbang
0000000000000000       F *UND*	0000000000000000              __assert_fail@@GLIBC_2.2.5
0000000000000000       F *UND*	0000000000000000              memset@@GLIBC_2.2.5
0000000000000000       F *UND*	0000000000000000              __tls_get_addr@@GLIBC_2.3
0000000000000000  w      *UND*	0000000000000000              __gmon_start__
0000000000000000       F *UND*	0000000000000000              memcpy@@GLIBC_2.14
0000000000000000         *UND*	0000000000000000              __muloti4
0000000000000000         *UND*	0000000000000000              __zig_probe_stack
0000000000000000         *UND*	0000000000000000              s_float
0000000000000000         *UND*	0000000000000000              post
0000000000000000         *UND*	0000000000000000              outlet_new
0000000000000000         *UND*	0000000000000000              class_new
0000000000000000         *UND*	0000000000000000              outlet_float
0000000000000000  w      *UND*	0000000000000000              _ITM_registerTMCloneTable
0000000000000000         *UND*	0000000000000000              floatinlet_new
0000000000000000  w    F *UND*	0000000000000000              __cxa_finalize@@GLIBC_2.2.5
```

What else do I need to link against?

Maybe try creating a zig executable and seeing if these zig-related symbols are defined there.

## 2021-01-22

Try adding these zig compilation options:

```
zig build-lib -fno-stack-check -fcompiler-rt ...
```

And, since I was dumb enough to leave out the original compilation command:

```
zig build-lib -DPD -DUNIX -fPIC -rpath "\$ORIGIN" zigimock.zig 
```

making the full command:

```bash
zig build-lib --library c -I . -I "/usr/include/pd" -fno-stack-check -fcompiler-rt -DPD -DUNIX -fPIC -rpath "\$ORIGIN" zigimock.zig
```

Really I should be doing this in a Makefile, but I feel unfamiliar enough with the tooling that I'm not yet ready to abstract away from it.

Oh geez, I didn't even record the command I used to link in zigimock. ugh.

```
cc -rdynamic -shared -fPIC -Wl,-rpath,"\$ORIGIN",--enable-new-dtags -o midimock.pd_linux midimock.o libzigimock.a  -lc -lm                                                                             

```

# 2021-01-23

Instead of calling into my zig lib from the c shim, just register the lib function directly with pd.

# 2021-02-20

Compiling in midilib (TODO: use build.zig for this)

```bash
cd libsmartloop
zig cc -c midilib/src/midifile.c -o midilib/src/midifile.o
zig test midilib/src/midifile.o src/main.zig -I midilib/src -lc
```

# 2021-03-01

Decision: I will track note_offs by necessity, but for periodicity calculations I will only (or dominantly) use note_ons

# 2021-03-27

[ ] Need to set up final project structure (particularly the build process)
    maybe src/main.zig

# 2021-05-15

Commands to compile and run zigimock all in one:

``` bash
cc -DPD -I "/usr/include/pd" -DUNIX  -fPIC  -Wall -Wextra -Wshadow -Winline -Wstrict-aliasing -O3 -ffast-math -funroll-loops -fomit-frame-pointer -march=core2 -mfpmath=sse -msse -msse2 -msse3 -o midimock.o -c midimock.c
zig build-lib --library c -I . -I "/usr/include/pd" -fno-stack-check -fcompiler-rt -DPD -DUNIX -fPIC -rpath "\$ORIGIN" --main-pkg-path .. zigimock.zig
cc -rdynamic -shared -fPIC -Wl,-rpath,"\$ORIGIN",--enable-new-dtags -o midimock.pd_linux midimock.o libzigimock.a  -lc -lm                                                                             
pd -alsamidi -midiindev 1 -midioutdev 1 -lib midimock.pd_linux mockingbird-test.pd
```

# 2021-05-23

The current pd object architecture (in midimock) won't work because it can fundamentally take only one note at a time, but we want to be note rate to be unlimited. So need to find another architecture. Maybe it could be as simple as adding one more 'active' inlet that it banged when a new note is sent. That way we don't have to wait for the tick to add a new note.

# 2021-05-30

Developed using zig version 0.7.1+dfacac916

# 2021-05-31

- [x] Some things that zig test complains about memory leaks for, running pd will error with a double-free. For now I'm defaulting to making pd happy, but something is screwy. Maybe run it under valgrind

2021-06-21: pretty sure this was because I was explicitly using the std.testing.allocator in some places instead of the passed-in allocator.

# 2021-06-05

Next thing to do is to set up a usable looping/testing environment (like recording midi up front so I can replay issues).

I might need to run it on ReleaseFast for it to be fast enough.

Then I can start fine-tuning the loop detection.

# 2021-06-10

First, I realized that once I have a loop recorded, then I can record stuff on top of that without needing to recalculate periodicity for the new track (unless I still want to do phrase-level polyrythms)

Also, I tried to translate the c shim to zig. The translate nominally worked, but a lot of the types are still opaque. I might still try to see if I can get it to compile

# 2021-06-19

- [ ] Do more extensive testing of equivalence between getPeriodicity and getFinePeriodicity
- [ ] Be able to easily plot spectra
- [ ] Be able to easily plot notes in piano-roll style

# 2021-06-20

```powershell
get-childitem -recurse ./pd-midi-mockingbird-2/recordings/ |?{$_ -match "\.txt$"} | %{python ./plot_spectra.py $_.FullName}
```

# 2021-06-23

1624505205.txt
periodicity power: 29824, periodicity: 456

looks like this is a difference between getPeriodicity and getFinePeriodicity

- [ ] How to handle when recording buffer is full? Ideally the buffer should be sized such that it never practically happens, but what about when it does?
  Maybe the pd object should have an 'error' output that triggers whenever something like this happens. This could toggle a light to indicate something happened.

# 2021-06-24

Fixed a bug in getFinePeriodicity and loop detection seems better now. Still need more extensive testing, but for the sake of a setup that is more encouraging I think I should focus on syncing multiple loops. Maybe try to implement simpleloop?

Then I need to do some cleanup.

# 2021-07-19

The commandline midi recording tool is `arecordmidi`

# 2021-07-21

1626923074.txt caused this?
```
/home/nathanmcrae/personal_root/projects/smart-loop-pedal-test/libsmartloop/src/main.zig:647:34: 0x7f1579
e6edf0 in libsmartloop.src.main.getFinePeriodicity (zigimock)                                           
    if (glbi(shifts, rough_shifts[start_i])) |start_index| {
                                 ^
/home/nathanmcrae/personal_root/projects/smart-loop-pedal-test/pd-midi-mockingbird-2/zigimock.zig:138:59:
 0x7f1579e6bd7e in midimock_bang (zigimock)                                                             
            var periodicity_err = sloop.getFinePeriodicity(std.heap.c_allocator, note_ons[0..obj.note_on_
buffer.index], notes[0..obj.note_on_buffer.index], overlaps, 50, 100);                                  
                                                          ^
Pd: signal 6
```

Doesn't seem to do it when I run it through the executable. hmmm...

Actually, it seems like 1 note sequences do this

# 2021-08-05

To connect midi ports together, use aconnect:

```bash
aconnect 'Logidy UMI3':'Logidy UMI3 MIDI 1' 'Pure Data':'Pure Data Midi-In 1'
```

etc.

Use `aconnect --list` to see what's already connected for debug

https://digitaldub.wordpress.com/2009/12/16/linux-audio-session-scripting/

# 2021-08-07

- This seems like an important thread for pd MIDI IO: https://github.com/pure-data/pure-data/issues/399
- [ ] Need to be able to route MIDI recordings into my setup to be able to reproduce issues
- [ ] My pd sustain pedal will cancel notes coming out of the smartloop object that it just recorded into. How to avoid this?
- [ ] externally-controlled loops are playing long durations of silence when looping, though are otherwise in-sync. Check what region of time (relative to `obj.start_time_ms`) the loop spans and what region of time the playback spans.
