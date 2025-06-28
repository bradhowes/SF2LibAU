# SF2LibAU - AUv3 MIDI instrument with sound font (SF2) rendering [BETA]

The code defines an AUAudioUnit MIDI component in Swift that uses the 
[SF2Lib][sf2lib] engine for rendering audio samples.

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

* AUv3 parameter changes communicated via the [AUParameterTree][tree] instance provided by the AUv3 instrument.
* MIDI control messages using **NRPN** MIDI control. From the SF2 spec:

> *NRPN* stands for *Non-Registered Parameter Number*. The MIDI specification has defined this series of continuous 
> controllers to permit General MIDI compatible synthesizers to take advantage of their proprietary hardware by using 
> these messages to control the non-General MIDI compatible aspects of their hardware.
> The [SoundFont 2.01 specification][spec] uses these messages to allow arbitrary real-time control over all 
> SoundFont synthesis parameters.

Note that some MIDI control messages will by default also effect a parameter change. For instance, MIDI pitch bend
messages affect the pitch of the note being played, and MIDI controllers 64 (sustain pedal), 66 (soft pedal), and 67
(sostenuto pedal) affect the envelope behavior of a playing note.

## AUParameterTree

The [AUParameterTree][tree] for the SF2 engine contains entries for all of the implemented generators. 
See the [SF spec][spec] for descriptions of these generators and their valid value ranges.

Address | Name |
---: | --- |
0 | startAddrsOffset
1 | endAddrsOffset
2 | startloopAddrsOffset
3 | endloopAddrsOffset
4 | startAddrsCoarseOffset
5 | modLfoToPitch
6 | vibLfoToPitch
7 | modEnvToPitch
8 | initialFilterFc
9 | initialFilterQ
10 | modLfoToFilterFc
11 | modEnvToFilterFc
12 | endAddrsCoarseOffset
13 | modLfoToVolume
15 | chorusEffectsSend
16 | reverbEffectsSend
17 | pan
21 | delayModLFO
22 | freqModLFO
23 | delayVibLFO
24 | freqVibLFO
25 | delayModEnv
26 | attackModEnv
27 | holdModEnv
28 | decayModEnv
29 | sustainModEnv
30 | releaseModEnv
31 | keynumToModEnvHold
32 | keynumToModEnvDecay
33 | delayVolEnv
34 | attackVolEnv
35 | holdVolEnv
36 | decayVolEnv
37 | sustainVolEnv
38 | releaseVolEnv
39 | keynumToVolEnvHold
40 | keynumToVolEnvDecay
43 | keyRange
44 | velRange
45 | startloopAddrsCoarseOffset
46 | keynum
47 | velocity
48 | initialAttenuation
50 | endloopAddrsCoarseOffset
51 | coarseTune
52 | fineTune
54 | sampleModes
56 | scaleTuning
57 | exclusiveClass
58 | overridingRootKey

> NOTE: any address not listed above will not be found in the AUParameterTree due to gaps in the [SF spec][spec].

All values for the elements in the AUParameterTree are floating-point values which will be converted into integer values
that conform to the spec. For boolean (true/false) settings, values < 0.5 are treated as `false` and values >= 0.5 
`true`.

There are additional parameters definitions for MIDI control state:

Address | Name | Description
---: | ------------------------- | --------------------------------------------------------------------
1000 | portamentoModeEnabled     | Portamento mode (aka glide)
1001 | portamentoRate            | How must time to transition for each step
1002 | oneVoicePerKeyModeEnabled | When enabled, playing same key will cancel previous voice
1003 | polyphonicModeEnabled     | When enabled, supports playing multiple notes at same time
1004 | activeVoiceCount          | Reports the number of active voices (read-only)
1005 | retriggerModeEnabled      | When enabled, playing same voice restarts the envelope of the voice

# Loading File

There are some custom SysEx messages that one can use to load an SF2 file and a preset in the file in one shot:

```swift
func createLoadFileUsePreset(path: String, preset: Int) -> Data
```

[sf2lib]: https://github.com/bradhowes/SF2Lib
[tree]: https://developer.apple.com/documentation/audiotoolbox/auparametertree
[spec]: https://github.com/bradhowes/SF2Lib/blob/main/SoundFont%20Spec%202.01.pdf
