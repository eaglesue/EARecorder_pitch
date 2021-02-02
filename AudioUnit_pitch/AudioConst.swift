//
//  AudioConst.swift
//  AudioUnit_pitch
//
//  Created by 苏刁 on 2021/1/19.
//

import Foundation
import AudioUnit

struct AudioConst {
    static let SampleRate: Int = 44100
    
    static let Channels: UInt32 = 1
    
    static let InputBus: AudioUnitElement = 1
    
    static let OutputBus: AudioUnitElement = 0
    
    static let BufferDuration: Int = 1000 //在本例中，BufferDuration需要尽可能大一些，否则在输出中会出现杂音。但如果不需要输出回调函数，则不用管这个参数的大小
    
    static let mDataByteSize: Int = 4096
}
