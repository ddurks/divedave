var IS_MOBILE;
if(/(android|bb\d+|meego).+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|ipad|iris|kindle|Android|Silk|lge |maemo|midp|mmp|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows (ce|phone)|xda|xiino/i.test(navigator.userAgent)
  || /1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-/i.test(navigator.userAgent.substr(0,4))) {
    IS_MOBILE = true;
} else {
    IS_MOBILE = false;
}

fadeOutScene = function(sceneName, context, height) {
    context.cameras.main.fadeOut(250);
    context.time.addEvent({
        delay: 250,
        callback: function() {
            context.scene.start(sceneName, {height: height});
        },
        callbackScope: context
    });
};

getRandomInt = function(min, max) {
    min = Math.ceil(min);
    max = Math.floor(max);
    return Math.floor(Math.random() * (max - min) + min);
}

diff = function (num1, num2) {
    if (num1 > num2) {
        return num1 - num2
    } else {
        return num2 - num1
    }
}

class CookieManager {
    createCookie = (name,value,days) => {
        if (days) {
            var date = new Date();
            date.setTime(date.getTime()+(days*24*60*60*1000));
            var expires = "; expires="+date.toGMTString();
        }
        else var expires = "";
        document.cookie = name+"="+value+expires+"; path=/";
    }
    
    readCookie = (name) => {
        var nameEQ = name + "=";
        var ca = document.cookie.split(';');
        for(var i=0;i < ca.length;i++) {
            var c = ca[i];
            while (c.charAt(0)==' ') c = c.substring(1,c.length);
            if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
        }
        return null;
    }
    
    eraseCookie = (name) => {
        createCookie(name,"",-1);
    }
}

var CHALLENGE_MODE = true;
const GRAVITY = 500;
const WIDTH=1250, HEIGHT=1500, DAVE_SPEED = 300, JUMP_VELOCITY = 500, MIN_SPIN_VELOCITY = 75, MAX_SPIN_VELOCITY = 500, DRAG = 500, ANGULAR_DRAG = 125, MAX_BOOST = 200, IDLE_DELAY = 1000;
const MIN_CLOUDS = 7, MAX_CLOUDS = 15, CLOUDMINSPEED = 35, CLOUDMAXSPEED = 85;
const MIN_BIRDS = 0, MAX_BIRDS = 3, BIRDMINSPEED = 50, BIRDMAXSPEED = 200;
const HIGH_SCORE_COOKIE = 'highScore';
var springboard, dave;
var controls, waterLevel, jumping, landedAt = null, jumpReleasedAt = null;
var boost = 0, currentVelocity = MIN_SPIN_VELOCITY, tucked = false, tuckCount = 0;
var streak = 0, totalScore = 0;
const cookieManager = new CookieManager();
let storedHighScore = cookieManager.readCookie(HIGH_SCORE_COOKIE);
var highScore = storedHighScore ? storedHighScore : 0;
var highScoreSession = false;

class MainMenu extends Phaser.Scene {
    constructor() {
        super('MainMenu');
    }

    preload() {
        this.load.image('cover', 'assets/cover.png');
        this.load.image('panel', 'assets/panel.png');
        this.load.image('controls-help', 'assets/controls-help.png');
        this.load.image('arcade', 'assets/arcade.png');
        this.load.image('challenge', 'assets/challenge.png');
        this.load.image('sign', 'assets/sign.png');
        this.load.bitmapFont('black-arial', 'assets/fonts/black-arial.png', 'assets/fonts/black-arial.xml');
    }

    displayInstructions(strings) {
        this.add.image(WIDTH/2, HEIGHT/2 - 45, 'panel').setVisible(true).setScrollFactor(0).setDepth(20);
        let height = HEIGHT/2 - 450;
        strings.forEach(string => {
            this.add.text(WIDTH/2, height, string, { align: 'center', color: 'white', fontFamily: 'Arial', fontSize: '55px', fontStyle: 'bold'}).setOrigin(0.5).setScrollFactor(0).setDepth(21);
            height += 75;
        });
    }

