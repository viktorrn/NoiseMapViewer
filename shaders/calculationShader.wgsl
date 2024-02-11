@group(0) @binding(0) var<uniform> grid: vec2f;
@group(0) @binding(1) var<storage, read_write> pixelStateOut: array<f32>;
@group(0) @binding(2) var<uniform> time: f32;
@group(0) @binding(3) var<storage> mapValues: array<f32>;

const PI = 3.14159265359;
const OCEAN_LEVEL = 0.005;

@compute
@workgroup_size(16, 16)
fn computeMain(@builtin(global_invocation_id) pixel: vec3<u32>) {
    
    let pixelIndex = pixel.x + pixel.y * u32(grid.x);
    
    let center: vec3f = vec3f(grid.x/2, grid.y/2, 0.0);
    let height = clamp( mapValues[pixelIndex] * gaussian_2D(pixel, center, 40.0, 1.2, vec2f(1,1))  + gaussian_2D(pixel, center, 25.0, 1.5, vec2f(1,1)) , OCEAN_LEVEL, 8.0);
    
    pixelStateOut[3 * pixelIndex + 0] = height; //sin(0.01*time + f32(pixelIndex)/(grid.x*grid.y));
    pixelStateOut[3 * pixelIndex + 1] = height; //cos(sin(0.01*time + 2*f32(pixelIndex)/(grid.x*grid.y)));
    pixelStateOut[3 * pixelIndex + 2] = height; //cos(0.01*time + 1000*rand(pixelIndex)/(grid.x*grid.y));   
}

fn rand(local_seed: u32) -> f32 {
    var x = u32(time) * local_seed;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    return f32(x & 0xFFFFFF) / 0xFFFFFF;
}

fn lerp(t: f32, a: f32, b: f32) -> f32 {
    // Linear interpolation
    return a + t * (b - a);
}

fn gaussian_2D(input: vec3<u32>, center: vec3<f32>, stddev: f32, amplitude: f32, scew: vec2f) -> f32 {
    // 2D Gaussian
    let x = f32(input.x) - center.x;
    let y = f32(input.y) - center.y;
    let d = (scew.x * x * x + scew.y * y * y) / (2.0 * stddev * stddev);
    return amplitude*exp(-d); // ( stddev* sqrt(2.0*PI));
}
