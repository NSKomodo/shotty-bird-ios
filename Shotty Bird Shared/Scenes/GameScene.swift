//
//  GameScene.swift
//  Shotty Bird Shared
//
//  Copyright © 2023 Komodo Life. All rights reserved.
//

import SpriteKit

/// Defines what game mode to play.
enum GameMode {
    case slayer
    case timeAttack
    case practice
    case none
}

/// The difficulty level for practice mode.
enum Difficulty {
    case easy
    case normal
    case hard
    case none
}

/// Main game scene.
class GameScene: BaseScene {
    
    /// The game mode to play.
    private(set) var mode: GameMode
    /// Practice mode difficulty level.
    private(set) var difficulty: Difficulty
    
    /// Fixed position on the z-axis for UI elements.
    private let zPositionUIElements = CGFloat(Int.max)
    
    /// Last time update method was called.
    private(set) var lastUpdateTime: CFTimeInterval = 0.0
    /// Lat time an enemy spawned.
    private(set) var lastSpawnTime: CFTimeInterval = 0.0
    /// Last time a shot was fired.
    private(set) var lastShotFiredTime: CFTimeInterval = 0.0
    
    /// Initial amount of lives on Slayer.
    private(set) var initialLives = -1
    /// Number of lives remaining on Slayer.
    private(set) var lives = -1
    
    /// Time attack timer.
    private var timer: Timer?
    /// Time attack mode timer value.
    private(set) var timerValue = 60
    
    /// Game score.
    private(set) var score = 0
    
    /// Controls how many seconds has to pass before spawning a new enemy.
    private(set) var spawnFrequency: TimeInterval = 2.2
    
    /// Determines if a player has interacted with an ad and is elegible for a reward.
    private let didInteractWithAd: Bool
    
    /// Audio manager to play background music.
    let audioManager = AudioManager.shared
    
    /// Creates a new game scene to play.
    /// - Parameters:
    ///   - mode: The game mode.
    ///   - difficulty: Practice mode difficulty level.
    ///   - backgroundSpeed: The parallax background speed.
    ///   - didWatchdAd: Determines if player watched and ad and is elegible for a reward.
    init(mode: GameMode, difficulty: Difficulty = .easy, backgroundSpeed: BackgroundSpeed = .fast, didInteractWithAd: Bool = false) {
        self.mode = mode
        self.difficulty = difficulty
        self.didInteractWithAd = didInteractWithAd
        super.init(backgroundSpeed: backgroundSpeed)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        Task {
            if await StoreManager.shared.unlockRemoveAds() {
                initialLives = 4
                lives = 4
            } else {
                if self.didInteractWithAd {
                    initialLives = 4
                    lives = 4
                } else {
                    initialLives = 3
                    lives = 3
                }
            }
            setupUI()
        }
        
        if mode == .timeAttack {
            spawnFrequency = 0.33
            timer = Timer.scheduledTimer(timeInterval: 1.0,
                                         target: self,
                                         selector: #selector(updateTimerNode),
                                         userInfo: nil,
                                         repeats: true)
        } else if mode == .practice {
            switch difficulty {
            case .easy:
                spawnFrequency = 2.2
            case .normal:
                spawnFrequency = 1.5
            case .hard:
                spawnFrequency = 0.8
            default:
                spawnFrequency = 2.2
            }
        }
        
        let musicType: MusicType = (mode == .slayer || mode == .timeAttack) ? .gameplay : .practice
        audioManager.playMusic(type: musicType, loop: true)
    }
    
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        
        var timeSinceLast = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        if timeSinceLast > 1 {
            timeSinceLast = 1 / 60
        }
        
        lastSpawnTime += timeSinceLast
        
