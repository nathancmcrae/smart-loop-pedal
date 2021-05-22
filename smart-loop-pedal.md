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
