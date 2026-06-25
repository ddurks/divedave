import {
  BIRDMAXSPEED,
  BIRDMINSPEED,
  BIRD_PARALLAX,
  CLOUDMAXSPEED,
  CLOUDMINSPEED,
  CLOUD_PARALLAX,
  MAX_BIRDS,
  MAX_CLOUDS,
  MIN_BIRDS,
  MIN_CLOUDS,
  PLANE_PARALLAX,
  STAR_PARALLAX,
  UFO_PARALLAX,
  WIDTH,
} from "../../util/Constants.js";
import { getRandomInt } from "../../util/Utilities.js";

const SEGMENT = 1000;
const FADE_MARGIN = 500;

const Motion = {
  Stationary: "stationary",
  DriftRight: "driftRight",
  DriftLeft: "driftLeft",
};

// Mirrors divedave-ios Atmosphere. Three levels, going up: clouds/birds at the
// ground, planes in the middle, stars/ufos in space, split at middleY and endY
// (the same pin points as old-web and iOS). Each level's sprites are kept
// inside their world-Y band by wrapping, so a level is on screen while the
// camera overlaps its band and absent otherwise; sprites fade within
// FADE_MARGIN of a band edge so the wrap teleport stays hidden rather than
// popping "behind an invisible wall." Parallax comes from offsetting each
// level against the camera by (1 - parallaxFactor); deeper levels track the
// camera more and so drift slower.
export class Atmosphere {
  constructor(scene, sceneHeight, middleY, endY) {
    this.scene = scene;
    this.referenceScrollY = null;
    this.layers = Atmosphere.buildLayers(sceneHeight, middleY, endY);
    this.layers.forEach((layer) => this.spawnLayer(layer));
  }

  static buildLayers(sceneHeight, middleY, endY) {
    const layers = [];
    const add = (bandLow, bandHigh, config) => {
      const low = Math.max(0, bandLow);
      const high = Math.min(sceneHeight, bandHigh);
      if (low >= high) return;
      layers.push({ ...config, bandLow: low, bandHigh: high, sprites: [] });
    };

    add(0, endY, {
      name: "stars",
      spriteKey: "star",
      animKey: "sparkle",
      animDelayRange: [0, 750],
      scaleRange: [0.75, 0.75],
      randomRotation: true,
      motion: Motion.Stationary,
      parallax: STAR_PARALLAX,
      depth: 1,
      countRange: [MIN_CLOUDS * 2, MAX_CLOUDS * 2],
      cap: 600,
      xPadding: 0,
    });

    add(middleY, sceneHeight, {
      name: "clouds",
      spriteKey: "cloud",
      frameRange: [0, 8],
      scaleRange: [0.75, 1.5],
      motion: Motion.DriftRight,
      speedRange: [CLOUDMINSPEED, CLOUDMAXSPEED],
      parallax: CLOUD_PARALLAX,
      depth: 0,
      countRange: [MIN_CLOUDS, MAX_CLOUDS],
      cap: 200,
      xPadding: 256,
    });

    add(middleY, sceneHeight, {
      name: "birds",
      spriteKey: "bird",
      animKey: "fly",
      animDelayRange: [0, 750],
      scaleRange: [1, 1],
      motion: Motion.DriftLeft,
      speedRange: [BIRDMINSPEED, BIRDMAXSPEED],
      parallax: BIRD_PARALLAX,
      depth: 0,
      countRange: [MIN_BIRDS, MAX_BIRDS],
      cap: 80,
      xPadding: 128,
    });

    add(endY, middleY, {
      name: "planes",
      spriteKey: "plane",
      scaleRange: [1, 1],
      motion: Motion.DriftLeft,
      speedRange: [BIRDMINSPEED, BIRDMAXSPEED],
      parallax: PLANE_PARALLAX,
      depth: 1,
      countRange: [MIN_BIRDS, MAX_BIRDS],
      cap: 80,
      xPadding: 128,
    });

    // Front-most atmosphere, mirroring iOS zPosition order, while staying
    // below the landscape (depth 2).
    add(0, endY, {
      name: "ufos",
      spriteKey: "ufo",
      scaleRange: [1, 1],
      motion: Motion.DriftLeft,
      speedRange: [BIRDMINSPEED, BIRDMAXSPEED],
      parallax: UFO_PARALLAX,
      depth: 1.9,
      countRange: [MIN_BIRDS, MAX_BIRDS],
      cap: 80,
      xPadding: 128,
    });

    return layers;
  }