    create() {
        let instructionStrings = IS_MOBILE ? 
            [
                "touch left and right buttons", 
                "to move dave",
                "",
                "touch the jump button to jump", 
                "while above the board",
                "",
                "jump quickly multiple times",
                "near the end of the board",
                "to jump higher",
                "",
                "touch the flip button to flip",
                "once dave has left the board"
            ] : [
                "[A] and [D] or [<] [>] arrow keys",
                "to move dave",
                "",
                "[W] or [^] arrow key to jump",
                "while above the board",
                "",
                "jump quickly multiple times",
                "near the end of the board", 
                "to jump higher",
                "",
                "[R] [^] or [space] to flip",
                "once dave has left the board"
            ];
        this.input.keyboard.on('keydown', this.handleKey, this);
        var cover = this.add.image(WIDTH/2, HEIGHT/2 - 75, 'cover');
        cover.setScale(2);
        var instructions = this.add.image(WIDTH - 100, 100, 'controls-help').setOrigin(0.5).setScale(0.5);
        instructions.setInteractive({ useHandCursor: true }).on('pointerdown', () => {
            this.displayInstructions(instructionStrings);
        });
        var startText = this.add.image(WIDTH/2 + 200, HEIGHT/2 + 570, 'arcade').setOrigin(0.5).setScale(0.5);
        startText.setInteractive({ useHandCursor: true }).on('pointerdown', () => {
            CHALLENGE_MODE = false;
            this.clickStart(this);
        });
        var startChallengeText = this.add.image(WIDTH/2 - 200, HEIGHT/2 + 570, 'challenge').setOrigin(0.5).setScale(0.5);
        startChallengeText.setInteractive({ useHandCursor: true }).on('pointerdown', () => {
            this.clickStart(this);
        });
        if (highScore > 0) {
            this.add.image(125, 110, 'sign').setRotation(Math.PI).setDepth(23).setScrollFactor(0);
            this.add.bitmapText(125, 60, 'black-arial', 'YOUR CHALLENGE', 20).setOrigin(0.5).setScrollFactor(0).setDepth(24).setActive(false);
            this.add.bitmapText(125, 90, 'black-arial', 'HIGH SCORE', 30).setOrigin(0.5).setScrollFactor(0).setDepth(24).setActive(false);
            this.add.bitmapText(125, 150, 'black-arial', highScore, 50).setOrigin(0.5).setScrollFactor(0).setDepth(24).setActive(false);
        }
    }

    handleKey(e) {
        switch(e.code) {
            case 'Enter': {
                this.clickStart(this);
                break;
            }
            default: {}
        }
    }

    clickStart(scene) {
        if (CHALLENGE_MODE) {
            fadeOutScene('DiveScene', scene, 1500);
        } else {
            fadeOutScene('DiveScene', scene, getRandomInt(1500, 10000));
        }
    }
}

class InfoPanel extends Phaser.GameObjects.Group {
    constructor(scene, depth) {
        super(scene);
        this.baseDepth = depth;
        this.panel = scene.add.image(WIDTH/2, HEIGHT/2, 'panel').setVisible(false).setScrollFactor(0).setDepth(this.baseDepth);
        this.daveimage = scene.add.sprite(WIDTH/2, HEIGHT/2 - 175, 'davemotions').setVisible(false).setScrollFactor(0).setScale(2).setFrame(2).setDepth(this.baseDepth + 1);
        this.score1 = scene.add.image(WIDTH/2 - 275, HEIGHT/2 + 325, 'sign').setVisible(false).setScrollFactor(0).setDepth(this.baseDepth + 2);
        this.score2 = scene.add.image(WIDTH/2, HEIGHT/2 + 325, 'sign').setVisible(false).setScrollFactor(0).setDepth(this.baseDepth + 2);
        this.score3 = scene.add.image(WIDTH/2 + 275, HEIGHT/2 + 325, 'sign').setVisible(false).setScrollFactor(0).setDepth(this.baseDepth + 2);
        this.tryAgain = scene.add.bitmapText(125, 75, 'red-arial', (IS_MOBILE ? 'tap' : 'click') + ' to dive again', 65).setOrigin(0.5).setDepth(this.baseDepth + 2).setScrollFactor(0).setVisible(false);
    }

    display(scene, result, strings, frame, scores, sceneHeight) {
        let height = HEIGHT/2 + 5;
        scene.add.bitmapText(WIDTH/2, height - 375, ((result === 'FAILED DIVE') || (result === 'GAME OVER')) ? 'red-arial' : 'green-arial', result, 80).setOrigin(0.5).setDepth(this.baseDepth + 1).setScrollFactor(0);
        strings.forEach(string => {
            scene.add.bitmapText(WIDTH/2, height, (string.includes('rotations') && ((result === 'FAILED DIVE') || (result === 'GAME OVER'))) ? 'red-arial' : 'black-arial', string, 80).setOrigin(0.5).setDepth(this.baseDepth + 1).setScrollFactor(0);
            height += 75;
        });
        let width = WIDTH/2 - 275;
        scores ? scores.forEach(score => {
            scene.add.bitmapText(width, HEIGHT/2 + 325, 'red-arial', score, 100).setOrigin(0.5).setDepth(this.baseDepth + 3).setScrollFactor(0);
            width += 275;
        }) : null;
        this.tryAgain.setPosition(WIDTH/2, sceneHeight - 100);
        this.tryAgain.setVisible(scores ? true : false);
        this.panel.setVisible(true);
        this.daveimage.setFrame(frame);
        this.daveimage.setVisible(true);
        this.score1.setVisible(scores ? true : false);
        this.score2.setVisible(scores ? true : false);
        this.score3.setVisible(scores ? true : false);
    }

