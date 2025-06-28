import AVFAudio
import XCTest
@testable import SF2LibAU

@MainActor
final class SF2LibAUTests: XCTestCase {
  static let sampleRate: Double = 48_000.0
  static let audioFormat: AVAudioFormat = .init(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 2,
                                                interleaved: false)!

  // Make the number of frames to render the same as the sample rate to render 1 second of audio samples
  let frameCount: AVAudioFrameCount = .init(sampleRate) * 2

  let audioComponentDescription: AudioComponentDescription = .init(componentType: FourCharCode("aumu"),
                                                                   componentSubType: FourCharCode("sf2L"),
                                                                   componentManufacturer: FourCharCode("bray"),
                                                                   componentFlags: 0, componentFlagsMask: 0)
  let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(sampleRate), channels: 2,
                             interleaved: false)!
  var stereoBuffer: AVAudioPCMBuffer!
  var au: SF2LibAU!
  var playedAudioExpectation: XCTestExpectation?
  var player: AVAudioPlayer?
  var audioFile: AVAudioFile? // = try makeAudioFile()
  var framesRemaining: AVAudioFrameCount = 0

  override func setUp() async throws {
    stereoBuffer = AVAudioPCMBuffer(pcmFormat: Self.audioFormat, frameCapacity: self.frameCount)
    stereoBuffer.frameLength = 0
    print("frameCapacity: \(stereoBuffer.frameCapacity)")
    framesRemaining = self.frameCount

    au = try SF2LibAU(componentDescription: self.audioComponentDescription, options: [])
    au.maximumFramesToRender = self.frameCount
    playedAudioExpectation = nil
    player = nil
  }

  func testInitDoesNotThrow() throws {
    XCTAssertFalse(au.renderResourcesAllocated)
    XCTAssertEqual("", au.activePresetName)
  }

  func testInputBussesReturnsSameInstance() throws {
    let b1 = au.inputBusses
    let b2 = au.inputBusses
    XCTAssertTrue(b1 === b2)
    XCTAssertEqual(0, b1.count)
  }

  func testOutputBussesReturnsSameInstance() throws {
    let b1 = au.outputBusses
    let b2 = au.outputBusses
    XCTAssertTrue(b1 === b2)
    XCTAssertEqual(3, b1.count)
  }

  func testCanAllocateResources() throws {
    let busses = au.outputBusses
    for index in 0..<busses.count {
      try busses[index].setFormat(self.format)
    }
    try au.allocateRenderResources()
    XCTAssertTrue(au.renderResourcesAllocated)
    XCTAssertEqual("", au.activePresetName)
  }

  func testCanRender() throws {
    try au.allocateRenderResources()
    XCTAssertEqual(0, doRender())
    XCTAssertEqual("", au.activePresetName)
  }

  func testCanLoadLibrary() throws {
    try prepareToRender(index: 1, preset: 0) {
      let presetName = au.activePresetName
      XCTAssertEqual("Nice Piano", presetName)
    }
  }

  func testCanSetBankProgram() throws {
    try prepareToRender(index: 0, preset: 0, recording: true) {
      let presetName1 = au.activePresetName
      XCTAssertEqual("Piano 1", presetName1)
      for (bank, program, expectedName) in [(0, 123, "Bird"), (8, 28, "Funk Gt."), (128, 25, "TR-808")] {
        XCTAssertTrue(au.sendUseBankProgram(bank: UInt16(bank), program: UInt8(program)))
        XCTAssertTrue(au.sendNoteOn(note: 0x40))
        XCTAssertTrue(au.sendNoteOn(note: 0x44))
        XCTAssertTrue(au.sendNoteOn(note: 0x47))
        XCTAssertEqual(0, doRender(fraction: 0.3))
        let presetName = au.activePresetName
        XCTAssertEqual(expectedName, presetName)
      }
    }
  }

  func testCanUseIndex() throws {
    try prepareToRender(index: 0, preset: 0, recording: true) {
      let presetName1 = au.activePresetName
      XCTAssertEqual("Piano 1", presetName1)
      for (preset, expectedName) in [(0, "Piano 1"), (128, "SynthBass101"), (180, "Church Org.2")] {
        XCTAssertTrue(au.sendUsePreset(preset: preset))
        XCTAssertTrue(au.sendNoteOn(note: 0x40))
        XCTAssertTrue(au.sendNoteOn(note: 0x44))
        XCTAssertTrue(au.sendNoteOn(note: 0x47))
        XCTAssertEqual(0, doRender(fraction: 0.3))
        let presetName = au.activePresetName
        XCTAssertEqual(expectedName, presetName)
      }
    }
  }

  func testCanPlayNote() throws {
    try prepareToRender(index: 1, preset: 0, recording: true) {
      XCTAssertTrue(au.sendNoteOn(note: 0x40))
      XCTAssertTrue(au.sendNoteOn(note: 0x44))
      XCTAssertTrue(au.sendNoteOn(note: 0x47))
      XCTAssertEqual(0, doRender(fraction: 0.5))
      XCTAssertEqual(6, au.activeVoiceCount)
      XCTAssertEqual(0, doRender())
    }
  }

  func testCanSendNoteOff() throws {
    try prepareToRender(index: 1, preset: 0, recording: true) {
      XCTAssertTrue(au.sendNoteOn(note: 0x40))
      XCTAssertTrue(au.sendNoteOn(note: 0x44))
      XCTAssertTrue(au.sendNoteOn(note: 0x47))
      XCTAssertEqual(0, doRender(fraction: 0.5))
      XCTAssertTrue(au.sendNoteOff(note: 0x40))
      XCTAssertTrue(au.sendNoteOff(note: 0x44))
      XCTAssertTrue(au.sendNoteOff(note: 0x47))
      XCTAssertEqual(0, doRender())
      XCTAssertEqual(6, au.activeVoiceCount)
    }
  }

  func testAllSoundOff() throws {
    try prepareToRender(index: 1, preset: 0, recording: true) {
      XCTAssertTrue(au.sendNoteOn(note: 0x40))
      XCTAssertTrue(au.sendNoteOn(note: 0x44))
      XCTAssertTrue(au.sendNoteOn(note: 0x47))
      XCTAssertEqual(0, doRender(fraction: 0.25))
      XCTAssertEqual(6, au.activeVoiceCount)
      XCTAssertTrue(au.sendAllSoundOff())
      XCTAssertEqual(0, doRender(for: 10))
      XCTAssertEqual(0, au.activeVoiceCount)
      XCTAssertEqual(0, doRender())
    }
  }

  func testAllNotesOff() throws {
    try prepareToRender(index: 0, preset: 5, recording: true) {
      XCTAssertTrue(au.sendNoteOn(note: 0x40))
      XCTAssertTrue(au.sendNoteOn(note: 0x44))
      XCTAssertTrue(au.sendNoteOn(note: 0x47))
      XCTAssertEqual(0, doRender(fraction: 0.1))
      XCTAssertEqual(3, au.activeVoiceCount)
      XCTAssertTrue(au.sendAllNotesOff())
      XCTAssertEqual(0, doRender(for: 1))
      XCTAssertEqual(3, au.activeVoiceCount)
      XCTAssertEqual(0, doRender())
      XCTAssertEqual(0, au.activeVoiceCount)
    }
  }

  func testCanSendResetCmdToCancelNotes() throws {
    try prepareToRender(index: 1, preset: 0) {
      XCTAssertTrue(au.sendNoteOn(note: 0x60))
      XCTAssertEqual(0, doRender(fraction: 0.5))
      XCTAssertEqual(2, au.activeVoiceCount)
      XCTAssertTrue(au.sendReset())
      XCTAssertEqual(0, doRender(fraction: 0.5))
      XCTAssertEqual(0, au.activeVoiceCount)
    }
  }

  func testCanChangePhonicModes() throws {
    try prepareToRender(index: 0, preset: 0) {
      XCTAssertFalse(au.monophonicModeEnabled)
      XCTAssertTrue(au.polyphonicModeEnabled)
      XCTAssertTrue(au.sendChannelMessage(message: 0x7E, value: 1))
      XCTAssertEqual(0, doRender(fraction: 0.5))
      XCTAssertTrue(au.monophonicModeEnabled)
      XCTAssertFalse(au.polyphonicModeEnabled)
      XCTAssertTrue(au.sendChannelMessage(message: 0x7F, value: 1))
      XCTAssertEqual(0, doRender())
      XCTAssertFalse(au.monophonicModeEnabled)
      XCTAssertTrue(au.polyphonicModeEnabled)
    }
  }

  func testCanChangePanning() throws {
    try prepareToRender(index: 0, preset: 0) {
      XCTAssertTrue(au.sendChannelMessage(message: 0x0A, value: 0))
      XCTAssertTrue(au.sendNoteOn(note: 0x40))
      XCTAssertEqual(0, doRender(fraction: 0.5))
      XCTAssertTrue(au.sendChannelMessage(message: 0x0A, value: 0x7F))
      XCTAssertEqual(0, doRender())
    }
  }

  func testGetFullState() throws {
    try prepareToRender(index: 0, preset: 0) {
      let state = au.fullState
      XCTAssertNotNil(state)
    }
  }

  func testSetFullState() throws {
    try prepareToRender(index: 0, preset: 0) {
      let state = au.fullState
      XCTAssertNotNil(state)
      au.fullState = state
      XCTAssertTrue(au.supportsUserPresets)
    }
  }

  func testGetCurrentPreset() throws {
    try prepareToRender(index: 0, preset: 0) {
      let state = au.currentPreset
      XCTAssertNil(state)
    }
  }

  func testSetCurrentPreset() throws {
    try prepareToRender(index: 0, preset: 0) {
      let state = au.currentPreset
      au.currentPreset = state
    }
  }
}

