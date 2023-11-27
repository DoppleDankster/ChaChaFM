//
//  ContentView.swift
//  ChaChaFM
//
//  Created by David MEDIONI on 24.11.2023.
//

import SwiftUI
import AVFoundation


struct ContentView: View {
    @State private var isPlaying = true
    @State private var volume: Int = 20
    @StateObject private var audioPlayer = AudioPlayer()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Image(getBackgroundImageForSeason())
                .resizable()
                .edgesIgnoringSafeArea(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/)
            VStack {
                Spacer()
                Button(action: {
                    isPlaying.toggle()
                    if isPlaying{
                        playAudioForCurrentHour()
                    }else{
                        audioPlayer.stopPlayback()
                    }
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .resizable()
                        .frame(width: 50,height: 50)
                    }
                }
            }
        .onAppear {
            playAudioForCurrentHour()
        }
        .onReceive(timer) { _ in
            if isPlaying {
                playAudioForCurrentHour()
            }
        }
    }
    func playAudioForCurrentHour(){
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let filename = "\(hour)"
        audioPlayer.playAudio(fileName: filename)
    }
}


#Preview {
    ContentView()
}

enum Season {
    case spring, summer, autumn, winter
}

func currentSeason() -> Season{
    let today = Date()
    let calendar = Calendar.current
    let day = calendar.ordinality(of: .day, in: .year, for: today)!
    
    switch day{
    case 80...171: // March 20 to June 20
        return .spring
    case 172...264: //June 21 to September 22
        return .summer
    case 265...353: // September 23 to December 20
        return .autumn
    default:
        return .winter
    }
}

func getBackgroundImageForSeason() -> String{
    let season = currentSeason()
    
    switch season{
    case .spring:
        return "spring"
    case .summer:
        return "summer"
    case .autumn:
        return "autumn"
    case .winter:
        return "winter"
    }
}


class AudioPlayer: ObservableObject {
    private var player: AVAudioPlayer?
    
    init(player: AVAudioPlayer? = nil) {
        setupAudioPlayer()
        setupNotifications()
    }
    
    private func setupAudioPlayer(){
        do{
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        }catch{
            print("failed to set up audio session: \(error)")
        }
    }
    private func setupNotifications() {
            NotificationCenter.default.addObserver(self, selector: #selector(handleAudioSessionInterruption), name: AVAudioSession.interruptionNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleAudioSessionRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
        }

        @objc private func handleAudioSessionInterruption(notification: Notification) {
            guard let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                      return
            }

            if type == .began {
                player?.pause()
            } else if type == .ended {
                if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        player?.play()
                    }
                }
            }
        }
        @objc private func handleAudioSessionRouteChange(notification: Notification) {
            guard let info = notification.userInfo,
                let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                    return
            }

            switch reason {
            case .newDeviceAvailable:
                // A new device (like Bluetooth headphones) is available, continue playback
                player?.play()
            case .oldDeviceUnavailable:
                // The old device (like headphones) was unplugged, pause the playback
                if wasPlayingBeforeRouteChange {
                    player?.pause()
                }
            default:
                break
            }
        }

        private var wasPlayingBeforeRouteChange: Bool {
            player?.isPlaying ?? false
        }

    func playAudio(fileName: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "m4a", subdirectory: "kktracks") else{
            print("Audio file not found")
            return
        }
        do {
            if player == nil || player?.url != url {
                player = try AVAudioPlayer(contentsOf: url)
                player?.numberOfLoops = -1
            }
            player?.play()
        } catch {
            print("Playback failed for \(fileName): \(error)")
        }
    }
    
    func stopPlayback(){
        player?.stop()
    }
}