    close() {
        this.tryAgain.setVisible(false);
        this.panel.setVisible(false);
        this.daveimage.setVisible(false);
        this.score1.setVisible(false);
        this.score2.setVisible(true);
        this.score3.setVisible(true);
    }
}

class MobileControls {
    constructor(scene) {
        this.leftButton = scene.add.existing(new ControlButton(scene, 175, HEIGHT - 150, 'controls-left'));
        this.rightButton = scene.add.existing(new ControlButton(scene, 450, HEIGHT - 150, 'controls-right'));
        this.jumpButton = scene.add.existing(new ControlButton(scene, WIDTH - 175, HEIGHT - 150, 'controls-jump'));
        this.flipButton = scene.add.existing(new ControlButton(scene, WIDTH - 175, HEIGHT - 150, 'controls-flip'));
        this.flipButton.setVisible(false);
    }

    setVisible(visible) {
        this.leftButton.setVisible(visible);
        this.rightButton.setVisible(visible);
        this.jumpButton.setVisible(visible);
        this.flipButton.setVisible(visible);
    }

    jumpControls() {
        this.jumpButton.setVisible(true);
        this.flipButton.setVisible(false);
    }

    flipControls() {
        this.flipButton.setVisible(true);
        this.jumpButton.setVisible(false);
    }
}

class ControlButton extends Phaser.GameObjects.Image
{
    constructor(scene, x, y, texture, frame = null)
    {
        super(scene, x, y, texture, frame);

        this.setInteractive();
        this.setScrollFactor(0)
        this.setScale(0.5);
        this.setDepth(14);
        this.isDown = false;

        this.onPressed = null;
        this.onReleased = null;

        this.on('pointerdown', () => { this.isDown = true; });
        this.on('pointerup', () => { this.pointerUp(); });
        this.on('pointerout', () => { this.pointerUp(); });
    }

    pointerUp()
    {
        this.isDown = false;
        if(this.onReleased != null) this.onReleased();
    }
}

class DiveScene extends Phaser.Scene {
    constructor() {
        super('DiveScene');
    }

    init(data) {
        this.sceneHeight = data.height;
        this.clouds = new Array();
        this.birds = new Array();
        this.diveComplete = false;
        this.readyForReset = false;
        this.sumRotation = 0;
        this.totalRotations = 0;
        this.previousAngle = 0;
        this.currentAngle = 0;
        this.stats = {
            angle: 0,
            tucked: false,
            tuckCount: 0,
            rotations: 0,
            scores: [0, 0, 0]
        }
        this.timerStarted = false;
    }

    preload() {
        this.load.image('landscape', 'assets/landscape.png');
        this.load.image('platformtop', 'assets/platformtop.png');
        this.load.image('platformsection', 'assets/platformsection.png');
        this.load.image('platformbase', 'assets/platformbase.png');
        this.load.image('controls-right', 'assets/controls-right.png');
        this.load.image('controls-left', 'assets/controls-left.png');
        this.load.image('controls-flip', 'assets/controls-flip.png');
        this.load.image('controls-jump', 'assets/controls-jump.png');
        this.load.bitmapFont('Arial', 'assets/fonts/Arial20.png', 'assets/fonts/Arial20.xml');
        this.load.bitmapFont('green-arial', 'assets/fonts/green-arial.png', 'assets/fonts/green-arial.xml');
        this.load.bitmapFont('yellow-arial', 'assets/fonts/yellow-arial.png', 'assets/fonts/yellow-arial.xml');
        this.load.bitmapFont('red-arial', 'assets/fonts/red-arial.png', 'assets/fonts/red-arial.xml');
        this.load.spritesheet('springboard', 'assets/board.png', { frameWidth: 440, frameHeight: 64, margin: 0, spacing: 0 });
        this.load.spritesheet('water', 'assets/water.png', { frameWidth: 1250, frameHeight: 200, margin: 0, spacing: 0 });
        this.load.spritesheet('dave', 'assets/divedave-spritesheet-extruded.png', { frameWidth: 256, frameHeight: 256, margin: 1, spacing: 2 });
        this.load.spritesheet('cloud', 'assets/clouds.png', { frameWidth: 256, frameHeight: 256, margin: 0, spacing: 0 });
        this.load.spritesheet('bird', 'assets/bird.png', { frameWidth: 128, frameHeight: 128, margin: 0, spacing: 0 });
        this.load.spritesheet('splash', 'assets/splash.png', { frameWidth: 256, frameHeight: 256, margin: 0, spacing: 0 });
        this.load.spritesheet('davemotions', 'assets/divedave-emotions.png', { frameWidth: 150, frameHeight: 160, margin: 0, spacing: 0 }); 
    }