        if lastSpawnTime > spawnFrequency {
            spawnEnemy()
            lastSpawnTime = 0
        }
    }
    
    // MARK: - Gameplay Elements
    
    /// Spawns and animates a new enemy node.
    func spawnEnemy() {
        // Assign enemy nodes depth and scaling
        let zPosEnemy = CGFloat(arc4random_uniform(5))
        var scale: EnemyScale
        
        switch zPosEnemy {
        case 4:
            scale = .large
        case 3:
            scale = .medium
        case 2:
            scale = .small
        case 1:
            scale = .smaller
        case 0:
            scale = .smallest
        default:
            scale = .large
        }
        
        // Initialize enemy node
        let enemy = Enemy(enemyType: .raven, scale: scale)
        enemy.zPosition = zPosEnemy
        
        // Set starting point and add node
        let minY = CGFloat(180)
        let maxY = size.height - enemy.size.height / 2 - 70 * 1.5 - 5
        let randomY = CGFloat.random(in: minY...maxY)
        enemy.position = CGPoint(x: size.width + enemy.size.width / 2, y: randomY)
        addChild(enemy)
        
        // Setup enemy node Physics
        enemy.physicsBody = SKPhysicsBody(rectangleOf: enemy.size)
        enemy.physicsBody?.isDynamic = false
        enemy.physicsBody?.restitution = 1.0
        enemy.physicsBody?.collisionBitMask = PhysicsCollisionBitMask.enemy
        
        // Setup enemy speed
        let minDuration = 2.0
        let maxDuration = 5.0
        let duration = TimeInterval.random(in: minDuration...maxDuration)
        enemy.flightSpeed = duration
        
        // Configure actions
        var flappingSpeed: TimeInterval
        switch duration {
        case 2..<3:
            flappingSpeed = 1.0 / 120.0
        case 3..<4:
            flappingSpeed = 1.0 / 90.0
        case 4...5:
            flappingSpeed = 1.0 / 60.0
        default:
            flappingSpeed = 0.0
        }
        
        let playBirdSoundAction = SKAction.playSoundFileNamed("bird.wav", waitForCompletion: false)
        let flapAction = SKAction.animate(with: enemy.sprites, timePerFrame: flappingSpeed)
        let flappingSoundAction = SKAction.playSoundFileNamed("wing_flap.wav", waitForCompletion: false)
        let flyAction = SKAction.repeat(flapAction, count: Int(duration / flappingSpeed / 25))
        let moveAction = SKAction.move(to: CGPoint(x: -enemy.size.width / 2, y: enemy.position.y), duration: duration)
        let flyAndMoveAction = SKAction.group([flyAction, moveAction])
        let removeAction = SKAction.removeFromParent()
        
        let sequence = audioManager.isMuted ? SKAction.sequence([flyAndMoveAction, removeAction])
                                            : SKAction.sequence([flappingSoundAction,
                                                                 flyAndMoveAction,
                                                                 playBirdSoundAction])
        enemy.run(sequence) {
            if self.mode == .slayer {
                if enemy.position.x == -enemy.size.width / 2 {
                    self.lives -= 1
                    
                    if self.initialLives == 4 {
                        if self.lives == 3 {
                            guard let node = self.childNode(withName: "life1") as? SKSpriteNode else {
                                return
                            }
                            node.texture = SKTexture(imageNamed: "death")
                        } else if self.lives == 2 {
                            guard let node = self.childNode(withName: "life2") as? SKSpriteNode else {
                                return
                            }
                            node.texture = SKTexture(imageNamed: "death")
                        } else if self.lives == 1 {
                            guard let node = self.childNode(withName: "life3") as? SKSpriteNode else {
                                return
                            }
                            node.texture = SKTexture(imageNamed: "death")
                        } else if self.lives == 0 {
                            guard let node = self.childNode(withName: "life4") as? SKSpriteNode else {
                                return
                            }
                            node.texture = SKTexture(imageNamed: "death")
                            self.audioManager.stop()

                            let scene = GameOverScene(score: self.score, mode: .slayer)
                            let transition = SKTransition.flipVertical(withDuration: 1.0)
                            self.view?.presentScene(scene, transition: transition)
                        }
                    } else {
                        if self.lives == 2 {
                            guard let node = self.childNode(withName: "life1") as? SKSpriteNode else {
                                return
                            }
                            node.texture = SKTexture(imageNamed: "death")
                        } else if self.lives == 1 {
                            guard let node = self.childNode(withName: "life2") as? SKSpriteNode else {
                                return
                            }
                            node.texture = SKTexture(imageNamed: "death")
                        } else if self.lives == 0 {
                            guard let node = self.childNode(withName: "life3") as? SKSpriteNode else {
                                return
                            }
                            node.texture = SKTexture(imageNamed: "death")
                            self.audioManager.stop()

                            let scene = GameOverScene(score: self.score, mode: .slayer)
                            let transition = SKTransition.flipVertical(withDuration: 1.0)
                            self.view?.presentScene(scene, transition: transition)
                        }
                    }
                }
            }
        }
    }
    
    /// Shoots a missile sprite node.
    /// - Parameter location: The location where the node should appear.
    private func shootMissile(in location: CGPoint) {
        let missile = Missile(delegate: self)
        missile.position = location
        
        // Setup missile's Physics
        missile.physicsBody = SKPhysicsBody(rectangleOf: missile.size)
        missile.physicsBody?.isDynamic = false
        missile.physicsBody?.restitution = 0.0
        missile.physicsBody?.collisionBitMask = PhysicsCollisionBitMask.missile
        
        if !audioManager.isMuted {
            missile.run(SKAction.playSoundFileNamed("shot", waitForCompletion: false))
        }
        
        addChild(missile)
    }
    
    /// Toggles game's pause state.
    private func togglePause() {
        guard let pauseButton = childNode(withName: "pauseButton") as? SKSpriteNode else {
            return
        }
        if view?.isPaused == true {
            pauseButton.texture = SKTexture(imageNamed: "pause_button")
            toggleQuitButton(show: false)
            audioManager.resume()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if self.mode == .timeAttack {
                    self.timer = Timer.scheduledTimer(timeInterval: 1.0,
                                                      target: self,
                                                      selector: #selector(self.updateTimerNode),
                                                      userInfo: nil,
                                                      repeats: true)
                }
                self.view?.isPaused = false
            }
        } else {
            pauseButton.texture = SKTexture(imageNamed: "play_button_icon")
            toggleQuitButton(show: true)
            audioManager.pause()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if self.mode == .timeAttack {
                    self.timer?.invalidate()
                }
                self.view?.isPaused = true
            }
        }
    }
    
    /// Updates the Time Attack timer.
    @objc private func updateTimerNode() {
        timerValue -= 1
        
        // Update timer label with new time value
        guard let node = childNode(withName: "timer") as? AttributedLabelNode,
              let font =  UIFont(name: "Kenney-Bold", size: 35) else {
            return
        }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [.font: font,
                                                         .foregroundColor: timerValue <= 5 ? UIColor.red : UIColor.white,
                                                         .strokeColor: UIColor.black,
                                                         .strokeWidth: -10,
                                                         .paragraphStyle: paragraphStyle]
        
        let formattedString = timerValue < 10 ? "00: 0\(timerValue)"
                                              : "00: \(timerValue)"
        node.attributedString = NSAttributedString(string: formattedString, attributes: attributes)
        if timerValue <= 5 && !audioManager.isMuted {
            run(SKAction.playSoundFileNamed("beep.mp3", waitForCompletion: false))
        }
        if timerValue == 0 {
            timer?.invalidate()
            let scene = GameOverScene(score: score, mode: .timeAttack)
            let transition = SKTransition.flipVertical(withDuration: 1.0)
            self.view?.presentScene(scene, transition: transition)
        }
    }
}

