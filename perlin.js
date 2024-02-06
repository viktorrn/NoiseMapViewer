// Perlin noise function (a basic implementation)
class Perlin {
    constructor() {
        this.permutation = [];
        let p = [];
        for (let i = 0; i < 256; i++) {
            p[i] = Math.floor(Math.random() * 256);
        }
        // Duplicate the permutation to avoid overflow
        for (let i = 0; i < 512; i++) {
            this.permutation[i] = p[i & 255];
        }
    }

    fade(t) {
        return t * t * t * (t * (t * 6 - 15) + 10);
    }

    lerp(t, a, b) {
        return a + t * (b - a);
    }

    grad(hash, x, y, z) {
        const h = hash & 15;
        const u = h < 8 ? x : y;
        const v = h < 4 ? y : h === 12 || h === 14 ? x : z;
        return ((h & 1) === 0 ? u : -u) + ((h & 2) === 0 ? v : -v);
    }

    noise(x, y, z) {
        const p = this.permutation;
        const floorX = Math.floor(x) & 255,
              floorY = Math.floor(y) & 255,
              floorZ = Math.floor(z) & 255;
        x -= Math.floor(x);
        y -= Math.floor(y);
        z -= Math.floor(z);
        const u = this.fade(x),
              v = this.fade(y),
              w = this.fade(z);
        const a = p[floorX] + floorY,
              aa = p[a] + floorZ,
              ab = p[a + 1] + floorZ,
              b = p[floorX + 1] + floorY,
              ba = p[b] + floorZ,
              bb = p[b + 1] + floorZ;

        return this.lerp(w, this.lerp(v, this.lerp(u, this.grad(p[aa], x, y, z),
                                                        this.grad(p[ba], x - 1, y, z)),
                                        this.lerp(u, this.grad(p[ab], x, y - 1, z),
                                                      this.grad(p[bb], x - 1, y - 1, z))),
                            this.lerp(v, this.lerp(u, this.grad(p[aa + 1], x, y, z - 1),
                                                      this.grad(p[ba + 1], x - 1, y, z - 1)),
                                      this.lerp(u, this.grad(p[ab + 1], x, y - 1, z - 1),
                                                    this.grad(p[bb + 1], x - 1, y - 1, z - 1))));
    }
}

// Function to generate 2D Perlin noise and return it as a 1D array
function generatePerlinNoise(width, height, scale = 1.0) {
    const perlin = new Perlin();
    const noiseArray = [];
    for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
            const value = perlin.noise(x * scale, y * scale, 0);
            noiseArray.push(value);
        }
    }
    return noiseArray;
}


export { generatePerlinNoise };