extension SF2LibAUTests: @preconcurrency AVAudioPlayerDelegate {

  func loadSF2(index: Int, preset: Int) throws {
    let paths = getSF2Resources()
    print(paths)
    try au.allocateRenderResources()
    let path = paths[index].standardizedFileURL.absoluteString
    XCTAssertTrue(au.sendLoadFileUsePreset(path: path, preset: preset))
    XCTAssertEqual(0, doRender(for: 1))
  }

  func sendMIDI(cmd: Data) -> Bool {
    if let block = au.scheduleMIDIEventBlock {
      return cmd.withUnsafeBytes { ptr in
        if let bytes = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) {
          let now: AUEventSampleTime = .min
          let cable: UInt8 = 0
          let byteCount: Int = cmd.count
          block(now, cable, byteCount, bytes)
          return true
        }
        return false
      }
    }
    return false
  }

  func sendMIDI(bytes: [UInt8]) -> Bool {
    if let block = au.scheduleMIDIEventBlock {
      let now: AUEventSampleTime = .min
      let cable: UInt8 = 0
      block(now, cable, bytes.count, bytes)
      return true
    }
    return false
  }

  func sendMIDI(cmds: [Data]) -> Bool {
    for cmd in cmds {
      guard sendMIDI(cmd: cmd) else { return false }
    }
    return true
  }

  func prepareToRender(index: Int, preset: Int, recording: Bool = false, block: () -> Void) throws {
    try au.allocateRenderResources()
    try loadSF2(index: index, preset: preset)
    if (recording) {
      self.audioFile = try makeAudioFile()
    }
    block()
    if (recording) {
      try playSamples()
    }
  }

  func doRender(for frameCount: AVAudioFrameCount) -> AUAudioUnitStatus {
    precondition(frameCount <= framesRemaining)
    let renderBlock = au.renderBlock
    var flags: UInt32 = 0
    var when: AudioTimeStamp = .init()
    let status = renderBlock(&flags, &when, frameCount, 0, stereoBuffer.mutableAudioBufferList, nil)
    if status == noErr {
      stereoBuffer.frameLength = frameCount
      if let audioFile = self.audioFile {
        try? audioFile.write(from: stereoBuffer)
      }
      framesRemaining -= frameCount
    }
    return status
  }

  func doRender(fraction: Float) -> AUAudioUnitStatus {
    let frameCount: AVAudioFrameCount = .init(Float(framesRemaining) * fraction)
    return doRender(for: frameCount)
  }

  func doRender() -> AUAudioUnitStatus { doRender(for: self.framesRemaining) }

  func playSamples() throws {
    guard let audioFile = self.audioFile else {
      XCTFail("not configured to record samples")
      return
    }

    playedAudioExpectation = self.expectation(description: "played samples")
    let player = try AVAudioPlayer(contentsOf: audioFile.url)
    player.delegate = self
    player.play()
    self.player = player
    self.waitForExpectations(timeout: 30.0) { err in
      if let err = err {
        XCTFail("Expectation Failed with error: \(err)");
      }
    }
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    self.playedAudioExpectation?.fulfill()
  }

  var pathForTemporaryFile: String {
    let uuid = UUID()
    let result = NSTemporaryDirectory().appending("/" + uuid.uuidString + ".caf")
    return result;
  }

  func makeAudioFile() throws -> AVAudioFile {
    let path = URL(fileURLWithPath: pathForTemporaryFile)
    var settings = stereoBuffer.format.settings
    settings["AVLinearPCMIsNonInterleaved"] = 0
    let file = try AVAudioFile(
      forWriting: path,
      settings: settings,
      commonFormat: .pcmFormatFloat32,
      interleaved: false
    )
    return file
  }
}

extension FourCharCode: @retroactive ExpressibleByStringLiteral {

  public init(stringLiteral value: StringLiteralType) {
    var code: FourCharCode = 0
    // Value has to consist of 4 printable ASCII characters, e.g. '420v'.
    // Note: This implementation does not enforce printable range (32-126)
    if value.count == 4 && value.utf8.count == 4 {
      for byte in value.utf8 {
        code = code << 8 + FourCharCode(byte)
      }
    }
    else {
      code = 0x3F3F3F3F // = '????'
    }
    self = code
  }

  public init(_ value: String) {
    self = FourCharCode(stringLiteral: value)
  }
}

extension AVAudioFormat: @retroactive @unchecked Sendable {}
