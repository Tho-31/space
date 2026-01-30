import Cocoa
import SpriteKit
import AVFoundation
import AudioToolbox

// MARK: - Sound Manager
class SoundManager {
    static let shared = SoundManager()

    private var audioEngine: AVAudioEngine
    private var playerNodes: [AVAudioPlayerNode] = []
    private var playerAvailable: [Bool] = []
    private var outputFormat: AVAudioFormat?
    private var currentIndex = 0

    init() {
        audioEngine = AVAudioEngine()

        // Get the output format from the mixer
        outputFormat = audioEngine.mainMixerNode.outputFormat(forBus: 0)

        // Create multiple player nodes for concurrent sounds
        for _ in 0..<16 {
            let playerNode = AVAudioPlayerNode()
            audioEngine.attach(playerNode)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: outputFormat)
            playerNodes.append(playerNode)
            playerAvailable.append(true)
        }

        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }

    private func getAvailablePlayer() -> (AVAudioPlayerNode, Int)? {
        // Round-robin through players
        for _ in 0..<playerNodes.count {
            currentIndex = (currentIndex + 1) % playerNodes.count
            let player = playerNodes[currentIndex]
            // Stop any previous sound and reuse
            player.stop()
            return (player, currentIndex)
        }
        return nil
    }

    func playShoot() {
        playTone(frequency: 880, duration: 0.05, type: .square, volume: 0.3)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            self.playTone(frequency: 440, duration: 0.03, type: .square, volume: 0.2)
        }
    }

    func playExplosion() {
        // Layered explosion sound
        playNoise(duration: 0.15, volume: 0.4)
        playTone(frequency: 150, duration: 0.2, type: .sine, volume: 0.5, decay: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.playTone(frequency: 80, duration: 0.25, type: .sine, volume: 0.4, decay: true)
        }
    }

    func playBigExplosion() {
        // Bigger explosion for boss/bomb
        playNoise(duration: 0.4, volume: 0.6)
        playTone(frequency: 60, duration: 0.5, type: .sine, volume: 0.7, decay: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.playTone(frequency: 40, duration: 0.4, type: .sine, volume: 0.5, decay: true)
            self.playNoise(duration: 0.3, volume: 0.4)
        }
    }

    func playPowerUp() {
        // Ascending arpeggio
        let frequencies: [Double] = [523.25, 659.25, 783.99, 1046.50]
        for (i, freq) in frequencies.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                self.playTone(frequency: freq, duration: 0.15, type: .sine, volume: 0.4)
            }
        }
    }

    func playHit() {
        playTone(frequency: 200, duration: 0.1, type: .square, volume: 0.5)
        playTone(frequency: 100, duration: 0.15, type: .square, volume: 0.3)
    }

    func playGameOver() {
        // Descending sad melody
        let frequencies: [Double] = [392, 349.23, 329.63, 293.66, 261.63]
        for (i, freq) in frequencies.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                self.playTone(frequency: freq, duration: 0.4, type: .sine, volume: 0.5, decay: true)
            }
        }
    }

    func playLevelUp() {
        // Victory fanfare
        let frequencies: [Double] = [523.25, 523.25, 523.25, 523.25, 415.30, 466.16, 523.25, 466.16, 523.25]
        let durations: [Double] = [0.1, 0.1, 0.1, 0.3, 0.3, 0.3, 0.15, 0.15, 0.5]
        var time = 0.0
        for (i, freq) in frequencies.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + time) {
                self.playTone(frequency: freq, duration: durations[i], type: .sine, volume: 0.5)
            }
            time += durations[i]
        }
    }

    // Musique de fond
    private var musicTimer: Timer?
    private var musicPlaying = false
    private var beatIndex = 0

    func startBackgroundMusic() {
        guard !musicPlaying else { return }
        musicPlaying = true
        beatIndex = 0
        playMusicLoop()
    }

    func stopBackgroundMusic() {
        musicPlaying = false
        musicTimer?.invalidate()
        musicTimer = nil
    }

    private func playMusicLoop() {
        guard musicPlaying else { return }

        // Mélodie style space invaders / retro
        let bassLine: [(Double, Double)] = [
            (82.41, 0.2),  // E2
            (82.41, 0.2),
            (110.0, 0.2),  // A2
            (110.0, 0.2),
            (73.42, 0.2),  // D2
            (73.42, 0.2),
            (98.0, 0.2),   // G2
            (98.0, 0.2),
        ]

        let melody: [(Double, Double)] = [
            (329.63, 0.15), // E4
            (0, 0.05),
            (293.66, 0.15), // D4
            (0, 0.05),
            (261.63, 0.15), // C4
            (0, 0.05),
            (293.66, 0.15), // D4
            (0, 0.05),
            (329.63, 0.15), // E4
            (0, 0.05),
            (329.63, 0.15), // E4
            (0, 0.05),
            (329.63, 0.3),  // E4
            (0, 0.1),
        ]

        let bassNote = bassLine[beatIndex % bassLine.count]
        let melodyNote = melody[beatIndex % melody.count]

        // Jouer la basse
        if bassNote.0 > 0 {
            playTone(frequency: bassNote.0, duration: bassNote.1 * 0.9, type: .square, volume: 0.15, decay: true)
        }

        // Jouer la mélodie
        if melodyNote.0 > 0 {
            playTone(frequency: melodyNote.0, duration: melodyNote.1 * 0.8, type: .triangle, volume: 0.2, decay: false)
        }

        beatIndex += 1

        // Programmer le prochain beat
        let interval = max(bassNote.1, melodyNote.1)
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.playMusicLoop()
        }
    }

    enum WaveType {
        case sine, square, sawtooth, triangle
    }

    private func playTone(frequency: Double, duration: Double, type: WaveType, volume: Float, decay: Bool = false) {
        guard let (player, _) = getAvailablePlayer(),
              let format = outputFormat else { return }

        let sampleRate = format.sampleRate
        let channelCount = Int(format.channelCount)
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            var sample: Float = 0

            switch type {
            case .sine:
                sample = Float(sin(2.0 * .pi * frequency * t))
            case .square:
                sample = sin(2.0 * .pi * frequency * t) > 0 ? 1.0 : -1.0
            case .sawtooth:
                sample = Float(2.0 * (frequency * t - floor(frequency * t + 0.5)))
            case .triangle:
                sample = Float(2.0 * abs(2.0 * (frequency * t - floor(frequency * t + 0.5))) - 1.0)
            }

            // Apply decay envelope
            if decay {
                let envelope = Float(1.0 - t / duration)
                sample *= envelope * envelope
            }

            // Apply attack to avoid clicks
            let attackTime = 0.005
            if t < attackTime {
                sample *= Float(t / attackTime)
            }
            let releaseTime = 0.01
            if t > duration - releaseTime {
                sample *= Float((duration - t) / releaseTime)
            }

            sample *= volume

            // Write to all channels (stereo support)
            for ch in 0..<channelCount {
                buffer.floatChannelData![ch][i] = sample
            }
        }

        player.scheduleBuffer(buffer, completionHandler: nil)
        player.play()
    }

    private func playNoise(duration: Double, volume: Float) {
        guard let (player, _) = getAvailablePlayer(),
              let format = outputFormat else { return }

        let sampleRate = format.sampleRate
        let channelCount = Int(format.channelCount)
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        var prevSample: Float = 0

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            var sample = Float.random(in: -1...1)

            // Decay envelope
            let envelope = Float(1.0 - t / duration)
            sample *= envelope * envelope * volume

            // Low-pass filter simulation
            sample = (sample + prevSample) * 0.5
            prevSample = sample

            // Write to all channels
            for ch in 0..<channelCount {
                buffer.floatChannelData![ch][i] = sample
            }
        }

        player.scheduleBuffer(buffer, completionHandler: nil)
        player.play()
    }
}

