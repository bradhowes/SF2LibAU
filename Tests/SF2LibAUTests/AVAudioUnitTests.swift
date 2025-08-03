import AVFAudio
import Testing

@testable import SF2LibAU

@Suite("AVAudioUnitTests")
struct AVAudioUnitTests {
  let sampleRate: Double = 48_000.0
  let audioFormat: AVAudioFormat
  let audioComponentDescription: AudioComponentDescription = .init(
    componentType: FourCharCode("aumu"),
    componentSubType: FourCharCode("Sf2L"),
    componentManufacturer: FourCharCode("BRay"),
    componentFlags: 0,
    componentFlagsMask: 0
  )

  let avAudioUnit: AVAudioUnit
  let avMidiInstrument: AVAudioUnitMIDIInstrument
  let auAudioUnit: SF2LibAU
  let engine = AVAudioEngine()

  init() async throws {
    AUAudioUnit.registerSubclass(SF2LibAU.self, as: audioComponentDescription, name: "SF2LibAU", version: 1)
    avAudioUnit = try await AVAudioUnit.instantiate(with: audioComponentDescription, options: [])
    audioFormat = try #require(
      AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: sampleRate,
        channels: 2,
        interleaved: false
      )
    )

    avMidiInstrument = try #require(avAudioUnit as? AVAudioUnitMIDIInstrument)
    auAudioUnit = try #require(avMidiInstrument.auAudioUnit as? SF2LibAU)

    engine.attach(avMidiInstrument)
    engine.connect(avMidiInstrument, to: engine.outputNode, format: audioFormat)

    try engine.start()
  }

  @Test("can play MIDI notes")
  func canJoinEngine() async throws {
    #expect(try loadSF2(au: auAudioUnit, index: 0, preset: 14))
    avMidiInstrument.startNote(76, withVelocity: 127, onChannel: 0)
    try await Task.sleep(for: .milliseconds(300))
    avMidiInstrument.stopNote(76, onChannel: 0)
    avMidiInstrument.startNote(74, withVelocity: 127, onChannel: 0)
    try await Task.sleep(for: .milliseconds(300))
    avMidiInstrument.stopNote(74, onChannel: 0)
    avMidiInstrument.startNote(72, withVelocity: 127, onChannel: 0)
    try await Task.sleep(for: .milliseconds(800))
    avMidiInstrument.stopNote(72, onChannel: 0)
    try await Task.sleep(for: .milliseconds(100))
  }

  @Test("can change presets")
  func canChangePresets() async throws {
    #expect(try loadSF2(au: auAudioUnit, index: 0, preset: 0))

    avMidiInstrument.startNote(60, withVelocity: 100, onChannel: 0)
    avMidiInstrument.startNote(64, withVelocity: 100, onChannel: 0)
    avMidiInstrument.startNote(67, withVelocity: 100, onChannel: 0)
    try await Task.sleep(for: .milliseconds(1000))
    avMidiInstrument.stopNote(60, onChannel: 0)
    avMidiInstrument.stopNote(64, onChannel: 0)
    avMidiInstrument.stopNote(67, onChannel: 0)
    try await Task.sleep(for: .milliseconds(100))

    avMidiInstrument.sendProgramChange(100, onChannel: 0)

    avMidiInstrument.startNote(60, withVelocity: 100, onChannel: 0)
    avMidiInstrument.startNote(64, withVelocity: 100, onChannel: 0)
    avMidiInstrument.startNote(67, withVelocity: 100, onChannel: 0)
    try await Task.sleep(for: .milliseconds(1000))
    avMidiInstrument.stopNote(60, onChannel: 0)
    avMidiInstrument.stopNote(64, onChannel: 0)
    avMidiInstrument.stopNote(67, onChannel: 0)
    try await Task.sleep(for: .milliseconds(100))
  }

  @Test("can change parameters")
  func canChangeParameters() async throws {
    #expect(try loadSF2(au: auAudioUnit, index: 0, preset: 14))
    let parameterTree = auAudioUnit.parameterTree
    #expect(parameterTree != nil)

    let preset: AUParameter! = parameterTree?.parameter(withAddress: 1009)
    #expect(preset != nil)
    #expect(preset.identifier == "activePresetIndex")

    // Spin here until we see the preset we asked for
    while preset.value != 14 {
      try await Task.sleep(nanoseconds: 1_000_000)
    }

    // Set the attackVolumeEnvelope to 0.0 which per spec is 1.0 second to reach envelope peak.
    let attack = parameterTree?.parameter(withAddress: 34)
    #expect(attack != nil)
    #expect(attack?.identifier == "attackVolumeEnvelope")
    attack?.setValue(0, originator: nil)

    // Play three notes for 1 second each to hear the increasing attack volume
    avMidiInstrument.startNote(76, withVelocity: 127, onChannel: 0)
    try await Task.sleep(for: .milliseconds(1000))
    avMidiInstrument.stopNote(76, onChannel: 0)
    avMidiInstrument.startNote(74, withVelocity: 127, onChannel: 0)
    try await Task.sleep(for: .milliseconds(1000))
    avMidiInstrument.stopNote(74, onChannel: 0)
    avMidiInstrument.startNote(72, withVelocity: 127, onChannel: 0)
    try await Task.sleep(for: .milliseconds(1000))
    avMidiInstrument.stopNote(72, onChannel: 0)
    try await Task.sleep(for: .milliseconds(100))
  }
}

func loadSF2(au: SF2LibAU, index: Int, preset: Int) throws -> Bool {
  let paths = getSF2Resources()
  let path = paths[index].standardizedFileURL.absoluteString
  return au.sendLoadFileUsePreset(path: path, preset: preset)
}
