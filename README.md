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
1001 | portamentoRate            | How long it takes to transition for each step
1002 | oneVoicePerKeyModeEnabled | When enabled, playing same key will cancel previous voice
1003 | polyphonicModeEnabled     | When enabled, supports playing multiple notes at same time
1004 | activeVoiceCount          | Reports the number of active voices (read-only)
1005 | retriggerModeEnabled      | When enabled, playing same voice restarts the envelope of the voice

# Loading SF2 File

There is a custom SysEx messages that one can use to load an SF2 file and a preset in the file in one shot. To make this
easy for integration, there is a utility function that will generate the SysEx for a given file path and preset index
value.

```swift
func sendLoadFileUsePreset(path: String, preset: Int) -> Bool
```

The function creates the propery SysEx command and then provides it to the sendMIDI utility function that hands it to
`scheduleMIDIEventBlock` method defined by the audio unit:

```swift
func sendMIDI(bytes: Array<UInt8>, when: AUEventSampleTime = .min, cable: UInt8 = 0) -> Bool {
  guard let block = scheduleMIDIEventBlock else { return false }
  block(when, cable, bytes.count, bytes)
  return true
}
```

For the curious, the actual [format of the SysEx][sysex] is the following:

Byte | Field | Description
---: | -------- | -----------
0    | 0xF0 | Start of a MIDI 1.0 SysEx message
1    | 0x7E | Custom SF2Lib command
2    | 0x00 | Unused subtype (reserved)
3    | MSB  | the MSB of the preset index to use
4    | LSB  | the LSB of the preset index to use
5    | P[0] | the first character of the file path (Base 64 encoded)
N - 1 | P[N - 1] | the last character of the file path of N encoded characters
N | 0xF7 | End of a MIDI 1.0 SysEx message

The file path is Base-64 encoded since MIDI 1.0 data bytes are only 7 bits, even in a SysEx message.

There is a variant of the above that has no path -- it is used to change to a new preset in the same file:

Byte | Field | Description
---: | -------- | -----------
0    | 0xF0 | Start of a MIDI 1.0 SysEx message
1    | 0x7E | Custom SF2Lib command
2    | 0x00 | Unused subtype (reserved)
3    | MSB  | the MSB of the preset index to use
4    | LSB  | the LSB of the preset index to use
5    | 0xF7 | End of a MIDI 1.0 SysEx message

Since there is no file name, the size of this message is always 6 bytes.

# Selecting Bank/Program

The above SysEx command is useful when selecting a preset from within the SF2 file, but presets are also 
addressed by a _bank_ and a _program_ value, where a bank contains a collection of programs, and only one bank is
active at a time. To change the program in the current bank, there is the MIDI 1.0 programChange command (0xC0) that
takes one byte (0-127) that is the value of the program to use in the current bank.

To switch banks, one can do so by setting two dedicated continuous-controller (CC) values that hold the MSB (0x00) and 
LSB (0x20) of the bank. Both take one byte of value (0-127), so the maximum bank is 128 x 127 + 127 = 16383. To change
a bank and program at the same time, there is the utility function:

```swift
func sendUseBankProgram(bank: UInt16, program: UInt8) -> Bool
```

This function actually generates three MIDI commands: 2 to set the dedicated CC values for the bank, and 1 to set the 
preset value.

[sf2lib]: https://github.com/bradhowes/SF2Lib
[tree]: https://developer.apple.com/documentation/audiotoolbox/auparametertree
[spec]: https://github.com/bradhowes/SF2Lib/blob/main/SoundFont%20Spec%202.01.pdf
[sysex]: https://github.com/bradhowes/SF2Lib/blob/4da66ba295a4881a9fb94a7443a12071f70d0172/Sources/SF2Lib/Render/Engine/Engine.mm#L391
