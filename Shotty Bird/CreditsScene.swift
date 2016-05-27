//
//  CreditsScene.swift
//  Shotty Bird
//
//  Created by Jorge Tapia on 5/18/16.
//  Copyright © 2016 Prof Apps. All rights reserved.
//

import SpriteKit

class CreditsScene: SKScene {
    
    var bgLayers = [String]()
    var parallaxBackground: ParallaxBackground?
    
    let zPositionMenuItems = CGFloat(Int.max)
    var muted = false
    
    let playBirdSoundAction = SKAction.playSoundFileNamed("bird.wav", waitForCompletion: false)
    
    override func didMoveToView(view: SKView) {
        // Add parallax background
        addParallaxBackground()
        
        // Add Jorge's node
        let itsProf = SKSpriteNode(imageNamed: "itsprof")
        itsProf.name = "itsprof"
        itsProf.setScale(0.75)
        itsProf.position = CGPoint(x: CGRectGetMidX(frame), y: CGRectGetMidY(frame) + itsProf.size.height / 2 + 20)
        itsProf.zPosition = zPositionMenuItems
        addChild(itsProf)
        
        // Add JP's node
        let jpalbuja = SKSpriteNode(imageNamed: "jpalbuja")
        jpalbuja.name = "jpalbuja"
        jpalbuja.setScale(0.75)
        jpalbuja.position = CGPoint(x: CGRectGetMidX(frame), y: CGRectGetMidY(frame) - jpalbuja.size.height / 2 - 20)
        jpalbuja.zPosition = zPositionMenuItems
        addChild(jpalbuja)
        
        // Add back button
        let backButton = SKSpriteNode(imageNamed: "back_button")
        backButton.name = "backButton"
        
        if DeviceModel.iPhone4 {
            backButton.position = CGPoint(x: CGRectGetMinX(frame) + backButton.size.width / 2 + 20, y: CGRectGetMinY(frame) + backButton.size.height + 20)
        } else if DeviceModel.iPad || DeviceModel.iPadPro {
            backButton.position = CGPoint(x: CGRectGetMinX(frame) + backButton.size.width / 2 + 20, y: CGRectGetMinY(frame) + backButton.size.height - 20)
        } else {
            backButton.position = CGPoint(x: CGRectGetMinX(frame) + backButton.size.width / 2 + 20, y: CGRectGetMinY(frame) + backButton.size.height * 2)
        }
        
        backButton.zPosition = zPositionMenuItems
        addChild(backButton)
    }
    
    override func update(currentTime: NSTimeInterval) {
        parallaxBackground?.update()
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            let location = touch.locationInNode(self)
            
            if let backButton = childNodeWithName("backButton") {
                if backButton.containsPoint(location) {
                    if !muted {
                        backButton.runAction(playBirdSoundAction)
                    }
                    
                    let mainMenuScene = getMainMenuScene()
                    mainMenuScene.muted = muted
                    
                    let transition = SKTransition.crossFadeWithDuration(0.5)
                    view?.presentScene(mainMenuScene, transition: transition)
                }
            }
            
            if let itsProf = childNodeWithName("itsprof") {
                if itsProf.containsPoint(location) {
                    if let tweetbotURL = NSURL(string: "tweetbot://shottybird/user_profile/itsProf") {
                        if UIApplication.sharedApplication().canOpenURL(tweetbotURL) {
                            UIApplication.sharedApplication().openURL(tweetbotURL)
                        } else if let twitterURL = NSURL(string: "twitter://user?screen_name=itsProf") {
                            if UIApplication.sharedApplication().canOpenURL(twitterURL) {
                                UIApplication.sharedApplication().openURL(twitterURL)
                            } else {
                                if let twitterWebURL = NSURL(string: "http://twitter.com/itsProf") {
                                    UIApplication.sharedApplication().openURL(twitterWebURL)
                                }
                            }
                        }
                    }
                }
            }
            
            if let jpalbuja = childNodeWithName("jpalbuja") {
                if jpalbuja.containsPoint(location) {
                    if let tweetbotURL = NSURL(string: "tweetbot://shottybird/user_profile/jpalbuja") {
                        if UIApplication.sharedApplication().canOpenURL(tweetbotURL) {
                            UIApplication.sharedApplication().openURL(tweetbotURL)
                        } else if let twitterURL = NSURL(string: "twitter://user?screen_name=jpalbuja") {
                            if UIApplication.sharedApplication().canOpenURL(twitterURL) {
                                UIApplication.sharedApplication().openURL(twitterURL)
                            } else {
                                if let twitterWebURL = NSURL(string: "http://twitter.com/jpalbuja") {
                                    UIApplication.sharedApplication().openURL(twitterWebURL)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - User interface methods
    
    private func addParallaxBackground() {
        parallaxBackground = ParallaxBackground(texture: nil, color: UIColor.clearColor(), size: size)
        parallaxBackground?.setUpBackgrounds(bgLayers, size: size, fastestSpeed: 2.0, speedDecrease: 0.6)
        addChild(parallaxBackground!)
    }
    
    private func getMainMenuScene() -> MainMenuScene {
        // This is the "default" scene frame size provided by SpriteKit: print(scene.size)
        let scene = MainMenuScene(size: CGSize(width: 1024.0, height: 768.0))
        scene.scaleMode = .AspectFill
        
        return scene
    }
}
