import {
  BIRDMAXSPEED,
  BIRDMINSPEED,
  BOARD_Y,
  CLOUDMAXSPEED,
  CLOUDMINSPEED,
  END_COLOR,
  GRAVITY,
  HEIGHT,
  MAX_CLOUDS,
  MAX_SPIN_VELOCITY,
  MIDDLE_COLOR,
  MIN_BIRDS,
  MAX_BIRDS,
  MIN_CLOUDS,
  PLATFORM_SECTION_START_Y,
  PLATFORM_TOP_Y,
  REF_HEIGHT,
  START_COLOR,
  TIMING_TINT_GOOD,
  TIMING_TINT_OK,
  TIMING_TINT_PERFECT,
  WIDTH,
} from "../util/Constants.js";
import { GameState } from "../util/GameState.js";
import {
  diff,
  fadeOutScene,
  getRandomInt,
  makeShadowedBitmapText,
} from "../util/Utilities.js";
import { Haptics } from "../util/Haptics.js";
import { StatsStore } from "../util/StatsStore.js";
import { HUD } from "../components/controls/HUD.js";
import { InfoPanel } from "../components/menu/InfoPanel.js";
import {
  CameraController,
  ShakeStrength,
} from "../components/scene/CameraController.js";
import { DavePlayer, DaveState } from "../components/scene/DavePlayer.js";
import {
  BoostTiming,
  DiveResult,
  heightInMeters,
  scoreDive,
} from "../components/scene/DiveScorer.js";

const TIMING_FEEDBACK = {
  [BoostTiming.Perfect]: {
    label: "PERFECT!",
    font: "green-arial",
    tint: TIMING_TINT_PERFECT,
  },
  [BoostTiming.Good]: {
    label: "GOOD",
    font: "yellow-arial",
    tint: TIMING_TINT_GOOD,
  },
  [BoostTiming.Ok]: {
    label: "OK",
    font: "red-arial",
    tint: TIMING_TINT_OK,
  },
};

// Mirrored in divedave-ios GetOut.
const GETTING_OUT = {
  ladderX: 937,
  ladderYUp: 191,
  ladderScale: 0.87,
  emergeYUp: 207,
  deckYUp: 325,
  walkSpeed: 0.45,
  turnFrameMs: 70,
  climbX: 28,
  climbSpeed: 200,
  ladderOverlapPx: 70,
};

export class DiveScene extends Phaser.Scene {
  constructor() {
    super("DiveScene");
  }

  init(data) {
    this.sceneHeight = data.height;
    this.diveComplete = false;
    this.readyForReset = false;
    this.resetDiveAttempt();
    this.stats = {
      angle: 0,
      tucked: false,
      tuckCount: 0,
      rotations: 0,
      scores: [0, 0, 0],
    };
    this.timerStarted = false;
  }

  resetDiveAttempt() {
    this.sumRotation = 0;
    this.totalRotations = 0;
    this.previousAngle = 0;
    this.currentAngle = 0;
    this.lastFlipNumber = 0;
  }

  onJumpBoostApplied(timing) {
    const feedback = TIMING_FEEDBACK[timing];
    if (!feedback) {
      Haptics.impactLight();
      return;
    }

    const board = GameState.springboard;
    board.setTint(feedback.tint);
    this.time.delayedCall(250, () => board.clearTint());

    const labelY = board.y - board.height / 2 - 10;
    const label = makeShadowedBitmapText(
      this,
      board.x,
      labelY,
      feedback.font,
      feedback.label,
      50,
      4,
    )
      .setDepth(15)
      .setScale(0.3)
      .setAlpha(0);

    this.tweens.chain({
      targets: label,
      tweens: [
        { scaleX: 1.4, scaleY: 1.4, alpha: 1, duration: 120 },
        { scaleX: 1.0, scaleY: 1.0, duration: 80 },
        { y: "-=20", alpha: 0, duration: 400, delay: 500 },
      ],
      onComplete: () => label.destroy(),
    });

    if (timing === BoostTiming.Perfect) {
      Haptics.impactHeavy();
      this.camera.shake(ShakeStrength.Medium, 180);
    } else if (timing === BoostTiming.Good) {
      Haptics.impactMedium();
      this.camera.shake(ShakeStrength.Light, 150);
    } else {
      Haptics.impactLight();
      this.camera.shake(ShakeStrength.Light, 120);
    }
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
      "assets/fonts/Arial20.xml",
    );
    this.load.bitmapFont(
      "green-arial",
      "assets/fonts/green-arial.png",
      "assets/fonts/green-arial.xml",
    );
    this.load.bitmapFont(
      "yellow-arial",
      "assets/fonts/yellow-arial.png",
      "assets/fonts/yellow-arial.xml",
    );
    this.load.bitmapFont(
      "red-arial",
      "assets/fonts/red-arial.png",
      "assets/fonts/red-arial.xml",
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
      "assets/divedave-spritesheet_gettingout.png",
      {
        frameWidth: 256,
        frameHeight: 256,
      },
    );
    this.load.image("ladder", "assets/ladder.png");
    this.load.image("plane", "assets/plane.png");
    this.load.image("ufo", "assets/ufo.png");
    this.load.spritesheet("menu-button", "assets/menu-spritesheet.png", {
      frameWidth: 256,
      frameHeight: 256,
      margin: 0,
      spacing: 0,
    });
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
    // Mobile browser chrome (Safari address bar) collapses/expands
    // without Phaser's ScaleManager recomputing; refresh on every scene
    // entry to keep the canvas pinned to the current viewport.
    this.scale.refresh();

