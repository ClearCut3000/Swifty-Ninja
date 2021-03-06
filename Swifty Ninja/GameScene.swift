//
//  GameScene.swift
//  Swifty Ninja
//
//  Created by Николай Никитин on 01.02.2022.
//

import AVFoundation
import SpriteKit

class GameScene: SKScene {

//MARK: - Properties
  var gameScore: SKLabelNode!
  var gameOverLabel: SKLabelNode!
  var score = 0 {
    didSet {
      gameScore.text = "Score: \(score)"
    }
  }
  var livesImages = [SKSpriteNode]()
  var activeSliceBG: SKShapeNode!
  var activeSliceFG: SKShapeNode!
  var activeEnemies =  [SKSpriteNode]()
  var activeSlicePoints = [CGPoint]()
  var bombSoundEffect: AVAudioPlayer?
  var sequence = [SequenceType]()
  var lives = 3
  var popupTime = 0.9
  var sequencePosition = 0
  var chainDelay = 3.0
  var velocityIndex = 40
  var nextSequenceQueued = true
  var isSwooshSoundActive = false
  var isGameEnded = false

  //MARK: - Scene
  override func didMove(to view: SKView) {
    let background = SKSpriteNode(imageNamed: "sliceBackground")
    background.position = CGPoint(x: 512, y: 384)
    background.blendMode = .replace
    background.zPosition = -1
    addChild(background)

    physicsWorld.gravity = CGVector(dx: 0, dy: -6)
    physicsWorld.speed = 0.85

    createScore()
    createLives()
    createSlices()

    newGame()
  }

  override func update(_ currentTime: TimeInterval) {
    if activeEnemies.count > 0 {
      for (index,node) in activeEnemies.enumerated().reversed() {
        if node.position.y < -140 {
          node.removeAllActions()
          if node.name == "enemy" || node.name == "fastEnemy" {
            node.name = ""
            subtractLife()
            node.removeFromParent()
            activeEnemies.remove(at: index)
          } else if node.name == "bombContainer" {
            node.name = ""
            node.removeFromParent()
            activeEnemies.remove(at: index)
          }
        }
      }
    } else {
      if !nextSequenceQueued {
        DispatchQueue.main.asyncAfter(deadline: .now() + popupTime) { [weak self] in
          self?.tossEnemies()
        }
        nextSequenceQueued = true
      }
    }

    var bombCount = 0

    for node in activeEnemies {
      if node.name == "bombContainer" {
        bombCount += 1
        break
      }
    }
    if bombCount == 0 {
      bombSoundEffect?.stop()
      bombSoundEffect = nil
    }
  }

  //MARK: - Methods
  private func createScore() {
    gameScore = SKLabelNode(fontNamed: "Chalkduster")
    gameScore.horizontalAlignmentMode = .left
    gameScore.fontSize = 48
    addChild(gameScore)
    gameScore.position = CGPoint(x: 8, y: 8)
    score = 0
  }

