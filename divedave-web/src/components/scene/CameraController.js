// Mirrors divedave-ios/divedave Shared/Components/Scene/CameraController.swift.
//
// Thin wrapper around scene.cameras.main so consumer code uses the
// same vocabulary as iOS (follow, shake, setBounds, etc.) and the
// scene doesn't have to know about Phaser's specific API surface.
//
// Phaser's arcade camera already handles follow + clamp + shake +
// fade, so unlike iOS this isn't reimplementing the math — it's just
// a vocabulary adapter.

export const ShakeStrength = Object.freeze({
  // Intensity values are fractions of the camera dimensions, matching
  // Phaser's shake() API. ~0.005 ≈ 6 px on a 1250-wide camera.
  Light: 0.004,
  Medium: 0.008,
  Heavy: 0.015,
});

export class CameraController {
  constructor(scene) {
    this.scene = scene;
    this.camera = scene.cameras.main;
  }

  follow(target) {
    this.camera.startFollow(target);
    return this;
  }

  setBounds(x, y, width, height) {
    this.camera.setBounds(x, y, width, height);
    return this;
  }

  setBackgroundColor(color) {
    this.camera.setBackgroundColor(color);
    return this;
  }

  fadeOut(durationMs) {
    this.camera.fadeOut(durationMs);
  }

  /**
   * Kick off a screen shake. Intensity is the peak displacement
   * (camera-dimension fraction). Use ShakeStrength.* for the standard
   * tiers used by the scene's impact callbacks.
   */
  shake(intensity = ShakeStrength.Light, durationMs = 150) {
    this.camera.shake(durationMs, intensity);
  }

  get scrollY() {
    return this.camera.scrollY;
  }
}
