//
//  ViewController.swift
//  AudioUnit_pitch
//
//  Created by 苏刁 on 2021/1/19.
//

import UIKit
import AudioUnit

class ViewController: UIViewController {
    
    private let chain: PitchChains = PitchChains.init()

    @IBOutlet weak var volumeLable: UILabel!
    
    //MARK:Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.setupUnits()
        
    }
    
    //MARK:Private Method
    
    private func setupUnits() {

        self.chain.delegate = self
        
    }
    
    //MARK:Actions
    
    @IBAction func startAction(_ sender: Any) {
        
        self.chain.start()
        
    }
    
    @IBAction func stopAction(_ sender: Any) {

        self.chain.stop()
    }
    
    @IBAction func pitchAction(_ sender: UISlider) {
        self.chain.setPitch(pValue: sender.value)
        
    }
    
    //MARK:Public Method

}


extension ViewController: AudioRecordDelegate {
    
    func audioRecorder(recorder: PitchChains?, didUpdate volume: Double) {
        DispatchQueue.main.async {
//            self.volumeLable.text = "音量:\(volume)"
        }
        
    }

}
