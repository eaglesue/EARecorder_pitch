//
//  PitchChains.swift
//  AudioUnit_pitch
//
//  Created by 苏刁 on 2021/1/27.
//

import Foundation
import AudioUnit
import AVKit

protocol AudioRecordDelegate: NSObjectProtocol {
    
    func audioRecorder(recorder: PitchChains?, didUpdate volume: Double)
}

class PitchChains: NSObject {
    
    private var process: AUGraph? = nil
    
    var ioUnit: AudioUnit? = nil
    
    var pitchUnit: AudioUnit? = nil
    
    private var bufferList: AudioBufferList = AudioBufferList.init(mNumberBuffers: 1, mBuffers: AudioBuffer.init(mNumberChannels: UInt32(AudioConst.Channels), mDataByteSize: UInt32(0 * MemoryLayout<Float32>.stride * Int(AudioConst.Channels)), mData: nil))
    
    weak var delegate: AudioRecordDelegate? = nil
    
    
    override init() {
        super.init()
        self.setupSession()
        self.setupUnits()
    }
    
    func setupSession() {
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, options: [.allowBluetooth, .allowBluetoothA2DP])
            try session.overrideOutputAudioPort(.none)
            try session.setPreferredSampleRate(Double(AudioConst.SampleRate))
            try session.setPreferredIOBufferDuration(Double(AudioConst.BufferDuration) / 1000.0)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch  {
            print(error.localizedDescription)
        }
    }
    
    private func setupUnits() {
        
        var ioDes: AudioComponentDescription = AudioComponentDescription.init(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_RemoteIO,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0)
        var status: OSStatus = noErr
        status = NewAUGraph(&process)
        if status != noErr {
            print("NewAUGraph error")
            return
        }
        
        status = AUGraphOpen(self.process!)
        if status != noErr {
            print("AUGraphOpen error")
            return
        }
        
        var ioNode: AUNode = 0
        status = AUGraphAddNode(self.process!, &ioDes, &ioNode)
        if status != noErr {
            print("AUGraphAddNode error")
            return
        }
        
        
        AUGraphNodeInfo(self.process!, ioNode, &ioDes, &ioUnit)
        
        var value: UInt32 = 1
        if AudioUnitSetProperty(self.ioUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, AudioConst.InputBus, &value, UInt32(MemoryLayout.size(ofValue: value))) != noErr {
            print("can't enable input io")
            return
        }
        
        value = 1
        if AudioUnitSetProperty(self.ioUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, AudioConst.OutputBus, &value, UInt32(MemoryLayout.size(ofValue: value))) != noErr {
            print("can't enable output io")
            return
        }
        
        var maxSlice: Int32 = 4096
//        if AudioUnitSetProperty(self.ioUnit!, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, AudioConst.OutputBus, &maxSlice, UInt32(MemoryLayout.size(ofValue: maxSlice))) != noErr {
//            print("set MaximumFramesPerSlice error")
//            return
//        }
        
        var ioFormat: AudioStreamBasicDescription = AudioStreamBasicDescription.init(
            mSampleRate: Float64(AudioConst.SampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked ,
            mBytesPerPacket:  UInt32(2 * AudioConst.Channels),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(2 * AudioConst.Channels),
            mChannelsPerFrame: UInt32(AudioConst.Channels),
            mBitsPerChannel: 16,
            mReserved: 0)
        
        //不能设置inputBus格式，否则AU初始化失败。原因未知。
//        if AudioUnitSetProperty(self.ioUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, AudioConst.InputBus, &ioFormat, UInt32(MemoryLayout.size(ofValue: ioFormat))) != noErr {
//            print("set StreamFormat error")
//            return
//        }

        if AudioUnitSetProperty(self.ioUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, AudioConst.OutputBus, &ioFormat, UInt32(MemoryLayout.size(ofValue: ioFormat))) != noErr {
            print("set StreamFormat error")
            return
        }
        
        
        //pitch node
        
        var pitchDes: AudioComponentDescription = AudioComponentDescription.init(
            componentType: kAudioUnitType_FormatConverter,
            componentSubType: kAudioUnitSubType_NewTimePitch,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0)
        
        var pitchNode: AUNode = 0
        status = AUGraphAddNode(self.process!, &pitchDes, &pitchNode)
        if status != noErr {
            print("AUGraphAddNode error")
            return
        }
        
        
        status = AUGraphNodeInfo(self.process!, pitchNode, &pitchDes, &pitchUnit)
        if status != noErr {
            print("AUGraphNodeInfo error")
            return
        }
        
        
        if AudioUnitSetProperty(self.pitchUnit!, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, AudioConst.OutputBus, &maxSlice, UInt32(MemoryLayout.size(ofValue: maxSlice))) != noErr {
            print("set MaximumFramesPerSlice error")
            return
        }
        
        var recordCallback: AURenderCallbackStruct = AURenderCallbackStruct.init(inputProc:  { (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
            
            let bridgeSelf: PitchChains = bridge(ptr: UnsafeRawPointer.init(inRefCon))
            
            var mData: UnsafeMutableRawPointer = UnsafeMutableRawPointer.allocate(byteCount: Int(inNumberFrames) * 4 * Int(AudioConst.Channels), alignment: MemoryLayout<Int32>.alignment)
            var bufferList: AudioBufferList = AudioBufferList.init(mNumberBuffers: 1, mBuffers: AudioBuffer.init(mNumberChannels: UInt32(AudioConst.Channels), mDataByteSize: UInt32(Int(inNumberFrames) * 4 * Int(AudioConst.Channels)), mData: mData))
            
            var error: OSStatus = AudioUnitRender(bridgeSelf.ioUnit!, ioActionFlags, inTimeStamp, AudioConst.OutputBus, inNumberFrames, &bufferList)
            if error == noErr {

//                let bufferData: AudioBuffer = bufferList.mBuffers
//                let rawPointer = UnsafeMutableRawPointer.allocate(byteCount: Int(bufferData.mDataByteSize), alignment: MemoryLayout<Float32>.alignment)
//
//                if let mData = bufferData.mData {
//                    rawPointer.copyMemory(from: mData, byteCount: Int(bufferData.mDataByteSize))
//                    let tempBuf = AudioBuffer.init(mNumberChannels: bufferData.mNumberChannels, mDataByteSize: bufferData.mDataByteSize, mData: rawPointer)
//                    bridgeSelf.updateVolumeValue(buffer: tempBuf)
//                }
//
//                rawPointer.deallocate()
//

            } else {

//                if error != noErr {
//                    print("error")
//                }
            }
            
            mData.deallocate()
            return noErr
        }, inputProcRefCon: UnsafeMutableRawPointer(mutating: bridge(obj: self)))
        
        //使用这种回调也可以
//        if AudioUnitSetProperty(self.ioUnit!, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, AudioConst.OutputBus, &recordCallback, UInt32(MemoryLayout.size(ofValue: recordCallback))) != noErr {
//            print("SetRenderCallback error")
//            return
//        }
        
        if AudioUnitSetProperty(self.ioUnit!, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, AudioConst.OutputBus, &recordCallback, UInt32(MemoryLayout.size(ofValue: recordCallback))) != noErr {
            print("SetRenderCallback error")
            return
        }
        
        
        //连接node
        status = AUGraphConnectNodeInput(self.process!, ioNode, 1, pitchNode, 0)
        if status != noErr {
            print("AUGraphConnectNodeInput error")
            return
        }
        
        status = AUGraphConnectNodeInput(self.process!, pitchNode, 0, ioNode, 0)
        if status != noErr {
            print("AUGraphConnectNodeInput error")
            return
        }
        
        status = AUGraphInitialize(self.process!)
        if status != noErr {
            print("AUGraphInitialize error: \(status)")
        }
    }
    

    
    private func updateVolumeValue(buffer: AudioBuffer) {
        var pcmAll: Int = 0
        
        let bufferPoint = UnsafeMutableBufferPointer<Float32>.init(buffer)
        
        let bufferArray = Array(bufferPoint)
        

        let len = bufferArray.count
        for index in 0..<len {
            let value = Int(bufferArray[index])
            pcmAll += (Int(value) * Int(value))

        }
        let mean: Int = Int(pcmAll) / Int(bufferArray.count)
        let volume: Double = 10 * log(Double(mean))

        self.delegate?.audioRecorder(recorder: nil, didUpdate: volume)
    }
    
    
    public func start() {
    
        AUGraphStart(self.process!)
    }
    
    
    
    public func stop() {
        AUGraphStop(self.process!)
    }
    
    public func setPitch(pValue: Float) {
        
        //取值范围 -2000 ~ 2000
        var value: Float32 = Float32((pValue - 0.5) * 2 * 2000)
        if AudioUnitSetParameter(self.pitchUnit!, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, AudioConst.OutputBus, AudioUnitParameterValue(value), 0) != noErr {
            print("set kNewTimePitchParam_Pitch error")
        }
    }
}

