//
//  TYPlayerLayerView.swift
//
//  Created by ty on 2017/9/21.
//  Copyright © 2017年 ty. All rights reserved.
//

import UIKit
import AVFoundation

public enum TYPlayerState {
  case notSetURL
  case readyToPlay
  case buffering
  case bufferFinished
  case playedToTheEnd
  case error
}

public protocol TYPlayerLayerViewDelegate : class {
  
  func tyPlayerLayerView(playerLayerView: TYPlayerLayerView, playerStateDidChange state: TYPlayerState)
  
  func tyPlayerLayerView(playerLayerView: TYPlayerLayerView, loadedTimeDidChange loadedDuration: TimeInterval, totalDuration: TimeInterval)
  
  func tyPlayerLayerView(playerLayerView: TYPlayerLayerView, playTimeDidChange currentTime: TimeInterval, totalTime: TimeInterval)
  
  func tyPlayerLayerView(playerLayerView: TYPlayerLayerView, playerIsPlaying playing: Bool)
}

open class TYPlayerLayerView: UIView {
  
  open weak var delegate: TYPlayerLayerViewDelegate?
  open var seekTime = 0
  fileprivate var timer: Timer?
  fileprivate var urlAsset: AVURLAsset?
  fileprivate var lastPlayerItem: AVPlayerItem?
  fileprivate var playerLayer: AVPlayerLayer?
  open var playerItem: AVPlayerItem? {
    didSet {
      onPlayerItemChange()
    }
  }

  open lazy var player: AVPlayer? = {
    if let item = self.playerItem {
      let player = AVPlayer(playerItem: item)
      return player
    }
    return nil
  }()
  
  open var videoGravity = AVLayerVideoGravity.resizeAspect {
    didSet {
      self.playerLayer?.videoGravity = videoGravity
    }
  }
  
  open var isPlaying: Bool = false {
    didSet {
      if oldValue != isPlaying {
        delegate?.tyPlayerLayerView(playerLayerView: self, playerIsPlaying: isPlaying)
      }
    }
  }

  fileprivate var state = TYPlayerState.notSetURL {
    didSet {
      if state != oldValue {
        delegate?.tyPlayerLayerView(playerLayerView: self, playerStateDidChange: state)
      }
    }
  }
  
  fileprivate var isVolume = false
  fileprivate var sliderLastValue: Float = 0
  fileprivate var playDidEnd = false
  fileprivate var isBuffering = false
  fileprivate var hasReadyToPlay = false
  fileprivate var shouldSeekTo: TimeInterval = 0
  
  // MARK: - Actions
  open func playURL(url: URL) {
    
    let asset = AVURLAsset(url: url)
    playAsset(asset: asset)
  }
  
  open func playAsset(asset: AVURLAsset) {
    
    urlAsset = asset
    onSetVideoAsset()
    play()
  }

  open func play() {
    
    if let player = player {
      player.play()
      setupTimer()
      isPlaying = true
    }
  }
  
