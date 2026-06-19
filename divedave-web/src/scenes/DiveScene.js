// Mirrors divedave-ios/divedave Shared/Scenes/DiveScene.swift.
//
// Phase 0 keeps this scene structurally identical to the original
// divedave.js DiveScene class. The only changes are:
//   - imports replace bare globals and free functions
//   - GameState.foo replaces module-level mutable globals
//   - HUD replaces the old MobileControls class name
//
// Subsequent phases will extract DavePlayer, Atmosphere,
// CameraController, RotationTracker, DiveScorer etc. into their own
// modules to match the iOS file layout.

import {
  ANGULAR_DRAG,
  DRAG,
  DAVE_SPEED,
  END_COLOR,
  GRAVITY,
  HEIGHT,
  JUMP_VELOCITY,
  MAX_BOOST,
  MAX_SPIN_VELOCITY,
  MIDDLE_COLOR,
  MIN_SPIN_VELOCITY,
  START_COLOR,
  WIDTH,
  MIN_CLOUDS,
  MAX_CLOUDS,
  CLOUDMINSPEED,
  CLOUDMAXSPEED,
  MIN_BIRDS,
  MAX_BIRDS,
  BIRDMINSPEED,
  BIRDMAXSPEED,
} from "../util/Constants.js";
import { GameState } from "../util/GameState.js";
import { diff, getRandomInt, IS_MOBILE } from "../util/Utilities.js";
import { StatsStore } from "../util/StatsStore.js";
import { HUD } from "../components/controls/HUD.js";
import { InfoPanel } from "../components/menu/InfoPanel.js";

export class DiveScene extends Phaser.Scene {
  constructor() {
    super("DiveScene");
  }