    this.physics.world.setBounds(0, 0, WIDTH, this.sceneHeight);
    this.add.image(WIDTH / 2, this.sceneHeight - 250, "landscape").setDepth(2);
    this.add.image(205, PLATFORM_TOP_Y, "platformtop").setDepth(10);
    for (
      let i = PLATFORM_SECTION_START_Y;
      i < this.sceneHeight - 200;
      i += 100
    ) {
      this.add.image(205, i, "platformsection").setDepth(12);
    }
    this.add.image(205, this.sceneHeight - 200, "platformbase").setDepth(13);

    this.startY = this.sceneHeight - REF_HEIGHT;
    this.middleY = this.sceneHeight - REF_HEIGHT * 2;
    this.endY = this.sceneHeight - REF_HEIGHT * 4;

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
    let heightFromWater = GameState.waterLevel - PLATFORM_TOP_Y;
    this.add
      .bitmapText(
        WIDTH - 200,
        PLATFORM_TOP_Y - 10,
        "black-arial",
        "   " + Math.round((heightFromWater / 2 / 100) * 10) / 10 + "m",
        50,
      )
      .setDepth(14)
      .setActive(false);
    heightFromWater--;
    for (let i = PLATFORM_TOP_Y + 1; i < GameState.waterLevel; i++) {
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

    // Springboard must exist before registerAnimations() so the "flex"
    // animation can resolve the sprite key.
    GameState.springboard = this.physics.add
      .sprite(WIDTH / 4, BOARD_Y, "springboard")
      .setDepth(11);
    GameState.springboard.body.setAllowGravity(false);
    GameState.springboard.body.setImmovable(true);

    this.gettingoutdave = this.add
      .sprite(
        GETTING_OUT.ladderX,
        this.sceneHeight - GETTING_OUT.emergeYUp,
        "gettingoutdave",
      )
      .setDepth(12);
    this.gettingoutdave.setVisible(false);

    this.poolLadder = this.add
      .image(
        GETTING_OUT.ladderX,
        this.sceneHeight - GETTING_OUT.ladderYUp,
        "ladder",
      )
      .setScale(GETTING_OUT.ladderScale)
      .setDepth(13)
      .setVisible(false);

    this.climbdave = this.add
      .sprite(
        GETTING_OUT.climbX,
        this.sceneHeight - GETTING_OUT.deckYUp,
        "dave",
      )
      .setDepth(8);
    this.climbdave.setVisible(false);
    this.goState = "idle";

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
    this.hud.onMenuPressed = () => {
      GameState.streak = 0;
      GameState.totalScore = 0;
      GameState.highScoreSession = false;
      fadeOutScene("MainMenu", this);
    };

    this.registerAnimations();
    this.spawnAtmosphere();

    const water = this.add
      .sprite(WIDTH / 2, this.sceneHeight - 100, "water")
      .setDepth(11);
    water.anims.play("idlewater");
    const outerwater = this.add
      .sprite(WIDTH / 2, this.sceneHeight - 50, "water")
      .setDepth(13);
    outerwater.anims.play("idlewater");

    // Built after registerAnimations() so the anim-complete handler can
    // resolve the "jump" key.
    this.player = new DavePlayer(this, GameState.springboard);
    GameState.dave = this.player.sprite;

    this.calculateGameLogic();

    this.camera = new CameraController(this);
    this.camera.follow(this.player.sprite);
    this.camera.setBounds(0, 0, WIDTH, this.sceneHeight);

    this.physics.add.collider(this.player.sprite, GameState.springboard, () => {
      this.player.noteBoardLanded();
    });

    GameState.controls = {
      up: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.W, false),
      left: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.A, false),
      down: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.S, false),
      right: this.input.keyboard.addKey(
        Phaser.Input.Keyboard.KeyCodes.D,
        false,
      ),
      space: this.input.keyboard.addKey(
        Phaser.Input.Keyboard.KeyCodes.SPACE,
        false,
      ),
      enter: this.input.keyboard.addKey(
        Phaser.Input.Keyboard.KeyCodes.ENTER,
        false,
      ),
      r: this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.R, false),
      cursors: this.input.keyboard.createCursorKeys(),
    };

    this.input.on("pointerdown", () => this.resetScene());

    GameState.controls.up.on("up", () => this.player.noteJumpReleased());
    GameState.controls.cursors.up.on("up", () =>
      this.player.noteJumpReleased(),
    );
    this.input.on("pointerup", () => this.player.noteJumpReleased());
  }

  registerAnimations() {
    this.anims.create({
      key: "idle",
      frameRate: 8,
      frames: this.anims.generateFrameNumbers("dave", {
        frames: [15, 15, 15, 15, 15, 16, 17, 18],
      }),
      repeat: -1,
    });
    this.anims.create({
      key: "walk",
      frameRate: 8,
      frames: this.anims.generateFrameNumbers("dave", { frames: [5, 6, 7, 8] }),
      repeat: -1,
    });
    this.anims.create({
      key: "jump",
      frameRate: 12,
      frames: this.anims.generateFrameNumbers("dave", { frames: [10, 10, 11] }),
    });
    this.anims.create({
      key: "getout",
      frameRate: 10,
      frames: this.anims.generateFrameNumbers("gettingoutdave", {
        start: 0,
        end: 9,
      }),
      repeat: 0,
    });
    this.anims.create({
      key: "climb",
      frameRate: 8,
      frames: this.anims.generateFrameNumbers("dave", {
        frames: [20, 21, 22, 23],
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
    this.anims.create({
      key: "menuClicked",
      frameRate: 8,
      frames: this.anims.generateFrameNumbers("menu-button", {
        frames: [1, 2, 3, 4, 4, 3, 2, 1, 0, 1],
      }),
      repeat: 0,
    });
  }

  update(time, delta) {
    this.updateBoardCollisionGuard();
    this.physics.world.collide(this.player.sprite, [GameState.springboard]);
    this.updateSkyColor();
    this.handleAtmosphere();
    this.playerHandler();
    this.updateGettingOut(delta);
  }

  // Once Dave has dropped past the board entirely, drop board collisions so
  // he can't walk off the side, drift back, and tip onto the board's side
  // or get pinned by it. Threshold is the board's *bottom* edge (one
  // full board-height of slack past the top) so floating-point overlap
  // during contact resolution at launch/landing doesn't false-trigger.
  updateBoardCollisionGuard() {
    if (this.player.state !== DaveState.Airborne) return;
    const dave = this.player.sprite;
    const board = GameState.springboard;
    if (dave.y + dave.height / 2 > board.y + board.height / 2) {
      dave.body.checkCollision.none = true;
    }
  }

  playerHandler() {
    this.checkForReset();
    if (this.player.state === DaveState.Launching) return;

    if (
      this.player.state === DaveState.Airborne &&
      this.player.isAboveBoard() &&
      this.player.isTouchingBoard() &&
      this.player.isCleanLanding()
    ) {
      this.player.transition(DaveState.Grounded);
    } else if (
      this.player.state === DaveState.Grounded &&
      !this.player.isAboveBoard()
    ) {
      this.player.transition(DaveState.Airborne);
    }

    this.playerInputHandler();
    this.player.updateFrame();
  }

  startGettingOut() {
    this.goState = "emerge";
    this.gettingoutdave.setVisible(true);
    this.poolLadder.setVisible(false);
    this.gettingoutdave.play("getout");
    this.gettingoutdave.once(
      Phaser.Animations.Events.ANIMATION_COMPLETE,
      () => {
        this.gettingoutdave.setVisible(false);
        this.climbdave
          .setPosition(
            GETTING_OUT.ladderX,
            this.sceneHeight - GETTING_OUT.deckYUp,
          )
          .setFlipX(true)
          .setFrame(4)
          .setVisible(true);
        this.startTurn("turn1");
      },
    );
  }

  startTurn(which) {
    this.goState = which;
    this.goTurnElapsed = 0;
    if (which === "turn1") {
      this.goTurnFrames = [4, 3, 2];
      this.goTurnFlips = [true, true, true];
    } else {
      this.goTurnFrames = [2, 1, 0, 1, 2];
      this.goTurnFlips = [true, true, false, false, false];
    }
  }

  updateGettingOut(delta) {
    switch (this.goState) {
      case "turn1":
      case "turn2":
        this.advanceTurn(delta);
        break;
      case "walk":
        this.advanceWalk(delta);
        break;
      case "climb":
        this.advanceClimb(delta);
        break;
      default:
        break;
    }
    this.updateLadderOverlay();
  }

  advanceTurn(delta) {
    this.goTurnElapsed += delta;
    const step = Math.floor(this.goTurnElapsed / GETTING_OUT.turnFrameMs);
    if (step >= this.goTurnFrames.length) {
      if (this.goState === "turn1") {
        this.goState = "walk";
        this.climbdave.setFlipX(true).play("walk");
      } else {
        this.goState = "climb";
        this.climbdave.anims.stop();
        this.climbdave.setFlipX(false).play("climb");
      }
      return;
    }
    this.climbdave.setFrame(this.goTurnFrames[step]);
    this.climbdave.setFlipX(this.goTurnFlips[step]);
  }

  advanceWalk(delta) {
    this.climbdave.x -= GETTING_OUT.walkSpeed * delta;
    if (this.climbdave.x <= GETTING_OUT.climbX) {
      this.climbdave.x = GETTING_OUT.climbX;
      this.climbdave.anims.stop();
      this.startTurn("turn2");
    }
  }

  advanceClimb(delta) {
    this.climbdave.y -= (GETTING_OUT.climbSpeed * delta) / 1000;
    if (this.climbdave.y <= PLATFORM_TOP_Y) {
      this.climbdave.y = PLATFORM_TOP_Y;
      this.climbdave.anims.stop();
      this.climbdave.setFrame(20);
      this.goState = "done";
    }
  }

  updateLadderOverlay() {
    if (this.goState === "turn1") {
      this.poolLadder.setVisible(true);
      return;
    }
    if (this.goState === "walk") {
      const overlap =
        this.climbdave.x > GETTING_OUT.ladderX - GETTING_OUT.ladderOverlapPx;
      this.poolLadder.setVisible(overlap);
      return;
    }
    this.poolLadder.setVisible(false);
  }

  checkForReset() {
    if (this.diveComplete) return;
    const dave = this.player.sprite;
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
      this.player.transition(DaveState.Splashed);
      this.camera.shake(ShakeStrength.Heavy, 250);
      this.stats = {
        height: heightInMeters(PLATFORM_TOP_Y, GameState.waterLevel),
        angle: Math.round(dave.angle * 10) / 10,
        tucked: this.player.isTucked(),
        tuckCount: this.player.tuckCount,
        rotations: Math.round(this.totalRotations * 10) / 10,
        scores: [0, 0, 0],
      };
      const result = this.applyDiveOutcome();
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
        this.sceneHeight,
      );
      this.hud.setVisible(false);
      const splash = this.add.sprite(
        dave.x,
        GameState.waterLevel - 100,
        "splash",
      );
      splash.setDepth(14);
      splash.anims.play("splash");
      splash.on(Phaser.Animations.Events.ANIMATION_COMPLETE, () => {
        splash.destroy();
      });
      setTimeout(() => {
        this.readyForReset = true;
        this.startGettingOut();
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
    const fallTime = this.approximateFallTime(
      springboard.y,
      GameState.waterLevel,
      GRAVITY,
    );

    const spinVelocityRadPerSec = Phaser.Math.DegToRad(
      MAX_SPIN_VELOCITY * 0.75,
    );
    const totalRotation = fallTime * spinVelocityRadPerSec;
    const maxFlips = totalRotation / (2 * Math.PI);
    const halfFlips = Math.floor(maxFlips * 2);
    const randomHalfFlips = getRandomInt(1, halfFlips);
    const goalRotations = randomHalfFlips / 2;

    this.goalRotations = goalRotations;

    this.add
      .bitmapText(
        WIDTH - 25,
        25,
        "green-arial",
        "GOAL: " +
          this.goalRotations +
          (this.goalRotations < 1.5 ? " FLIP" : " FLIPS"),
        65,
      )
      .setOrigin(1, 0)
      .setScrollFactor(0)
      .setDepth(14)
      .setActive(false);
  }

  countRotations() {
    const dave = this.player.sprite;
    const daveRotation = Phaser.Math.Angle.Normalize(dave.rotation);
    if (daveRotation === this.currentAngle) return;

    let angleDiff = diff(this.previousAngle, this.currentAngle);
    if (angleDiff > 5) {
      if (daveRotation < 1) this.previousAngle = 0;
      else if (daveRotation > 5) this.previousAngle = 2 * Math.PI;
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
        makeShadowedBitmapText(
          this,
          dave.x,
          dave.y,
          roundedRotations > this.goalRotations ? "red-arial" : "green-arial",
          roundedRotations,
          75,
          5,
        )
          .setDepth(14)
          .setActive(false);
        Haptics.impactLight();
        this.lastFlipNumber = roundedRotations;
      }
    }
  }

  applyDiveOutcome() {
    const outcome = scoreDive({
      goalRotations: this.goalRotations,
      rotations: this.stats.rotations,
      angle: this.stats.angle,
      tuckCount: this.player.tuckCount,
    });
    this.stats.emotionFrame = outcome.emotionFrame;
    this.stats.scores = outcome.scores;

    if (outcome.result === DiveResult.Success) {
      GameState.streak++;
      GameState.totalScore +=
        outcome.scores[0] + outcome.scores[1] + outcome.scores[2];
      if (
        GameState.challengeMode &&
        GameState.totalScore > GameState.highScore
      ) {
        StatsStore.saveHighScore(GameState.totalScore);
        GameState.highScore = GameState.totalScore;
        GameState.highScoreSession = true;
        this.highScoreText.setVisible(true);
        this.time.delayedCall(5000, () => this.highScoreText.setVisible(false));
      }
      return "SUCCESS";
    }

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
        HEIGHT / 2,
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

  playerInputHandler() {
    const controls = GameState.controls;
    const hud = this.hud;
    const player = this.player;
    const dave = player.sprite;

    if (controls.enter.isDown || (controls.space.isDown && this.diveComplete)) {
      this.resetScene();
    }

    if (!this.diveComplete) {
      hud.updateButtons(
        player.state !== DaveState.Diving,
        player.state === DaveState.Airborne ||
          player.state === DaveState.Diving,
      );
    }

    const leftDown =
      controls.left.isDown ||
      controls.cursors.left.isDown ||
      hud.leftButton.isDown;
    const rightDown =
      controls.right.isDown ||
      controls.cursors.right.isDown ||
      hud.rightButton.isDown;
    if (leftDown) dave.setVelocityX(-dave.speed);
    if (rightDown) dave.setVelocityX(dave.speed);

    const jumpDown =
      controls.up.isDown ||
      controls.space.isDown ||
      controls.cursors.up.isDown ||
      hud.jumpButton.isDown;
    if (jumpDown && player.isAboveBoard() && player.isTouchingBoard()) {
      player.tryJump();
    }

    const flipDown = controls.r.isDown || hud.flipButton.isDown;
    if (flipDown) {
      player.applyTuck();
    } else {
      player.releaseTuck();
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
    const camY = this.camera.scrollY + HEIGHT / 2;
    let color;

    if (camY >= this.middleY) {
      color = START_COLOR;
    } else if (camY >= this.endY) {
      const t = (this.middleY - camY) / (this.middleY - this.endY);
      const interp = Phaser.Display.Color.Interpolate.ColorWithColor(
        Phaser.Display.Color.ValueToColor(START_COLOR),
        Phaser.Display.Color.ValueToColor(MIDDLE_COLOR),
        100,
        t * 100,
      );
      color = Phaser.Display.Color.GetColor(interp.r, interp.g, interp.b);
    } else {
      const t = (this.endY - camY) / this.endY;
      const interp = Phaser.Display.Color.Interpolate.ColorWithColor(
        Phaser.Display.Color.ValueToColor(MIDDLE_COLOR),
        Phaser.Display.Color.ValueToColor(END_COLOR),
        100,
        t * 100,
      );
      color = Phaser.Display.Color.GetColor(interp.r, interp.g, interp.b);
    }

    this.camera.setBackgroundColor(color);
  }
}