  open func pause() {
    
    player?.pause()
    isPlaying = false
    timer?.fireDate = Date.distantFuture
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  // MARK: - layoutSubviews
  override open func layoutSubviews() {
    
    super.layoutSubviews()
    self.playerLayer?.videoGravity = AVLayerVideoGravity(rawValue: "AVLayerVideoGravityResizeAspect")
    self.playerLayer?.frame  = self.bounds
  }
  
  open func resetPlayer() {
    
    self.playDidEnd = false
    self.playerItem = nil
    self.seekTime   = 0
    self.timer?.invalidate()
    self.pause()
    self.playerLayer?.removeFromSuperlayer()
    self.player?.replaceCurrentItem(with: nil)
    player?.removeObserver(self, forKeyPath: "rate")
    self.player = nil
  }
  
  open func prepareToDeinit() {
    self.resetPlayer()
  }
  
  open func onTimeSliderBegan() {
    
    if self.player?.currentItem?.status == AVPlayerItemStatus.readyToPlay {
      self.timer?.fireDate = Date.distantFuture
    }
  }
  
  open func seek(to secounds: TimeInterval, completion:(()->Void)?) {
    
    if secounds.isNaN {
      return
    }
    setupTimer()
    if self.player?.currentItem?.status == AVPlayerItemStatus.readyToPlay {
      let draggedTime = CMTimeMake(Int64(secounds), 1)
      self.player!.seek(to: draggedTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler: { (finished) in
        completion?()
      })
    } else {
      self.shouldSeekTo = secounds
    }
  }
  
  fileprivate func onSetVideoAsset() {
    
    playDidEnd   = false
    configPlayer()
  }
  
  fileprivate func onPlayerItemChange() {
    
    if lastPlayerItem == playerItem {
      return
    }
    if let item = lastPlayerItem {
      NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item)
      item.removeObserver(self, forKeyPath: "status")
      item.removeObserver(self, forKeyPath: "loadedTimeRanges")
      item.removeObserver(self, forKeyPath: "playbackBufferEmpty")
      item.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
    }
    lastPlayerItem = playerItem
    if let item = playerItem {
      NotificationCenter.default.addObserver(self, selector: #selector(moviePlayDidEnd),name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,object: playerItem)
      item.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil)
      item.addObserver(self, forKeyPath: "loadedTimeRanges", options: NSKeyValueObservingOptions.new, context: nil)
      item.addObserver(self, forKeyPath: "playbackBufferEmpty", options: NSKeyValueObservingOptions.new, context: nil)
      item.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: NSKeyValueObservingOptions.new, context: nil)
    }
  }
  
  fileprivate func configPlayer(){
    
    player?.removeObserver(self, forKeyPath: "rate")
    playerItem = AVPlayerItem(asset: urlAsset!)
    player = AVPlayer(playerItem: playerItem!)
    player!.addObserver(self, forKeyPath: "rate", options: NSKeyValueObservingOptions.new, context: nil)
    playerLayer?.removeFromSuperlayer()
    playerLayer = AVPlayerLayer(player: player)
    playerLayer!.videoGravity = videoGravity
    layer.addSublayer(playerLayer!)
    setNeedsLayout()
    layoutIfNeeded()
  }
  
  func setupTimer() {
    
    timer?.invalidate()
    timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(playerTimerAction), userInfo: nil, repeats: true)
    timer?.fireDate = Date()
  }
  
  @objc fileprivate func playerTimerAction() {
    
    if let playerItem = playerItem {
      if playerItem.duration.timescale != 0 {
        let currentTime = CMTimeGetSeconds(self.player!.currentTime())
        let totalTime   = TimeInterval(playerItem.duration.value) / TimeInterval(playerItem.duration.timescale)
        delegate?.tyPlayerLayerView(playerLayerView: self, playTimeDidChange: currentTime, totalTime: totalTime)
      }
      updateStatus(inclodeLoading: true)
    }
  }
  
  fileprivate func updateStatus(inclodeLoading: Bool = false) {
    
    if let player = player {
      if let playerItem = playerItem, inclodeLoading {
        if playerItem.isPlaybackLikelyToKeepUp || playerItem.isPlaybackBufferFull {
          self.state = .bufferFinished
        } else {
          self.state = .buffering
        }
      }
      if player.rate == 0.0 {
        if player.error != nil {
          self.state = .error
          return
        }
        if let currentItem = player.currentItem, player.currentTime() >= currentItem.duration {
          moviePlayDidEnd()
          return
        }
      }
    }
  }
  
  // MARK: - Notification Event
  @objc fileprivate func moviePlayDidEnd() {
    if state != .playedToTheEnd {
      if let playerItem = playerItem {
        delegate?.tyPlayerLayerView(playerLayerView: self, playTimeDidChange: CMTimeGetSeconds(playerItem.duration), totalTime: CMTimeGetSeconds(playerItem.duration))
      }
      self.state = .playedToTheEnd
      self.isPlaying = false
      self.playDidEnd = true
      self.timer?.invalidate()
    }
  }
  
  // MARK: - KVO
  override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    if let item = object as? AVPlayerItem, let keyPath = keyPath {
      if item == self.playerItem {
        switch keyPath {
        case "status":
          if player?.status == AVPlayerStatus.readyToPlay {
            self.state = .buffering
            if shouldSeekTo != 0 {
              seek(to: shouldSeekTo, completion: {
                self.shouldSeekTo = 0
                self.hasReadyToPlay = true
                self.state = .readyToPlay
              })
            } else {
              self.hasReadyToPlay = true
              self.state = .readyToPlay
            }
          } else if player?.status == AVPlayerStatus.failed {
            self.state = .error
          }
          
        case "loadedTimeRanges":
          if let timeInterVal    = self.availableDuration() {
            let duration        = item.duration
            let totalDuration   = CMTimeGetSeconds(duration)
            delegate?.tyPlayerLayerView(playerLayerView: self, loadedTimeDidChange: timeInterVal, totalDuration: totalDuration)
          }
          
        case "playbackBufferEmpty":
          if self.playerItem!.isPlaybackBufferEmpty {
            self.state = .buffering
            self.bufferingSomeSecond()
          }
        case "playbackLikelyToKeepUp":
          if item.isPlaybackBufferEmpty, state != .bufferFinished && hasReadyToPlay {
            self.state = .bufferFinished
            self.playDidEnd = true
          }
        default:
          break
        }
      }
    }
    if keyPath == "rate" {
      updateStatus()
    }
  }

  fileprivate func availableDuration() -> TimeInterval? {
    if let loadedTimeRanges = player?.currentItem?.loadedTimeRanges,
      let first = loadedTimeRanges.first {
      let timeRange = first.timeRangeValue
      let startSeconds = CMTimeGetSeconds(timeRange.start)
      let durationSecound = CMTimeGetSeconds(timeRange.duration)
      let result = startSeconds + durationSecound
      return result
    }
    return nil
  }

  fileprivate func bufferingSomeSecond() {
    self.state = .buffering
    if isBuffering {
      return
    }
    isBuffering = true
    player?.pause()
    let popTime = DispatchTime.now() + Double(Int64( Double(NSEC_PER_SEC) * 1.0 )) / Double(NSEC_PER_SEC)
    DispatchQueue.main.asyncAfter(deadline: popTime) {
      self.isBuffering = false
      if let item = self.playerItem {
        if !item.isPlaybackLikelyToKeepUp {
          self.bufferingSomeSecond()
        } else {
          self.state = TYPlayerState.bufferFinished
        }
      }
    }
  }
}
