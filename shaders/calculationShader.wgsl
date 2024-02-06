@group(0) @binding(0) var<uniform> grid: vec2f;
@group(0) @binding(1) var<storage> pixelStateIn: array<f32>;
@group(0) @binding(2) var<storage, read_write> pixelStateOut: array<f32>;
@group(0) @binding(3) var<uniform> time: f32;
@group(0) @binding(4) var<storage> mapValues: array<f32>;

const PI = 3.14159265359;

@compute
@workgroup_size(16, 16)
fn computeMain(@builtin(global_invocation_id) pixel: vec3<u32>) {
    
    let pixelIndex = pixel.x + pixel.y * u32(grid.x);
    let center: vec3f = vec3f(grid.x/2, grid.y/2, 0.0);
    let height = mapValues[3 * pixelIndex]* gaussian_2D(pixel, center, 30.0, 1.5);
    let value = colorGrad(height, pixel);

    pixelStateOut[3 * pixelIndex + 0] = value.x;//sin(0.01*time + f32(pixelIndex)/(grid.x*grid.y));
    pixelStateOut[3 * pixelIndex + 1] = value.y;//cos(sin(0.01*time + 2*f32(pixelIndex)/(grid.x*grid.y)));
    pixelStateOut[3 * pixelIndex + 2] = value.z;//cos(0.01*time + 1000*rand(pixelIndex)/(grid.x*grid.y));
   
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

fn gaussian_2D(input: vec3<u32>, center: vec3<f32>, stddev: f32, amplitude: f32) -> f32 {
    // 2D Gaussian
    let x = f32(input.x) - center.x;
    let y = f32(input.y) - center.y;
    let d = (x * x + y * y) / (2.0 * stddev * stddev);
    return amplitude*exp(-d); // ( stddev* sqrt(2.0*PI));
}

fn colorGrad(height: f32, pixel: vec3<u32> ) -> vec3<f32> {
    // Gradient color
   

    if(height > 0.3) {
        return vec3<f32>(0.8, 0.8, 0.8);
    }
    if(height > 0.03) {
        return vec3<f32>(0.1, 0.8, 0.1);
    }

    if(height > 0.005) {
        return vec3<f32>(0.8863, 0.7922, 0.42);
    }

    let center: vec3f = vec3f(grid.x/2, grid.y/2, 0.0);
    let scale = gaussian_2D(pixel, center, 220.0, 1.0);

    return vec3f(0.1, 0.1, 0.9) * clamp(scale,0.3,1);
}

