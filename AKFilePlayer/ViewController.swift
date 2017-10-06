//
//  ViewController.swift
//  AKFilePlayer
//
//  Created by dave on 10/5/17.
//  Copyright © 2017 AudioKit. All rights reserved.
//

import Cocoa
import AudioKit
import AudioKitUI

class ViewController: NSViewController {

    let filePlayer = AKFilePlayer(audioFile: .named("counting.mp3"))

    override func viewDidLoad() {
        super.viewDidLoad()
        
        filePlayer >>> AudioKit.mainMixer
        
        AudioKit.start()
        
        let player = filePlayer
        player.looping = true
        
        let playButton = addSubview(AKButton(title: "Play", callback: { button in
            if player.isPlaying {
                player.stop()
            } else {
                player.play()
            }
            button.title = player.isPlaying ? "Stop" : "Play"
        }))
        
        let slider = addSubview(AKSlider(property: "", callback: { slider in
            player.currentTime = player.duration * slider.value()
            playButton.title = "Play"
        }))
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            slider.value = player.currentTime / player.duration
        }
        
//        addSubview(AKButton(title: "Try the long file", callback: { button in
//            player.stop()
//
//
//
//            let buffer = player.audioFile!.pcmBuffer
//
//            var audioFile: AKAudioFile? = try! AKAudioFile()
//
//            let duration = 10.0 * 60.0
//
//            let buffers = Int(ceil(duration / player.duration))
//            for _ in 0..<buffers {
//                try? audioFile?.write(from: buffer)
//            }
//            player.audioFile = try! AKAudioFile(forReading: audioFile!.url)
//
//
//        }))
        
    }
    
    
    
    
    
    
    
    
    
    var views = [NSView]()
    
    @discardableResult func addSubview<T: NSView>(_ subView: T) -> T {
        views.append(subView)
        view.addSubview(subView)
        return subView
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        var frame = CGRect(x: 0,
                           y: 0,
                           width: view.bounds.width,
                           height: view.bounds.height / CGFloat(views.count))
        
        for view in views {
            view.frame = frame
            frame.origin.y += frame.height
        }
    }
}

extension AKAudioFile {
    static func named(_ name: String) -> AKAudioFile {
        return try! AKAudioFile(readFileName: "counting.mp3", baseDir: .resources)
    }
}

extension AudioKit {
    static var mainMixer: AVAudioMixerNode {
        return engine.mainMixerNode
    }
}
