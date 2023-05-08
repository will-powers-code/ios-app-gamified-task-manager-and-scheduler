//
//  GameScene.swif
//  Planner Pet
//
//  Created by Wenyin Zheng on 2019/4/12.
//  Copyright © 2019 Wenyin Zheng. All rights reserved.
//


import SpriteKit
import GameplayKit

// ZPosition
enum Layer:CGFloat {
    case ninja
    case projectile
    case moster
}

// 名称
struct Category {
    static let backgroundName:String = "BG"
    static let ninjaName :String     = "NinjaPiggy"
}

// 碰撞
struct PhysicsCategory {
    static let None      : UInt32 = 0x1 << 1
    static let All       : UInt32 = 0x1 << 2
    static let Projectile: UInt32 = 0x1 << 3 // 用于碰撞时判断BodyA还是BodyB.CategoryBitMask
    static let Monster   : UInt32 = 0x1 << 4
    static let Ninja     : UInt32 = 0x1 << 5 // 忽略与飞镖的碰撞
}

class GameScene: SKScene,SKPhysicsContactDelegate{
    
    let background = SKSpriteNode(imageNamed: Category.backgroundName)
    var isFingerOnNinja = false       // 手指是否在Ninja里
    let maxAspectRatio:CGFloat = CGFloat(16 / 9)
    
