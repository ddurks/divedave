// Mirrors divedave-ios/divedave Shared/Scenes/DiveScene.swift.
//
// Phase 1 pulled DavePlayer out into its own module with an explicit
// DaveState machine. Things that still live here:
//   - asset preload + animation registration
//   - HUD, InfoPanel, splash + getting-out + climb animations
//   - atmosphere (clouds/birds/planes/UFOs/stars) — extraction deferred
//   - sky-color interpolation
//   - rotation-counting accumulators (per-dive scene state)
//   - scoring (DiveScorer extraction also deferred)

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
import { diff, getRandomInt } from "../util/Utilities.js";
import { Haptics } from "../util/Haptics.js";
import { StatsStore } from "../util/StatsStore.js";
import { HUD } from "../components/controls/HUD.js";
import { InfoPanel } from "../components/menu/InfoPanel.js";
import {
  CameraController,
  ShakeStrength,
} from "../components/scene/CameraController.js";
import {
  BoostTiming,
  DavePlayer,
  DaveState,
} from "../components/scene/DavePlayer.js";
import {
  DiveResult,
  heightInMeters,
  scoreDive,
} from "../components/scene/DiveScorer.js";

// Color-coded label + tint for each BoostTiming tier. Miss has no
// visual — a failed timing reads as "no feedback" rather than a noisy
// red flash, matching iOS.
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

  /** Called by DavePlayer on Grounded entry, and by us on water-splash. */
  resetDiveAttempt() {
    this.sumRotation = 0;
    this.totalRotations = 0;
    this.previousAngle = 0;
    this.currentAngle = 0;
    this.lastFlipNumber = 0;
  }

  /**
   * Called by DavePlayer right after a jump's boost is applied.
   * Surfaces the timing tier visually (springboard tint pulse +
   * PERFECT/GOOD/OK label near Dave) and as a haptic.
   */
  onJumpBoostApplied(timing) {
    const feedback = TIMING_FEEDBACK[timing];
    if (!feedback) {
      // Miss — no flourish, just a faint haptic.
      Haptics.impactLight();
      return;
    }

    const board = GameState.springboard;
    board.setTint(feedback.tint);
    this.time.delayedCall(250, () => board.clearTint());

    // Anchor the label just above the springboard so it reads as
    // "this is about the timing of your push off the board" — matches
    // iOS DiveScene.showBoostTimingFeedback. World-space (default
    // scrollFactor) keeps it pinned to the board as the camera rises.
    const labelY = board.y - board.height / 2 - 10;
    const label = this.add
      .bitmapText(board.x, labelY, feedback.font, feedback.label, 50)
      .setOrigin(0.5)
      .setDepth(15)
      .setScale(0.3)
      .setAlpha(0);

    // Pop in → settle → hold → drift up + fade out. Matches iOS
    // SKAction.sequence timings (120/80/500/400 ms).
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
    this.add.image(205, PLATFORM_TOP_Y, "platformtop").setDepth(10);
    for (
      let i = PLATFORM_SECTION_START_Y;
      i < this.sceneHeight - 200;
      i += 100
    ) {
      this.add.image(205, i, "platformsection").setDepth(12);
    }
    this.add.image(205, this.sceneHeight - 200, "platformbase").setDepth(13);

    // Atmosphere altitude bands stay tied to REF_HEIGHT (world geometry)
    // so a taller device viewport doesn't accidentally push clouds and
    // stars off the world.
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
        50
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

    // Springboard first so the animations registered below can find the
    // sprite key. Player needs the board reference for boost-distance math.
    GameState.springboard = this.physics.add
      .sprite(WIDTH / 4, BOARD_Y, "springboard")
      .setDepth(11);
    GameState.springboard.body.setAllowGravity(false);
    GameState.springboard.body.setImmovable(true);

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

    // Player owns the dave sprite. Built after animations are registered
    // so its anim-complete handler can resolve the "jump" key.
    this.player = new DavePlayer(this, GameState.springboard);
    GameState.dave = this.player.sprite; // legacy globals for code we haven't moved yet

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
        false
      ),
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

    this.input.on("pointerdown", () => this.resetScene());

    GameState.controls.up.on("up", () => this.player.noteJumpReleased());
    GameState.controls.cursors.up.on("up", () =>
      this.player.noteJumpReleased()
    );
    this.input.on("pointerup", () => this.player.noteJumpReleased());
  }

  registerAnimations() {
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
  }

  update() {
    this.physics.world.collide(this.player.sprite, [GameState.springboard]);
    this.updateSkyColor();
    this.handleAtmosphere();
    this.playerHandler();
    this.updateClimbDave();
  }

  playerHandler() {
    this.checkForReset();
    if (this.player.state === DaveState.Launching) return;

    // Keep state in sync with what the geometry says each frame:
    //   - Airborne → Grounded when Dave lands cleanly on the board
    //     (isCleanLanding guards against the single-frame false snap
    //     where Dave is still touching the board geometrically but
    //     already flying upward right after launch).
    //   - Grounded → Airborne when Dave is no longer above the board
    //     (walked off the end, or fell off the front). Without this,
    //     a player who steps off the tip without ever jumping stays
    //     in Grounded forever — jump button stays lit, flip button
    //     stays greyed, and tuck input no-ops. iOS allows this same
    //     transition in its allowedTransitions table.
    //   - Diving is intentionally not Grounded-reachable here: it's
    //     a commit point (iOS parity), collisions are zeroed in
    //     DavePlayer.didEnter(Diving), Dave falls through.
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

  updateClimbDave() {
    if (
      this.climbdave &&
      this.climbdave.visible &&
      this.climbdave.y <= PLATFORM_TOP_Y
    ) {
      this.climbdave.setVelocityY(0);
      this.climbdave.anims.stop();
      this.climbdave.setFrame(0);
    }
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

    const spinVelocityRadPerSec = Phaser.Math.DegToRad(
      MAX_SPIN_VELOCITY * 0.75
    );
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
        this.add
          .bitmapText(
            dave.x,
            dave.y,
            roundedRotations > this.goalRotations ? "red-arial" : "green-arial",
            roundedRotations,
            75
          )
          .setDepth(14)
          .setActive(false);
        Haptics.impactLight();
        this.lastFlipNumber = roundedRotations;
      }
    }
  }

  /**
   * Compute the dive outcome via DiveScorer (pure) and apply the
   * scene-side effects: stash scores/emotion on this.stats, bump
   * session totals, persist high score, show the game-over panel on
   * a streak-ending failure. Returns the result-label text.
   */
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

  /**
   * Unified input handler for desktop + mobile. Reads from both
   * keyboard and HUD buttons; HUD buttons are the only input source on
   * mobile, while desktop layers them onto the keyboard so a player
   * can click jump/flip the same way they'd tap on mobile.
   *
   * Space and cursor.up are jump-only now — the legacy double-duty
   * (also acting as flip when airborne) made it impossible to hold the
   * jump button for a chain-jump without also kicking off a flip.
   * Flip is R or the flip button.
   */
  playerInputHandler() {
    const controls = GameState.controls;
    const hud = this.hud;
    const player = this.player;
    const dave = player.sprite;

    if (controls.enter.isDown || (controls.space.isDown && this.diveComplete)) {
      this.resetScene();
    }

    // Visual enabled state for jump + flip. Jump stays lit in
    // Grounded AND Airborne so the early-tap-before-landing press
    // reads as a real button (DavePlayer buffers it). Flip greys out
    // on the board so a stray click doesn't read as "would have spun".
    if (!this.diveComplete) {
      hud.updateButtons(
        player.state !== DaveState.Diving,
        player.state === DaveState.Airborne || player.state === DaveState.Diving
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
      // applyTuck() is a no-op outside Airborne / Diving.
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

    this.camera.setBackgroundColor(color);
  }
}
