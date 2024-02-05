@group(0) @binding(0) var<uniform> grid: vec2f;
@group(0) @binding(1) var<storage> pixelStateIn: array<f32>;
@group(0) @binding(2) var<storage, read_write> pixelStateOut: array<f32>;
@group(0) @binding(3) var<uniform> time: f32;


@compute
@workgroup_size(16, 16)
fn computeMain(@builtin(global_invocation_id) pixel: vec3<u32>) {
    
    let pixelIndex = pixel.x + pixel.y * u32(grid.x);

    pixelStateOut[3 * pixelIndex + 0] = sin(0.01*time + f32(pixelIndex)/(grid.x*grid.y));
    pixelStateOut[3 * pixelIndex + 1] = cos(sin(0.01*time + 2*f32(pixelIndex)/(grid.x*grid.y)));
    pixelStateOut[3 * pixelIndex + 2] = cos(0.01*time + f32(pixelIndex)/(grid.x*grid.y));
   
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