struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) textureCoord: vec2f,
};

@group(0) @binding(0) var<uniform> grid: vec2f;
@group(0) @binding(1) var<storage, read_write> pixelState: array<f32>;
@group(0) @binding(2) var<uniform> time: f32;
@group(0) @binding(3) var<storage> mapValues: array<f32>;

const OCEAN_LEVEL = 0.005;

@vertex
fn vertexMain(@location(0) position: vec2f) -> VertexOutput {
    var output: VertexOutput;
    output.position = vec4f(position, 0.0, 1.0);
    output.textureCoord = position * 0.5 + 0.5;
    return output;
}


@fragment
fn fragmentMain(input: VertexOutput) -> @location(0) vec4f {
    // Get the pixel index
    let pixel = vec2u(input.textureCoord * grid);
    let i = pixel.x + pixel.y * u32(grid.x);

    let height = pixelState[3*i];
    let light = vec3f(10, 10, 10);
    let pixelPos = vec3f(f32(pixel.x), f32(pixel.y), height);
    let value = colorGrad(height, pixel) ;
    let shadow = stepToLight(pixelPos, light);
    
    

    // Get the cell state
    let red = value.x * shadow + height/5.0 - 0.1;// - cotrastThreshold)*contrast + cotrastThreshold;
    let green = value.y * shadow + height/5.0 - 0.1;// - cotrastThreshold)*contrast + cotrastThreshold;
    let blue = value.z * shadow + height/5.0 - 0.1;// - cotrastThreshold)*contrast + cotrastThreshold;


    return vec4f(red, green, blue, 1.0);
}

fn stepToLight(pos: vec3f, light: vec3f) -> f32 {
    // Step to light
    let dir: vec3f = normalize(pos - light);
    let stepSize = 0.1;
    var p: vec3f = pos.xyz;
    var h_prev = mapValues[3 * (u32(pos.x) + u32(pos.y) * u32(grid.x))];
    for (var i = 0; i < 100; i++) {
        h_prev = p.z;
        p = p + dir * stepSize;
        if (mapValues[3 * (u32(p.x) + u32(p.y) * u32(grid.x))] > h_prev) {
            return 0.7;
        }
    }
    return 1.0;
}

fn colorGrad(height: f32, pixel: vec2u ) -> vec3<f32> {
    // Gradient color
    if(height > 0.3) {
        return vec3<f32>(0.8, 0.8, 0.8);
    }
    if(height > 0.03) {
        return vec3<f32>(0.1, 0.8, 0.1);
    }

    if(height > OCEAN_LEVEL) {
        return vec3<f32>(0.8863, 0.7922, 0.42);
    }

    let center: vec3f = vec3f(grid.x/2, grid.y/2, 0.0);
    let scale = gaussian_2D(pixel, center, 220.0, 1.0, vec2f(1.0, 1.0));

    return vec3f(0.1, 0.1, 0.9) * clamp(scale,0.3,1);
}

fn gaussian_2D(input: vec2u, center: vec3<f32>, stddev: f32, amplitude: f32, scew: vec2f) -> f32 {
    // 2D Gaussian
    let x = f32(input.x) - center.x;
    let y = f32(input.y) - center.y;
    let d = (scew.x * x * x + scew.y * y * y) / (2.0 * stddev * stddev);
    return amplitude*exp(-d); // ( stddev* sqrt(2.0*PI));
}