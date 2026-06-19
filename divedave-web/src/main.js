// Entry point. Mirrors divedave-ios/divedave iOS/GameViewController.swift
// (the place that creates the SKView + presents the initial scene).

import { GRAVITY, HEIGHT, WIDTH } from "./util/Constants.js";
import { GameState } from "./util/GameState.js";
import { StatsStore } from "./util/StatsStore.js";
import { MainMenuScene } from "./scenes/MainMenuScene.js";
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
