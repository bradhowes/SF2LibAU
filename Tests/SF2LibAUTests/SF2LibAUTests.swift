import AVFAudio
import XCTest
import AUv3Support
@testable import SF2LibAU

final class SF2LibAUTests: XCTestCase {
  static let sampleRate = 48_000

  // Make the number of frames to render the same as the sample rate to render 1 second of audio samples
  let frameCount: AVAudioFrameCount = .init(sampleRate)

  let audioComponentDescription: AudioComponentDescription = .init(componentType: FourCharCode("aumu"),
                                                                   componentSubType: FourCharCode("sf2L"),
                                                                   componentManufacturer: FourCharCode("bray"),
                                                                   componentFlags: 0, componentFlagsMask: 0)
  let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(sampleRate), channels: 2, 
                             interleaved: false)!
  var stereoBufferList: UnsafeMutableAudioBufferListPointer!
  var au: SF2LibAU!

  override func setUp() async throws {
    makeBufferList()
    au = try SF2LibAU(componentDescription: self.audioComponentDescription, options: [])
    au.maximumFramesToRender = self.frameCount
  }

  override func tearDown() {
    freeBufferList()
    au = nil
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
    let renderBlock = au.renderBlock
    var flags: UInt32 = 0
    var when: AudioTimeStamp = .init()
    let status = renderBlock(&flags, &when, au.maximumFramesToRender, 0, stereoBufferList.unsafeMutablePointer, nil)
    XCTAssertEqual(0, status)
    XCTAssertEqual("", au.activePresetName)
  }

  func testCanLoadLibrary() throws {
    let paths = getResources()
    print(paths)
    try au.allocateRenderResources()
    let cmd = au.createLoadSysExec(path: paths[0].absoluteString, preset: 0)
    if let block = au.scheduleMIDIEventBlock {
      cmd.withUnsafeBytes { ptr in
        if let bytes = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) {
          let now: AUEventSampleTime = .min
          let cable: UInt8 = 0
          let byteCount: Int = cmd.count
          block(now, cable, byteCount, bytes)
        }
      }
    }

    let renderBlock = au.renderBlock
    var flags: UInt32 = 0
    var when: AudioTimeStamp = .init()
    let status = renderBlock(&flags, &when, au.maximumFramesToRender, 0, stereoBufferList.unsafeMutablePointer, nil)
    XCTAssertEqual(0, status)
    let presetName = au.activePresetName
    XCTAssertEqual("Nice Piano", presetName)
  }
}

extension SF2LibAUTests {

  func getResources() -> [URL] {
    Bundle.module.urls(forResourcesWithExtension: "sf2", subdirectory: nil) ?? []
  }

  func makeBufferList() {
    let bufferSizeBytes = MemoryLayout<Float>.size * Int(self.frameCount)
    let bufferList = AudioBufferList.allocate(maximumBuffers: 2)
    for index in 0..<bufferList.count {
      bufferList[index] = AudioBuffer(mNumberChannels: 1,
                                      mDataByteSize: UInt32(bufferSizeBytes),
                                      mData: malloc(bufferSizeBytes))
    }
    stereoBufferList = bufferList
  }

  func freeBufferList() {
    for buffer in stereoBufferList {
      free(buffer.mData)
    }
    free(stereoBufferList.unsafeMutablePointer)
    stereoBufferList = nil
  }
}