  init(data) {
    this.sceneHeight = data.height;
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
      scores: [0, 0, 0],
    };
    this.timerStarted = false;
  }

  preload() {
    this.load.image("landscape", "assets/landscape.png");
    this.load.image("platformtop", "assets/platformtop.png");
    this.load.image("platformsection", "assets/platformsection.png");
    this.load.image("platformbase", "assets/platformbase.png");
    this.load.image("controls-right", "assets/controls-right.png");
    this.load.image("controls-left", "assets/controls-left.png");
    this.load.image("controls-flip", "assets/controls-flip.png");
    this.load.image("controls-jump", "assets/controls-jump.png");
    this.load.bitmapFont(
      "Arial",
      "assets/fonts/Arial20.png",
      "assets/fonts/Arial20.xml"
    );
    this.load.bitmapFont(
      "green-arial",
      "assets/fonts/green-arial.png",
      "assets/fonts/green-arial.xml"
    );
    this.load.bitmapFont(
      "yellow-arial",
      "assets/fonts/yellow-arial.png",
      "assets/fonts/yellow-arial.xml"
    );
    this.load.bitmapFont(
      "red-arial",
      "assets/fonts/red-arial.png",
      "assets/fonts/red-arial.xml"
    );
    this.load.spritesheet("springboard", "assets/board.png", {
      frameWidth: 440,
      frameHeight: 64,
      margin: 0,
      spacing: 0,
    });
    this.load.spritesheet("water", "assets/water.png", {
      frameWidth: 1250,
      frameHeight: 200,
      margin: 0,
      spacing: 0,
    });
    this.load.spritesheet("dave", "assets/divedave-spritesheet-extruded.png", {
      frameWidth: 256,
      frameHeight: 256,
      margin: 1,
      spacing: 2,
    });
    this.load.spritesheet(
      "gettingoutdave",
      "assets/getting-out-spritesheet.png",
      {
        frameWidth: 1250,
        frameHeight: 500,
      }
    );
    this.load.spritesheet("climbdave", "assets/climbdave.png", {
      frameWidth: 256,
      frameHeight: 256,
    });
    this.load.image("plane", "assets/plane.png");
    this.load.image("ufo", "assets/ufo.png");
    this.load.spritesheet("cloud", "assets/clouds.png", {
      frameWidth: 256,
      frameHeight: 256,
      margin: 0,
      spacing: 0,
    });
    this.load.spritesheet("bird", "assets/bird.png", {
      frameWidth: 128,
      frameHeight: 128,
      margin: 0,
      spacing: 0,
    });
    this.load.spritesheet("star", "assets/star-spritesheet.png", {
      frameWidth: 128,
      frameHeight: 128,
    });
    this.load.spritesheet("splash", "assets/splash.png", {
      frameWidth: 256,
      frameHeight: 256,
      margin: 0,
      spacing: 0,
    });
    this.load.spritesheet("davemotions", "assets/divedave-emotions.png", {
      frameWidth: 150,
      frameHeight: 160,
      margin: 0,
      spacing: 0,
    });
  }

  create() {
    this.physics.world.setBounds(0, 0, WIDTH, this.sceneHeight);
    this.add.image(WIDTH / 2, this.sceneHeight - 250, "landscape").setDepth(2);
    this.add.image(205, 797, "platformtop").setDepth(10);
    for (let i = 897; i < this.sceneHeight - 200; i += 100) {
      this.add.image(205, i, "platformsection").setDepth(12);
    }
    this.add.image(205, this.sceneHeight - 200, "platformbase").setDepth(13);

    this.startY = this.sceneHeight - HEIGHT;
    this.middleY = this.sceneHeight - HEIGHT * 2;
    this.endY = this.sceneHeight - HEIGHT * 4;

    this.add
      .image(125, 110, "sign")
      .setRotation(Math.PI)
      .setDepth(14)
      .setScrollFactor(0);
    this.runningStreak = this.add
      .bitmapText(125, 135, "black-arial", "streak: " + GameState.streak, 30)
      .setOrigin(0.5)
      .setScrollFactor(0)
      .setDepth(14)
      .setActive(false);
    this.runningScore = this.add
      .bitmapText(125, 75, "black-arial", "score: " + GameState.totalScore, 30)
      .setOrigin(0.5)
      .setScrollFactor(0)
      .setDepth(14)
      .setActive(false);

    GameState.waterLevel = this.sceneHeight - 100;
    let heightFromWater = GameState.waterLevel - 797;
    this.add
      .bitmapText(
        WIDTH - 200,
        797 - 10,
        "black-arial",
        "   " + Math.round((heightFromWater / 2 / 100) * 10) / 10 + "m",
        50
      )
      .setDepth(14)
      .setActive(false);
    heightFromWater--;
    for (let i = 798; i < GameState.waterLevel; i++) {
      let labelColor = "red-arial";
      const currHeight = heightFromWater / 2 / 100;
      if (currHeight < 25) labelColor = "yellow-arial";
      if (currHeight < 10) labelColor = "green-arial";
      if (heightFromWater % 200 === 0) {
        this.add
          .bitmapText(WIDTH - 250, i, labelColor, "-- " + currHeight, 32)
          .setDepth(14)
          .setActive(false);
      } else if (heightFromWater % 20 === 0) {
        this.add
          .bitmapText(WIDTH - 250, i, labelColor, "-", 32)
          .setDepth(14)
          .setActive(false);
      }
      heightFromWater--;
    }

    GameState.springboard = this.physics.add
      .sprite(WIDTH / 4, HEIGHT / 2 + 40, "springboard")
      .setDepth(11);
    GameState.springboard.body.setAllowGravity(false);
    GameState.springboard.body.setImmovable(true);

    GameState.dave = this.physics.add
      .sprite(WIDTH / 8, HEIGHT / 3, "dave")
      .setDepth(12);
    GameState.dave.setOrigin(0.5, 0.5);
    GameState.dave.body.setSize(64, 256);
    GameState.dave.body.setAllowGravity(true);
    GameState.dave.speed = DAVE_SPEED;
    GameState.dave.setDrag(DRAG, 1);
    GameState.dave.body.setAngularDrag(ANGULAR_DRAG);
    GameState.dave.body.setAllowDrag(true);
    GameState.jumping = false;

    // Getting-out animation
    this.gettingoutdave = this.add
      .sprite(WIDTH / 2, GameState.waterLevel - 150, "gettingoutdave")
      .setDepth(11);
    this.gettingoutdave.setVisible(false);

    // Climb animation
    this.climbdave = this.physics.add
      .sprite(28, this.sceneHeight - 200, "climbdave")
      .setDepth(8);
    this.climbdave.setVisible(false);
    this.climbdave.body.setAllowGravity(false);
    this.climbdave.setVelocityY(0);

    this.info = new InfoPanel(this, 20);
    this.highScorePanel = new InfoPanel(this, 24);
    this.highScoreText = this.add
      .bitmapText(WIDTH / 2, 150, "green-arial", "NEW HIGH SCORE!", 50)
      .setOrigin(0.5)
      .setScrollFactor(0)
      .setDepth(24)
      .setActive(false)
      .setVisible(false);
    this.hud = new HUD(this);
    if (!IS_MOBILE) {
      this.hud.setVisible(false);
    }

    this.calculateGameLogic();

    this.anims.create({
      key: "idle",
      frameRate: 8,
      frames: this.anims.generateFrameNumbers("dave", {
        frames: [18, 18, 18, 18, 18, 19, 20, 21],
      }),
      repeat: -1,
    });
    this.anims.create({
      key: "walkright",
      frameRate: 6,
      frames: this.anims.generateFrameNumbers("dave", { frames: [2, 3, 2, 4] }),
      repeat: -1,
    });
    this.anims.create({
      key: "walkleft",
      frameRate: 6,
      frames: this.anims.generateFrameNumbers("dave", {
        frames: [11, 12, 11, 13],
      }),
      repeat: -1,
    });
    this.anims.create({
      key: "jump",
      frameRate: 12,
      frames: this.anims.generateFrameNumbers("dave", { frames: [5, 5, 6] }),
    });
    this.anims.create({
      key: "getout",
      frameRate: 10,
      frames: this.anims.generateFrameNumbers("gettingoutdave", {
        start: 0,
        end: 27,
      }),
      repeat: 0,
    });
    this.anims.create({
      key: "climb",
      frameRate: 8,
      frames: this.anims.generateFrameNumbers("climbdave", {
        frames: [0, 1, 2, 3],
      }),
      repeat: -1,
    });
    this.anims.create({
      key: "splash",
      frameRate: 8,
      frames: this.anims.generateFrameNumbers("splash", {
        frames: [0, 1, 2, 3, 4, 5, 6, 7],
      }),
      repeat: 0,
    });
    this.anims.create({
      key: "idlewater",
      frameRate: 4,
      frames: this.anims.generateFrameNumbers("water", {
        frames: [0, 1, 2, 3],
      }),
      repeat: -1,
    });
    this.anims.create({
      key: "flex",
      frameRate: 4,
      frames: this.anims.generateFrameNumbers("springboard", {
        frames: [0, 1, 0],
      }),
      repeat: 0,
    });
    this.anims.create({
      key: "fly",
      frameRate: 12,
      frames: this.anims.generateFrameNumbers("bird", {
        frames: [0, 0, 0, 0, 1, 2, 3, 4, 3, 2, 1],
      }),
      repeat: -1,
    });
    this.anims.create({
      key: "sparkle",
      frameRate: 4,
      frames: this.anims.generateFrameNumbers("star", {
        frames: [0, 0, 0, 0, 0, 1, 2, 3],
      }),
      repeat: -1,
    });

    this.spawnAtmosphere();

    const water = this.add
      .sprite(WIDTH / 2, this.sceneHeight - 100, "water")
      .setDepth(11);
    water.anims.play("idlewater");
    const outerwater = this.add
      .sprite(WIDTH / 2, this.sceneHeight - 50, "water")
      .setDepth(13);
    outerwater.anims.play("idlewater");

    GameState.dave.on(Phaser.Animations.Events.ANIMATION_COMPLETE, () => {
      GameState.jumping = false;
      this.calculateBoost();
      GameState.landedAt = null;
      GameState.dave.setVelocityY(-JUMP_VELOCITY - GameState.boost);
    });

    this.cameras.main.startFollow(GameState.dave);
    this.cameras.main.setBounds(0, 0, WIDTH, this.sceneHeight);

    this.physics.add.collider(GameState.dave, GameState.springboard, () => {
      if (!GameState.landedAt) {
        GameState.landedAt = Date.now();
      }
    });

    GameState.controls = {
      up: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.W, false),
      left: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.A, false),
      down: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.S, false),
      right: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.D, false),
      space: this.input.keyboard.addKey(
        Phaser.Input.Keyboard.KeyCodes.SPACE,
        false
      ),
      enter: this.input.keyboard.addKey(
        Phaser.Input.Keyboard.KeyCodes.ENTER,
        false
      ),
      r: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.R, false),
      cursors: this.input.keyboard.createCursorKeys(),
    };

    this.input.on("pointerdown", () => {
      this.resetScene();
    });

    GameState.controls.up.on("up", () => {
      GameState.jumpReleasedAt = Date.now();
    });
    GameState.controls.cursors.up.on("up", () => {
      GameState.jumpReleasedAt = Date.now();
    });
    this.input.on("pointerup", () => {
      GameState.jumpReleasedAt = Date.now();
    });

    GameState.tucked = false;
    GameState.tuckCount = 0;
    this.lastFlipNumber = 0;
  }

  calculateBoost() {
    const quickness = diff(GameState.landedAt, GameState.jumpReleasedAt);
    if (quickness < 125) {
      GameState.boost = MAX_BOOST;
    } else if (quickness < 250) {
      GameState.boost = MAX_BOOST - 50;
    } else if (quickness < 350) {
      GameState.boost = MAX_BOOST - 100;
    } else {
      GameState.boost = 0;
    }
    const daveBoardDist =
      GameState.dave.x -
      (GameState.springboard.x - GameState.springboard.width / 2);
    if (daveBoardDist > 0) {
      let newRatio = daveBoardDist / GameState.springboard.width;
      newRatio = newRatio <= 1 ? newRatio : 1;
      GameState.boost = GameState.boost * newRatio;
    }
  }

  update() {
    this.physics.world.collide(GameState.dave, [GameState.springboard]);
    this.updateSkyColor();
    this.handleAtmosphere();
    this.playerHandler();
    this.updateClimbDave();
  }

  playerHandler() {
    this.checkForReset();
    if (!GameState.jumping) {
      if (IS_MOBILE) {
        this.playerMobileMovementHandler();
      } else {
        this.playerMovementHandler();
      }
      this.playerFrameHandler();
    }
  }

  playerFrameHandler() {
    if (GameState.jumping) return;
    const dave = GameState.dave;
    if (this.daveIsAboveBoard()) {
      if (dave.angle !== 0) dave.setAngle(0);
      if (this.daveIsTouchingBoard()) {
        if (dave.body.velocity.x > 0) {
          dave.anims.play("walkright", true);
        } else if (dave.body.velocity.x < 0) {
          dave.anims.play("walkleft", true);
        } else if (dave.anims.getName() !== "idle") {
          dave.anims.play("idle", true);
        }
      } else {
        if (dave.body.velocity.y < 0) {
          if (dave.body.velocity.x < 0) dave.setFrame(15);
          else dave.setFrame(6);
        } else {
          if (dave.body.velocity.x < 0) dave.setFrame(11);
          else dave.setFrame(2);
        }
      }
    } else if (!GameState.tucked) {
      if (dave.angle >= -90 && dave.angle <= 90) dave.setFrame(6);
      else dave.setFrame(8);
    }
  }

  updateClimbDave() {
    if (this.climbdave && this.climbdave.visible) {
      if (this.climbdave.y <= 797) {
        this.climbdave.setVelocityY(0);
        this.climbdave.anims.stop();
        this.climbdave.setFrame(0);
      }
    }
  }

  daveIsAboveBoard() {
    const dave = GameState.dave;
    const springboard = GameState.springboard;
    const result =
      dave.x + dave.width / 4 > 0 &&
      dave.x - dave.width / 4 < springboard.x + springboard.width / 2 - 10 &&
      dave.y + dave.height / 2 < springboard.y - springboard.height / 2 + 1;
    if (result) {
      // Reset all per-dive-attempt state — rotation accumulators AND
      // tuck state — so each bounce on the board starts a fresh dive
      // attempt. Without resetting tuckCount/tucked here, a re-bounce
      // would carry the previous attempt's tucks into scoring,
      // subtracting (tuckCount - 1) from each judge's score even
      // though the new attempt only tucked once.
      this.sumRotation = 0;
      this.totalRotations = 0;
      this.previousAngle = 0;
      this.currentAngle = 0;
      this.lastFlipNumber = 0;
      GameState.tuckCount = 0;
      GameState.tucked = false;
    }
    return result;
  }

  daveIsTouchingBoard() {
    const dave = GameState.dave;
    const springboard = GameState.springboard;
    return dave.y + dave.height / 2 >= springboard.y - springboard.height / 2;
  }

  daveIsTucked() {
    const dave = GameState.dave;
    if (GameState.tucked) dave.setFrame(7);
    return dave.frame.name === 7 || GameState.tucked;
  }

  daveJump() {
    const dave = GameState.dave;
    if (!GameState.jumping && dave.anims.getName() !== "jump") {
      GameState.jumping = true;
      GameState.springboard.anims.play("flex", true);
      dave.anims.play("jump", true);
    }
  }

  checkForReset() {
    if (this.diveComplete) return;
    const dave = GameState.dave;
    const springboard = GameState.springboard;
    if (
      dave.body.velocity.y > 0 &&
      dave.x - dave.width / 4 > springboard.x + springboard.width / 2 - 10 &&
      !this.timerStarted
    ) {
      this.timerStart = Date.now();
      this.timerStarted = true;
    }
    if (dave.y > GameState.waterLevel - 15) {
      this.diveComplete = true;
      const heightFromWater = GameState.waterLevel - 797;
      this.stats = {
        height: Math.round((heightFromWater / 2 / 100) * 10) / 10,
        angle: Math.round(dave.angle * 10) / 10,
        tucked: this.daveIsTucked(),
        tuckCount: GameState.tuckCount,
        rotations: Math.round(this.totalRotations * 10) / 10,
        scores: [0, 0, 0],
      };
      const result = this.scoreDive();
      this.runningStreak.setText("streak: " + GameState.streak);
      this.runningScore.setText("score: " + GameState.totalScore);
      this.info.display(
        this,
        result,
        [
          "height: " + this.stats.height + "m",
          "entry angle: " + this.stats.angle,
          "rotations: " + this.stats.rotations,
        ],
        this.stats.emotionFrame,
        this.stats.scores,
        this.sceneHeight
      );
      this.hud.setVisible(false);
      const splash = this.add.sprite(dave.x, GameState.waterLevel - 100, "splash");
      splash.setDepth(14);
      splash.anims.play("splash");
      splash.on(Phaser.Animations.Events.ANIMATION_COMPLETE, () => {
        splash.destroy();
      });
      setTimeout(() => {
        this.readyForReset = true;
        this.gettingoutdave.setVisible(true);
        this.gettingoutdave.play("getout");
        this.gettingoutdave.on(
          Phaser.Animations.Events.ANIMATION_COMPLETE,
          () => {
            this.gettingoutdave.setVisible(false);
            this.climbdave.setVisible(true);
            this.climbdave.play("climb");
            this.climbdave.setVelocityY(-200);
          }
        );
      }, 1000);
    }
    this.countRotations();
  }

  approximateFallTime(startY, endY, gravity, frameRate = 60) {
    let velocity = 0;
    let currentY = startY;
    let time = 0;
    const timeStep = 1 / frameRate;
    while (currentY < endY) {
      velocity += gravity * timeStep;
      currentY += velocity * timeStep;
      time += timeStep;
      if (time > 10) break;
    }
    return time;
  }

  calculateGameLogic() {
    const springboard = GameState.springboard;
    const diveHeight = GameState.waterLevel - springboard.y;
    const fallTime = this.approximateFallTime(
      springboard.y,
      GameState.waterLevel,
      GRAVITY
    );

    const spinVelocityRadPerSec = Phaser.Math.DegToRad(MAX_SPIN_VELOCITY * 0.75);
    const totalRotation = fallTime * spinVelocityRadPerSec;
    const maxFlips = totalRotation / (2 * Math.PI);
    const halfFlips = Math.floor(maxFlips * 2);
    const randomHalfFlips = getRandomInt(1, halfFlips);
    const goalRotations = randomHalfFlips / 2;

    this.goalRotations = goalRotations;

    console.log("🎯 Dive Debug Info:");
    console.log("• Platform Y:", springboard.y.toFixed(2));
    console.log("• Water Y:", GameState.waterLevel.toFixed(2));
    console.log("• Dive Height (waterY - platformY):", diveHeight.toFixed(2));
    console.log("• Approximated Fall Time (s):", fallTime.toFixed(3));
    console.log("• Spin Velocity (deg/s):", MAX_SPIN_VELOCITY.toFixed(2));
    console.log("• Total Rotation (radians):", totalRotation.toFixed(3));
    console.log("• Max Flips:", maxFlips.toFixed(3));
    console.log("• Half-Flips (int):", halfFlips);
    console.log("• Random Half-Flips (selected):", randomHalfFlips / 2);
    console.log("• Goal Rotations:", goalRotations);

    this.add
      .bitmapText(
        WIDTH - 25,
        25,
        "green-arial",
        "GOAL: " +
          this.goalRotations +
          (this.goalRotations < 1.5 ? " FLIP" : " FLIPS"),
        65
      )
      .setOrigin(1, 0)
      .setScrollFactor(0)
      .setDepth(14)
      .setActive(false);
  }

  countRotations() {
    const dave = GameState.dave;
    const daveRotation = Phaser.Math.Angle.Normalize(dave.rotation);
    if (daveRotation !== this.currentAngle) {
      let angleDiff = diff(this.previousAngle, this.currentAngle);
      if (angleDiff > 5) {
        if (daveRotation < 1) {
          this.previousAngle = 0;
        } else if (daveRotation > 5) {
          this.previousAngle = 2 * Math.PI;
        }
        angleDiff = diff(this.previousAngle, this.currentAngle);
      }
      this.sumRotation += angleDiff;
      this.totalRotations = this.sumRotation / (2 * Math.PI);
      this.previousAngle = this.currentAngle;
      this.currentAngle = daveRotation;
      if (this.totalRotations > this.lastFlipNumber) {
        const flipDelta = this.totalRotations - this.lastFlipNumber;
        if (flipDelta >= 1) {
          const roundedRotations = Math.round(this.totalRotations);
          this.add
            .bitmapText(
              dave.x,
              dave.y,
              roundedRotations > this.goalRotations
                ? "red-arial"
                : "green-arial",
              roundedRotations,
              75
            )
            .setDepth(14)
            .setActive(false);
          this.lastFlipNumber = roundedRotations;
        }
      }
    }
  }

  chooseEmotionFrame(angle) {
    angle = Math.abs(angle);
    if (angle < 10 || angle > 170) return 4;
    if ((angle >= 10 && angle < 25) || (angle <= 170 && angle > 155)) return 3;
    if ((angle >= 25 && angle < 45) || (angle <= 155 && angle > 135)) return 2;
    if ((angle >= 45 && angle < 70) || (angle <= 135 && angle > 110)) return 1;
    if (angle >= 70 && angle < 110) return 0;
    return 2;
  }

  scoreDive() {
    if (Math.abs(this.stats.rotations - this.goalRotations) < 0.25) {
      this.stats.emotionFrame = this.chooseEmotionFrame(this.stats.angle);
      this.stats.scores.forEach((_score, index, scores) => {
        switch (this.stats.emotionFrame) {
          case 4:
            scores[index] = 10 - getRandomInt(0, 1) / 2.0 - (GameState.tuckCount - 1);
            break;
          case 3:
            scores[index] = 10 - getRandomInt(3, 6) / 2.0 - (GameState.tuckCount - 1);
            break;
          case 2:
            scores[index] = 10 - getRandomInt(7, 10) / 2.0 - (GameState.tuckCount - 1);
            break;
          case 1:
            scores[index] = 10 - getRandomInt(10, 15) / 2.0 - (GameState.tuckCount - 1);
            break;
          case 0:
            scores[index] = 10 - getRandomInt(14, 18) / 2.0 - (GameState.tuckCount - 1);
            break;
        }
      });
      if (GameState.tuckCount > 1) {
        this.stats.emotionFrame = this.stats.emotionFrame - 1;
      }
      GameState.streak++;
      GameState.totalScore =
        GameState.totalScore +
        this.stats.scores[0] +
        this.stats.scores[1] +
        this.stats.scores[2];
      if (GameState.challengeMode && GameState.totalScore > GameState.highScore) {
        StatsStore.saveHighScore(GameState.totalScore);
        GameState.highScore = GameState.totalScore;
        GameState.highScoreSession = true;
        this.highScoreText.setVisible(true);
        setTimeout(() => {
          this.highScoreText.setVisible(false);
        }, 5000);
      }
      return "SUCCESS";
    }
    this.stats.emotionFrame = 0;
    this.stats.scores.forEach((_score, index, scores) => {
      scores[index] = 0;
    });
    if (GameState.highScoreSession) {
      this.highScorePanel.display(
        this,
        "GAME OVER",
        [
          "",
          "NEW HIGH SCORE: " + GameState.totalScore,
          "",
          "final height: " + this.stats.height + "m",
          "streak: " + GameState.streak + " dives",
        ],
        3,
        null,
        HEIGHT / 2
      );
    }
    GameState.streak = 0;
    GameState.totalScore = 0;
    return "FAILED DIVE";
  }

  resetScene() {
    if (!(this.diveComplete && this.readyForReset)) return;
    if (!GameState.challengeMode) {
      this.scene.restart({ height: getRandomInt(1500, 10000) });
    } else if (GameState.totalScore === 0) {
      this.scene.restart({ height: 1500 });
    } else {
      const streakFactor = 2 * GameState.streak;
      const denominator = streakFactor + 100;
      const streakMultiplier = 1 + streakFactor / denominator;
      const randomHeightIncrease = getRandomInt(0, 500);
      const newPlatformHeight = this.sceneHeight + randomHeightIncrease;
      const finalHeight = Math.round(newPlatformHeight * streakMultiplier);
      this.sceneHeight = finalHeight;
      this.scene.restart({ height: finalHeight });
    }
  }

  playerMovementHandler() {
    const controls = GameState.controls;
    const dave = GameState.dave;
    if (controls.enter.isDown || (controls.space.isDown && this.diveComplete)) {
      this.resetScene();
    }
    if (
      controls.up.isDown ||
      controls.space.isDown ||
      controls.cursors.up.isDown
    ) {
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
    if (
      controls.r.isDown ||
      controls.space.isDown ||
      controls.cursors.up.isDown
    ) {
      if (!this.daveIsAboveBoard()) {
        if (!this.daveIsTucked()) {
          GameState.tucked = true;
          GameState.tuckCount++;
        }
        if (GameState.currentVelocity < MAX_SPIN_VELOCITY - 200) {
          GameState.currentVelocity += 5;
        } else if (GameState.currentVelocity < MAX_SPIN_VELOCITY) {
          GameState.currentVelocity += 1;
        }
        dave.body.setAngularVelocity(GameState.currentVelocity);
      }
    } else {
      GameState.tucked = false;
      GameState.currentVelocity = MIN_SPIN_VELOCITY;
    }
  }

  playerMobileMovementHandler() {
    const hud = this.hud;
    const dave = GameState.dave;
    if (!this.diveComplete) {
      if (this.daveIsAboveBoard()) hud.jumpControls();
      else hud.flipControls();
    }
    if (
      hud.leftButton.isDown ||
      hud.rightButton.isDown ||
      hud.jumpButton.isDown ||
      hud.flipButton.isDown
    ) {
      if (this.diveComplete) {
        this.resetScene();
      } else if (this.daveIsAboveBoard()) {
        if (hud.jumpButton.isDown && this.daveIsTouchingBoard()) {
          this.daveJump();
        }
        if (hud.leftButton.isDown) dave.setVelocityX(-dave.speed);
        if (hud.rightButton.isDown) dave.setVelocityX(dave.speed);
      } else if (hud.flipButton.isDown) {
        if (!this.daveIsTucked()) {
          GameState.tucked = true;
          GameState.tuckCount++;
        } else {
          if (GameState.currentVelocity < MAX_SPIN_VELOCITY - 200) {
            GameState.currentVelocity += 5;
          } else if (GameState.currentVelocity < MAX_SPIN_VELOCITY) {
            GameState.currentVelocity += 1;
          }
        }
        dave.body.setAngularVelocity(GameState.currentVelocity);
      }
    } else {
      GameState.tucked = false;
      GameState.currentVelocity = MIN_SPIN_VELOCITY;
    }
  }

  spawnAtmosphere() {
    const segmentSize = 1000;
    this.clouds = [];
    this.birds = [];
    this.planes = [];
    this.ufos = [];
    this.stars = [];

    for (let s = 0; s < this.sceneHeight; s += segmentSize) {
      const yMin = s;
      const yMax = s + segmentSize;

      const cloudCount = getRandomInt(MIN_CLOUDS, MAX_CLOUDS);
      const birdCount = getRandomInt(MIN_BIRDS, MAX_BIRDS);
      const starMult = 1;

      for (let i = 0; i < cloudCount; i++) {
        const y = getRandomInt(yMin, yMax);
        const x = getRandomInt(-256, WIDTH + 256);

        if (y >= this.middleY) {
          const cloud = this.physics.add.sprite(x, y, "cloud");
          cloud.setFrame(getRandomInt(0, 8));
          cloud.setDepth(1);
          cloud.setScale(getRandomInt(75, 150) / 100);
          cloud.body.setAllowGravity(false);
          cloud.setVelocityX(getRandomInt(CLOUDMINSPEED, CLOUDMAXSPEED));
          this.clouds.push(cloud);
        } else if (y < this.endY) {
          for (let j = 0; j < starMult; j++) {
            const star = this.add
              .sprite(getRandomInt(0, WIDTH), y, "star")
              .setDepth(1);
            star.setScale(0.75);
            star.setRotation(Phaser.Math.FloatBetween(0, 2 * Math.PI));
            this.time.delayedCall(getRandomInt(0, 750), () => {
              star.play("sparkle");
            });
            this.stars.push(star);
          }
        }
      }

      for (let i = 0; i < birdCount; i++) {
        const y = getRandomInt(yMin, yMax);
        const x = getRandomInt(-128, WIDTH + 128);

        if (y >= this.middleY) {
          const bird = this.physics.add.sprite(x, y, "bird");
          bird.body.setAllowGravity(false);
          bird.setVelocityX(-getRandomInt(BIRDMINSPEED, BIRDMAXSPEED));
          this.time.delayedCall(getRandomInt(0, 750), () => {
            bird.play("fly");
          });
          this.birds.push(bird);
        } else if (y >= this.endY) {
          const plane = this.physics.add.sprite(x, y, "plane");
          plane.body.setAllowGravity(false);
          plane.setVelocityX(-getRandomInt(BIRDMINSPEED, BIRDMAXSPEED));
          this.planes.push(plane);
        } else {
          const ufo = this.physics.add.sprite(x, y, "ufo");
          ufo.body.setAllowGravity(false);
          ufo.setVelocityX(-getRandomInt(BIRDMINSPEED, BIRDMAXSPEED));
          this.ufos.push(ufo);
        }
      }
    }
  }

  handleAtmosphere() {
    this.clouds.forEach((cloud) => {
      if (cloud.x >= WIDTH + cloud.width / 2) {
        const y = getRandomInt(this.middleY, this.sceneHeight - 500);
        cloud.setPosition(-cloud.width * 2, y);
        cloud.setVelocityX(getRandomInt(CLOUDMINSPEED, CLOUDMAXSPEED));
        cloud.setFrame(getRandomInt(0, 8));
      }
    });
    this.birds.forEach((bird) => {
      if (bird.x + bird.width / 2 < 0) {
        const y = getRandomInt(this.middleY, this.sceneHeight - 500);
        bird.setPosition(WIDTH + bird.width * 2, y);
        bird.setVelocityX(-getRandomInt(BIRDMINSPEED, BIRDMAXSPEED));
      }
    });
    this.planes.forEach((plane) => {
      if (plane.x + plane.width / 2 < 0) {
        const y = getRandomInt(this.endY, this.middleY);
        plane.setPosition(WIDTH + plane.width * 2, y);
        plane.setVelocityX(-getRandomInt(BIRDMINSPEED, BIRDMAXSPEED));
      }
    });
    this.ufos.forEach((ufo) => {
      if (ufo.x + ufo.width / 2 < 0) {
        const y = getRandomInt(0, this.endY);
        ufo.setPosition(WIDTH + ufo.width * 2, y);
        ufo.setVelocityX(-getRandomInt(BIRDMINSPEED, BIRDMAXSPEED));
      }
    });
  }

  updateSkyColor() {
    const camY = this.cameras.main.scrollY + HEIGHT / 2;
    let color;

    if (camY >= this.middleY) {
      color = START_COLOR;
    } else if (camY >= this.endY) {
      const t = (this.middleY - camY) / (this.middleY - this.endY);
      const interp = Phaser.Display.Color.Interpolate.ColorWithColor(
        Phaser.Display.Color.ValueToColor(START_COLOR),
        Phaser.Display.Color.ValueToColor(MIDDLE_COLOR),
        100,
        t * 100
      );
      color = Phaser.Display.Color.GetColor(interp.r, interp.g, interp.b);
    } else {
      const t = (this.endY - camY) / this.endY;
      const interp = Phaser.Display.Color.Interpolate.ColorWithColor(
        Phaser.Display.Color.ValueToColor(MIDDLE_COLOR),
        Phaser.Display.Color.ValueToColor(END_COLOR),
        100,
        t * 100
      );
      color = Phaser.Display.Color.GetColor(interp.r, interp.g, interp.b);
    }

    this.cameras.main.setBackgroundColor(color);
  }
}
