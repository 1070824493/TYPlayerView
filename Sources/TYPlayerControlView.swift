//
//  TYPlayerControlView.swift
//
//  Created by ty on 2017/9/21.
//  Copyright © 2017年 ty. All rights reserved.
//

import UIKit

public protocol TYPlayerControlViewDelegate: class {
  
  func controlView(controlView: TYPlayerControlView, didPressButton button: UIButton)
  
  func controlView(controlView: TYPlayerControlView, slider: UISlider, onSliderEvent event: UIControlEvents)
}

open class TYPlayerControlView: UIView {
  
  public enum ButtonType: Int {
    case play = 101
    case pause = 102
    case back = 103
    case replay = 106
  }
  weak var delegate: TYPlayerControlViewDelegate?
  weak var player: TYPlayer?
  open var resource: TYPlayerResource?
  open var isMaskShowing = true
  open var totalDuration: TimeInterval = 0
  var playerLastState: TYPlayerState = .notSetURL
  // MARK: UI Components
  fileprivate var mainMaskView = UIView()
  fileprivate var topMaskView = UIView()
  fileprivate var bottomMaskView = UIView()
  fileprivate var loadingBaseView = UIView()
  /// top views
    var backButton = UIButton(type : UIButtonType.custom)
  /// bottom view
  fileprivate var currentTimeLabel = UILabel()
  fileprivate var totalTimeLabel = UILabel()
  var timeSlider = TYPlayerSlider()
  open var progressView = UIProgressView()
  open var playButton = UIButton(type: UIButtonType.custom)
  fileprivate var seekToView = UIView()
  fileprivate var seekToViewImage = UIImageView()
  fileprivate var seekToLabel = UILabel()
  fileprivate var replayButton = UIButton(type: UIButtonType.custom)
  fileprivate var tapGesture: UITapGestureRecognizer!
  
  open func playTimeDidChange(currentTime: TimeInterval, totalTime: TimeInterval) {
    
    currentTimeLabel.text = TYPlayer.formatSecondsToString(currentTime)
    totalTimeLabel.text = TYPlayer.formatSecondsToString(totalTime)
    timeSlider.value = Float(currentTime) / Float(totalTime)
  }
  
  open func loadedTimeDidChange(loadedDuration: TimeInterval , totalDuration: TimeInterval) {
    
    progressView.setProgress(Float(loadedDuration) / Float(totalDuration), animated: true)
  }
  
  open func playerStateDidChange(state: TYPlayerState) {
    
    switch state {
    case .readyToPlay:
      hideLoader()
      
    case .buffering:
      showLoader()
      
    case .bufferFinished:
      hideLoader()
      
    case .playedToTheEnd:
      hideSeekToView()
      playButton.isSelected = false
      showPlayToTheEndView()
      controlViewAnimation(isShow: true)
    default:
      break
    }
    playerLastState = state
  }
  
  open func showSeekToView(to toSecound: TimeInterval, total totalDuration:TimeInterval, isAdd: Bool) {
    
    seekToView.isHidden = false
    seekToLabel.text = TYPlayer.formatSecondsToString(toSecound)
    let rotate = isAdd ? 0 : CGFloat(Double.pi)
    seekToViewImage.transform = CGAffineTransform(rotationAngle: rotate)
    let targetTime = TYPlayer.formatSecondsToString(toSecound)
    timeSlider.value = Float(toSecound / totalDuration)
    currentTimeLabel.text = targetTime
  }
  
  open func prepareUI(for resource: TYPlayerResource) {
    self.resource = resource
  }
  
  open func playStateDidChange(isPlaying: Bool) {
    playButton.isSelected = isPlaying
  }
  
