// Perlin noise function (a basic implementation)
class Perlin {
    permutation = [ 
        151, 160, 137,  91,  90,  15, 131,  13, 201,  95,  96,  53, 194, 233,   7, 225,
        140,  36, 103,  30,  69, 142,   8,  99,  37, 240,  21,  10,  23, 190,   6, 148,
        247, 120, 234,  75,   0,  26, 197,  62,  94, 252, 219, 203, 117,  35,  11,  32,
         57, 177,  33,  88, 237, 149,  56,  87, 174,  20, 125, 136, 171, 168,  68, 175,
         74, 165,  71, 134, 139,  48,  27, 166,  77, 146, 158, 231,  83, 111, 229, 122,
         60, 211, 133, 230, 220, 105,  92,  41,  55,  46, 245,  40, 244, 102, 143,  54,
         65,  25,  63, 161,   1, 216,  80,  73, 209,  76, 132, 187, 208,  89,  18, 169,
        200, 196, 135, 130, 116, 188, 159,  86, 164, 100, 109, 198, 173, 186,   3,  64,
         52, 217, 226, 250, 124, 123,   5, 202,  38, 147, 118, 126, 255,  82,  85, 212,
        207, 206,  59, 227,  47,  16,  58,  17, 182, 189,  28,  42, 223, 183, 170, 213,
        119, 248, 152,   2,  44, 154, 163,  70, 221, 153, 101, 155, 167,  43, 172,   9,
        129,  22,  39, 253,  19,  98, 108, 110,  79, 113, 224, 232, 178, 185, 112, 104,
        218, 246,  97, 228, 251,  34, 242, 193, 238, 210, 144,  12, 191, 179, 162, 241,
         81,  51, 145, 235, 249,  14, 239, 107,  49, 192, 214,  31, 181, 199, 106, 157,
        184,  84, 204, 176, 115, 121,  50,  45, 127,   4, 150, 254, 138, 236, 205,  93,
        222, 114,  67,  29,  24,  72, 243, 141, 128, 195,  78,  66, 215,  61, 156, 180 ];

    constructor() {
        
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

        return 0.5*this.lerp(w, this.lerp(v, this.lerp(u, this.grad(p[aa], x, y, z),
                                                        this.grad(p[ba], x - 1, y, z)),
                                        this.lerp(u, this.grad(p[ab], x, y - 1, z),
                                                      this.grad(p[bb], x - 1, y - 1, z))),
                            this.lerp(v, this.lerp(u, this.grad(p[aa + 1], x, y, z - 1),
                                                      this.grad(p[ba + 1], x - 1, y, z - 1)),
                                      this.lerp(u, this.grad(p[ab + 1], x, y - 1, z - 1),
                                                    this.grad(p[bb + 1], x - 1, y - 1, z - 1))));
    }
}





function lerp(t, a, b) {
    return a + t * (b - a);
}

// Function to generate 2D Perlin noise and return it as a 1D array
function generatePerlinNoise(width, height, offsetX, offsetY, scale = 1.0) {
    const perlin = new Perlin();
    const noiseArray = [];
    for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
            const value = perlin.noise((x) * scale, (y) * scale, 0.2);
            noiseArray.push(value);
        }
    }
    return noiseArray;
}


/* Implementation of https://en.wikipedia.org/wiki/Perlin_noise */
function randomGradient(xi, yi){
    let random = math.random()*PI*2.0;
    let v = vec2f(cos(random), sin(random));
    return v;
}

function dotGradient(xi, yi, x, y){
    let g = randomGradient(xi, yi);
    let dx = x - f32(xi);
    let dy = y - f32(yi);
    return dx*g.x + g.y * y;
}

function perlin(x, y){
    let x0 = Math.floor(x);
    let x1 = x0 + 1;
    let y0 = Math.floor(y);
    let y1 = y0 + 1;

    let sx = x - f32(x0);
    let sy = y - f32(y0);
    
    var n0 = dotGradient(x0, y0, x, y);
    var n1 = dotGradient(x1, y0, x, y);
    let ix0 = lerp(sx, n0, n1);

    n0 = dotGradient(x0, y1, x, y);
    n1 = dotGradient(x1, y1, x, y);
    let ix1 = lerp(sx, n0, n1);

    return 0.5*lerp(sy, ix0, ix1)+0.5;
}

export { generatePerlinNoise };