// MARK: - UI configuration

extension GameScene {
    /// Creates and positions UI elements to be displayed during gameplay.
    /// - Number of lives
    /// - Score
    /// - Pause Button
    /// - Mute button
    private func setupUI() {
        switch mode {
        case .slayer:
            addLifeNodes()
        case .practice:
            addBackButton()
        case .timeAttack:
            addTimerNode()
        default:
            break
        }
        addScoreNode()
        addPauseButton()
        addMuteButton()
    }
    
    /// Adds the timer node.
    private func addTimerNode() {
        guard let font = UIFont(name: "Kenney-Bold", size: 35) else {
            return
        }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [.font: font,
                                                         .foregroundColor: UIColor.white,
                                                         .strokeColor: UIColor.black,
                                                         .strokeWidth: -10,
                                                         .paragraphStyle: paragraphStyle]
        let attributedString = NSAttributedString(string: "01:00", attributes: attributes)
        
        let timerNode = AttributedLabelNode(size: CGSize(width: 165, height: 65.0))
        timerNode.attributedString = attributedString
        var position: CGPoint = .zero
        if DeviceModel.iPad || DeviceModel.iPadPro {
            position = CGPoint(x: CGRectGetMinX(frame) + timerNode.size.width / 2 + 20, y: CGRectGetMaxY(frame) - timerNode.size.height / 2 - 10)
        } else if DeviceModel.iPhoneSE {
            position = CGPoint(x: CGRectGetMinX(frame) + timerNode.size.width / 2 + 20, y: CGRectGetMaxY(frame) - timerNode.size.height + 20)
        } else {
            position = CGPoint(x: CGRectGetMinX(frame) + timerNode.size.width / 2 + 20, y: CGRectGetMaxY(frame) - timerNode.size.height)
        }
        timerNode.position = position
        timerNode.name = "timer"
        timerNode.zPosition = zPositionUIElements
        addChild(timerNode)
    }
    
