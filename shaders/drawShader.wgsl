struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) textureCoord: vec2f,
};

@group(0) @binding(0) var<uniform> grid: vec2f;
@group(0) @binding(1) var<storage, read_write> pixelState: array<f32>;
// [0]: Time, [1]: Ocean level, [2]: Light position x [3]: Light position y [4]: Light position z [5]: Change Gradient
@group(0) @binding(2) var<storage> settings: array<f32>;
@group(0) @binding(3) var<storage> mapValues: array<f32>;


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
    let show_grad = false;
    let height = pixelState[i];
    let lightPosition = vec3f(settings[2], settings[3], settings[4]);

    let pixelPos = vec3f(f32(pixel.x), f32(pixel.y), f32(height));
    let value = colorGrad(height, pixel);
    let shadow = stepToLight(pixelPos, lightPosition);
    
    // Get the cell state
    var red = value.x * shadow;
    var green = value.y * shadow ;
    var blue = value.z * shadow;

    if(distance(pixelPos.xy, lightPosition.xy) < 10) {
        red = 255.0;
        green = 255.0;
        blue = 255.0;
    }
    if(show_grad)
    {
        return vec4f(height, height, height, 1.0);  
    }
    return vec4f(red, green, blue, 1.0);
}

fn indexMap(x: u32, y: u32) -> u32 {
    return  x + y * u32(grid.x);
}

fn lerp(a: vec3<f32>, b: vec3<f32>, t: f32) -> vec3<f32> {
    return a * (1.0 - t) + b * t;
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
            return 0.5;
        } 
        t += stepSize;
    }
    
    return 1.0;
}

fn rbg2ZeroOne(r: u32, g: u32, b: u32) -> vec3<f32> {
    return vec3f(f32(r) / 255.0, f32(g) / 255.0, f32(b) / 255.0);
}

fn colorGrad(height: f32, pixel: vec2u ) -> vec3<f32> {
    let oceanLevel = settings[1];
    // Gradient color
    if(height > 0.7) {
        let c = clamp(height,0.8,0.95);
        return vec3<f32>(c,c,c);
    }
    
    if(height > 0.4) {
        return vec3<f32>(0.8, 0.8, 0.8);
    }

    if(height > 0.1 && calculateSteepness(pixel.x, pixel.y) > 0.00005) {
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

    //let noise1 = perlin(pixel, vec2f(16.0,16.0));
    //let noise2 = perlin(pixel, vec2f(32.0,32.0));
    //let noise3 = perlin(pixel, vec2f(4.0,4.0));

    //let inHeight = (noise1 + noise2 + 0.5*noise3)/3;

    let diff = f32(clamp(oceanLevel-height, 0.0, 1.0));
  

    let center: vec3f = vec3f(grid.x/2, grid.y/2, 0.0);
    let scale = gaussian_2D(pixel, center, 360.0, 1.0, vec2f(1.0, 1.0));


    let c = mix(vec3<f32>(0.8863, 0.7922, 0.42), rbg2ZeroOne(35,137,218), 255*diff);


    return c * clamp(scale, 0.0, 1.0);
}

fn gaussian_2D(input: vec2u, center: vec3<f32>, stddev: f32, amplitude: f32, scew: vec2f) -> f32 {
    // 2D Gaussian
    let x = f32(input.x) - center.x;
    let y = f32(input.y) - center.y;
    let d = (scew.x * x * x + scew.y * y * y) / (2.0 * stddev * stddev);
    return amplitude*exp(-d); // ( stddev* sqrt(2.0*PI));
}

fn quintic(p: vec2f ) -> vec2f{
    return p * p * p * (p * (p * 6.0 - 15.0) + 10.0);
}

fn cubic(p: vec2f ) -> vec2f{
    return p * p * (3.0 - 2.0 * p);
}

fn randomGradiant(pos: vec2f, scale: vec2f ) -> vec2f{
    let changeWithsettings = true;
    var p = (pos + vec2f(0.1,0.1))*scale;
    let x = dot(p,vec2f(123.4, 234.5));
    let y = dot(p,vec2f(234.5, 345.6));
    var gradient = vec2f(x,y);
    gradient = sin(gradient);
    gradient = gradient * 43758.5453;

    let time = settings[0];

    if(changeWithsettings){
        return sin(gradient + time*0.1);
    }
    return sin(gradient);
}

fn perlin(pos: vec2u, scale: vec2f ) -> f32{
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