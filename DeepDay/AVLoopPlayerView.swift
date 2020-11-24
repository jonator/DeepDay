//
//  OnboardingPlayerView.swift
//  DeepDay
//
//  Created by Jon Ator on 11/24/20.
//

import SwiftUI
import AVKit

struct AVLoopPlayerView: UIViewControllerRepresentable {
    let url: URL

    private var player: AVPlayer {
        return AVPlayer(url: url)
    }
    
    class Coordinator {
        var controller: AVPlayerViewController?
        
        @objc
        func fileComplete(_ notification: NSNotification) {
            let playerItem = notification.object as! AVPlayerItem
            playerItem.seek(to: .zero, completionHandler: { _ in })
            controller?.player!.play()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()
        NotificationCenter.default.addObserver(
                coordinator,
                selector: #selector(coordinator.fileComplete),
                name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                object: nil)
        return coordinator
    }

    func updateUIViewController(_ playerController: AVPlayerViewController, context: Context) {
        context.coordinator.controller = playerController
        playerController.modalPresentationStyle = .fullScreen
        playerController.showsPlaybackControls = false
        playerController.videoGravity = .resizeAspect
        playerController.view.backgroundColor = UIColor.clear
        playerController.player = player
        playerController.player?.play()
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let pvController = AVPlayerViewController()
        return pvController
    }
}