// MARK: - Sprite Generator (Pixel Art)
class SpriteGenerator {
    static let shared = SpriteGenerator()

    // Cache des textures
    var squidTextures: [SKTexture] = []
    var crabTextures: [SKTexture] = []
    var octopusTextures: [SKTexture] = []
    var playerTexture: SKTexture?

    init() {
        generateAllSprites()
    }

    func generateAllSprites() {
        // Squid - 2 frames (8x8 pixels, scaled up)
        let squid1: [[UInt8]] = [
            [0,0,0,1,1,0,0,0],
            [0,0,1,1,1,1,0,0],
            [0,1,1,1,1,1,1,0],
            [1,1,0,1,1,0,1,1],
            [1,1,1,1,1,1,1,1],
            [0,0,1,0,0,1,0,0],
            [0,1,0,1,1,0,1,0],
            [1,0,1,0,0,1,0,1],
        ]
        let squid2: [[UInt8]] = [
            [0,0,0,1,1,0,0,0],
            [0,0,1,1,1,1,0,0],
            [0,1,1,1,1,1,1,0],
            [1,1,0,1,1,0,1,1],
            [1,1,1,1,1,1,1,1],
            [0,0,1,0,0,1,0,0],
            [0,1,0,1,1,0,1,0],
            [0,1,0,0,0,0,1,0],
        ]
        squidTextures = [
            createTexture(from: squid1, color: NSColor.red),
            createTexture(from: squid2, color: NSColor.red)
        ]

        // Crab - 2 frames (11x8 pixels)
        let crab1: [[UInt8]] = [
            [0,0,1,0,0,0,0,0,1,0,0],
            [0,0,0,1,0,0,0,1,0,0,0],
            [0,0,1,1,1,1,1,1,1,0,0],
            [0,1,1,0,1,1,1,0,1,1,0],
            [1,1,1,1,1,1,1,1,1,1,1],
            [1,0,1,1,1,1,1,1,1,0,1],
            [1,0,1,0,0,0,0,0,1,0,1],
            [0,0,0,1,1,0,1,1,0,0,0],
        ]
        let crab2: [[UInt8]] = [
            [0,0,1,0,0,0,0,0,1,0,0],
            [1,0,0,1,0,0,0,1,0,0,1],
            [1,0,1,1,1,1,1,1,1,0,1],
            [1,1,1,0,1,1,1,0,1,1,1],
            [1,1,1,1,1,1,1,1,1,1,1],
            [0,1,1,1,1,1,1,1,1,1,0],
            [0,0,1,0,0,0,0,0,1,0,0],
            [0,1,0,0,0,0,0,0,0,1,0],
        ]
        crabTextures = [
            createTexture(from: crab1, color: NSColor.cyan),
            createTexture(from: crab2, color: NSColor.cyan)
        ]

        // Octopus - 2 frames (12x8 pixels)
        let octopus1: [[UInt8]] = [
            [0,0,0,0,1,1,1,1,0,0,0,0],
            [0,1,1,1,1,1,1,1,1,1,1,0],
            [1,1,1,1,1,1,1,1,1,1,1,1],
            [1,1,1,0,0,1,1,0,0,1,1,1],
            [1,1,1,1,1,1,1,1,1,1,1,1],
            [0,0,0,1,1,0,0,1,1,0,0,0],
            [0,0,1,1,0,1,1,0,1,1,0,0],
            [1,1,0,0,0,0,0,0,0,0,1,1],
        ]
        let octopus2: [[UInt8]] = [
            [0,0,0,0,1,1,1,1,0,0,0,0],
            [0,1,1,1,1,1,1,1,1,1,1,0],
            [1,1,1,1,1,1,1,1,1,1,1,1],
            [1,1,1,0,0,1,1,0,0,1,1,1],
            [1,1,1,1,1,1,1,1,1,1,1,1],
            [0,0,1,1,1,0,0,1,1,1,0,0],
            [0,1,1,0,0,1,1,0,0,1,1,0],
            [0,0,1,1,0,0,0,0,1,1,0,0],
        ]
        octopusTextures = [
            createTexture(from: octopus1, color: NSColor.magenta),
            createTexture(from: octopus2, color: NSColor.magenta)
        ]

        // Player ship (13x8 pixels)
        let player: [[UInt8]] = [
            [0,0,0,0,0,0,1,0,0,0,0,0,0],
            [0,0,0,0,0,1,1,1,0,0,0,0,0],
            [0,0,0,0,0,1,1,1,0,0,0,0,0],
            [0,1,1,1,1,1,1,1,1,1,1,1,0],
            [1,1,1,1,1,1,1,1,1,1,1,1,1],
            [1,1,1,1,1,1,1,1,1,1,1,1,1],
            [1,1,1,1,1,1,1,1,1,1,1,1,1],
            [1,1,1,1,1,1,1,1,1,1,1,1,1],
        ]
        playerTexture = createTexture(from: player, color: NSColor.green)
    }

    func createTexture(from pixels: [[UInt8]], color: NSColor) -> SKTexture {
        let height = pixels.count
        let width = pixels[0].count
        let scale = 3 // Scale up pixels for retro look

        let scaledWidth = width * scale
        let scaledHeight = height * scale

        var pixelData = [UInt8](repeating: 0, count: scaledWidth * scaledHeight * 4)

        let r = UInt8(color.redComponent * 255)
        let g = UInt8(color.greenComponent * 255)
        let b = UInt8(color.blueComponent * 255)

        for y in 0..<height {
            for x in 0..<width {
                let pixel = pixels[y][x]
                if pixel == 1 {
                    // Scale up the pixel
                    for sy in 0..<scale {
                        for sx in 0..<scale {
                            let scaledX = x * scale + sx
                            let scaledY = y * scale + sy
                            let index = (scaledY * scaledWidth + scaledX) * 4
                            pixelData[index] = r
                            pixelData[index + 1] = g
                            pixelData[index + 2] = b
                            pixelData[index + 3] = 255
                        }
                    }
                }
            }
        }

        let data = Data(pixelData)
        let cgImage = CGImage(
            width: scaledWidth,
            height: scaledHeight,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: scaledWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: data as CFData)!,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!

        return SKTexture(cgImage: cgImage)
    }

    func getAlienTexture(row: Int, frame: Int) -> SKTexture {
        switch row {
        case 0:
            return squidTextures[frame % 2]
        case 1, 2:
            return crabTextures[frame % 2]
        default:
            return octopusTextures[frame % 2]
        }
    }
}

