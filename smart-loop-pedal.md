# Smart Loop-Pedal

I want a midi loop pedal. When I press it, it will listen to a pattern I play and then will start repeating it as soon as I release it.

- [ ] Potential problem: with long enough sequences that don't actually have any commonality, there could be quite a bit of overlap. How much of a problem is this? Test.

## References

- https://github.com/pure-data/externals-howto

- ~~Python for PD Externals: https://grrrr.org/research/software/py/~~

## Roadmap

- [x] concept testing in python
- [x] basic pd library compilation
- [ ] research data architecture
  - How will I store an impulse sequence?
  - Are there libraries that will do my (d)alloc for me so I don't fuck it up?
    - I don't have that much, probably I just want to allocate a single array and have an index into that.
- [ ] do basic MIDI recording and playback
- ...
- [ ] write processing library
- [ ] processing library testing setup
- [ ] integration...

## 2020-12-23

When I have multiple inlets and they both receive float messages at the same time, how can I make sure that the 'hot' inlet will trigger using the correct value from the 'cold' inlet?

If I have cold inlets, when the hot inlet is triggered (e.g. via a tick), how do I tell that the cold inlets have been updated other than that the values are different.
  Could I set the cold inlet values to NaN when I process them?
