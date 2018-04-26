//
//  TYPlayer.swift
//
//  Created by ty on 2017/9/21.
//  Copyright © 2017年 ty. All rights reserved.
//

import UIKit
import MediaPlayer
import SnapKit
import MBProgressHUD

protocol TYVideoPlayerDelegate: class {
  
  func tyPlayer(player: TYPlayer, playerStateDidChange state: TYPlayerState)
  
  func tyPlayer(player: TYPlayer, loadedTimeDidChange loadedDuration: TimeInterval, totalDuration: TimeInterval)
  
  func tyPlayer(player: TYPlayer, playTimeDidChange currentTime: TimeInterval, totalTime: TimeInterval)
  
  func tyPlayer(player: TYPlayer, playerIsPlaying playing: Bool)
}

enum TYPanDirection: Int {
  case horizontal = 0
  case vertical = 1
}

public struct TYPlayerResource {
  
  public let url: URL
  public var options: [String : Any]? //可以考虑移除
  
  var avURLAsset: AVURLAsset {
    get {
      return AVURLAsset(url: url, options: options)
    }
  }
  
  public init(url: URL , options : [String : Any]?) {
    self.url = url
    self.options = options
  }
}

//默认配置项,目前只配置是否自动播放
open class TYPlayerConfig {
  
  open static let shared = TYPlayerConfig()
  open var shouldAutoPlay = true
}

open class TYPlayer: UIView {
  
  weak var delegate: TYVideoPlayerDelegate?
    open var backBlock: ((Bool) -> Void)? {
        didSet{
            controlView.backButton.isHidden = false
        }
    }//未设置时返回按钮不显示
    
  fileprivate var panGesture: UIPanGestureRecognizer!
  var isPlaying: Bool {
    get {
      return playerLayer?.isPlaying ?? false
    }
  }
  var avPlayer: AVPlayer? {
    return playerLayer?.player
  }
  var playerLayer: TYPlayerLayerView?
  
  fileprivate var resource: TYPlayerResource!
  fileprivate var controlView: TYPlayerControlView!
  fileprivate var panDirection = TYPanDirection.horizontal
  fileprivate var volumeViewSlider: UISlider!
  fileprivate var currentDragTime: TimeInterval = 0
  fileprivate var totalDuration: TimeInterval = 0
  fileprivate var currentPosition: TimeInterval = 0
  fileprivate var shouldSeekTo: TimeInterval = 0
  fileprivate var isURLSet = false
  fileprivate var isSliderSliding = false
  fileprivate var isPauseByUser = false
  fileprivate var isVolumeChange = false
  fileprivate var isMirrored = false
  fileprivate var isPlayToTheEnd = false
  
  // MARK: - 生命周期
  deinit {
    
    playerLayer?.pause()
    playerLayer?.prepareToDeinit()
  }
  