// MARK: - Game Constants
struct GameConfig {
    static let windowWidth: CGFloat = 800
    static let windowHeight: CGFloat = 600
    static let playerSpeed: CGFloat = 8.0
    static let bulletSpeed: CGFloat = 12.0
    static let enemyBulletSpeed: CGFloat = 6.0
    static let enemyRows = 5
    static let enemyCols = 10
    static let enemySpacing: CGFloat = 50
}

// MARK: - Physics Categories
struct PhysicsCategory {
    static let none: UInt32 = 0
    static let player: UInt32 = 0b1
    static let playerBullet: UInt32 = 0b10
    static let enemy: UInt32 = 0b100
    static let enemyBullet: UInt32 = 0b1000
    static let powerUp: UInt32 = 0b10000
    static let boss: UInt32 = 0b100000
}

// MARK: - Power-Up Types
enum PowerUpType: CaseIterable {
    case shield, rapidFire, tripleShot, extraLife, bomb

    var color: NSColor {
        switch self {
        case .shield: return .cyan
        case .rapidFire: return .yellow
        case .tripleShot: return .magenta
        case .extraLife: return .green
        case .bomb: return .red
        }
    }

    var symbol: String {
        switch self {
        case .shield: return "🛡"
        case .rapidFire: return "⚡"
        case .tripleShot: return "∴"
        case .extraLife: return "❤"
        case .bomb: return "💣"
        }
    }
}

// MARK: - Game Scene
class GameScene: SKScene, SKPhysicsContactDelegate {

    // Sound
    let sound = SoundManager.shared

    // Player
    var player: SKShapeNode!
    var playerSprite: SKSpriteNode?
    var lives = 3
    var score = 0
    var level = 1
    var highScore = UserDefaults.standard.integer(forKey: "HighScore")

    // Enemies
    var enemies: [SKNode] = []
    var enemyDirection: CGFloat = 1
    var enemySpeed: CGFloat = 1.0
    var lastEnemyMove: TimeInterval = 0
    var enemyMoveInterval: TimeInterval = 0.5

    // Boss
    var boss: SKNode?
    var bossHealth = 0
    var isBossLevel = false

    // Power-ups
    var hasShield = false
    var shieldNode: SKShapeNode?
    var hasRapidFire = false
    var hasTripleShot = false
    var rapidFireTimer: Timer?
    var tripleShotTimer: Timer?

    // Shooting
    var lastShotTime: TimeInterval = 0
    var shootInterval: TimeInterval = 0.3

    // Input
    var keysPressed: Set<UInt16> = []

    // Labels
    var scoreLabel: SKLabelNode!
    var livesLabel: SKLabelNode!
    var levelLabel: SKLabelNode!
    var highScoreLabel: SKLabelNode!
    var comboLabel: SKLabelNode!

    // Combo system
    var combo = 0
    var lastKillTime: TimeInterval = 0
    var comboTimeout: TimeInterval = 2.0

    // Game state
    var isGameOver = false
    var gamePaused = false
    var godMode = false
    var isTransitioning = false
    var panicMode = false

    // Stars background
    var stars: [SKShapeNode] = []

