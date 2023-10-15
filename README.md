# SF2LibAU - AUv3 MIDI instrument with sound font (SF2) rendering [BETA]

The code defines an AUAudioUnit MIDI component in Swifth that uses the
[SF2Lib](https://github.com/bradhowes/SF2Lib) engine for rendering audio samples.

Currently, the AUv3 component:

* responds to MIDI messages and can render audio
* supports loading of SF2 files via custom sysex MIDI command
* supports selecting of a preset by bank/program as well as index position

The unit tests contain examples showing all of the above.

NOTE: requires Swift 5.9 for it's Swift/C++ interoperability facility.
