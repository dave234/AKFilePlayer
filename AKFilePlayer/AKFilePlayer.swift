//
//  AKFilePlayer.swift
//  AKFilePlayer
//
//  Created by dave on 10/5/17.
//  Copyright © 2017 AudioKit. All rights reserved.
//

import Foundation
import AudioKit



// AKTiming IS IN AUDIOKIT ALREADY, should be made public //
@objc protocol AKTiming {
    
    /// Starts playback at a specific time.
    /// - Parameter audioTime: A time in the audio render context.
    ///
    func play(at audioTime: AVAudioTime?)
    
    /// Stops playback immediately.
    func stop()
    
    /// Start playback immediately.
    func play()
    
    /// Set time in playback timeline (seconds).
    func setTime(_ time: Double)
    
    /// Timeline time at an audio time
    /// - Parameter audioTime: A time in the audio render context.
    /// - Return: Time in the timeline context (seconds).
    ///
    func time(atAudioTime audioTime: AVAudioTime?) -> Double
    
    /// Audio time at timeline time
    /// - Parameter time: Time in the timeline context (seconds).
    /// - Return: A time in the audio render context.
    ///
    func audioTime(atTime time: Double) -> AVAudioTime?
    
}


class AKFilePlayer: NSObject, AKOutput, AKTiming {
    
    public let playerNode = AVAudioPlayerNode()
    public var audioFile: AKAudioFile?
    public var looping = false {
        didSet{
            scheduled = false
        }
    }

    private var timeAtStart: Double = 0
    private let mixer = AVAudioMixerNode()
    private var scheduled = false

    var outputNode: AVAudioNode { return mixer }
    
    init(audioFile: AKAudioFile? = nil) {
        self.audioFile = audioFile
        super.init()
        playerNode.connect(to: mixer)
    }


    open func setTime(_ time: Double) {
        playerNode.stop()
        timeAtStart = time
    }
    
    /// Time in seconds at a given audio time
    ///
    /// - parameter audioTime: A time in the audio render context.
    /// - Returns: Time in seconds in the context of the player's timeline.
    ///
    open func time(atAudioTime audioTime: AVAudioTime?) -> Double {
        guard let playerTime = playerNode.playerTime(forNodeTime: audioTime ?? AVAudioTime.now()) else {
            return timeAtStart
        }
        return timeAtStart + Double(playerTime.sampleTime) / playerTime.sampleRate
    }
    
    /// Audio time for a given time.
    ///
    /// - Parameter time: Time in seconds in the context of the player's timeline.
    /// - Returns: A time in the audio render context.
    ///
    open func audioTime(atTime time: Double) -> AVAudioTime? {
        let sampleRate = playerNode.outputFormat(forBus: 0).sampleRate
        let sampleTime = (time - timeAtStart) * sampleRate
        let playerTime = AVAudioTime(sampleTime: AVAudioFramePosition(sampleTime), atRate: sampleRate)
        return playerNode.nodeTime(forPlayerTime: playerTime)
    }
    
    /// Current time of the player in seconds.
//    open var currentTime: Double {
//        get { return time(atAudioTime: nil) }
//        set { setTime(newValue) }
//    }
    open var currentTime: Double {
        get {
            guard let audioFile = audioFile, looping else {
                return time(atAudioTime: nil)
            }
            return fmod(time(atAudioTime: nil), audioFile.duration)

        }
        set {
            guard let audioFile = audioFile, looping else {
                return setTime(newValue)
            }
            setTime(fmod(newValue, audioFile.duration))
        }
    }
    
    open var duration: Double {
        return audioFile?.duration ?? 0
    }
    
    /// True is play, flase if not.
    open var isPlaying: Bool {
        return playerNode.isPlaying
    }
    
    // Offsets clips' time and duration when starting mid clip before scheduling
    private func schedule(at offset: Double) {
        self.stop()
        guard let audioFile = audioFile else { return }
        
        var scheduleNext: (() -> Void)?
        
        if looping {
            scheduleNext = {
                if self.playerNode.isPlaying {
                    self.playerNode.scheduleFile(audioFile, at: nil, completionHandler: scheduleNext)
                }
            }
        }
        
        if offset < audioFile.duration {
            
            scheduleFile(audioFile: audioFile,
                         time: 0,
                         offset: offset,
                         duration: audioFile.duration - offset,
                         completion: scheduleNext)
            
            scheduleNext?()

            
        }
        
        
        
        scheduled = true
    }
    
    // Convert into sample times, and schedules the internal player to play file.
    private func scheduleFile(audioFile: AKAudioFile,
                              time: Double,
                              offset: Double,
                              duration: Double,
                              completion: (() -> Void)?) {
        let outputSamplerate = playerNode.outputFormat(forBus: 0).sampleRate
        let offsetFrame = AVAudioFramePosition(round(offset * audioFile.processingFormat.sampleRate))
        let frameCount = AVAudioFrameCount(round(duration * audioFile.processingFormat.sampleRate))
        
        let startTime = AVAudioTime(sampleTime: AVAudioFramePosition(round(time * outputSamplerate)),
                                    atRate: outputSamplerate)
        playerNode.scheduleSegment(audioFile,
                                   startingFrame: offsetFrame,
                                   frameCount: frameCount,
                                   at: startTime,
                                   completionHandler: completion)
    }
    
    /// Prepares previously scheduled file regions or buffers for playback.
    ///
    /// - Parameter frameCount: The number of sample frames of data to be prepared before returning.
    ///
    open func prepare(withFrameCount frameCount: AVAudioFrameCount) {
        if !scheduled {
            schedule(at: currentTime)
        }
        playerNode.prepare(withFrameCount: frameCount)
    }
    
    /// Starts playback at next render cycle, AVAudioEngine must be running.
    open func play() {
        play(at: nil)
    }
    
    /// Starts playback at time
    ///
    /// - Parameter audioTime: A time in the audio render context.  If non-nil, the player's current
    /// current time will align with this time when playback starts.
    ///
    open func play(at audioTime: AVAudioTime?) {
        
        if !scheduled {
            schedule(at: currentTime)
        }
        playerNode.play(at: audioTime)
        scheduled = false
    }
    
    /// Stops playback.
    open func stop() {
        timeAtStart = time(atAudioTime: nil)
        playerNode.stop()
        scheduled = false
    }
    
    /// Volume 0.0 -> 1.0, default 1.0
    open var volume: Float {
        get { return playerNode.volume }
        set { playerNode.volume = newValue }
    }
    
    /// Left/Right balance -1.0 -> 1.0, default 0.0
    open var pan: Float {
        get { return playerNode.pan }
        set { playerNode.pan = newValue }
    }
    
}
