# SF2LibAU - AUv3 MIDI instrument with sound font (SF2) rendering [BETA]

The code defines an AUAudioUnit MIDI component in Swifth that uses the
[SF2Lib](https://github.com/bradhowes/SF2Lib) engine for rendering audio samples.

Currently, the AUv3 component:

* responds to MIDI messages and can render audio
* supports loading of SF2 files via custom sysex MIDI command
* supports selecting of a preset by bank/program as well as index position

The unit tests contain examples showing all of the above.

NOTE: requires Swift 5.9 for it's Swift/C++ interoperability facility.

# Parameter Control

An SF2 file contains a collection of instruments and presets each of which contains a set of values for the SF2 
synthesizer parameters (generators) and modulator mappings; those for instruments are absolute values, while the
preset values are always relative, adding to an instrument's value. Many of these parameters can be modified in
real-time by two means:

* AUv3 parameter changes communicated via the 
  [AUParameterTree](https://developer.apple.com/documentation/audiotoolbox/auparametertree) instance provided by
  the AUv3 instrument.

* MIDI control messages using "NRPN" MIDI control. From the SF2 spec:

> NRPN stands for Non Registered Parameter Number. The MIDI specification has defined this series of continuous 
> controllers to permit General MIDI compatible synthesizers to take advantage of their proprietary hardware by using 
> these messages to control the non-General MIDI compatible aspects of their hardware. The SoundFont 2.01 specification 
> uses these messages to allow arbitrary real-time control over all SoundFont synthesis parameters.

Note that some MIDI control messages will by default also effect a parameter change. For instance, MIDI pitch bend
messages affect the pitch of the note being played, and MIDI controllers 64 (sustain pedal), 66 (soft pedal), and 67
(sostenuto pedal) affect the envelope behavior of a playing note.

## AUParameterTree