    /// Adds back button node.
    private func addBackButton() {
        let backButton = SKSpriteNode(imageNamed: "back_button")
        var y: CGFloat = 0.0
        if DeviceModel.iPad || DeviceModel.iPadPro {
            y = CGRectGetMaxY(frame) - backButton.size.height + 20
        } else if DeviceModel.iPhoneSE {
            y = CGRectGetMaxY(frame) - backButton.size.height + 20
        } else {
            y = CGRectGetMaxY(frame) - backButton.size.height
        }
        backButton.position = CGPoint(x: CGRectGetMinX(frame) + backButton.size.width / 2 + 20, y: y)
        backButton.name = "backButton"
        backButton.zPosition = zPositionUIElements
        addChild(backButton)
    }
    
    /// Handles the back button tap event.
    /// - Parameter location: A point where the screen is tapped.
    private func handleBackButton(in location: CGPoint) -> Bool {
        guard let backButton = childNode(withName: "backButton") as? SKSpriteNode else {
            return false
        }
        if backButton.contains(location) {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                  let rootViewController = appDelegate.window?.rootViewController else {
                return false
            }
            if view?.isPaused == false {
                togglePause()
            }
            let alert = UIAlertController(title: "Shotty Bird", message: Constants.quitAlert, preferredStyle: .alert)
            let noAction = UIAlertAction(title: "No", style: .cancel) { _ in
                alert.dismiss(animated: true)
            }
            let yesAction = UIAlertAction(title: "Yes", style: .destructive) { _ in
                alert.dismiss(animated: true)
                self.togglePause()
                if !self.audioManager.isMuted {
                    backButton.run(SKAction.playSoundFileNamed("explosion", waitForCompletion: false))
                }
                let mainMenuScene = GameModeScene()
                let transition = SKTransition.doorsCloseHorizontal(withDuration: 1.0)
                self.view?.presentScene(mainMenuScene, transition: transition)
                self.audioManager.playMusic(type: .menu, loop: true)
            }
            alert.addAction(noAction)
            alert.addAction(yesAction)
            rootViewController.present(alert, animated: true)
            return true
        }
        return false
    }
    
    /// Adds life nodes.
    private func addLifeNodes() {
        let lifeNode1 = SKSpriteNode(imageNamed: "life")
        var y: CGFloat = 0.0
        if DeviceModel.iPad || DeviceModel.iPadPro {
            y = CGRectGetMaxY(frame) - lifeNode1.size.height + 20
        } else if DeviceModel.iPhoneSE {
            y = CGRectGetMaxY(frame) - lifeNode1.size.height + 20
        } else {
            y = CGRectGetMaxY(frame) - lifeNode1.size.height
        }
        lifeNode1.position = CGPoint(x: CGRectGetMinX(frame) + lifeNode1.size.width / 2 + 20, y: y)
        lifeNode1.name = "life1"
        lifeNode1.zPosition = zPositionUIElements
        addChild(lifeNode1)
        
        let lifeNode2 = SKSpriteNode(imageNamed: "life")
        lifeNode2.position = CGPoint(x: CGRectGetMinX(frame) + lifeNode2.size.width * 2 - 10, y: y)
        lifeNode2.name = "life2"
        lifeNode2.zPosition = zPositionUIElements
        addChild(lifeNode2)
        
        let lifeNode3 = SKSpriteNode(imageNamed: "life")
        lifeNode3.position = CGPoint(x: CGRectGetMinX(frame) + lifeNode3.size.width * 3 - 5, y: y)
        lifeNode3.name = "life3"
        lifeNode3.zPosition = zPositionUIElements
        addChild(lifeNode3)
        
        if lives == 4 {
            let lifeNode4 = SKSpriteNode(imageNamed: "life")
            lifeNode4.position = CGPoint(x: CGRectGetMinX(frame) + lifeNode4.size.width * 4 - 2.5, y: y)
            lifeNode4.name = "life4"
            lifeNode4.zPosition = zPositionUIElements
            addChild(lifeNode4)
        }
    }
    