  private func createGameOver() {
    gameOverLabel = SKLabelNode(fontNamed: "Chalkduster")
    gameOverLabel.position = CGPoint(x: 512, y: 384)
    gameOverLabel.fontSize = 48
    gameOverLabel.text = "GAME OVER"
    gameOverLabel.zPosition = 4
    addChild(gameOverLabel)

    DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
      self?.newGame()
    }
  }

  private func createLives() {
    for i in 0 ..< 3 {
      let spriteNode = SKSpriteNode(imageNamed: "sliceLife")
      spriteNode.position = CGPoint(x: CGFloat(834 + (i * 70)), y: 720)
      addChild(spriteNode)
      livesImages.append(spriteNode)
    }
  }

  private func createSlices() {
    activeSliceBG = SKShapeNode()
    activeSliceBG.zPosition = 2
    activeSliceFG = SKShapeNode()
    activeSliceFG.zPosition = 3
    activeSliceBG.strokeColor = UIColor(red: 1, green: 0.9, blue: 0, alpha: 1)
    activeSliceBG.lineWidth = 9
    activeSliceFG.strokeColor = UIColor.white
    activeSliceFG.lineWidth = 5
    addChild(activeSliceBG)
    addChild(activeSliceFG)
  }

  private func createEnemy(forceBomb: ForceBomb = .random) {
    let enemy: SKSpriteNode
    var enemyType = Int.random(in: 0...6)
    if forceBomb == .never {
      enemyType = 1
    } else if forceBomb == .always {
      enemyType = 0
    }

    if enemyType == 0 {
      enemy = SKSpriteNode()
      enemy.zPosition = 1
      enemy.name = "bombConteiner"
      let bomdImage = SKSpriteNode(imageNamed: "sliceBomb")
      bomdImage.name = "bomb"
      enemy.addChild(bomdImage)

      if bombSoundEffect != nil {
        bombSoundEffect?.stop()
        bombSoundEffect = nil
      }
      if let path = Bundle.main.url(forResource: "sliceBombFuse", withExtension: "caf") {
        if let sound = try? AVAudioPlayer(contentsOf: path) {
          bombSoundEffect = sound
          sound.play()
        }
      }
      if let emitter = SKEmitterNode(fileNamed: "sliceFuse") {
        emitter.position = CGPoint(x: 76, y: 64)
        enemy.addChild(emitter)
      }
    } else if enemyType == 6 {
      enemy = SKSpriteNode(imageNamed: "penguinEvil")
      run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
      enemy.name = "fastEnemy"
    } else {
      enemy = SKSpriteNode(imageNamed: "penguin")
      run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
      enemy.name = "enemy"
    }
    let randomPosition = CGPoint(x: Int.random(in: 64...960), y: -128)
    enemy.position = randomPosition

    let randomAngularVelocity = CGFloat.random(in: -3...3)
      let randomXVelocity: Int
      if randomPosition.x < 256 {
        randomXVelocity = Int.random(in: 8...15)
      } else if randomPosition.x < 512 {
        randomXVelocity = Int.random(in: 3...5)
      } else if randomPosition.x < 768 {
        randomXVelocity = -Int.random(in: 3...5)
      } else {
        randomXVelocity = -Int.random(in: 8...15)
      }

      let randomYVelocity = Int.random(in: 24...32)

      velocityIndex = (enemyType == 1) ? 50 : 40

      enemy.physicsBody = SKPhysicsBody(circleOfRadius: 64)
      enemy.physicsBody?.velocity = CGVector(dx: randomXVelocity * velocityIndex, dy: randomYVelocity * velocityIndex)
      enemy.physicsBody?.angularVelocity = randomAngularVelocity
      enemy.physicsBody?.collisionBitMask = 0

      addChild(enemy)
      activeEnemies.append(enemy)
  }

  private func newGame() {
    if !isUserInteractionEnabled {
      isUserInteractionEnabled = true
      gameOverLabel.removeFromParent()
    }
    isGameEnded = false
    score = 0
    lives = 3
    popupTime = 0.9
    sequencePosition = 0
    chainDelay = 3
    physicsWorld.gravity = CGVector(dx: 0, dy: -6)
    physicsWorld.speed = 0.85
    activeEnemies.removeAll(keepingCapacity: true)
    sequence.removeAll(keepingCapacity: true)
    nextSequenceQueued = true
    sequence = [.oneNoBomb, .oneNoBomb, .twoWithOneBomb, .twoWithOneBomb, .three, .one, .chain]

    livesImages.forEach { $0.texture = SKTexture(imageNamed: "sliceLife") }

    for _ in 0...1000 {
      if let nextSequence = SequenceType.allCases.randomElement() {
        sequence.append(nextSequence)
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
      self?.tossEnemies()
    }
  }

  private func subtractLife() {
    lives -= 1
    run(SKAction.playSoundFileNamed("wrong.caf", waitForCompletion: false))
    var life: SKSpriteNode
    if lives == 2 {
      life = livesImages[0]
    } else if lives == 1 {
      life = livesImages[1]
    } else {
      life = livesImages[2]
      endGame(triggeredByBomb: false)
    }
    life.texture = SKTexture(imageNamed: "sliceLifeGone")
    life.xScale = 1.3
    life.yScale = 1.3
    life.run(SKAction.scale(to: 1, duration: 0.1))
  }

  private func tossEnemies() {
    guard isGameEnded == false else { return }
    popupTime *= 0.991
    chainDelay *= 0.99
    physicsWorld.speed *= 1.02
    let sequenceType = sequence[sequencePosition]
    switch sequenceType {
    case .oneNoBomb:
      createEnemy(forceBomb: .never)
    case .one:
      createEnemy()
    case .twoWithOneBomb:
      createEnemy(forceBomb: .never)
      createEnemy(forceBomb: .always)
    case .two:
      createEnemy()
      createEnemy()
    case .three:
      createEnemy()
      createEnemy()
      createEnemy()
    case .four:
      createEnemy()
      createEnemy()
      createEnemy()
      createEnemy()
    case .chain:
      createEnemy()
      DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0)) { [weak self] in
        self?.createEnemy()
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 2)) { [weak self] in
        self?.createEnemy()
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 3)) { [weak self] in
        self?.createEnemy()
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 4)) { [weak self] in
        self?.createEnemy()
      }
    case .fastChain:
      createEnemy()
      DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0)) { [weak self] in
        self?.createEnemy()
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 2)) { [weak self] in
        self?.createEnemy()
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 3)) { [weak self] in
        self?.createEnemy()
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 4)) { [weak self] in
        self?.createEnemy()
      }
    }
    sequencePosition += 1
    nextSequenceQueued = false
  }

  private func redrawActiveSlice() {
    if activeSlicePoints.count < 2 {
      activeSliceBG.path = nil
      activeSliceFG.path = nil
      return
    }
    if activeSlicePoints.count > 12 {
      activeSlicePoints.removeFirst(activeSlicePoints.count - 12)
    }

    let path = UIBezierPath()
    path.move(to: activeSlicePoints[0])
    for i in 1 ..< activeSlicePoints.count {
      path.addLine(to: activeSlicePoints[i])
    }
    activeSliceBG.path = path.cgPath
    activeSliceFG.path = path.cgPath
  }

  private func playSwooshSound() {
    isSwooshSoundActive = true
    let randomNumber = Int.random(in: 1...3)
    let soundName = "swoosh\(randomNumber).caf"
    let swooshSound = SKAction.playSoundFileNamed(soundName, waitForCompletion: true)
    run(swooshSound) { [weak self] in
      self?.isSwooshSoundActive = false
    }
  }

  private func endGame(triggeredByBomb: Bool) {
    guard isGameEnded == false else { return }
    isGameEnded = true
    physicsWorld.speed = 0
    isUserInteractionEnabled = false
    bombSoundEffect?.stop()
    bombSoundEffect = nil
    createGameOver()

    if triggeredByBomb {
      livesImages.forEach { $0.texture = SKTexture(imageNamed: "sliceLifeGone") }
    }
  }

  //MARK: - Touch Methods
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard isGameEnded == false else { return }
    guard let touch = touches.first else { return }
    let location = touch.location(in: self)
    activeSlicePoints.append(location)
    redrawActiveSlice()
    if !isSwooshSoundActive {
      playSwooshSound()
    }
    let nodeAtPoint = nodes(at: location)
    for case let node as SKSpriteNode in nodeAtPoint {
      if node.name == "enemy" || node.name == "fastEnemy" {
        if let emitter = SKEmitterNode(fileNamed: "sliceHitEnemy") {
          emitter.position = node.position
          addChild(emitter)
        }
        if node.name == "enemy" {
          score += 1
        } else if node.name == "fastEnemy" {
          score += 10
        }
        node.name = ""
        node.physicsBody?.isDynamic = false
        let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let group = SKAction.group([scaleOut, fadeOut])
        let seq = SKAction.sequence([group, .removeFromParent()])
        node.run(seq)
        if let index = activeEnemies.firstIndex(of: node) {
          activeEnemies.remove(at: index)
        }
        run(SKAction.playSoundFileNamed("whack.caf", waitForCompletion: false))
      } else if node.name == "bomb" {
        guard let bombContainer = node.parent as? SKSpriteNode else { continue }
        if let emitter = SKEmitterNode(fileNamed: "sliceHitBomb") {
          emitter.position = bombContainer.position
          addChild(emitter)
        }
        node.name = ""
        bombContainer.physicsBody?.isDynamic = false
        let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let group = SKAction.group([scaleOut, fadeOut])
        let seq = SKAction.sequence([group, .removeFromParent()])
        bombContainer.run(seq)
        if let index = activeEnemies.firstIndex(of: bombContainer) {
          activeEnemies.remove(at: index)
        }
        run(SKAction.playSoundFileNamed("explosion.caf", waitForCompletion: false))
        endGame(triggeredByBomb: true)
      }
    }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    activeSliceBG.run(SKAction.fadeOut(withDuration: 0.25))
    activeSliceFG.run(SKAction.fadeOut(withDuration: 0.25))
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    activeSlicePoints.removeAll(keepingCapacity: true)
    let location = touch.location(in: self)
    activeSlicePoints.append(location)
    redrawActiveSlice()
    activeSliceBG.removeAllActions()
    activeSliceFG.removeAllActions()
    activeSliceBG.alpha = 1
    activeSliceFG.alpha = 1
  }
}
