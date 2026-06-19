export const ShakeStrength = Object.freeze({
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

  shake(intensity = ShakeStrength.Light, durationMs = 150) {
    this.camera.shake(durationMs, intensity);
  }

  get scrollY() {
    return this.camera.scrollY;
  }
}