  public init(url: URL) {
    super.init(frame:.zero)
    initUI()
    configureVolume()
    preparePlayer()
    let asset = TYPlayerResource(url: url, options: nil)
    self.setMedia(resource: asset)
  }
  
  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    initUI()
    configureVolume()
    preparePlayer()
  }
  
  // MARK: - 通过XIB加载时使用此方法设置视频URL
  public func setMedia(resource: TYPlayerResource) {
    
    isURLSet = false
    self.resource = resource
    controlView.prepareUI(for: resource)
    if TYPlayerConfig.shared.shouldAutoPlay {
      isURLSet = true
      playerLayer?.playAsset(asset: resource.avURLAsset)
    }
  }

  open func autoPlay() {
    if !isPauseByUser && isURLSet && !isPlayToTheEnd {
      play()
    }
  }

  open func play() {
    if resource == nil {
      return
    }
    if !isURLSet {
      playerLayer?.playAsset(asset: resource.avURLAsset)
      isURLSet = true
    }
    panGesture.isEnabled = true
    playerLayer?.play()
    isPauseByUser = false
  }

  open func pause(allowAutoPlay allow: Bool = false) {
    playerLayer?.pause()
    isPauseByUser = !allow
  }

  open func seek(_ to:TimeInterval, completion: (()->Void)? = nil) {
    playerLayer?.seek(to: to, completion: completion)
  }

  open func addVolume(step: Float = 0.1) {
    self.volumeViewSlider.value += step
  }

  open func reduceVolume(step: Float = 0.1) {
    self.volumeViewSlider.value -= step
  }

  open func prepareToDealloc() {
    playerLayer?.prepareToDeinit()
  }
 
  // MARK: - Action Response
  @objc fileprivate func panDirection(_ pan: UIPanGestureRecognizer) {
    
    let locationPoint = pan.location(in: self)
    let velocityPoint = pan.velocity(in: self)
    
    switch pan.state {
    case UIGestureRecognizerState.began:
      let x = fabs(velocityPoint.x)
      let y = fabs(velocityPoint.y)
      if x > y {
        self.panDirection = TYPanDirection.horizontal
        if let player = playerLayer?.player {
          let time = player.currentTime()
          self.currentDragTime = TimeInterval(time.value) / TimeInterval(time.timescale)
        }
      } else {
        self.panDirection = TYPanDirection.vertical
        if locationPoint.x > self.bounds.size.width / 2 {
          self.isVolumeChange = true
        } else {
          self.isVolumeChange = false
        }
      }
      
    case UIGestureRecognizerState.changed:
      switch self.panDirection {
      case TYPanDirection.horizontal:
        self.horizontalMoved(velocityPoint.x)
      case TYPanDirection.vertical:
        self.verticalMoved(velocityPoint.y)
      }
      
    case UIGestureRecognizerState.ended:
      switch (self.panDirection) {
      case TYPanDirection.horizontal:
        controlView.hideSeekToView()
        isSliderSliding = false
        if isPlayToTheEnd {
          isPlayToTheEnd = false
          seek(self.currentDragTime, completion: {
            self.play()
          })
        } else {
          seek(self.currentDragTime, completion: {
            self.autoPlay()
          })
        }
        self.currentDragTime = 0.0
        
    case TYPanDirection.vertical:
      self.isVolumeChange = false
    }
    default:
      break
    }
  }
  
  fileprivate func verticalMoved(_ value: CGFloat) {
    self.isVolumeChange ? (self.volumeViewSlider.value -= Float(value / 10000)) : (UIScreen.main.brightness -= value / 10000)
  }
  
  fileprivate func horizontalMoved(_ value: CGFloat) {
    
    isSliderSliding = true
    if let playerItem = playerLayer?.playerItem {
      self.currentDragTime = self.currentDragTime + TimeInterval(value) / 100.0 * (TimeInterval(self.totalDuration)/400)
      let totalTime = playerItem.duration
      if totalTime.timescale == 0 { return }
      let totalDuration = TimeInterval(totalTime.value) / TimeInterval(totalTime.timescale)
      if (self.currentDragTime >= totalDuration) { self.currentDragTime = totalDuration}
      if (self.currentDragTime <= 0){ self.currentDragTime = 0}
      controlView.showSeekToView(to: currentDragTime, total: totalDuration, isAdd: value > 0)
    }
  }

  // MARK: - 初始化
  fileprivate func initUI() {
    self.backgroundColor = UIColor.black
    controlView = TYPlayerControlView()
    addSubview(controlView)
    controlView.delegate = self
    controlView.player = self
    controlView.snp.makeConstraints { (make) in
      make.edges.equalTo(self)
    }
    panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.panDirection(_:)))
    self.addGestureRecognizer(panGesture)
  }
  
  fileprivate func configureVolume() {
    let volumeView = MPVolumeView()
    for view in volumeView.subviews {
      if let slider = view as? UISlider {
        self.volumeViewSlider = slider
      }
    }
  }
  
  fileprivate func preparePlayer() {
    playerLayer = TYPlayerLayerView()
    playerLayer!.videoGravity = AVLayerVideoGravity.resizeAspect
    insertSubview(playerLayer!, at: 0)
    playerLayer!.snp.makeConstraints { (make) in
      make.edges.equalTo(self)
    }
    playerLayer!.delegate = self
    controlView.showLoader()
    self.layoutIfNeeded()
  }
}

extension TYPlayer: TYPlayerLayerViewDelegate {
  
  public func tyPlayerLayerView(playerLayerView: TYPlayerLayerView, playerStateDidChange state: TYPlayerState) {
    controlView.playerStateDidChange(state: state)
    switch state {
    case TYPlayerState.readyToPlay:
      if !isPauseByUser {
        play()
      }
      if shouldSeekTo != 0 {
        seek(shouldSeekTo, completion: {
          if !self.isPauseByUser {
            self.play()
          } else {
            self.pause()
          }
        })
      }
      
    case TYPlayerState.bufferFinished:
      autoPlay()
      
    case TYPlayerState.playedToTheEnd:
      isPlayToTheEnd = true
      isSliderSliding = false
    default:
      break
    }
    panGesture.isEnabled = state != .playedToTheEnd
    delegate?.tyPlayer(player: self, playerStateDidChange: state)
  }
  
