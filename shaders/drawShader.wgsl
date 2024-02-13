struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) textureCoord: vec2f,
};

@group(0) @binding(0) var<uniform> grid: vec2f;
@group(0) @binding(1) var<storage, read_write> pixelState: array<f32>;
@group(0) @binding(2) var<uniform> time: f32;
@group(0) @binding(3) var<storage> mapValues: array<f32>;
@group(0) @binding(4) var<uniform> oceanLevel: f32;
@group(0) @binding(5) var<uniform> lightPosition: vec3f;

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

    let height = pixelState[i];

    let pixelPos = vec3f(f32(pixel.x), f32(pixel.y), f32(height));
    let value = colorGrad(height, pixel);
    let shadow = stepToLight(pixelPos, lightPosition);
    
    // Get the cell state
    var red = value.x * shadow;
    var green = value.y * shadow ;
    var blue = value.z * shadow;

    if(distance(pixelPos.xy, lightPosition.xy) < 20) {
        red = 255.0;
        green = 255.0;
        blue = 255.0;
    }

    return vec4f(red, green, blue, 1.0);
}

fn indexMap(x: u32, y: u32) -> u32 {
    return  x + y * u32(grid.x);
}

fn calculateSteepness(x: u32, y: u32) -> f32 {
    
    let h = f32(pixelState[indexMap(x, y)]);
    let p0 = f32(pixelState[indexMap(x+1, y)]);
    let p1 = f32(pixelState[indexMap(x, y+1)]);
    let p2 = f32(pixelState[indexMap(x-1, y)]);
    let p3 = f32(pixelState[indexMap(x, y-1)]);

    let dx1 = h-p0;
    let dx2 = h-p2;
    let dy1 = h-p1;
    let dy2 = h-p3;
    let steepness = (dx1+dx2+dy1+dy2)/4;
    
    return steepness;
}

fn stepToLight(pos: vec3f, light: vec3f) -> f32 {
    
    // Step to light
    let dir: vec3f = light - pos;
    let stepSize = 0.005;
    var p: vec3f = pos.xyz;
    let start = pos.xyz;
    var h_prev = pixelState[indexMap(u32(p.x), u32(p.y))];
    
    for (var t = 0.0; t < 1; ) {
        p = start + dir * t;
        
        if(pixelState[indexMap(u32(p.x), u32(p.y))] > 8.0)
        {
            return 1.0;
        }

        if ( p.z < pixelState[indexMap(u32(p.x), u32(p.y))]) {
            return 0.2;
        } 
        t += stepSize;
    }
    
    return 1.0;
}

fn rbg2ZeroOne(r: u32, g: u32, b: u32) -> vec3<f32> {
    return vec3f(f32(r) / 255.0, f32(g) / 255.0, f32(b) / 255.0);
}

fn colorGrad(height: f32, pixel: vec2u ) -> vec3<f32> {
    // Gradient color
    if(height > 2) {
        return vec3<f32>(1.0, 1.0, 1.0);
    }

    if(height > 0.3 && calculateSteepness(pixel.x, pixel.y) > 0.001) {
        return vec3<f32>(0.8, 0.8, 0.8);
    }

    if(height > 0.03) {
        return rbg2ZeroOne(21,114,65);
    }

    if(height > 0.01) {
        return rbg2ZeroOne(117,184,85);
    }

    if(height > oceanLevel) {
        return vec3<f32>(0.8863, 0.7922, 0.42);
    }

    let diff = abs(height - oceanLevel);
  

    let center: vec3f = vec3f(grid.x/2, grid.y/2, 0.0);
    let scale = gaussian_2D(pixel, center, 320.0, 1.0, vec2f(1.0, 1.0));

    return rbg2ZeroOne(35,137,218) * clamp(scale, 0.0, 1.0) + rbg2ZeroOne(255,255,255)*exp(-pow(diff-1.2,2)); //rbg2ZeroOne(21,114,65) * exp(-1.0*pow(diff-1.2,2));
}

fn gaussian_2D(input: vec2u, center: vec3<f32>, stddev: f32, amplitude: f32, scew: vec2f) -> f32 {
    // 2D Gaussian
    let x = f32(input.x) - center.x;
    let y = f32(input.y) - center.y;
    let d = (scew.x * x * x + scew.y * y * y) / (2.0 * stddev * stddev);
    return amplitude*exp(-d); // ( stddev* sqrt(2.0*PI));
}