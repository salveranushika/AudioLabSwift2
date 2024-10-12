//
//  BViewController.swift
//  AudioLabSwift
//
//  Created by Ayush on 10/8/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import UIKit



class BViewController: UIViewController {

    var audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    
    // Store the last frequency to detect Doppler shifts
    var lastFrequency: Float = 0.0
    
    // Create a slider to control tone frequency
    let frequencySlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 17000 // Minimum frequency
        slider.maximumValue = 20000 // Maximum frequency
        slider.value = 18000        // Default frequency
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()
    
    // Labels for the minimum, maximum, and current frequency
    let minFrequencyLabel: UILabel = {
        let label = UILabel()
        label.text = "17kHz"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
       
    let maxFrequencyLabel: UILabel = {
        let label = UILabel()
        label.text = "20kHz"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
       
    let currentFrequencyLabel: UILabel = {
        let label = UILabel()
        label.text = "18kHz"
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        return label
    }()
    
    // Two labels for FFT data
    let fftLabel1: UILabel = {
        let label = UILabel()
        label.text = "FFT Magnitude (dB)"
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        return label
    }()
        
    let fftLabel2: UILabel = {
        let label = UILabel()
        label.text = "Peak Frequency"
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        return label
    }()
    
    // Label to show gesture detection result
    let gestureLabel: UILabel = {
        let label = UILabel()
        label.text = "No gesture detected"
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = .blue
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Module B"

        // Add slider to the view
        view.addSubview(frequencySlider)
        view.addSubview(minFrequencyLabel)
        view.addSubview(maxFrequencyLabel)
        view.addSubview(currentFrequencyLabel)
        
        // Add FFT labels to the view
        view.addSubview(fftLabel1)
        view.addSubview(fftLabel2)
        view.addSubview(gestureLabel)
        
        frequencySlider.addTarget(self, action: #selector(frequencyChanged(_:)), for: .valueChanged)
        
        // Setup constraints for the slider (simple layout example)
        NSLayoutConstraint.activate([
            frequencySlider.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            frequencySlider.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            frequencySlider.widthAnchor.constraint(equalToConstant: 300),
            
            // Min frequency label constraints
            minFrequencyLabel.leadingAnchor.constraint(equalTo: frequencySlider.leadingAnchor),
            minFrequencyLabel.topAnchor.constraint(equalTo: frequencySlider.bottomAnchor, constant: 8),
                        
            // Max frequency label constraints
            maxFrequencyLabel.trailingAnchor.constraint(equalTo: frequencySlider.trailingAnchor),
            maxFrequencyLabel.topAnchor.constraint(equalTo: frequencySlider.bottomAnchor, constant: 8),
                        
            // Current frequency label constraints
            currentFrequencyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            currentFrequencyLabel.topAnchor.constraint(equalTo: frequencySlider.topAnchor, constant: -30),
            
            // FFT label 1 constraints (150 points from the top of the screen)
            fftLabel1.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            fftLabel1.topAnchor.constraint(equalTo: view.topAnchor, constant: 150),
                        
            // FFT label 2 constraints (below FFT label 1)
            fftLabel2.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            fftLabel2.topAnchor.constraint(equalTo: fftLabel1.bottomAnchor, constant: 10),
            
            // Gesture label constraints (below FFT label 2)
            gestureLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            gestureLabel.topAnchor.constraint(equalTo: fftLabel2.bottomAnchor, constant: 20)
        ])
        
        
        // Start microphone processing
        audio.startMicrophoneProcessing(withFps: 10)
        audio.startProcessingSinewaveForPlayback(withFreq: frequencySlider.value)
        audio.play()
        
        // Timer to regularly update the FFT peak information
        Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updateLabels), userInfo: nil, repeats: true)
        }
        
    
        
    // Update frequency as the slider changes
    @objc func frequencyChanged(_ sender: UISlider) {
        let frequency = sender.value
        audio.startProcessingSinewaveForPlayback(withFreq: frequency)
        
        // Update the current frequency label to show the current slider value
        currentFrequencyLabel.text = String(format: "%.2fkHz", frequency / 1000)
        
    }
    
    var frequencyHistory: [Float] = []
    let historySize = 5 // Number of samples to average

    func smoothFrequency(frequency: Float) -> Float {
        let weight: Float = 0.7 // Adjust the weight to emphasize recent data
        if frequencyHistory.isEmpty {
            frequencyHistory.append(frequency)
            return frequency
        }
        let smoothedFrequency = weight * frequency + (1 - weight) * frequencyHistory.last!
        frequencyHistory.append(smoothedFrequency)
        if frequencyHistory.count > historySize {
            frequencyHistory.removeFirst()
        }
        return smoothedFrequency
    }
    
    // Declare last update time and hysteresis threshold
    var lastUpdate: Date = Date()
    let hysteresisThreshold: Float = 3.0 // Adjust this value as needed
    
    // Update FFT labels dynamically based on audio data
    @objc func updateLabels() {
        let (peakMagnitude, peakFrequency) = self.audio.getMaxFrequencyMagnitude()
        
        DispatchQueue.main.async {
                    self.fftLabel1.text = "Peak Magnitude: \(peakMagnitude) dB"
                    self.fftLabel2.text = "Peak Frequency: \(peakFrequency) Hz"
                }
        // Check if enough time has passed since the last update
        let currentDate = Date()
        if currentDate.timeIntervalSince(lastUpdate) > 0.5 { // 500 ms debounce
           
            let smoothedFrequency = smoothFrequency(frequency: peakFrequency)
            var frequencyChange = smoothedFrequency - lastFrequency

            if abs(smoothedFrequency - peakFrequency) < hysteresisThreshold {
                // Ignore outliers that differ too much from the smoothed value
                 frequencyChange = smoothedFrequency - lastFrequency
                // Gesture detection logic
            }
                        
            // Use Float instead of Double for comparisons
            if frequencyChange > 5.0 {
                gestureLabel.text = "User is gesturing toward"
                gestureLabel.textColor = .green
            } else if frequencyChange < -5.0 {
                gestureLabel.text = "User is gesturing away"
                gestureLabel.textColor = .red
            } else if abs(frequencyChange) < hysteresisThreshold {
                gestureLabel.text = "User is not gesturing"
                gestureLabel.textColor = .blue
            }
            
            lastFrequency = smoothedFrequency
            lastUpdate = currentDate // Update last update time
        }
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
