@group(0) @binding(0) var<uniform> grid: vec2f;
@group(0) @binding(1) var<storage, read_write> pixelStateOut: array<f32>;
// [0]: Time, [1]: TimeScale, [2]: Change Gradient, [3]: Light position x [4]: Light position y [5]: Light position z  [6]: Ocean level [7]: Normal varaiance  [8]: terrain tine
@group(0) @binding(2) var<storage> settings: array<f32>;
@group(0) @binding(3) var<storage> mapValues: array<f32>;



const PI = 3.14159265359;
 

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
        
        let noise0 = perlin(pixel, vec2f(0.25,0.25));
        let noise1 = perlin(pixel, vec2f(0.5,0.5));
        let noise3 = perlin(pixel, vec2f(4.0,4.0));
        let noise4 = perlin(pixel, vec2f(8.0,8.0));
        let noise2 = perlin(pixel, vec2f(16.0,16.0));

        

        inHeight = 0.4 + 0.3*(noise0 + noise1 + noise2 + noise3 + noise4);
    }
  
    let variance = settings[7];

    let dx = f32(pixel.x) - center.x;
    let dy = f32(pixel.y) - center.y;
    let distance  = sqrt(dx*dx + dy*dy);
    var height = inHeight * gaussian_2D(pixel, center, variance, 2, vec2f(1,0.8));;
    height = pow(height, 6);
  
    pixelStateOut[pixelIndex] = clamp(height,0.000001,8.0);
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


/* Implementation based on this guys idea https://www.youtube.com/watch?v=7fd331zsie0*/

fn quintic(p: vec2f ) -> vec2f{
    return p * p * p * (p * (p * 6.0 - 15.0) + 10.0);
}


fn randomGradiant(pos: vec2f, scale: vec2f ) -> vec2f{
    let changeWithTime = u32(settings[2]);
    var p = (pos + vec2f(0.1,0.1))*scale;
    let x = dot(p,vec2f(123.4, 234.5));
    let y = dot(p,vec2f(234.5, 345.6));
    var gradient = vec2f(x,y);
    gradient = sin(gradient);
    gradient = gradient * 43758.5453;

    let time = settings[8];
    let timeScale = settings[1];
    if(changeWithTime == 1){
        return sin(gradient + time*0.1*timeScale);
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

    
    return p;
}