    let monsterScoreLabelNode:SKLabelNode = SKLabelNode()
    var monsterScore:Int = 0   // monster score 分数
    let ninjaLiveLabelNode  :SKLabelNode = SKLabelNode()
    let timeLabelNode  :SKLabelNode = SKLabelNode()
//    var ninjaLive:Int    = 5   // ninja live  生命
    var ninjaLive:String = "5:00" //显示的倒计时时间字符串 分：秒
    
    
    var ninjaNode  = SKSpriteNode()   // 加入ninja player
    // Ninja Atlas
    var ninjaAtlas = SKTextureAtlas() // atlas 文件夹名称
    var ninjaTextureArray = [SKTexture]()
    var ninjaActionRepeat1Times = SKAction() // Ninja手挥动的SKAction touchesBegan调用
    // Monsters Atlas
    var monsterNode  = SKSpriteNode()  // 加入 monster
    var monsterAtlas = SKTextureAtlas()
    var monsterTexturesArray = [SKTexture]()
    var hitAction = SKAction()
    var timer : Timer = Timer()
    var djsTime:Int = 60*5//倒计时时间：单位 秒
    
    
    var invincible = false    // 无敌时刻
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: "begainPlayGame"), object: nil)
        
        // 真实世界的物理重力
        physicsWorld.gravity = CGVector(dx: 0.0, dy: -9.8)
        physicsWorld.contactDelegate = self
        // 加入音乐
        hitAction = SKAction.playSoundFileNamed("hitNinja", waitForCompletion: false)
        addBg()
        addLogo()
        addTimer()
        addNinja()
        addScore()
        /*
         1.SK.Action无限产生 monsters
         let actionAddMonster = SKAction.run {
         self.addMonsters()
         }
         run(SKAction.repeatForever(SKAction.sequence([
         actionAddMonster,SKAction.wait(forDuration: TimeInterval(1))])))
         */
        //2.用Timer每隔1s调用 addMonster
        Timer.scheduledTimer(timeInterval: TimeInterval(1.0), target: self, selector: #selector(addMonsters), userInfo: nil, repeats: true)
        addFloor()
    }
    
    //MARK:- 加入背景 option+Command+<-(箭头) 折叠
    func addBg(){
        background.anchorPoint = CGPoint(x: 0.5, y: 0.5) // default
        background.position = CGPoint(x: size.width/2, y: size.height/2)
        // background.zRotation = CGFloat.pi / 8
        background.name = "background"
        background.zPosition = -1
        addChild(background)
        // 背景音乐
        let backgroundMusic = SKAudioNode(fileNamed: "background-music-aac.caf")
        backgroundMusic.autoplayLooped = true
        addChild(backgroundMusic)
    }
    //MARK:- 加入logo
    func addLogo(){
        let logo = SKSpriteNode(imageNamed: "logo")
        logo.position = CGPoint(x: self.size.width / 2, y: self.frame.height - (self.frame.height / 5)-30)
        logo.zPosition = Layer.ninja.rawValue
        logo.setScale(0.7)
        logo.name = "logo"
        self.addChild(logo)       
    }
    func transToHourMinSec(time: Int) -> String
    {
        let allTime: Int = Int(time)
        var minutes = 0
        var seconds = 0
        var minutesText = ""
        var secondsText = ""
        minutes = allTime % 3600 / 60
        minutesText = minutes > 9 ? "\(minutes)" : "0\(minutes)"
        
        seconds = allTime % 3600 % 60
        secondsText = seconds > 9 ? "\(seconds)" : "0\(seconds)"
        
        return "\(minutesText):\(secondsText)"
    }
    
    //添加倒计时
    func addTimer() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { (timer) in
            if self.djsTime<=0 {
                //游戏结束
                NotificationCenter.default.post(name: Notification.Name(rawValue: "endPlayGame"), object: nil, userInfo: ["score":self.monsterScore])
                timer.fireDate = Date.distantFuture
                timer.invalidate()
                // 切换场景
                // 播放失败的音乐
                let loseAction = SKAction.playSoundFileNamed("lose", waitForCompletion: false)
                self.run(loseAction, completion: {
                    //monsterNode.run(SKAction.removeFromParent())
                    //ninjaNode.run(SKAction.removeFromParent())
                    // you win 切换场景 Scene
                    let reveal = SKTransition.doorsCloseHorizontal(withDuration: 0.5)
                    let gameLoseScene = SKScene(fileNamed: "GameLose")
                    gameLoseScene?.size = (self.size)
                    gameLoseScene?.scaleMode = .aspectFill
                    self.view?.presentScene(gameLoseScene!, transition: reveal)
                })
            }else{
                self.djsTime = self.djsTime-1
                self.ninjaLive = self.transToHourMinSec(time: self.djsTime)
                self.ninjaLiveLabelNode.text = "Time:\(self.ninjaLive)"
            }
        })
        //开始计时器
        timer.fire()
    }
    
    // MARK: - 分数
    func addScore(){
        // NINJA
        ninjaLiveLabelNode.text = "Time:\(ninjaLive)"
        ninjaLiveLabelNode.fontColor = SKColor.black
        ninjaLiveLabelNode.fontSize = 40
        ninjaLiveLabelNode.setScale(1.0)
        ninjaLiveLabelNode.zPosition = 1
        ninjaLiveLabelNode.position = CGPoint(x: 150, y: self.frame.height - (self.frame.height / 5) - 40)
        ninjaLiveLabelNode.name = "ninjaLiveLabel"
        self.addChild(ninjaLiveLabelNode)
        
        // monster
        monsterScoreLabelNode.text = "MONSTER:\(monsterScore)"
        monsterScoreLabelNode.fontColor = SKColor.black
        monsterScoreLabelNode.fontSize = 40
        monsterScoreLabelNode.setScale(1.0)
        monsterScoreLabelNode.zPosition = 1
        monsterScoreLabelNode.position = CGPoint(x: 150 + 300, y: self.frame.height - (self.frame.height / 5)-40)
        monsterScoreLabelNode.name = "monsterLabel"
        self.addChild(monsterScoreLabelNode)
        
    }
    
    //MARK:- 加入Ninja Player
    func addNinja(){
        ninjaAtlas = SKTextureAtlas(named: "NinjaPiggy")
        for i in 1...ninjaAtlas.textureNames.count {
            let imageName = "NinjaPiggy0\(i).png"
            ninjaTextureArray.append(SKTexture(imageNamed: imageName))
        }
        ninjaNode = SKSpriteNode(imageNamed: ninjaAtlas.textureNames[2])
        // 加入物理实体
        ninjaNode.physicsBody = SKPhysicsBody(rectangleOf: ninjaNode.size)
        ninjaNode.physicsBody?.affectedByGravity = true
        // FIXME: 修复Ninja发射飞镖时的反作用力，否则Ninja发射飞镖时会反弹；
        // physicsBody=>CategoryBitMask,ContactTestBitMask,collisionBitMask
        ninjaNode.anchorPoint = CGPoint (x: 0.5, y: 0.5)
        ninjaNode.position    = CGPoint(x: self.frame.size.width / 8 + 150 , y: (self.frame.size.height / 4 - 100))
        ninjaNode.setScale(1.0)
        ninjaNode.name = "ninja"
        self.addChild(ninjaNode)
        // 手的动画 Animation
        let ninjaActionAnimation = SKAction.animate(with: ninjaTextureArray, timePerFrame: 0.1)
        ninjaActionRepeat1Times = SKAction.repeat(ninjaActionAnimation, count: 1)
        // 1.属于哪个对像
        ninjaNode.physicsBody?.categoryBitMask = PhysicsCategory.Ninja
        // 2.和谁发生碰撞
        ninjaNode.physicsBody?.contactTestBitMask = PhysicsCategory.Monster
        // 3.碰撞后会弹开吗？ bounce off
        ninjaNode.physicsBody?.collisionBitMask = PhysicsCategory.None
        ninjaNode.physicsBody?.usesPreciseCollisionDetection = false
    }
    //MARK:- 随机产生 单个 Monster Y 轴 + 从右往左移动+移出屏幕 removeFromParent
    @objc func addMonsters(){
        monsterAtlas = SKTextureAtlas(named: "Bomb")
        for i in 1...monsterAtlas.textureNames.count {
            let imageName = "Bomb0\(i).png"
            monsterTexturesArray.append(SKTexture(imageNamed: imageName))
        }
        monsterNode = SKSpriteNode(imageNamed: monsterAtlas.textureNames[0])
        monsterNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        monsterNode.zPosition = Layer.projectile.rawValue
        monsterNode.name = "monster"
        // Y值随机位置
        let randomPositionY  = CGFloat.random(min: monsterNode.size.height , max: size.height - monsterNode.size.height)
        monsterNode.position = CGPoint(x: size.width + monsterNode.size.width, y: randomPositionY)
        // 加monster
        monsterNode.setScale(0.9)
        self.addChild(monsterNode)
        // 物理
        monsterNode.physicsBody = SKPhysicsBody(circleOfRadius: self.monsterNode.size.width / 2)
        monsterNode.physicsBody?.affectedByGravity = false // 不会重力影响
        // monsterNode.physicsBody?.isDynamic = false
        monsterNode.physicsBody?.categoryBitMask    = PhysicsCategory.Monster
        monsterNode.physicsBody?.contactTestBitMask = PhysicsCategory.Projectile | PhysicsCategory.Ninja
        monsterNode.physicsBody?.collisionBitMask   = PhysicsCategory.None
        monsterNode.physicsBody?.usesPreciseCollisionDetection = false
        /// MONSTER自身动画
        let monsterAction = SKAction.animate(with: monsterTexturesArray, timePerFrame: 0.1)
        let monsterActionRepeatForever = SKAction.repeatForever(monsterAction)
        monsterNode.run(monsterActionRepeatForever, withKey: "Monster")
        /// 从右往左的随机速度
        let duration = CGFloat.random(min: CGFloat(1.0), max: CGFloat(3.8))
        let actionMoveToLeft = SKAction.move(to: CGPoint(x: CGFloat(-monsterNode.size.width), y: randomPositionY), duration: TimeInterval(duration))
        let actionRemove = SKAction.removeFromParent()
        monsterNode.run(SKAction.sequence([actionMoveToLeft,actionRemove]))
    }
    
    //MARK:-  加入物理地板 edge-base 让 Ninja站在物理世界的地板上
    func addFloor(){
        let yPos = self.frame.size.height / 4 - 100 - 1 // (Ninja脚的高度 - 1)
        let startPoint = CGPoint(x: 0, y: yPos)
        let endPoint   = CGPoint(x:size.width,y:yPos)
        let floorNode = SKNode()
        floorNode.physicsBody = SKPhysicsBody(edgeFrom: startPoint, to: endPoint)
        floorNode.name = "floor"
        addChild(floorNode)
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let touchLocation = touch.location(in: self)
            if ninjaNode.contains(touchLocation){
                isFingerOnNinja = true
            }
            //ninja发射飞镖
            if !isFingerOnNinja {
                let actionFire = SKAction.playSoundFileNamed("pew-pew-lei.caf", waitForCompletion: false)
                run(actionFire)
                // 扔Projectile
                ninjaNode.run(ninjaActionRepeat1Times, withKey: "FireProjectile")
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isFingerOnNinja {
            let touch = touches.first
            let touchLocation = touch!.location(in: self)
            let previousLocation = touch!.previousLocation(in: self)
            let ninjaNode = self.ninjaNode
            //let ninjaY = (ninjaNode.position.y) + (touchLocation.y - previousLocation.y)
            var ninja = (ninjaNode.position) + (touchLocation - previousLocation)
            // ninjaNode.position = CGPoint(x: (ninjaNode.position.x), y: ninja.y)
            // FIXME:限定移动的区域 min ,max
            // ninja.x = min(ninja.x,ninjaNode.size.width / 2)
            if ninja.x < self.ninjaNode.size.width / 2 {
                ninja.x = self.ninjaNode.size.width / 2
            }
            // ninja.x = max(ninja.x,(self.size.width - self.ninjaNode.size.width))
            if ninja.x > self.size.width - self.ninjaNode.size.width {
                ninja.x = self.size.width - self.ninjaNode.size.width
            }
            
            if ninja.y < (self.frame.size.height / 4 - 100) {
                ninja.y = self.frame.size.height / 4 - 100
            }
            
            ninjaNode.position = CGPoint(x: ninja.x, y: ninja.y)
        }
    }
    //MARK: -- 生成飞镖并发射
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isFingerOnNinja = false
        
        guard let touch = touches.first else {
            return
        }
        let touchLocation = touch.location(in: self)
        // 生成飞镖
        let projectileNode = SKSpriteNode(imageNamed: "projectile")
        // 飞镖的位置位于Ninja的手上 0.5,0.5 X轴右移 ninjaNode.size.with 1/2
        projectileNode.position = CGPoint(x: ninjaNode.position.x + self.ninjaNode.size.width / 2 , y: ninjaNode.position.y)
        projectileNode.physicsBody = SKPhysicsBody(circleOfRadius: projectileNode.size.width / 2)
        projectileNode.physicsBody?.isDynamic = false // 不受重力影响
        projectileNode.name = "projectile"
        projectileNode.setScale(CGFloat(maxAspectRatio))
        projectileNode.zPosition = Layer.projectile.rawValue
        projectileNode.setScale(1.0)
        
        let offset = touchLocation - projectileNode.position
        // print("projectile offset:\(offset)")
        if (offset.x < 0 ) {return } // Ninja Never Look Back
        
        self.addChild(projectileNode)
        
        // 加入碰撞对象
        projectileNode.physicsBody?.categoryBitMask    = PhysicsCategory.Projectile
        projectileNode.physicsBody?.contactTestBitMask = PhysicsCategory.Monster
        // projectileNode.physicsBody?.collisionBitMask   = PhysicsCategory.None
        // 精细的对象detect，才可以飞行中的monster进行碰撞
        projectileNode.physicsBody?.usesPreciseCollisionDetection = true
        
        /*
         SKEmitter：加入酷酷飞镖粒子拖影
         图层关系：
         projectNode -> emitterNode -> trailNode */
        // 1.新建一个节点 (发生碰撞时也须移除此节点)
        let trailNode = SKNode()
        trailNode.zPosition = Layer.projectile.rawValue
        trailNode.name = "trail"
        addChild(trailNode)
        // 2.新建粒子效果
        let emitterNode = SKEmitterNode(fileNamed: "ProjectileTrail")!
        emitterNode.name = "emitter"
        // 3.粒子效果的子节点为 trailNode
        emitterNode.targetNode = trailNode
        // 4.飞镖Node加上子节点 emitter
        projectileNode.addChild(emitterNode)
        
        let actionRotate  = SKAction.rotate(byAngle: CGFloat(-Double.pi/2), duration: 0.2)
        let actionRotateForever = SKAction.repeatForever(actionRotate)
        projectileNode.run(actionRotateForever)
        
        let direction = offset.normalized()  // 发射方向/每单位
        let shootAmount = direction * self.frame.size.width   // 足够长 射出屏幕
        let realDestination = shootAmount + projectileNode.position
        let actionMove  = SKAction.move(to: realDestination, duration: 3.0)
        let actionRemove = SKAction.removeFromParent()
        projectileNode.run(SKAction.sequence([
            actionMove,
            actionRemove,
            SKAction.run {
                trailNode.removeFromParent()  // MARK：除了projectile要移除,新建的trailNode粒子节点也需移除
            }
            ]))
    }
    
    // 发生碰撞时的代理
    func didBegin(_ contact: SKPhysicsContact) {
        //顺序 project < monster < ninja
        var bodyA:SKPhysicsBody
        var bodyB:SKPhysicsBody
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            bodyA = contact.bodyA
            bodyB = contact.bodyB
        }else {
            bodyA = contact.bodyB
            bodyB = contact.bodyA
        }
        
        // 使用这种switch判断方法，比判断哪个碰撞的对像是bodyA，bodyB更快捷，个人比较喜欢用,awesome!
        // print("project:",PhysicsCategory.Projectile,"-monster:",PhysicsCategory.Monster,"-ninja:",PhysicsCategory.Ninja)
        let contactBitMASK = contact.bodyA.categoryBitMask  | contact.bodyB.categoryBitMask
        switch contactBitMASK {
        // 击中monster
        case PhysicsCategory.Projectile | PhysicsCategory.Monster:
            
            projectileCollideWithMonster(projectileNode: bodyA.node as! SKSpriteNode, monsterNode: bodyB.node as! SKSpriteNode)
            
        case  PhysicsCategory.Ninja | PhysicsCategory.Monster:
            // 得判断ninja是bodyA或者bodyB
            if bodyA.categoryBitMask == PhysicsCategory.Ninja{
                // print("bodyA is not ninja piggy")
                // ninjaCollideWithMonster(ninjaNode: bodyA.node as! SKSpriteNode, monsterNode: bodyB.node as! SKSpriteNode)
            }else {
                /*
                 * 为防止手指一直拖动Ninja和Monster发生碰撞，在碰撞发生的第一时刻didBegin
                 * 就立刻把ninjaNode的物理实体设为不会再发生碰撞 => ninjaNode.physicsBody?.categoryBitMask = 0
                 * 待ninjaCollideWithMonster函数的Action执行完毕后
                 * 再设置 ninjaNode 可以发生碰撞 => ninjaNode.physicsBody?.categoryBitMask = PhysicsCategory.Ninja
                 */
                ninjaNode.physicsBody?.categoryBitMask = 0
                ninjaCollideWithMonster(ninjaNode: bodyB.node as! SKSpriteNode, monsterNode: bodyA.node as! SKSpriteNode)
            }
        default:
            break
        }
    }
    //MARK: - 飞镖击中Monsters
    func projectileCollideWithMonster(projectileNode:SKSpriteNode,monsterNode:SKSpriteNode){
        // monster score 加分
        self.monsterScore += 1
        monsterScoreLabelNode.text = "MONSTER:\(monsterScore)"
        // 切换场景 + 播放胜利的音乐
        if monsterScore >= 5 {// monsterScore wrote as 5 for DEMO REASON!!!!!!
            // 播放胜利的音乐
            let wonAction = SKAction.playSoundFileNamed("won", waitForCompletion: false)
            run(wonAction, completion: {
                // you win 切换场景 Scene
                let reveal = SKTransition.doorsCloseHorizontal(withDuration: 0.5)
                //let gameWonScene = SKScene(fileNamed: "GameWon")
                let gameWonScene = GameWon(fileNamed: "GameWon")
                gameWonScene?.size = self.size
                gameWonScene?.scaleMode = .aspectFill
                self.view?.presentScene(gameWonScene!, transition: reveal)
            })
        }
        // 击中粒子效果 Particle
        let explosion = SKEmitterNode(fileNamed: "Explosion")!
        explosion.position = monsterNode.position
        self.addChild(explosion)
        // 击中的音乐
        let colisionAction = SKAction.playSoundFileNamed("yew-yew.wav", waitForCompletion: false)
        let removeMonsterAction = SKAction.run { monsterNode.removeFromParent()}
        run(SKAction.sequence([
            SKAction.run {
                //MARK:- 移除所有节点projectile的child的emitter效果 设置projectile不可见,让飞出屏幕后自动消除
                projectileNode.removeAllChildren()
                projectileNode.isHidden = true
                projectileNode.physicsBody?.categoryBitMask = 0 // 不会再发生下一个碰撞
                
            },
            removeMonsterAction,
            colisionAction,
            SKAction.wait(forDuration: 0.2),
            SKAction.run {
                explosion.removeFromParent() //移除爆炸效果
            }
            ]))
    }
    //MARK: - Ninja被Monster击中
    func ninjaCollideWithMonster(ninjaNode:SKSpriteNode,monsterNode:SKSpriteNode){
        //MARK: 进阶 monster 击中 ninja时的 ACTION Sequence
        //减分
//        if self.monsterScore>0{
//            self.monsterScore -= 1;}
//
        
        
    
        // 1.变成绿色
        let turnGreeenAction  = SKAction.colorize(with: SKColor.green, colorBlendFactor: 1.0, duration: 0.2)
        // texture恢复ninja的色彩 colorBlendFactor 默认是0.0 也就是纹理不做改变直接呈现
        let removeGreenAction = SKAction.run {
            ninjaNode.colorBlendFactor = 0.0
            // ninjaNode.texture = SKTexture(imageNamed: self.ninjaAtlas.textureNames[2])
        }
        // 2.闪烁
        let fadeIn  = SKAction.fadeAlpha(to: 0, duration: 0.2)
        let fadeOut = SKAction.fadeAlpha(to: 1, duration: 0.2)
        let blinkAction = SKAction.repeat(SKAction.sequence([fadeIn,fadeOut]), count: 5)
        
        // 4.执行Action Sequence
        ninjaNode.run(SKAction.sequence([
            self.hitAction,
            turnGreeenAction,
            blinkAction,
            removeGreenAction,
            SKAction.run({ [weak self] in
                if self!.monsterScore>0{
                    
                    self?.monsterScore-=1;
                }
                /*
                // 等待ACTION结束后 开始计分;
                // monster score 加分
                self?.ninjaLive -= 1
                if ((self?.ninjaLive)! < 0) {
                    self?.ninjaLive = 0
                }
                // 切换场景
                if (self?.ninjaLive)! <= 0 {
                    // 播放失败的音乐
                    let loseAction = SKAction.playSoundFileNamed("lose", waitForCompletion: false)
                    self?.run(loseAction, completion: {
                        //monsterNode.run(SKAction.removeFromParent())
                        //ninjaNode.run(SKAction.removeFromParent())
                        // you win 切换场景 Scene
                        let reveal = SKTransition.doorsCloseHorizontal(withDuration: 0.5)
                        let gameLoseScene = SKScene(fileNamed: "GameLose")
                        gameLoseScene?.size = (self?.size)!
                        gameLoseScene?.scaleMode = .aspectFill
                        self?.view?.presentScene(gameLoseScene!, transition: reveal)
                    })
                }
                self?.ninjaLiveLabelNode.text = "NINJA:\(self?.ninjaLive ?? 5)"
                */
            }),
            SKAction.run({
                // 设次设置可以和Ninja发生碰撞
                self.ninjaNode.physicsBody?.categoryBitMask = PhysicsCategory.Ninja
            })
            ]))
        
    }
    
    override func update(_ currentTime: TimeInterval) {
    }
}