  spawnLayer(layer) {
    const first = layer.bandLow + SEGMENT;
    const last = layer.bandHigh + SEGMENT;
    for (let seg = first; seg < last; seg += SEGMENT) {
      const count = getRandomInt(layer.countRange[0], layer.countRange[1]);
      const yMin = Math.max(layer.bandLow, seg - SEGMENT);
      const yMax = Math.min(layer.bandHigh, seg);
      if (yMin >= yMax) continue;
      for (let i = 0; i < count; i++) {
        if (layer.sprites.length >= layer.cap) return;
        this.spawnEntity(layer, getRandomInt(yMin, yMax));
      }
    }
  }

  spawnEntity(layer, anchorY) {
    const x = getRandomInt(-layer.xPadding, WIDTH + layer.xPadding);
    const sprite = this.scene.add
      .sprite(x, anchorY, layer.spriteKey)
      .setDepth(layer.depth);

    const [scaleLow, scaleHigh] = layer.scaleRange;
    sprite.setScale(
      scaleLow === scaleHigh
        ? scaleLow
        : getRandomInt(scaleLow * 100, scaleHigh * 100) / 100,
    );

    if (layer.frameRange) {
      sprite.setFrame(getRandomInt(layer.frameRange[0], layer.frameRange[1]));
    }
    if (layer.randomRotation) {
      sprite.setRotation(Phaser.Math.FloatBetween(0, 2 * Math.PI));
    }
    if (layer.animKey) {
      const key = layer.animKey;
      this.scene.time.delayedCall(
        getRandomInt(layer.animDelayRange[0], layer.animDelayRange[1]),
        () => sprite.play(key),
      );
    }

    layer.sprites.push({
      sprite,
      anchorY,
      halfWidth: sprite.displayWidth / 2,
      vx: Atmosphere.driftVelocity(layer),
    });
  }

  static driftVelocity(layer) {
    if (layer.motion === Motion.DriftRight) {
      return getRandomInt(layer.speedRange[0], layer.speedRange[1]);
    }
    if (layer.motion === Motion.DriftLeft) {
      return -getRandomInt(layer.speedRange[0], layer.speedRange[1]);
    }
    return 0;
  }

  update(scrollY, viewHeight, delta) {
    if (this.referenceScrollY === null) {
      this.referenceScrollY = scrollY;
    }
    const cameraDelta = scrollY - this.referenceScrollY;
    const dt = delta / 1000;

    for (const layer of this.layers) {
      const offset = cameraDelta * (1 - layer.parallax);
      const bandHeight = layer.bandHigh - layer.bandLow;
      // Fade sprites out as they near a band edge so the modulo wrap (the
      // teleport that keeps them inside the band) lands while they're invisible
      // — otherwise they pop "behind an invisible wall" at the edge.
      const fade = Math.min(FADE_MARGIN, bandHeight / 2);

      for (const entity of layer.sprites) {
        if (layer.motion !== Motion.Stationary) {
          entity.sprite.x += entity.vx * dt;
          this.recycleHorizontal(layer, entity, scrollY, offset, viewHeight);
        }
        const y =
          layer.bandLow + Atmosphere.mod(entity.anchorY + offset - layer.bandLow, bandHeight);
        entity.sprite.y = y;
        const edgeDist = Math.min(y - layer.bandLow, layer.bandHigh - y);
        entity.sprite.alpha = Math.min(1, edgeDist / fade);
      }
    }
  }

  recycleHorizontal(layer, entity, scrollY, offset, viewHeight) {
    const { sprite, halfWidth } = entity;
    const offRight =
      layer.motion === Motion.DriftRight && sprite.x >= WIDTH + halfWidth;
    const offLeft =
      layer.motion === Motion.DriftLeft && sprite.x + halfWidth < 0;
    if (!offRight && !offLeft) return;

    // Re-enter from the far side at a fresh on-screen height within the band.
    entity.anchorY = scrollY - offset + getRandomInt(0, viewHeight);
    sprite.x = offRight ? -halfWidth * 4 : WIDTH + halfWidth * 4;
    entity.vx = Atmosphere.driftVelocity(layer);
    if (layer.frameRange) {
      sprite.setFrame(getRandomInt(layer.frameRange[0], layer.frameRange[1]));
    }
  }

  static mod(value, modulus) {
    if (modulus <= 0) return 0;
    const r = value % modulus;
    return r < 0 ? r + modulus : r;
  }
}
