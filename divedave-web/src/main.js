import { GRAVITY, HEIGHT, WIDTH } from "./util/Constants.js";
import { GameState } from "./util/GameState.js";
import { StatsStore } from "./util/StatsStore.js";
// Query param busts the year-long immutable cache — bump it (with the one in
// index.html) whenever this scene file changes.
import { MainMenuScene } from "./scenes/MainMenuScene.js?v=4.2.1";
import { DiveScene } from "./scenes/DiveScene.js";

GameState.highScore = StatsStore.loadHighScore();

const config = {
  type: Phaser.AUTO,
  backgroundColor: "#bed5ff",
  scale: {
    parent: "phaser-div",
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    width: WIDTH,
    height: HEIGHT,
  },
  physics: {
    default: "arcade",
    arcade: {
      gravity: { y: GRAVITY },
      debug: false,
    },
  },
  input: {
    activePointers: 3,
  },
  dom: {
    createContainer: true,
  },
  scene: [MainMenuScene, DiveScene],
};

// eslint-disable-next-line no-unused-vars
const game = new Phaser.Game(config);