    override func didMove(to view: SKView) {
        backgroundColor = .black

        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        setupStars()
        setupPlayer()
        setupLabels()
        setupEnemies()

        // Start enemy shooting timer
        let enemyShootAction = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.wait(forDuration: 1.5),
                SKAction.run { [weak self] in self?.enemyShoot() }
            ])
        )
        run(enemyShootAction, withKey: "enemyShooting")

        // Démarrer la musique de fond
        sound.startBackgroundMusic()
    }

    func setupStars() {
        // Moins d'étoiles, pas d'animation pour économiser les FPS
        for _ in 0..<50 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...1.5))
            star.fillColor = .white
            star.strokeColor = .clear
            star.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            star.alpha = CGFloat.random(in: 0.4...1.0)
            star.zPosition = -1
            addChild(star)
            stars.append(star)
        }
    }

    func setupPlayer() {
        // SKShapeNode invisible pour la physique, sprite bitmap en enfant
        player = SKShapeNode(rectOf: CGSize(width: 39, height: 24))
        player.fillColor = .clear
        player.strokeColor = .clear
        player.position = CGPoint(x: size.width / 2, y: 50)
        player.name = "player"

        player.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 39, height: 24))
        player.physicsBody?.categoryBitMask = PhysicsCategory.player
        player.physicsBody?.contactTestBitMask = PhysicsCategory.enemyBullet | PhysicsCategory.enemy | PhysicsCategory.powerUp
        player.physicsBody?.collisionBitMask = PhysicsCategory.none
        player.physicsBody?.isDynamic = true

        // Sprite bitmap en enfant
        if let texture = sprites.playerTexture {
            playerSprite = SKSpriteNode(texture: texture)
            player.addChild(playerSprite!)
        }

        addChild(player)
    }

    func setupLabels() {
        scoreLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        scoreLabel.fontSize = 20
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: 80, y: size.height - 30)
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.text = "Score: 0"
        addChild(scoreLabel)

        livesLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        livesLabel.fontSize = 20
        livesLabel.fontColor = .red
        livesLabel.position = CGPoint(x: size.width - 80, y: size.height - 30)
        livesLabel.horizontalAlignmentMode = .right
        livesLabel.text = "❤❤❤"
        addChild(livesLabel)

        levelLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        levelLabel.fontSize = 20
        levelLabel.fontColor = .yellow
        levelLabel.position = CGPoint(x: size.width / 2, y: size.height - 30)
        levelLabel.text = "Level: 1"
        addChild(levelLabel)

        highScoreLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        highScoreLabel.fontSize = 16
        highScoreLabel.fontColor = .gray
        highScoreLabel.position = CGPoint(x: 80, y: size.height - 55)
        highScoreLabel.horizontalAlignmentMode = .left
        highScoreLabel.text = "High Score: \(highScore)"
        addChild(highScoreLabel)

        comboLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        comboLabel.fontSize = 24
        comboLabel.fontColor = .orange
        comboLabel.position = CGPoint(x: size.width / 2, y: size.height - 60)
        comboLabel.text = ""
        addChild(comboLabel)
    }

    func setupEnemies() {
        enemies.removeAll()

        if level % 5 == 0 {
            // Boss level
            isBossLevel = true
            spawnBoss()
        } else {
            isBossLevel = false
            let startX = (size.width - CGFloat(GameConfig.enemyCols - 1) * GameConfig.enemySpacing) / 2
            let startY = size.height - 100

            for row in 0..<GameConfig.enemyRows {
                for col in 0..<GameConfig.enemyCols {
                    let enemy = createEnemy(row: row)
                    enemy.position = CGPoint(
                        x: startX + CGFloat(col) * GameConfig.enemySpacing,
                        y: startY - CGFloat(row) * 40
                    )
                    addChild(enemy)
                    enemies.append(enemy)
                }
            }
        }

        // Adjust speed based on level
        enemyMoveInterval = max(0.1, 0.5 - Double(level) * 0.03)
        enemySpeed = 1.0 + CGFloat(level) * 0.2
    }

    // Animation frame pour les aliens (comme Space Invaders original)
    var alienAnimationFrame = 0
    let sprites = SpriteGenerator.shared

    func createEnemy(row: Int) -> SKNode {
        let texture = sprites.getAlienTexture(row: row, frame: 0)
        let enemy = SKSpriteNode(texture: texture)
        enemy.name = "enemy"
        enemy.userData = ["row": row]
        enemy.setScale(1.0)

        enemy.physicsBody = SKPhysicsBody(rectangleOf: enemy.size)
        enemy.physicsBody?.categoryBitMask = PhysicsCategory.enemy
        enemy.physicsBody?.contactTestBitMask = PhysicsCategory.playerBullet
        enemy.physicsBody?.collisionBitMask = PhysicsCategory.none
        enemy.physicsBody?.isDynamic = true

        return enemy
    }

    func updateEnemySprite(_ enemy: SKSpriteNode, row: Int, frame: Int) {
        enemy.texture = sprites.getAlienTexture(row: row, frame: frame)
    }

    func spawnBoss() {
        let bossNode = SKShapeNode()
        let path = CGMutablePath()

        // Large boss shape
        path.move(to: CGPoint(x: 0, y: 40))
        path.addLine(to: CGPoint(x: -40, y: 20))
        path.addLine(to: CGPoint(x: -60, y: 0))
        path.addLine(to: CGPoint(x: -40, y: -20))
        path.addLine(to: CGPoint(x: -20, y: -30))
        path.addLine(to: CGPoint(x: 0, y: -20))
        path.addLine(to: CGPoint(x: 20, y: -30))
        path.addLine(to: CGPoint(x: 40, y: -20))
        path.addLine(to: CGPoint(x: 60, y: 0))
        path.addLine(to: CGPoint(x: 40, y: 20))
        path.closeSubpath()

        bossNode.path = path
        bossNode.fillColor = .purple
        bossNode.strokeColor = .white
        bossNode.lineWidth = 3
        bossNode.position = CGPoint(x: size.width / 2, y: size.height - 100)
        bossNode.name = "boss"

        bossNode.physicsBody = SKPhysicsBody(polygonFrom: path)
        bossNode.physicsBody?.categoryBitMask = PhysicsCategory.boss
        bossNode.physicsBody?.contactTestBitMask = PhysicsCategory.playerBullet
        bossNode.physicsBody?.collisionBitMask = PhysicsCategory.none
        bossNode.physicsBody?.isDynamic = true

        bossHealth = 20 + level * 5
        boss = bossNode
        addChild(bossNode)

        // Boss movement
        let moveLeft = SKAction.moveBy(x: -200, y: 0, duration: 2)
        let moveRight = SKAction.moveBy(x: 200, y: 0, duration: 2)
        let moveDown = SKAction.moveBy(x: 0, y: -20, duration: 0.5)
        let sequence = SKAction.sequence([moveLeft, moveDown, moveRight, moveDown])
        bossNode.run(SKAction.repeatForever(sequence))

        // Boss shooting (moins rapide)
        let shootAction = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.wait(forDuration: 2.0),
                SKAction.run { [weak self] in self?.bossShoot() }
            ])
        )
        bossNode.run(shootAction, withKey: "bossShooting")

        // Health bar
        let healthBar = SKShapeNode(rectOf: CGSize(width: 120, height: 10))
        healthBar.fillColor = .red
        healthBar.strokeColor = .white
        healthBar.position = CGPoint(x: 0, y: 50)
        healthBar.name = "healthBar"
        bossNode.addChild(healthBar)
    }

    func bossShoot() {
        guard let boss = boss else { return }

        sound.playShoot()

        for angle in [-0.3, 0, 0.3] {
            let bullet = SKShapeNode(circleOfRadius: 6)
            bullet.fillColor = .red
            bullet.strokeColor = .orange
            bullet.glowWidth = 3
            bullet.position = CGPoint(x: boss.position.x, y: boss.position.y - 40)
            bullet.name = "enemyBullet"
            bullet.zPosition = 10

            bullet.physicsBody = SKPhysicsBody(circleOfRadius: 6)
            bullet.physicsBody?.categoryBitMask = PhysicsCategory.enemyBullet
            bullet.physicsBody?.contactTestBitMask = PhysicsCategory.player
            bullet.physicsBody?.collisionBitMask = PhysicsCategory.none
            bullet.physicsBody?.isDynamic = true
            bullet.physicsBody?.affectedByGravity = false

            addChild(bullet)

            // Use action for movement
            let dx = sin(angle) * GameConfig.enemyBulletSpeed * 1.5 * 60 * 2
            let dy = -GameConfig.enemyBulletSpeed * 1.5 * 60 * 2
            let moveAction = SKAction.moveBy(x: dx, y: dy, duration: 2.0)
            let remove = SKAction.removeFromParent()
            bullet.run(SKAction.sequence([moveAction, remove]))
        }
    }

    func shoot() {
        guard !gamePaused && !isGameOver && !isTransitioning else { return }

        let currentTime = CACurrentMediaTime()
        let interval = hasRapidFire ? shootInterval / 3 : shootInterval

        guard currentTime - lastShotTime >= interval else { return }
        lastShotTime = currentTime

        sound.playShoot()

        if hasTripleShot {
            for angle in [-0.2, 0, 0.2] {
                createBullet(angle: angle)
            }
        } else {
            createBullet(angle: 0)
        }
    }

    func createBullet(angle: CGFloat) {
        guard let playerNode = player else { return }

        let bullet = SKShapeNode(rectOf: CGSize(width: 6, height: 16), cornerRadius: 2)
        bullet.fillColor = .yellow
        bullet.strokeColor = .orange
        bullet.lineWidth = 1
        bullet.position = CGPoint(x: playerNode.position.x, y: playerNode.position.y + 35)
        bullet.name = "playerBullet"
        bullet.zPosition = 100

        bullet.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 8, height: 20))
        bullet.physicsBody?.categoryBitMask = PhysicsCategory.playerBullet
        bullet.physicsBody?.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.boss
        bullet.physicsBody?.collisionBitMask = PhysicsCategory.none
        bullet.physicsBody?.isDynamic = true
        bullet.physicsBody?.affectedByGravity = false
        bullet.physicsBody?.usesPreciseCollisionDetection = true

        addChild(bullet)

        // Simple movement vers le haut
        let moveUp = SKAction.moveBy(x: 0, y: 600, duration: 0.8)
        let remove = SKAction.removeFromParent()
        bullet.run(SKAction.sequence([moveUp, remove]))
    }

    func enemyShoot() {
        guard !enemies.isEmpty && !isBossLevel && !isTransitioning else { return }

        // Random enemy shoots
        if let shooter = enemies.randomElement() {
            let bullet = SKShapeNode(circleOfRadius: 4)
            bullet.fillColor = .red
            bullet.strokeColor = .yellow
            bullet.glowWidth = 2
            bullet.position = CGPoint(x: shooter.position.x, y: shooter.position.y - 15)
            bullet.name = "enemyBullet"
            bullet.zPosition = 10

            bullet.physicsBody = SKPhysicsBody(circleOfRadius: 4)
            bullet.physicsBody?.categoryBitMask = PhysicsCategory.enemyBullet
            bullet.physicsBody?.contactTestBitMask = PhysicsCategory.player
            bullet.physicsBody?.collisionBitMask = PhysicsCategory.none
            bullet.physicsBody?.isDynamic = true
            bullet.physicsBody?.affectedByGravity = false

            addChild(bullet)

            // Use action for movement
            let moveAction = SKAction.moveBy(x: 0, y: -GameConfig.enemyBulletSpeed * 60 * 3, duration: 3.0)
            let remove = SKAction.removeFromParent()
            bullet.run(SKAction.sequence([moveAction, remove]))
        }
    }

    func spawnPowerUp(at position: CGPoint) {
        guard Int.random(in: 0..<10) < 2 else { return } // 20% chance

        let type = PowerUpType.allCases.randomElement()!
        let powerUp = SKShapeNode(circleOfRadius: 12)
        powerUp.fillColor = type.color
        powerUp.strokeColor = .white
        powerUp.lineWidth = 2
        powerUp.glowWidth = 5
        powerUp.position = position
        powerUp.name = "powerUp"
        powerUp.userData = ["type": type]

        // Symbol
        let label = SKLabelNode(text: type.symbol)
        label.fontSize = 14
        label.verticalAlignmentMode = .center
        powerUp.addChild(label)

        powerUp.physicsBody = SKPhysicsBody(circleOfRadius: 12)
        powerUp.physicsBody?.categoryBitMask = PhysicsCategory.powerUp
        powerUp.physicsBody?.contactTestBitMask = PhysicsCategory.player
        powerUp.physicsBody?.collisionBitMask = PhysicsCategory.none
        powerUp.physicsBody?.isDynamic = true
        powerUp.physicsBody?.velocity = CGVector(dx: 0, dy: -100)

        addChild(powerUp)

        // Pulsing
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.3)
        ])
        powerUp.run(SKAction.repeatForever(pulse))

        // Remove after time
        let remove = SKAction.sequence([
            SKAction.wait(forDuration: 10),
            SKAction.removeFromParent()
        ])
        powerUp.run(remove)
    }

    func applyPowerUp(_ type: PowerUpType) {
        sound.playPowerUp()

        switch type {
        case .shield:
            activateShield()
        case .rapidFire:
            activateRapidFire()
        case .tripleShot:
            activateTripleShot()
        case .extraLife:
            lives = min(lives + 1, 5)
            updateLivesDisplay()
        case .bomb:
            activateBomb()
        }

        // Show power-up text
        let text = SKLabelNode(text: "\(type.symbol) \(type)")
        text.fontSize = 30
        text.fontColor = type.color
        text.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(text)

        let fadeOut = SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 50, duration: 1),
                SKAction.fadeOut(withDuration: 1)
            ]),
            SKAction.removeFromParent()
        ])
        text.run(fadeOut)
    }

    func activateShield() {
        if shieldNode != nil {
            shieldNode?.removeFromParent()
        }

        hasShield = true
        shieldNode = SKShapeNode(circleOfRadius: 30)
        shieldNode?.fillColor = NSColor.cyan.withAlphaComponent(0.3)
        shieldNode?.strokeColor = .cyan
        shieldNode?.lineWidth = 2
        shieldNode?.glowWidth = 5
        player.addChild(shieldNode!)

        // Shield duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.hasShield = false
            self?.shieldNode?.removeFromParent()
            self?.shieldNode = nil
        }
    }

    func activateRapidFire() {
        hasRapidFire = true
        rapidFireTimer?.invalidate()
        rapidFireTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            self?.hasRapidFire = false
        }
    }

    func activateTripleShot() {
        hasTripleShot = true
        tripleShotTimer?.invalidate()
        tripleShotTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            self?.hasTripleShot = false
        }
    }

    func activateBomb() {
        sound.playBigExplosion()

        // Screen flash
        let flash = SKShapeNode(rectOf: size)
        flash.fillColor = .white
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.zPosition = 100
        addChild(flash)

        let fadeOut = SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ])
        flash.run(fadeOut)

        // Destroy all enemies with explosions
        for enemy in enemies {
            createExplosion(at: enemy.position, big: false)
            score += 10
            enemy.removeFromParent()
        }
        enemies.removeAll()

        // Damage boss
        if boss != nil {
            bossHealth -= 10
            if bossHealth <= 0 {
                defeatBoss()
                return
            }
        }

        updateScore()

        // FIX: Check if level complete after bomb
        if enemies.isEmpty && !isBossLevel {
            levelComplete()
        }
    }

    // MARK: - Optimized Explosion Effect
    func createExplosion(at position: CGPoint, big: Bool = false) {
        let container = SKNode()
        container.position = position
        container.zPosition = 50
        addChild(container)

        let scale: CGFloat = big ? 1.5 : 1.0
        let particleCount = big ? 8 : 6

        // 1. Central flash
        let flash = SKShapeNode(circleOfRadius: 12 * scale)
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.glowWidth = 10 * scale
        container.addChild(flash)

        let flashAction = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.5, duration: 0.1),
                SKAction.fadeOut(withDuration: 0.12)
            ]),
            SKAction.removeFromParent()
        ])
        flash.run(flashAction)

        // 2. One expanding ring
        let ring = SKShapeNode(circleOfRadius: 8 * scale)
        ring.fillColor = .clear
        ring.strokeColor = .orange
        ring.lineWidth = 3
        ring.glowWidth = 3
        container.addChild(ring)

        let ringAction = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 4.0, duration: 0.25),
                SKAction.fadeOut(withDuration: 0.25)
            ]),
            SKAction.removeFromParent()
        ])
        ring.run(ringAction)

        // 3. Flying sparks (reduced)
        let colors: [NSColor] = [.orange, .yellow, .red]

        for i in 0..<particleCount {
            let angle = (CGFloat(i) / CGFloat(particleCount)) * .pi * 2
            let distance = CGFloat.random(in: 30...50) * scale

            let spark = SKShapeNode(circleOfRadius: 3 * scale)
            spark.fillColor = colors[i % colors.count]
            spark.strokeColor = .clear
            spark.glowWidth = 4
            container.addChild(spark)

            let dx = cos(angle) * distance
            let dy = sin(angle) * distance

            let sparkAction = SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: 0.25),
                    SKAction.fadeOut(withDuration: 0.25)
                ]),
                SKAction.removeFromParent()
            ])
            spark.run(sparkAction)
        }

        // Remove container after animations
        let cleanupAction = SKAction.sequence([
            SKAction.wait(forDuration: 0.4),
            SKAction.removeFromParent()
        ])
        container.run(cleanupAction)
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let nodeA = contact.bodyA.node
        let nodeB = contact.bodyB.node

        // Player bullet hits enemy
        if (nodeA?.name == "playerBullet" && nodeB?.name == "enemy") ||
           (nodeA?.name == "enemy" && nodeB?.name == "playerBullet") {
            let enemy = nodeA?.name == "enemy" ? nodeA : nodeB
            let bullet = nodeA?.name == "playerBullet" ? nodeA : nodeB

            if let enemyNode = enemy, let position = enemy?.position {
                sound.playExplosion()
                createExplosion(at: position, big: false)
                spawnPowerUp(at: position)
                enemies.removeAll { $0 === enemyNode }

                // Combo system
                let currentTime = CACurrentMediaTime()
                if currentTime - lastKillTime < comboTimeout {
                    combo += 1
                } else {
                    combo = 1
                }
                lastKillTime = currentTime

                let points = 10 * combo
                score += points
                updateScore()
                updateCombo()
            }

            enemy?.removeFromParent()
            bullet?.removeFromParent()

            // Check level complete
            if enemies.isEmpty && !isBossLevel {
                levelComplete()
            }
        }

        // Player bullet hits boss
        if (nodeA?.name == "playerBullet" && nodeB?.name == "boss") ||
           (nodeA?.name == "boss" && nodeB?.name == "playerBullet") {
            let bullet = nodeA?.name == "playerBullet" ? nodeA : nodeB
            bullet?.removeFromParent()

            // Mode dieu = boss one-shot
            if godMode {
                bossHealth = 0
            } else {
                bossHealth -= 1
            }
            sound.playHit()

            // Update health bar
            if let healthBar = boss?.childNode(withName: "healthBar") as? SKShapeNode {
                let maxHealth = CGFloat(20 + level * 5)
                let width = 120 * (CGFloat(bossHealth) / maxHealth)
                healthBar.path = CGPath(rect: CGRect(x: -60, y: -5, width: width, height: 10), transform: nil)
            }

            // Small hit effect on boss
            if let bossPos = boss?.position {
                let hitEffect = SKShapeNode(circleOfRadius: 8)
                hitEffect.fillColor = .yellow
                hitEffect.strokeColor = .clear
                hitEffect.glowWidth = 10
                hitEffect.position = CGPoint(
                    x: bossPos.x + CGFloat.random(in: -30...30),
                    y: bossPos.y + CGFloat.random(in: -20...20)
                )
                addChild(hitEffect)

                let hitAction = SKAction.sequence([
                    SKAction.group([
                        SKAction.scale(to: 2.0, duration: 0.1),
                        SKAction.fadeOut(withDuration: 0.15)
                    ]),
                    SKAction.removeFromParent()
                ])
                hitEffect.run(hitAction)
            }

            if bossHealth <= 0 {
                defeatBoss()
            }
        }

        // Enemy bullet hits player
        if (nodeA?.name == "enemyBullet" && nodeB?.name == "player") ||
           (nodeA?.name == "player" && nodeB?.name == "enemyBullet") {
            let bullet = nodeA?.name == "enemyBullet" ? nodeA : nodeB
            bullet?.removeFromParent()

            playerHit()
        }

        // Player collects power-up
        if (nodeA?.name == "powerUp" && nodeB?.name == "player") ||
           (nodeA?.name == "player" && nodeB?.name == "powerUp") {
            let powerUp = nodeA?.name == "powerUp" ? nodeA : nodeB

            if let type = powerUp?.userData?["type"] as? PowerUpType {
                applyPowerUp(type)
            }
            powerUp?.removeFromParent()
        }
    }

    func playerHit() {
        // Mode dieu = immortel
        if godMode {
            // Petit flash pour montrer qu'on a été touché mais on s'en fout
            let flash = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.5, duration: 0.05),
                SKAction.fadeAlpha(to: 1.0, duration: 0.05)
            ])
            player.run(flash)
            return
        }

        if hasShield {
            hasShield = false
            shieldNode?.removeFromParent()
            shieldNode = nil
            sound.playHit()

            // Shield break effect
            let flash = SKShapeNode(circleOfRadius: 40)
            flash.fillColor = .cyan
            flash.strokeColor = .clear
            flash.position = player.position
            flash.alpha = 0.8
            addChild(flash)

            let fadeOut = SKAction.sequence([
                SKAction.scale(to: 2, duration: 0.2),
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent()
            ])
            flash.run(fadeOut)
            return
        }

        sound.playHit()
        lives -= 1
        updateLivesDisplay()

        // Flash player
        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.2, duration: 0.1),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        ])
        player.run(SKAction.repeat(flash, count: 5))

        if lives <= 0 {
            gameOver()
        }
    }

    func defeatBoss() {
        guard let bossNode = boss else { return }
        let bossPos = bossNode.position

        sound.playBigExplosion()

        // Multiple big explosions
        for i in 0..<8 {
            let delay = Double(i) * 0.1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                let offset = CGPoint(
                    x: CGFloat.random(in: -50...50),
                    y: CGFloat.random(in: -40...40)
                )
                self?.createExplosion(at: CGPoint(
                    x: bossPos.x + offset.x,
                    y: bossPos.y + offset.y
                ), big: true)

                if i > 3 {
                    self?.sound.playExplosion()
                }
            }
        }

        score += 500 * level
        updateScore()

        bossNode.removeFromParent()
        self.boss = nil

        // Delay level complete to let explosions play
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.levelComplete()
        }
    }

    func levelComplete() {
        // Protection contre la réentrance
        guard !isTransitioning else { return }
        isTransitioning = true

        level += 1
        levelLabel.text = "Level: \(level)"

        sound.playLevelUp()

        // Créer la scènette de transition
        showLevelTransition()
    }

    func showLevelTransition() {
        // Overlay sombre
        let overlay = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        overlay.fillColor = NSColor.black.withAlphaComponent(0.8)
        overlay.strokeColor = .clear
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.zPosition = 200
        overlay.alpha = 0
        overlay.name = "transitionOverlay"
        addChild(overlay)

        // Texte "LEVEL COMPLETE"
        let completeText = SKLabelNode(text: "LEVEL COMPLETE!")
        completeText.fontSize = 40
        completeText.fontColor = .green
        completeText.position = CGPoint(x: size.width / 2, y: size.height / 2 + 100)
        completeText.zPosition = 201
        completeText.alpha = 0
        addChild(completeText)

        // Stats
        let statsText = SKLabelNode(text: "Score: \(score)")
        statsText.fontSize = 25
        statsText.fontColor = .white
        statsText.position = CGPoint(x: size.width / 2, y: size.height / 2 + 30)
        statsText.zPosition = 201
        statsText.alpha = 0
        addChild(statsText)

        let livesText = SKLabelNode(text: "Vies restantes: \(lives)")
        livesText.fontSize = 25
        livesText.fontColor = .red
        livesText.position = CGPoint(x: size.width / 2, y: size.height / 2 - 10)
        livesText.zPosition = 201
        livesText.alpha = 0
        addChild(livesText)

        // Prochain niveau
        let nextLevelText = SKLabelNode(text: "NIVEAU \(level)")
        nextLevelText.fontSize = 60
        nextLevelText.fontColor = .yellow
        nextLevelText.position = CGPoint(x: size.width / 2, y: size.height / 2 - 80)
        nextLevelText.zPosition = 201
        nextLevelText.alpha = 0
        nextLevelText.setScale(0.5)
        addChild(nextLevelText)

        // Message spécial pour boss
        var bossWarning: SKLabelNode? = nil
        if level % 5 == 0 {
            bossWarning = SKLabelNode(text: "⚠️ BOSS INCOMING ⚠️")
            bossWarning!.fontSize = 30
            bossWarning!.fontColor = .red
            bossWarning!.position = CGPoint(x: size.width / 2, y: size.height / 2 - 140)
            bossWarning!.zPosition = 201
            bossWarning!.alpha = 0
            addChild(bossWarning!)
        }

        // Vaisseau qui traverse l'écran
        let ship = SKShapeNode()
        let shipPath = CGMutablePath()
        shipPath.move(to: CGPoint(x: 0, y: 15))
        shipPath.addLine(to: CGPoint(x: -10, y: -8))
        shipPath.addLine(to: CGPoint(x: 10, y: -8))
        shipPath.closeSubpath()
        ship.path = shipPath
        ship.fillColor = .cyan
        ship.strokeColor = .white
        ship.position = CGPoint(x: -50, y: size.height / 2 - 180)
        ship.zPosition = 201
        ship.zRotation = .pi / 2
        addChild(ship)

        // Animations
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)

        overlay.run(fadeIn)

        completeText.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.2),
            fadeIn
        ]))

        statsText.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            fadeIn
        ]))

        livesText.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.7),
            fadeIn
        ]))

        nextLevelText.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.group([
                fadeIn,
                SKAction.scale(to: 1.0, duration: 0.5)
            ])
        ]))

        if let warning = bossWarning {
            let blink = SKAction.sequence([
                SKAction.fadeAlpha(to: 1.0, duration: 0.2),
                SKAction.fadeAlpha(to: 0.3, duration: 0.2)
            ])
            warning.run(SKAction.sequence([
                SKAction.wait(forDuration: 1.3),
                SKAction.repeatForever(blink)
            ]))
        }

        // Animation du vaisseau
        let shipMove = SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.moveTo(x: size.width + 50, duration: 2.0)
        ])
        ship.run(shipMove)

        // Étoiles filantes
        for i in 0..<5 {
            let star = SKShapeNode(circleOfRadius: 2)
            star.fillColor = .white
            star.strokeColor = .clear
            star.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: size.height + 20)
            star.zPosition = 201
            addChild(star)

            let starMove = SKAction.sequence([
                SKAction.wait(forDuration: Double(i) * 0.3 + 0.5),
                SKAction.group([
                    SKAction.moveTo(y: -20, duration: 1.0),
                    SKAction.fadeOut(withDuration: 1.0)
                ]),
                SKAction.removeFromParent()
            ])
            star.run(starMove)
        }

        // Nettoyer et passer au niveau suivant après 3 secondes
        let cleanup = SKAction.sequence([
            SKAction.wait(forDuration: 3.0),
            SKAction.run { [weak self] in
                // Supprimer tous les éléments de transition
                overlay.removeFromParent()
                completeText.removeFromParent()
                statsText.removeFromParent()
                livesText.removeFromParent()
                nextLevelText.removeFromParent()
                bossWarning?.removeFromParent()
                ship.removeFromParent()

                // Fin de la transition
                self?.isTransitioning = false

                // Démarrer le niveau suivant
                self?.setupEnemies()
            }
        ])
        run(cleanup)
    }

    func updateScore() {
        scoreLabel.text = "Score: \(score)"

        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "HighScore")
            highScoreLabel.text = "High Score: \(highScore)"
        }
    }

    func updateLivesDisplay() {
        livesLabel.text = String(repeating: "❤", count: max(0, lives))
    }

    func updateCombo() {
        if combo > 1 {
            comboLabel.text = "x\(combo) COMBO!"
            comboLabel.removeAllActions()

            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.3, duration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.1)
            ])
            comboLabel.run(pulse)
        } else {
            comboLabel.text = ""
        }
    }

    func gameOver() {
        isGameOver = true
        removeAction(forKey: "enemyShooting")

        sound.playGameOver()

        // Explosion on player
        createExplosion(at: player.position, big: true)
        player.isHidden = true

        let gameOverLabel = SKLabelNode(text: "GAME OVER")
        gameOverLabel.fontSize = 60
        gameOverLabel.fontColor = .red
        gameOverLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 30)
        addChild(gameOverLabel)

        let scoreText = SKLabelNode(text: "Final Score: \(score)")
        scoreText.fontSize = 30
        scoreText.fontColor = .white
        scoreText.position = CGPoint(x: size.width / 2, y: size.height / 2 - 30)
        addChild(scoreText)

        let restartText = SKLabelNode(text: "Press SPACE to restart")
        restartText.fontSize = 20
        restartText.fontColor = .gray
        restartText.position = CGPoint(x: size.width / 2, y: size.height / 2 - 70)
        addChild(restartText)

        // Pulsing restart text
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.5),
            SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        ])
        restartText.run(SKAction.repeatForever(pulse))
    }

    func restart() {
        // Remove all nodes
        removeAllChildren()
        removeAllActions()

        // Reset state
        lives = 3
        score = 0
        level = 1
        combo = 0
        isGameOver = false
        gamePaused = false
        isTransitioning = false
        panicMode = false
        hasShield = false
        hasRapidFire = false
        hasTripleShot = false
        enemies.removeAll()
        boss = nil

        // Setup again
        setupStars()
        setupPlayer()
        setupLabels()
        setupEnemies()

        let enemyShootAction = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.wait(forDuration: 1.5),
                SKAction.run { [weak self] in self?.enemyShoot() }
            ])
        )
        run(enemyShootAction, withKey: "enemyShooting")
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver && !gamePaused && !isTransitioning else { return }

        // Player movement
        if keysPressed.contains(123) || keysPressed.contains(0) { // Left arrow or A
            player.position.x -= GameConfig.playerSpeed
        }
        if keysPressed.contains(124) || keysPressed.contains(2) { // Right arrow or D
            player.position.x += GameConfig.playerSpeed
        }

        // Continuous shooting while holding space
        if keysPressed.contains(49) {
            shoot()
        }

        // Keep player in bounds
        player.position.x = max(20, min(size.width - 20, player.position.x))

        // Move enemies
        if !isBossLevel {
            if panicMode {
                // PANIC MODE: bouge à chaque frame (60 FPS = vitesse maximum possible)
                moveEnemiesPanic()
            } else if currentTime - lastEnemyMove > enemyMoveInterval {
                moveEnemies()
                lastEnemyMove = currentTime
            }
        }

        // Combo timeout
        if combo > 0 && currentTime - lastKillTime > comboTimeout {
            combo = 0
            comboLabel.text = ""
        }
    }

    func moveEnemies() {
        var shouldChangeDirection = false
        var shouldMoveDown = false

        for enemy in enemies {
            if enemy.position.x <= 30 || enemy.position.x >= size.width - 30 {
                shouldChangeDirection = true
                shouldMoveDown = true
                break
            }
        }

        if shouldChangeDirection {
            enemyDirection *= -1
        }

        // Changer la frame d'animation (comme Space Invaders original)
        alienAnimationFrame = (alienAnimationFrame + 1) % 2

        for enemy in enemies {
            enemy.position.x += 10 * enemyDirection * enemySpeed
            if shouldMoveDown {
                enemy.position.y -= 15
            }

            // Animer l'alien (sprite bitmap)
            if let spriteEnemy = enemy as? SKSpriteNode,
               let row = enemy.userData?["row"] as? Int {
                updateEnemySprite(spriteEnemy, row: row, frame: alienAnimationFrame)
            }

            // Check if enemies reached player
            if enemy.position.y < 80 {
                gameOver()
                return
            }
        }
    }

    // Version PANIC: bouge à chaque frame, vitesse maximum absolue
    func moveEnemiesPanic() {
        var shouldChangeDirection = false

        for enemy in enemies {
            if enemy.position.x <= 20 || enemy.position.x >= size.width - 20 {
                shouldChangeDirection = true
                break
            }
        }

        if shouldChangeDirection {
            enemyDirection *= -1
            // Descendre aussi à chaque changement de direction
            for enemy in enemies {
                enemy.position.y -= 8
            }
        }

        // Animation à chaque frame aussi
        alienAnimationFrame = (alienAnimationFrame + 1) % 2

        for enemy in enemies {
            // Vitesse maximum: 20 pixels par frame = 1200 pixels/seconde à 60 FPS
            enemy.position.x += 20 * enemyDirection

            // Animer l'alien (sprite bitmap)
            if let spriteEnemy = enemy as? SKSpriteNode,
               let row = enemy.userData?["row"] as? Int {
                updateEnemySprite(spriteEnemy, row: row, frame: alienAnimationFrame)
            }

            // Check if enemies reached player
            if enemy.position.y < 80 {
                gameOver()
                return
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        keysPressed.insert(event.keyCode)

        // Space to shoot or restart
        if event.keyCode == 49 {
            if isGameOver {
                restart()
            } else {
                shoot()
            }
        }

        // P to pause
        if event.keyCode == 35 {
            gamePaused.toggle()
            self.isPaused = gamePaused

            if gamePaused {
                // Show pause text
                let pauseText = SKLabelNode(text: "PAUSED")
                pauseText.fontSize = 50
                pauseText.fontColor = .white
                pauseText.position = CGPoint(x: size.width / 2, y: size.height / 2)
                pauseText.name = "pauseText"
                addChild(pauseText)
            } else {
                // Remove pause text
                childNode(withName: "pauseText")?.removeFromParent()
            }
        }

        // Escape to quit
        if event.keyCode == 53 {
            NSApplication.shared.terminate(nil)
        }

        // B pour aller directement au boss (keyCode 11)
        if event.keyCode == 11 && !isGameOver {
            skipToBoss()
        }

        // G pour mode dieu (keyCode 5)
        if event.keyCode == 5 {
            godMode.toggle()
            showGodModeStatus()
        }

        // K pour tuer tous les ennemis en mode dieu (keyCode 40)
        if event.keyCode == 40 && godMode && !isGameOver {
            killAllEnemies()
        }

        // M pour toggle musique (keyCode 46)
        if event.keyCode == 46 {
            toggleMusic()
        }

        // O pour mode panique - aliens vitesse max (keyCode 31)
        if event.keyCode == 31 && !isGameOver && !isTransitioning {
            activatePanicMode()
        }
    }

    func activatePanicMode() {
        panicMode = true
        showMessage("⚠️ PANIC MODE ⚠️")
        sound.playHit()
    }

    var musicEnabled = true

    func toggleMusic() {
        musicEnabled.toggle()
        if musicEnabled {
            sound.startBackgroundMusic()
            showMessage("MUSIC ON")
        } else {
            sound.stopBackgroundMusic()
            showMessage("MUSIC OFF")
        }
    }

    func showMessage(_ text: String) {
        let label = SKLabelNode(text: text)
        label.fontSize = 30
        label.fontColor = .white
        label.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(label)

        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: 0.8),
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ])
        label.run(fadeOut)
    }

    func skipToBoss() {
        // Supprimer tous les ennemis actuels
        for enemy in enemies {
            enemy.removeFromParent()
        }
        enemies.removeAll()

        // Aller au niveau 5 (boss)
        level = 5
        levelLabel.text = "Level: \(level)"
        isBossLevel = true
        setupEnemies()
    }

    func showGodModeStatus() {
        // Supprimer ancien message
        childNode(withName: "godModeText")?.removeFromParent()

        let text = SKLabelNode(text: godMode ? "GOD MODE ON" : "GOD MODE OFF")
        text.fontSize = 40
        text.fontColor = godMode ? .green : .red
        text.position = CGPoint(x: size.width / 2, y: size.height / 2)
        text.name = "godModeText"
        addChild(text)

        // Effet visuel sur le joueur
        if godMode {
            playerSprite?.color = .yellow
            playerSprite?.colorBlendFactor = 0.5
        } else {
            playerSprite?.colorBlendFactor = 0
        }

        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ])
        text.run(fadeOut)
    }

    func killAllEnemies() {
        sound.playBigExplosion()

        // Tuer tous les ennemis normaux
        for enemy in enemies {
            createExplosion(at: enemy.position, big: false)
            score += 10
            enemy.removeFromParent()
        }
        enemies.removeAll()

        // Tuer le boss instantanément
        if let bossNode = boss {
            createExplosion(at: bossNode.position, big: true)
            score += 500 * level
            bossNode.removeFromParent()
            boss = nil
        }

        updateScore()

        // Passer au niveau suivant
        if !isBossLevel || boss == nil {
            levelComplete()
        }
    }

    override func keyUp(with event: NSEvent) {
        keysPressed.remove(event.keyCode)
    }

    // Clic souris pour tirer aussi
    override func mouseDown(with event: NSEvent) {
        if isGameOver {
            restart()
        } else {
            shoot()
        }
    }
}

// MARK: - Custom SKView that accepts keyboard input
class GameSKView: SKView {
    override var acceptsFirstResponder: Bool { return true }

    override func keyDown(with event: NSEvent) {
        if let scene = self.scene as? GameScene {
            scene.keyDown(with: event)
        }
    }

    override func keyUp(with event: NSEvent) {
        if let scene = self.scene as? GameScene {
            scene.keyUp(with: event)
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var skView: GameSKView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create window
        let windowRect = NSRect(
            x: 0, y: 0,
            width: GameConfig.windowWidth,
            height: GameConfig.windowHeight
        )

        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Space Invaders"
        window.center()

        // Create custom SpriteKit view
        skView = GameSKView(frame: windowRect)
        skView.showsFPS = true
        skView.showsNodeCount = true
        skView.ignoresSiblingOrder = true

        // Create and present scene
        let scene = GameScene(size: CGSize(width: GameConfig.windowWidth, height: GameConfig.windowHeight))
        scene.scaleMode = .aspectFill
        skView.presentScene(scene)

        window.contentView = skView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(skView)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Main
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