  fileprivate func controlViewAnimation(isShow: Bool) {
    
    let alpha: CGFloat = isShow ? 1.0 : 0.0
    self.isMaskShowing = isShow
    UIApplication.shared.setStatusBarHidden(!isShow, with: .fade)
    UIView.animate(withDuration: 0.3) {
      self.topMaskView.alpha    = alpha
      self.bottomMaskView.alpha = alpha
      self.mainMaskView.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: isShow ? 0.4 : 0.0)
      if !isShow {
        self.replayButton.isHidden = true
      }
      self.layoutIfNeeded()
    }
  }
  
  open func showPlayToTheEndView() {
    replayButton.isHidden = false
  }
  
  open func hidePlayToTheEndView() {
    replayButton.isHidden = true
  }
  
  open func showLoader() {
    TYPlayer.showHUD(view: loadingBaseView)
  }
  
  open func hideLoader() {
    TYPlayer.hideHUD(for: loadingBaseView)
  }
  
  open func hideSeekToView() {
    seekToView.isHidden = true
  }
  
  @objc fileprivate func onButtonPressed(_ button: UIButton) {
    
    if let type = ButtonType(rawValue: button.tag) {
      switch type {
      case .play, .replay:
        if playerLastState == .playedToTheEnd {
          hidePlayToTheEndView()
        }
      default:
        break
      }
    }
    delegate?.controlView(controlView: self, didPressButton: button)
  }
  
  @objc fileprivate func onTapGestureTapped(_ gesture: UITapGestureRecognizer) {
    if playerLastState == .playedToTheEnd {
      return
    }
    controlViewAnimation(isShow: !isMaskShowing)
  }
  
  @objc func progressSliderTouchBegan(_ sender: UISlider)  {
    delegate?.controlView(controlView: self, slider: sender, onSliderEvent: .touchDown)
  }
  
  @objc func progressSliderValueChanged(_ sender: UISlider)  {
    
    hidePlayToTheEndView()
    let currentTime = Double(sender.value) * totalDuration
    currentTimeLabel.text = TYPlayer.formatSecondsToString(currentTime)
    delegate?.controlView(controlView: self, slider: sender, onSliderEvent: .valueChanged)
  }
  
  @objc func progressSliderTouchEnded(_ sender: UISlider)  {
    delegate?.controlView(controlView: self, slider: sender, onSliderEvent: .touchUpInside)
  }
  
  
  // MARK: - private functions
  
  @objc fileprivate func onReplyButtonPressed() {
    replayButton.isHidden = true
  }
  
  override init(frame: CGRect) {
    
    super.init(frame: frame)
    setupUIComponents()
    addSnapKitConstraint()
  }
  
  required public init?(coder aDecoder: NSCoder) {
    
    super.init(coder: aDecoder)
    setupUIComponents()
    addSnapKitConstraint()
  }
  
  func setupUIComponents() {
    
    // Main mask view
    addSubview(mainMaskView)
    mainMaskView.addSubview(topMaskView)
    mainMaskView.addSubview(bottomMaskView)
    mainMaskView.insertSubview(loadingBaseView, at: 0)
    mainMaskView.clipsToBounds = true
    mainMaskView.backgroundColor = UIColor ( red: 0.0, green: 0.0, blue: 0.0, alpha: 0.4 )
    
    // Top views
    topMaskView.addSubview(backButton)
    backButton.tag = TYPlayerControlView.ButtonType.back.rawValue
    backButton.setImage(ImageResourcePath("TYPlayer_back"), for: .normal)
    backButton.addTarget(self, action: #selector(onButtonPressed(_:)), for: .touchUpInside)
    backButton.isHidden = true
    
    // Bottom views
    bottomMaskView.addSubview(playButton)
    bottomMaskView.addSubview(currentTimeLabel)
    bottomMaskView.addSubview(totalTimeLabel)
    bottomMaskView.addSubview(progressView)
    bottomMaskView.addSubview(timeSlider)
    
    playButton.tag = TYPlayerControlView.ButtonType.play.rawValue
    playButton.setImage(ImageResourcePath("TYPlayer_play"), for: .normal)
    playButton.setImage(ImageResourcePath("TYPlayer_pause"), for: .selected)
    playButton.addTarget(self, action: #selector(onButtonPressed(_:)), for: .touchUpInside)
    
    currentTimeLabel.textColor = UIColor.white
    currentTimeLabel.font = UIFont.systemFont(ofSize: 12)
    currentTimeLabel.text = "00:00"
    currentTimeLabel.textAlignment = NSTextAlignment.center
    
    totalTimeLabel.textColor = UIColor.white
    totalTimeLabel.font = UIFont.systemFont(ofSize: 12)
    totalTimeLabel.text = "00:00"
    totalTimeLabel.textAlignment = NSTextAlignment.center
    
    timeSlider.maximumValue = 1.0
    timeSlider.minimumValue = 0.0
    timeSlider.value = 0.0
    timeSlider.setThumbImage(ImageResourcePath("TYPlayer_slider_thumb"), for: .normal)
    timeSlider.maximumTrackTintColor = .clear
    timeSlider.minimumTrackTintColor = .white
    timeSlider.addTarget(self, action: #selector(progressSliderTouchBegan(_:)),for: UIControlEvents.touchDown)
    timeSlider.addTarget(self, action: #selector(progressSliderValueChanged(_:)),for: UIControlEvents.valueChanged)
    timeSlider.addTarget(self, action: #selector(progressSliderTouchEnded(_:)),for: [UIControlEvents.touchUpInside,UIControlEvents.touchCancel, UIControlEvents.touchUpOutside])
    
    progressView.tintColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.6)
    progressView.trackTintColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.3)
    
    // View to show when slide to seek
    addSubview(seekToView)
    seekToView.addSubview(seekToViewImage)
    seekToView.addSubview(seekToLabel)
    seekToLabel.font = UIFont.systemFont(ofSize: 13)
    seekToLabel.textColor = UIColor(red: 0.9098, green: 0.9098, blue: 0.9098, alpha: 1.0 )
    seekToView.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.7 )
    seekToView.layer.cornerRadius = 4
    seekToView.layer.masksToBounds = true
    seekToView.isHidden = true
    seekToViewImage.image = ImageResourcePath("TYPlayer_seek_to_image")
    
    addSubview(replayButton)
    replayButton.isHidden = true
    replayButton.setImage(ImageResourcePath("TYPlayer_replay"), for: .normal)
    replayButton.addTarget(self, action: #selector(onButtonPressed(_:)), for: .touchUpInside)
    replayButton.tag = ButtonType.replay.rawValue
    
    tapGesture = UITapGestureRecognizer(target: self, action: #selector(onTapGestureTapped(_:)))
    addGestureRecognizer(tapGesture)
  }
  
  func addSnapKitConstraint() {
    
    mainMaskView.snp.makeConstraints { (make) in
      make.edges.equalTo(self)
    }
    
    loadingBaseView.snp.makeConstraints { (make) in
      make.edges.equalTo(mainMaskView)
    }
    
    topMaskView.snp.makeConstraints { (make) in
      make.top.left.right.equalTo(mainMaskView)
      make.height.equalTo(65)
    }
    
    bottomMaskView.snp.makeConstraints { (make) in
      make.bottom.left.right.equalTo(mainMaskView)
      make.height.equalTo(50)
    }
    
    // Top views
    backButton.snp.makeConstraints { (make) in
      make.width.height.equalTo(50)
      make.left.bottom.equalTo(topMaskView)
    }
    
    // Bottom views
    playButton.snp.makeConstraints { (make) in
      make.width.equalTo(50)
      make.height.equalTo(50)
      make.left.bottom.equalTo(bottomMaskView)
    }
    
    currentTimeLabel.snp.makeConstraints { (make) in
      make.left.equalTo(playButton.snp.right)
      make.centerY.equalTo(playButton)
      make.width.equalTo(45)
    }
    
    timeSlider.snp.makeConstraints { (make) in
      make.centerY.equalTo(currentTimeLabel)
      make.left.equalTo(currentTimeLabel.snp.right).offset(5).priority(750)
      make.height.equalTo(30)
    }
    
    progressView.snp.makeConstraints { (make) in
      make.centerY.left.right.equalTo(timeSlider)
      make.height.equalTo(2)
    }
    
    totalTimeLabel.snp.makeConstraints { (make) in
      make.centerY.equalTo(currentTimeLabel)
      make.left.equalTo(timeSlider.snp.right).offset(5)
      make.width.equalTo(45)
      make.right.equalTo(bottomMaskView).offset(-10)
    }
    
    // View to show when slide to seek
    seekToView.snp.makeConstraints { (make) in
      make.center.equalTo(self.snp.center)
      make.width.equalTo(100)
      make.height.equalTo(40)
    }
    
    seekToViewImage.snp.makeConstraints { (make) in
      make.left.equalTo(seekToView.snp.left).offset(15)
      make.centerY.equalTo(seekToView.snp.centerY)
      make.height.equalTo(15)
      make.width.equalTo(25)
    }
    
    seekToLabel.snp.makeConstraints { (make) in
      make.left.equalTo(seekToViewImage.snp.right).offset(10)
      make.centerY.equalTo(seekToView.snp.centerY)
    }
    
    replayButton.snp.makeConstraints { (make) in
      make.centerX.equalTo(mainMaskView.snp.centerX)
      make.centerY.equalTo(mainMaskView.snp.centerY)
      make.width.height.equalTo(50)
    }
  }
}

//MARK: imageHelper
extension TYPlayerControlView {
  fileprivate func ImageResourcePath(_ fileName: String) -> UIImage? {
    let bundle = Bundle(for: TYPlayer.self)
    let image  = UIImage(named: fileName, in: bundle, compatibleWith: nil)
    return image
  }
}

