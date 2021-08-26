var IS_MOBILE;
if(/(android|bb\d+|meego).+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|ipad|iris|kindle|Android|Silk|lge |maemo|midp|mmp|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows (ce|phone)|xda|xiino/i.test(navigator.userAgent)
  || /1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-/i.test(navigator.userAgent.substr(0,4))) {
    IS_MOBILE = true;
} else {
    IS_MOBILE = false;
}

const WIDTH=1250, HEIGHT=1500, JUMP_VELOCITY = -500;
var config = {
    type: Phaser.AUTO,
    backgroundColor: '#ADD8E6',
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
            gravity: { y: 300 },
            debug: true
        }
    },
    scene: {
        preload: preload,
        create: create,
        update: update
    }
};

var game = new Phaser.Game(config);
var board, dave;
var controls, lastBoardDist, boardY;

function preload () {
    this.load.image('bg', '../assets/bg.png');
    this.load.image('board', '../assets/board.png');
    this.load.image('platform', '../assets/platform.png');
    this.load.image('water', '../assets/water.png');
    this.load.spritesheet('dave', '../assets/divedave-full.png', { frameWidth: 256, frameHeight: 256, margin: 0, spacing: 0 });
}

function create () {
    this.physics.world.setBounds(0, 0, WIDTH, HEIGHT);
    let bg = this.add.image(WIDTH/2, HEIGHT/2, 'bg');
    let water = this.add.image(WIDTH/2, HEIGHT/2, 'water');
    let platform = this.add.image(WIDTH/6, 5*HEIGHT/7, 'platform');
    board = this.physics.add.staticImage(WIDTH/4, HEIGHT/2 + 25, 'board');
    boardY = board.y - board.height/2;

    dave = this.physics.add.sprite(WIDTH/8, HEIGHT/3, 'dave');
    dave.body.setSize(64, 256);
    dave.body.setAllowGravity(true);
    dave.setCollideWorldBounds(true);
    dave.setFrame(1);
    dave.speed = 300;
    dave.setDrag(250, 1);
    dave.body.setAllowDrag(true);

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

    controls = {
        up: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.W, false),
        left: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.A, false),
        down: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.S, false),
        right: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.D, false),
        space: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.SPACE, false),
        r: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.R, false),
        q: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.Q, false),
    };
}

function update() {
    updateBounce();
    this.physics.world.collide(dave, [board]);
    playerHandler();
}

function updateBounce() {
    let daveBoardDist = dave.x - (board.x - board.width/2);
    if (daveBoardDist > 0 && lastBoardDist !== daveBoardDist) {
        lastBoardDist = daveBoardDist;
        let newRatio = daveBoardDist/board.width;
        newRatio = newRatio <= 1 ? newRatio : 1;
        console.log(newRatio);
        dave.body.setBounce(newRatio);
    }
}

function playerHandler() {
    if (IS_MOBILE) {
        playerMobileMovementHandler();
    } else {
        playerMovementHandler();
    }

    if (dave.body.velocity.y < -25) {
        if (dave.body.velocity.x < 0) {
            dave.setFrame(15);
        } else {
            dave.setFrame(6)
        }
    } else {
        if (dave.y + dave.height/2 <= boardY-5) {
            if (dave.body.velocity.x > 0) {
                dave.anims.play('walkright', true);
            } else if (dave.body.velocity.x < 0) {
                dave.anims.play('walkleft', true);
            } else {
                dave.setFrame(2);
            }
        }
    }
}

function playerMovementHandler() {
    if ((controls.up.isDown || controls.space.isDown) && (dave.y + dave.height/2) >= (boardY)) {
        dave.setVelocityY(JUMP_VELOCITY);
    } 
    if (controls.left.isDown) {
        dave.setVelocityX(-dave.speed);
    }
    if (controls.right.isDown) {
        dave.setVelocityX(dave.speed);
    }
    if (controls.r.isDown) {
        dave.body.setAngularVelocity(180);
    } else if (controls.q.isDown) {
        dave.body.setAngularVelocity(-180);
    } else {
        dave.body.setAngularVelocity(0);
    }
}

function playerMobileMovementHandler() {
    var pointer = game.scene.input.activePointer;
    if ((pointer.isDown)) {
        var touchX = pointer.x;
        var touchY = pointer.y;
        var touchWorldPoint = this.cameras.main.getWorldPoint(touchX, touchY);
        if (touchWorldPoint.y <= GROUNDY-PLAYER_SIZE*GLOBAL_SCALE && dave.body.velocity.y === 0 && dave.y >= GROUNDY - PLAYER_SIZE*GLOBAL_SCALE - GLOBAL_SCALE) {
            dave.setVelocityY(JUMP_VELOCITY);
        } else {
            if (touchWorldPoint.x > dave.body.position.x + PLAYER_SIZE*GLOBAL_SCALE/2) {
                dave.setVelocityX(dave.speed);
            } else if (touchWorldPoint.x < dave.body.position.x - PLAYER_SIZE*GLOBAL_SCALE/2) {
                dave.setVelocityX(-dave.speed);
            } else if (dave.body.velocity.y === 0 && dave.y >= GROUNDY - PLAYER_SIZE*GLOBAL_SCALE - GLOBAL_SCALE) {
                dave.setVelocityY(JUMP_VELOCITY);
            }
        }
    }
}

