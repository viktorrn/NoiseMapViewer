@group(0) @binding(0) var<uniform> grid: vec2f;
@group(0) @binding(1) var<storage, read_write> pixelStateOut: array<f32>;
@group(0) @binding(2) var<uniform> time: f32;
@group(0) @binding(3) var<storage> mapValues: array<f32>;
@group(0) @binding(4) var<uniform> oceanLevel: f32;


const PI = 3.14159265359;

/*const permutation: array<u32> = {
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
    222, 114,  67,  29,  24,  72, 243, 141, 128, 195,  78,  66, 215,  61, 156, 180
}*/
    



@compute
@workgroup_size(16, 16)
fn computeMain(@builtin(global_invocation_id) pixel: vec3<u32>) {
    
    let pixelIndex = pixel.x + pixel.y * u32(grid.x);
    let center: vec3f = vec3f(grid.x/2, grid.y/2, 0.0);

    let externalNoiseMap = false;
    
    var inHeight = 0.5;
    if(externalNoiseMap)
    {
        inHeight = mapValues[pixelIndex];
    } else {

        let noise1 = perlin(pixel, vec2f(16.0,16.0));
        let noise2 = perlin(pixel, vec2f(32.0,32.0));
        let noise3 = perlin(pixel, vec2f(4.0,4.0));
        let noise4 = perlin(pixel, vec2f(8.0,8.0));

        inHeight = (noise1 + noise2 + noise3 + noise4)/4;
    }
  
    
    let dx = f32(pixel.x) - center.x;
    let dy = f32(pixel.y) - center.y;
    let distance  = sqrt(dx*dx + dy*dy);
    var height = inHeight * gaussian_2D(pixel, center, 160.0, 2, vec2f(1,0.9));;
    height = pow(height, 4);
  
    pixelStateOut[pixelIndex] = height;
}

fn gaussian_2D(input: vec3<u32>, center: vec3<f32>, stddev: f32, amplitude: f32, scew: vec2f) -> f32 {
    // 2D Gaussian
    let x = f32(input.x) - center.x;
    let y = f32(input.y) - center.y;
    let d = (scew.x * x * x + scew.y * y * y) / (2.0 * stddev * stddev);
    return amplitude*exp(-d);
}

fn rand(local_seed: u32) -> f32 {
    var x = local_seed;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    return f32(x & 0xFFFFFF) / 0xFFFFFF;
}

fn lerp(t: f32, a: f32, b: f32) -> f32 {
    // Linear interpolation
    return a + t * (b - a);
}

/* Implementation based on this guys idea https://www.youtube.com/watch?v=7fd331zsie0*/

fn quintic(p: vec2f ) -> vec2f{
    return p * p * p * (p * (p * 6.0 - 15.0) + 10.0);
}

fn cubic(p: vec2f ) -> vec2f{
    return p * p * (3.0 - 2.0 * p);
}

fn randomGradiant(pos: vec2f, scale: vec2f ) -> vec2f{
    let changeWithTime = false;
    var p = (pos + vec2f(0.1,0.1))*scale;
    let x = dot(p,vec2f(123.4, 234.5));
    let y = dot(p,vec2f(234.5, 345.6));
    var gradient = vec2f(x,y);
    gradient = sin(gradient);
    gradient = gradient * 43758.5453;

    if(changeWithTime){
        return sin(gradient + time*0.1);
    }
    return sin(gradient);
}

fn perlin(pos: vec3u, scale: vec2f ) -> f32{
    // Get corners
    
    var uv = vec2f(f32(pos.x), f32(pos.y)) / grid.x;
    uv = uv * scale;
    let gridId = floor(uv);
    let gridUv = fract(uv);

    let bl = gridId + vec2f(0.0, 0.0);
    let br = gridId + vec2f(1.0, 0.0);
    let tl = gridId + vec2f(0.0, 1.0);
    let tr = gridId + vec2f(1.0, 1.0);

    // Get gradients for each corner
    let gradBl = randomGradiant(bl, scale);
    let gradBr = randomGradiant(br, scale);
    let gradTl = randomGradiant(tl, scale);
    let gradTr = randomGradiant(tr, scale);

    // Distance from current pixel to each corner
    let distBl = gridUv - vec2f(0.0, 0.0);
    let distBr = gridUv - vec2f(1.0, 0.0);
    let distTl = gridUv - vec2f(0.0, 1.0);
    let distTr = gridUv - vec2f(1.0, 1.0);

    // Dot product of distance and gradient
    let dotBl = dot(distBl, gradBl);
    let dotBr = dot(distBr, gradBr);
    let dotTl = dot(distTl, gradTl);
    let dotTr = dot(distTr, gradTr);

    let step = quintic(gridUv);

    // Interpolate between the gradients
    let b = mix(dotBl, dotBr, step.x);
    let t = mix(dotTl, dotTr, step.x);
    let p = mix(b, t, step.y);

    // 

    
    return 0.3+p*0.7;
}