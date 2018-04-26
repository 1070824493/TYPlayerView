//
//  ViewController.swift
//  TYPlayer
//
//  Created by ty on 2017/9/26.
//  Copyright © 2017年 ty. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
  
    @IBOutlet weak var playerViewXib: TYPlayer!
  var playerViewCode: TYPlayer!
  
    @IBAction func go2Test(_ sender: Any) {
      if playerViewCode != nil {
        playerViewCode.removeFromSuperview()
      }
    //通过纯代码加载播放视图
      let testUrl = URL(string: "http://music.163.com/song/media/outer/url?id=37095476.mp3")
      playerViewCode = TYPlayer(url: testUrl!)
      self.view.addSubview(playerViewCode)
      playerViewCode.snp.makeConstraints { (make) in
        make.left.equalToSuperview().offset(20)
        make.right.equalToSuperview().offset(-20)
        make.top.equalTo(playerViewXib.snp.bottom).offset(20)
        make.height.equalTo(150)
      }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    //通过xib加载播放视图
    let testUrl = URL(string: "http://music.163.com/song/media/outer/url?id=37095476.mp3")
    let asset = TYPlayerResource(url: testUrl!, options: nil)
    playerViewXib.setMedia(resource: asset)
    
//    playerViewXib.backBlock = { animate in
//      self.dismiss(animated: animate, completion: nil)
//    }
    
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }


}