    /// Adds the score node.
    private func addScoreNode() {
        guard let font = UIFont(name: "Kenney-Bold", size: 35) else {
            return
        }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [.font: font,
                                                         .foregroundColor: UIColor.white,
                                                         .strokeColor: UIColor.black,
                                                         .strokeWidth: -10,
                                                         .paragraphStyle: paragraphStyle]
        let attributedString = NSAttributedString(string: "x0", attributes: attributes)
        
        let scoreNode = AttributedLabelNode(size: CGSize(width: 165.0, height: 65.0))
        scoreNode.attributedString = attributedString
        var position: CGPoint = .zero
        if DeviceModel.iPad || DeviceModel.iPadPro {
            position = CGPoint(x: CGRectGetMaxX(frame) - scoreNode.size.width / 2 - 10, y: CGRectGetMaxY(frame) - scoreNode.size.height / 2 - 10)
        } else if DeviceModel.iPhoneSE {
            position = CGPoint(x: CGRectGetMaxX(frame) - scoreNode.size.width / 2 - 10, y: CGRectGetMaxY(frame) - scoreNode.size.height + 20)
        } else {
            position = CGPoint(x: CGRectGetMaxX(frame) - scoreNode.size.width / 2 - 10, y: CGRectGetMaxY(frame) - scoreNode.size.height)
        }
        scoreNode.position = position
        scoreNode.name = "score"
        scoreNode.zPosition = zPositionUIElements
        addChild(scoreNode)
    }
    
    /// Adds the pause button node.
    private func addPauseButton() {
        let pauseButton = SKSpriteNode(imageNamed: "pause_button")
        var position: CGPoint = .zero
        if DeviceModel.iPad || DeviceModel.iPadPro {
            position = CGPoint(x: CGRectGetMinX(frame) + pauseButton.size.width - 20, y: CGRectGetMinY(frame) + pauseButton.size.height - 20)
        } else if DeviceModel.iPhoneSE {
            position = CGPoint(x: CGRectGetMinX(frame) + pauseButton.size.width / 2 + 20, y: CGRectGetMinY(frame) + pauseButton.size.height - 20)
        } else {
            position = CGPoint(x: CGRectGetMinX(frame) + pauseButton.size.width, y: CGRectGetMinY(frame) + pauseButton.size.height)
        }
        pauseButton.position = position
        pauseButton.name = "pauseButton"
        pauseButton.zPosition = zPositionUIElements
        addChild(pauseButton)
    }
    
    /// Intercepts the pause button tap and processes it.
    /// - Parameter location: Tap locatiopn on screen.
    /// - Returns: Value of `true` if the pause button was tapped.
    private func handlePauseButton(in location: CGPoint) -> Bool {
        guard let pauseButton = childNode(withName: "pauseButton") as? SKSpriteNode else {
            return false
        }
        if pauseButton.contains(location) {
            togglePause()
            return true
        }
        return false
    }
    
    /// Adds the quit button that appears if paused.
    private func toggleQuitButton(show: Bool) {
        if mode == .practice {
            return
        }
        guard let pauseButton = childNode(withName: "pauseButton") else {
            return
        }
        if show {
            let backButton = SKSpriteNode(imageNamed: "back_button")
            backButton.position = CGPoint(x: pauseButton.position.x + backButton.size.width + 20, y: pauseButton.position.y)
            backButton.name = "backButton"
            backButton.zPosition = zPositionUIElements
            addChild(backButton)
        } else {
            guard let backButton = childNode(withName: "backButton") else {
                return
            }
            backButton.removeFromParent()
        }
    }
    