  public func tyPlayerLayerView(playerLayerView: TYPlayerLayerView, loadedTimeDidChange loadedDuration: TimeInterval, totalDuration: TimeInterval) {
    
    controlView.loadedTimeDidChange(loadedDuration: loadedDuration , totalDuration: totalDuration)
    delegate?.tyPlayer(player: self, loadedTimeDidChange: loadedDuration, totalDuration: totalDuration)
    controlView.totalDuration = totalDuration
    self.totalDuration = totalDuration
  }
  
  public func tyPlayerLayerView(playerLayerView: TYPlayerLayerView, playTimeDidChange currentTime: TimeInterval, totalTime: TimeInterval) {
    
    delegate?.tyPlayer(player: self, playTimeDidChange: currentTime, totalTime: totalTime)
    self.currentPosition = currentTime
    totalDuration = totalTime
    if isSliderSliding {
      return
    }
    controlView.playTimeDidChange(currentTime: currentTime, totalTime: totalTime)
    controlView.totalDuration = totalDuration
  }
  
  public func tyPlayerLayerView(playerLayerView: TYPlayerLayerView, playerIsPlaying playing: Bool) {
    
    controlView.playStateDidChange(isPlaying: playing)
    delegate?.tyPlayer(player: self, playerIsPlaying: playing)
  }
}

extension TYPlayer: TYPlayerControlViewDelegate {
  
  public func controlView(controlView: TYPlayerControlView, didPressButton button: UIButton) {
    if let action = TYPlayerControlView.ButtonType(rawValue: button.tag) {
      switch action {
      case .back:
        backBlock?(true)
        playerLayer?.prepareToDeinit()
        
      case .play:
        if button.isSelected {
          pause()
        } else {
          if isPlayToTheEnd {
            seek(0, completion: {
              self.play()
            })
            controlView.hidePlayToTheEndView()
            isPlayToTheEnd = false
          }
          play()
        }
        
      case .replay:
        isPlayToTheEnd = false
        seek(0)
        play()
        
      default:
        print("[Error] unhandled Action")
      }
    }
  }
  
  public func controlView(controlView: TYPlayerControlView, slider: UISlider, onSliderEvent event: UIControlEvents) {
    switch event {
    case UIControlEvents.touchDown:
      playerLayer?.onTimeSliderBegan()
      isSliderSliding = true
      
    case UIControlEvents.touchUpInside:
      isSliderSliding = false
      let target = self.totalDuration * Double(slider.value)
      if isPlayToTheEnd {
        isPlayToTheEnd = false
        seek(target, completion: {
          self.play()
        })
        controlView.hidePlayToTheEndView()
      } else {
        seek(target, completion: {
          self.autoPlay()
        })
      }
    default:
      break
    }
  }
}

// MARK: convert helper
extension TYPlayer {
  
  static func formatSecondsToString(_ secounds: TimeInterval) -> String {
    
    let min = Int(secounds / 60.0)
    let sec = Int(secounds.truncatingRemainder(dividingBy: 60))
    return min > 100 ? String(format: "%03d:%02d", min, sec) : String(format: "%02d:%02d", min, sec)
  }
}

// MARK: HUD
extension TYPlayer {

  
  static func showHUD(view: UIView? = nil) {
    hideHUD(for: view)
    show(view: view)
  }
  
  static func hideHUD(for view: UIView? = nil, animated: Bool = true) {
    getMainQueue {
      if let container = view {
//        MBProgressHUD.hideAllHUDs(for: container, animated: animated)
        MBProgressHUD.hide(for: container, animated: animated)
      }
      if let window = UIApplication.shared.keyWindow {
//        MBProgressHUD.hideAllHUDs(for: window, animated: animated)
        MBProgressHUD.hide(for: window, animated: animated)
      }
    }
  }
  
  private static func show(view: UIView? = nil) {
    hideHUD(for: view)
    getMainQueue {
      let container = view ?? UIApplication.shared.keyWindow!
      let hud = MBProgressHUD.showAdded(to: container, animated: true)
      hud.mode = .indeterminate
    }
  }
  
  private static func getMainQueue(_ handle: @escaping ()->Void) {
    
    if Thread.isMainThread {
      handle()
    } else {
      DispatchQueue.main.async {
        handle()
      }
    }
  }
}