    create() {
        this.physics.world.setBounds(0, 0, WIDTH, this.sceneHeight);
        this.add.image(WIDTH/2, this.sceneHeight-250, 'landscape');
        this.add.image(205, 797, 'platformtop').setDepth(10);
        for (let i = 897; i < this.sceneHeight - 200; i+=100) {
            this.add.image(205, i, 'platformsection').setDepth(9);
        }
        this.add.image(205, this.sceneHeight - 200, 'platformbase').setDepth(10);

        this.spawnClouds();

        this.add.image(125, 110, 'sign').setRotation(Math.PI).setDepth(14).setScrollFactor(0);
        this.runningStreak = this.add.bitmapText(125, 135, 'black-arial', "streak: " + streak, 30).setOrigin(0.5).setScrollFactor(0).setDepth(14).setActive(false);
        this.runningScore = this.add.bitmapText(125, 75, 'black-arial', "score: " + totalScore, 30).setOrigin(0.5).setScrollFactor(0).setDepth(14).setActive(false);
        this.calculateGameLogic();
    
        waterLevel = this.sceneHeight - 100;
        let heightFromWater = waterLevel - 797;
        this.add.bitmapText(WIDTH - 200, 797 - 10, 'black-arial', "   " + Math.round(heightFromWater/2/100 * 10) / 10 + "m", 50).setDepth(14).setActive(false);
        heightFromWater--;
        for (let i = 798; i < waterLevel; i++) {
            let labelColor = 'red-arial';
            let currHeight = heightFromWater/2/100;
            if (currHeight < 25) {
                labelColor = 'yellow-arial';
            }
            if (currHeight < 10) {
                labelColor = 'green-arial'
            }
            if ( heightFromWater%200 === 0 ) {
                this.add.bitmapText(WIDTH - 250, i, labelColor, "-- " + currHeight, 32).setDepth(14).setActive(false);
            } else if ( heightFromWater%20 === 0 ) {
                this.add.bitmapText(WIDTH - 250, i, labelColor, "-", 32).setDepth(14).setActive(false);
            }
            heightFromWater--;
        }
    
        springboard = this.physics.add.sprite(WIDTH/4, HEIGHT/2 + 40, 'springboard').setDepth(11);
        springboard.body.setAllowGravity(false);
        springboard.body.setImmovable(true);
    
        dave = this.physics.add.sprite(WIDTH/8, HEIGHT/3, 'dave').setDepth(12);
        dave.setOrigin(0.5, 0.5);
        dave.body.setSize(64, 256);
        dave.body.setAllowGravity(true);
        dave.speed = DAVE_SPEED;
        dave.setDrag(DRAG, 1);
        dave.body.setAngularDrag(ANGULAR_DRAG);
        dave.body.setAllowDrag(true);
        jumping = false;

        this.info = new InfoPanel(this, 20);
        this.highScorePanel = new InfoPanel(this, 24);
        this.highScoreText = this.add.bitmapText(WIDTH/2, 150, 'green-arial', 'NEW HIGH SCORE!', 50).setOrigin(0.5).setScrollFactor(0).setDepth(24).setActive(false).setVisible(false);
        this.mobileControls = new MobileControls(this);
        if (!IS_MOBILE) {
            this.mobileControls.setVisible(false);
        }

        this.anims.create({
            key: 'idle', 
            frameRate: 8,
            frames: this.anims.generateFrameNumbers('dave', { frames: [18, 18, 18, 18, 18, 19, 20, 21] }),
            repeat: -1
        });
    
        this.anims.create({
            key: 'walkright', 
            frameRate: 6,
            frames: this.anims.generateFrameNumbers('dave', { frames: [2, 3, 2, 4] }),
            repeat: -1
        });
    
        this.anims.create({
            key: 'walkleft', 
            frameRate: 6,
            frames: this.anims.generateFrameNumbers('dave', { frames: [11, 12, 11, 13] }),
            repeat: -1
        });
    
        this.anims.create({
            key: 'jump',
            frameRate: 12,
            frames: this.anims.generateFrameNumbers('dave', { frames: [5, 5, 6] })
        });

        this.anims.create({
            key: 'splash', 
            frameRate: 8,
            frames: this.anims.generateFrameNumbers('splash', { frames: [0, 1, 2, 3, 4, 5, 6, 7] }),
            repeat: 0
        });

        this.anims.create({
            key: 'idlewater',
            frameRate: 4,
            frames:this.anims.generateFrameNumbers('water', { frames: [0, 1, 2, 3] }),
            repeat: -1
        })

        this.anims.create({
            key: 'flex', 
            frameRate: 4,
            frames: this.anims.generateFrameNumbers('springboard', { frames: [0, 1, 0] }),
            repeat: 0
        });

        this.anims.create({
            key: 'fly', 
            frameRate: 12,
            frames: this.anims.generateFrameNumbers('bird', { frames: [0, 0, 0, 0, 1, 2, 3, 4, 3, 2, 1] }),
            repeat: -1
        });
        
        this.spawnBirds();

        let water = this.add.sprite(WIDTH/2, this.sceneHeight- 100, 'water').setDepth(11);
        water.anims.play('idlewater');
        let outerwater = this.add.sprite(WIDTH/2, this.sceneHeight - 50, 'water').setDepth(13);
        outerwater.anims.play('idlewater');

        dave.on(Phaser.Animations.Events.ANIMATION_COMPLETE, () => {
            jumping = false;
            this.calculateBoost();
            landedAt = null;
            dave.setVelocityY(- JUMP_VELOCITY - boost);
        });
    
        this.cameras.main.startFollow(dave);
        this.cameras.main.setBounds(0, 0, WIDTH, this.sceneHeight);
    
        this.physics.add.collider(dave, springboard, (dave, springboard) => {
            if (!landedAt) {
                landedAt = Date.now();
            }
        })
    
        controls = {
            up: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.W, false),
            left: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.A, false),
            down: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.S, false),
            right: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.D, false),
            space: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.SPACE, false),
            enter: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.ENTER, false),
            r: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.R, false),
            cursors: this.input.keyboard.createCursorKeys(),
        };

        this.input.on('pointerdown', () => {
            this.resetScene();
        })

        controls.up.on('up', () => {
            jumpReleasedAt = Date.now();
        });

        controls.cursors.up.on('up', () => {
            jumpReleasedAt = Date.now();
        })

        this.input.on('pointerup', () => {
            jumpReleasedAt = Date.now();
        });

        tucked = false;
        tuckCount = 0;
        this.lastFlipNumber = 0;
    }

    calculateBoost() {
        let quickness = diff(landedAt, jumpReleasedAt);
        if (quickness < 125) {
            boost = MAX_BOOST;
        } else if (quickness < 250) {
            boost = MAX_BOOST - 50;
        } else if (quickness < 350) {
            boost = MAX_BOOST - 100;
        } else {
            boost = 0;
        }
        let daveBoardDist = dave.x - (springboard.x - springboard.width/2);
        if (daveBoardDist > 0 ) {
            let newRatio = daveBoardDist/springboard.width;
            newRatio = newRatio <= 1 ? newRatio : 1;
            boost = boost * newRatio;
        }
    }

    update() {
        this.physics.world.collide(dave, [springboard]);
        this.handleClouds();
        this.handleBirds();
        this.playerHandler();
    }

    playerHandler() {
        this.checkForReset();
        if (!jumping) {
            if (IS_MOBILE) {
                this.playerMobileMovementHandler();
            } else {
                this.playerMovementHandler();
            }
    
            this.playerFrameHandler();
        }
    }
    
    playerFrameHandler() {
        if (!jumping) {
            if(this.daveIsAboveBoard()) {
                if (dave.angle !== 0) {
                    dave.setAngle(0);
                }
                if(this.daveIsTouchingBoard()) {
                    if (dave.body.velocity.x > 0) {
                        dave.anims.play('walkright', true);
                    } else if (dave.body.velocity.x < 0) {
                        dave.anims.play('walkleft', true);
                    } else if (dave.anims.getName() !== 'idle') {
                        dave.anims.play('idle', true);
                    }
                } else {
                    if (dave.body.velocity.y < 0) {
                        if (dave.body.velocity.x < 0) {
                            dave.setFrame(15);
                        } else {
                            dave.setFrame(6);
                        }
                    } else {
                        if (dave.body.velocity.x < 0) {
                            dave.setFrame(11);
                        } else {
                            dave.setFrame(2);
                        }
                    }
                }
            } else {
                if (!tucked) {
                    if (dave.angle >= -90 && dave.angle <= 90) {
                        dave.setFrame(6);
                    } else {
                        dave.setFrame(8)
                    }
                }
            }
        }
    }
    
    daveIsAboveBoard() {
        let result = (dave.x + dave.width/4 > 0 && dave.x - dave.width/4 < springboard.x + springboard.width/2 - 10) && dave.y + dave.height/2 < springboard.y - springboard.height/2 + 1;
        if (result && this.sumRotation !== 0) {
            this.sumRotation = 0;
            this.totalRotations = 0;
        }
        return result;
    }
    
    daveIsTouchingBoard() {
        return dave.y + dave.height/2 >= springboard.y - (springboard.height/2);
    }
    
    daveIsTucked() {
        if (tucked) {
            dave.setFrame(7)
        }
        return dave.frame.name === 7 || tucked;
    }
    
    daveJump() {
        if (!jumping && dave.anims.getName() !== 'jump') {
            jumping = true;
            springboard.anims.play('flex', true);
            dave.anims.play('jump', true);
        }
    }
    
    checkForReset() {
        if (!this.diveComplete) {
            if (dave.body.velocity.y > 0 && (dave.x - dave.width/4 > springboard.x + springboard.width/2 - 10) && !this.timerStarted) {
                this.timerStart = Date.now();
                this.timerStarted = true;
            }
            if (dave.y > waterLevel - 15) {
                this.diveComplete = true;
                let heightFromWater = waterLevel - 797;
                this.stats = {
                    height: Math.round(heightFromWater/2/100 * 10) / 10,
                    angle: Math.round(dave.angle * 10) / 10,
                    tucked: this.daveIsTucked(),
                    tuckCount: tuckCount,
                    rotations: Math.round(this.totalRotations * 10) / 10,
                    scores: [0, 0, 0]
                }
                let result = this.scoreDive();
                this.runningStreak.setText("streak: " + streak);
                this.runningScore.setText("score: " + totalScore);
                this.info.display(this, result, [
                    "height: " + this.stats.height + "m",
                    "entry angle: " + this.stats.angle, 
                    "rotations: " + this.stats.rotations
                ], this.stats.emotionFrame, this.stats.scores, this.sceneHeight);
                this.mobileControls.setVisible(false);
                let splash = this.add.sprite(dave.x, waterLevel - 100, 'splash');
                splash.setDepth(14);
                splash.anims.play('splash');
                splash.on(Phaser.Animations.Events.ANIMATION_COMPLETE, () => {
                    splash.destroy();
                });
                setTimeout(() => {
                    this.readyForReset = true;
                }, 1000);
            }
            this.countRotations();
        }
    }

    calculateGameLogic() {
        let time = Math.sqrt(2 * (this.sceneHeight - 250) / GRAVITY);
        let maxFlips = time * (MAX_SPIN_VELOCITY/360);
        this.goalRotations = (getRandomInt(1, maxFlips*2)/2.0);
        this.add.bitmapText(WIDTH - 25, 25, 'green-arial', "GOAL: " + this.goalRotations + (this.goalRotations < 1.5 ? " FLIP" : " FLIPS"), 65).setOrigin(1,0).setScrollFactor(0).setDepth(14).setActive(false);
    }

    countRotations() {
        let daveRotation = Phaser.Math.Angle.Normalize(dave.rotation)
        if (daveRotation !== this.currentAngle) {
            let angleDiff = diff(this.previousAngle, this.currentAngle);
            if (angleDiff > 5) {
                if (daveRotation < 1) {
                    this.previousAngle = 0;
                } else if (daveRotation > 5) {
                    this.previousAngle = 2*Math.PI;
                }
                angleDiff = diff(this.previousAngle, this.currentAngle);
            }
            this.sumRotation += angleDiff;
            this.totalRotations = this.sumRotation / (2 * Math.PI);
            this.previousAngle = this.currentAngle;
            this.currentAngle = daveRotation;
            if (this.totalRotations > this.lastFlipNumber) {
                let diff = this.totalRotations - this.lastFlipNumber;
                if (diff >= 1) {
                    let roundedRotations = Math.round(this.totalRotations);
                    this.add.bitmapText(dave.x, dave.y, roundedRotations > this.goalRotations ? 'red-arial' : 'green-arial', roundedRotations, 75).setDepth(14).setActive(false);
                    this.lastFlipNumber = roundedRotations;
                }
            }
        }
    }

    chooseEmotionFrame(angle) {
        angle = Math.abs(angle);
        if (angle < 10 || angle > 170) {
            return 4;
        } else if ( (angle >= 10 && angle < 25) || (angle <= 170 && angle > 155) ) {
            return 3;
        } else if ( (angle >= 25 && angle < 45) || (angle <= 155 && angle > 135) ) {
            return 2;
        } else if ( (angle >= 45 && angle < 70) || (angle <= 135 && angle > 110) ) {
            return 1;
        } else if ( (angle >= 70 && angle < 110) ) {
            return 0;
        }
        return 2;
    }

    scoreDive() {
        if (Math.abs(this.stats.rotations - this.goalRotations) < 0.25) {
            this.stats.emotionFrame = this.chooseEmotionFrame(this.stats.angle);
            this.stats.scores.forEach( (score, index, scores) => {
                switch(this.stats.emotionFrame) {
                    case 4:
                        scores[index] = 10 - getRandomInt(0,1)/2.0 - (tuckCount - 1);
                        break;
                    case 3:
                        scores[index] = 10 - getRandomInt(3,6)/2.0 - (tuckCount - 1) ;
                        break;
                    case 2:
                        scores[index] = 10 - getRandomInt(7,10)/2.0 - (tuckCount - 1);
                        break;  
                    case 1:
                        scores[index] = 10 - getRandomInt(10,15)/2.0 - (tuckCount - 1);
                        break;
                    case 0:
                        scores[index] = 10 - getRandomInt(14,18)/2.0 - (tuckCount - 1);
                        break;
                }
            });
            if (tuckCount > 1) {
                this.stats.emotionFrame = this.stats.emotionFrame - 1;
            }
            streak++;
            totalScore = totalScore + this.stats.scores[0] + this.stats.scores[1] + this.stats.scores[2];
            if (CHALLENGE_MODE && totalScore > highScore) {
                cookieManager.createCookie(HIGH_SCORE_COOKIE, totalScore, 400);
                highScore = totalScore;
                highScoreSession = true;
                this.highScoreText.setVisible(true);
                setTimeout( () => {
                    this.highScoreText.setVisible(false);
                }, 5000);
            }
            return 'SUCCESS';
        } else {
            this.stats.emotionFrame = 0;
            this.stats.scores.forEach( (score, index, scores) => {
                scores[index] = 0;
            });
            if (highScoreSession) {
                this.highScorePanel.display(this, 'GAME OVER', [
                        '',
                        'NEW HIGH SCORE: ' + totalScore,
                        '',
                        'final height: ' + this.stats.height + "m",
                        'streak: ' + streak + ' dives',
                    ], 3, null, HEIGHT/2);
            }
            streak = 0;
            totalScore = 0;
            return 'FAILED DIVE'
        }
    }

    resetScene() {
        if (this.diveComplete && this.readyForReset) {
            if (!CHALLENGE_MODE) {
                this.scene.restart({ height: getRandomInt(1500, 10000) }); 
            } else {
                if (totalScore === 0) {
                    this.scene.restart({ height: 1500 });
                } else {
                    let streakMultiplier = 1+((2*streak)/((2*streak)+100));
                    let newSceneHeight = this.sceneHeight += getRandomInt(0, 500);
                    this.scene.restart({ height: Math.round(newSceneHeight * streakMultiplier) });
                }
            }
        }
    }
    
    playerMovementHandler() {
        if (controls.enter.isDown || controls.space.isDown && this.diveComplete) {
            this.resetScene();
        }
        if ((controls.up.isDown || controls.space.isDown || controls.cursors.up.isDown)) {
            if (this.daveIsAboveBoard() && this.daveIsTouchingBoard()) {
                this.daveJump();
            }
        } 
        if (controls.left.isDown || controls.cursors.left.isDown) {
            dave.setVelocityX(-dave.speed);
        }
        if (controls.right.isDown || controls.cursors.right.isDown) {
            dave.setVelocityX(dave.speed);
        }
        if ( controls.r.isDown || controls.space.isDown || controls.cursors.up.isDown) {
            if (!this.daveIsAboveBoard()) {
                if (!this.daveIsTucked()) {
                    tucked = true;
                    tuckCount++;
                }
                if (currentVelocity < MAX_SPIN_VELOCITY - 200) {
                    currentVelocity+=5;
                } else if (currentVelocity < MAX_SPIN_VELOCITY) {
                    currentVelocity+=1;
                }
                dave.body.setAngularVelocity(currentVelocity);
            }
        } else {
            tucked = false;
            currentVelocity = MIN_SPIN_VELOCITY;
        }
    }

    playerMobileMovementHandler() {
        if (!this.diveComplete) {
            if (this.daveIsAboveBoard()) {
                this.mobileControls.jumpControls();
            } else {
                this.mobileControls.flipControls();
            }
        }
        if (this.mobileControls.leftButton.isDown || this.mobileControls.rightButton.isDown || this.mobileControls.jumpButton.isDown || this.mobileControls.flipButton.isDown) {
            if (this.diveComplete) {
                this.resetScene();
            } else {
                if (this.daveIsAboveBoard()) {
                    if (this.mobileControls.jumpButton.isDown && this.daveIsTouchingBoard()) {
                        this.daveJump();
                    }
                    if (this.mobileControls.leftButton.isDown) {
                        dave.setVelocityX(-dave.speed);
                    }
                    if (this.mobileControls.rightButton.isDown) {
                        dave.setVelocityX(dave.speed);
                    }
                } else if (this.mobileControls.flipButton.isDown) {
                    if (!this.daveIsTucked()) {
                        tucked = true;
                        tuckCount++;
                    } else {
                        if (currentVelocity < MAX_SPIN_VELOCITY - 200) {
                            currentVelocity+=5;
                        } else if (currentVelocity < MAX_SPIN_VELOCITY) {
                            currentVelocity+=1;
                        }
                    }
                    dave.body.setAngularVelocity(currentVelocity);
                }
            }
        } else {
                tucked = false;
                currentVelocity = MIN_SPIN_VELOCITY;
        }
    }

    spawnClouds() {
        let segmentSize = 1000;
        for (let s = segmentSize; s < this.sceneHeight - 500 + 1; s+=segmentSize) {
            for (let i = 0; i < getRandomInt(MIN_CLOUDS, MAX_CLOUDS); i++) {
                let yMin = s - segmentSize;
                let yMax = s;
                let yPos = getRandomInt(yMin, yMax);
                let cloud = this.physics.add.sprite(getRandomInt(-256, WIDTH + 256), yPos, 'cloud');
                cloud.setFrame(getRandomInt(0, 8));
                cloud.flipX = getRandomInt(0, 2) === 0 ? true : false;
                cloud.body.setAllowGravity(false);
                cloud.setVelocityX(getRandomInt(CLOUDMINSPEED, CLOUDMAXSPEED));
                this.clouds.push(cloud);
            }
        }
    }

    handleClouds() {
        this.clouds.forEach( cloud => {
            if (cloud.x >= WIDTH + cloud.width/2) {
                let yMax = this.sceneHeight - 500;
                let yPos = getRandomInt(0, yMax);
                cloud.setPosition(-cloud.width*2, yPos);
                cloud.setVelocityX(getRandomInt(CLOUDMINSPEED, CLOUDMAXSPEED));
                cloud.setFrame(getRandomInt(0, 8));
            }
        });
    }

    spawnBirds() {
        let segmentSize = 1000;
        for (let s = segmentSize; s < this.sceneHeight - 500 + 1; s+=segmentSize) {
            for (let i = 0; i < getRandomInt(MIN_BIRDS, MAX_BIRDS); i++) {
                let yMin = s - segmentSize;
                let yMax = s;
                let yPos = getRandomInt(yMin, yMax);
                let bird = this.physics.add.sprite(getRandomInt(-128, WIDTH + 128), yPos, 'bird');
                bird.body.setAllowGravity(false);
                bird.setVelocityX(-getRandomInt(BIRDMINSPEED, BIRDMAXSPEED));
                setTimeout(() => {
                    if (bird && bird.anims) {
                        bird.anims.play('fly', true);
                    }
                }, getRandomInt(0, 750))
                this.birds.push(bird);
            }
        }
    }

    handleBirds() {
        this.birds.forEach( bird => {
            if (bird.x + bird.width/2 < 0 ) {
                let yMax = this.sceneHeight - 500;
                let yPos = getRandomInt(0, yMax);
                bird.setPosition(WIDTH+bird.width*2, yPos);
                bird.setVelocityX(-getRandomInt(BIRDMINSPEED, BIRDMAXSPEED));
            }
        });
    }
}

var config = {
    type: Phaser.AUTO,
    backgroundColor: '#bed5ff',
    scale: {
		parent: 'phaser-div',
		mode: Phaser.Scale.FIT,
		autoCenter: Phaser.Scale.CENTER_BOTH,
		width: WIDTH,
		height: HEIGHT
	},
    physics: {
        default: 'arcade',
        arcade: {
            gravity: { y: GRAVITY },
            debug: false
        }
    },
    input :{
        activePointers:3,
    },
    dom: {
		createContainer: true
	},
    scene: [MainMenu, DiveScene]
};

var game = new Phaser.Game(config);