    /// Adds the mute button.
    private func addMuteButton() {
        let muteButton = audioManager.isMuted ? SKSpriteNode(imageNamed: "mute_button") : SKSpriteNode(imageNamed: "unmute_button")
        var position: CGPoint = .zero
        if DeviceModel.iPad || DeviceModel.iPadPro {
            position = CGPoint(x: CGRectGetMaxX(frame) - muteButton.size.width / 2 - 20, y: CGRectGetMinY(frame) + muteButton.size.height - 20)
        } else if DeviceModel.iPhoneSE {
            position = CGPoint(x: CGRectGetMaxX(frame) - muteButton.size.width / 2 - 20, y: CGRectGetMinY(frame) + muteButton.size.height - 20)
        } else {
            position = CGPoint(x: CGRectGetMaxX(frame) - muteButton.size.width / 2 - 20, y: CGRectGetMinY(frame) + muteButton.size.height + 20)
        }
        muteButton.position = position
        muteButton.name = "muteButton"
        muteButton.zPosition = zPositionUIElements
        addChild(muteButton)
    }
    
    /// Handles the mute button tap event.
    /// - Parameter location: A point where the screen is tapped.
    /// - Returns: Value of `true` if the mute button was tapped.
    private func handleMuteButton(in location: CGPoint) -> Bool {
        guard let muteButton = childNode(withName: "muteButton") as? SKSpriteNode else {
            return false
        }
        if muteButton.contains(location) {
            audioManager.isMuted.toggle()
            muteButton.texture = audioManager.isMuted ? SKTexture(imageNamed: "mute_button") : SKTexture(imageNamed: "unmute_button")
            return true
        }
        return false
    }
}

// MARK: - Touch-based event handling

extension GameScene {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            // Handle back button
            if handleBackButton(in: location) {
                return
            }
            // Handle pause button tap
            if handlePauseButton(in: location) {
                return
            }
            // Dont propagate events below this point if game is paused
            if view?.isPaused == true {
                return
            }
            // Handle mute button tap
            if handleMuteButton(in: location) {
                return
            }
            // Shoot a missile
            if lastShotFiredTime == 0.0 {
                shootMissile(in: location)
                lastShotFiredTime = CACurrentMediaTime()
            } else {
                let deltaTime = CACurrentMediaTime() - lastShotFiredTime
                if deltaTime >= spawnFrequency / 3 {
                    shootMissile(in: location)
                    lastShotFiredTime = CACurrentMediaTime()
                }
            }
        }
    }
}

// MARK: - GameScoreDelegate

extension GameScene: GameScoreDelegate {
    func updateScore(grantExtraLife: Bool) {
        score += 1
        
        if mode == .slayer {
            if score % 5 == 0 {
                audioManager.increasePlaybackRate(by: 0.05)
                if spawnFrequency >= 0.8 {
                    spawnFrequency -= 0.2
                }
            }
            
            if grantExtraLife {
                if initialLives == 4 {
                    if lives == 1 {
                        guard let node = self.childNode(withName: "life3") as? SKSpriteNode else {
                            return
                        }
                        node.texture = SKTexture(imageNamed: "life")
                        lives += 1
                    } else if lives == 2 {
                        guard let node = self.childNode(withName: "life2") as? SKSpriteNode else {
                            return
                        }
                        node.texture = SKTexture(imageNamed: "life")
                        lives += 1
                    } else if lives == 3 {
                        guard let node = self.childNode(withName: "life1") as? SKSpriteNode else {
                            return
                        }
                        node.texture = SKTexture(imageNamed: "life")
                        lives += 1
                    }
                } else {
                    if lives == 1 {
                        guard let node = self.childNode(withName: "life2") as? SKSpriteNode else {
                            return
                        }
                        node.texture = SKTexture(imageNamed: "life")
                        lives += 1
                    } else if lives == 2 {
                        guard let node = self.childNode(withName: "life1") as? SKSpriteNode else {
                            return
                        }
                        node.texture = SKTexture(imageNamed: "life")
                        lives += 1
                    }
                }
                if !audioManager.isMuted {
                    run(SKAction.playSoundFileNamed("1up.mp3", waitForCompletion: false))
                }
            }
        }
        
        // Update score label with new score
        guard let node = childNode(withName: "score") as? AttributedLabelNode,
              let font =  UIFont(name: "Kenney-Bold", size: 35) else {
            return
        }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [.font: font,
                                                         .foregroundColor: UIColor.white,
                                                         .strokeColor: UIColor.black,
                                                         .strokeWidth: -10,
                                                         .paragraphStyle: paragraphStyle]
        node.attributedString = NSAttributedString(string: "x\(score)", attributes: attributes)
    }
}

