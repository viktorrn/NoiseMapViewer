struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) textureCoord: vec2f,
};

@group(0) @binding(0) var<uniform> grid: vec2f;
@group(0) @binding(1) var<storage, read_write> pixelState: array<f32>;
// [0]: Time, [1]: TimeScale, [2]: Change Gradient, [3]: Light position x [4]: Light position y [5]: Light position z  [6]: Ocean level [7]: Normal varaiance 
@group(0) @binding(2) var<storage> settings: array<f32>;
@group(0) @binding(3) var<storage> mapValues: array<f32>;

const PI = 3.14159265359;

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

    let lightPosition = vec3f(settings[3], settings[4], settings[5]);
    let pixelPos = vec3f(f32(pixel.x), f32(pixel.y), f32(height));
    let value = colorGrad(height, pixel);
    
    
    // Get the cell state
    var red = value.x;;
    var green = value.y;
    var blue = value.z;

    if(distance(pixelPos.xy, lightPosition.xy) < clamp(2*settings[5],4,30)) {
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

fn smoothstep(start:f32, end:f32, t: f32) -> f32 {
    let x = clamp((t - start) / (end - start), 0.0, 1.0);
    return x * x * (3.0 - 2.0 * x);
}

fn calculateSteepness(x: u32, y: u32) -> f32 {
    
    let normal = calculateNormal(vec2u(x, y));
    let groundVector = normalize(vec3f(normal.x, normal.y, 0.0));

    let angle = dot(groundVector, normal)/(length(groundVector)*length(normal));

    let clamped = clamp(angle, 0.0, PI/2.0);
    return clamped;
}

fn stepToLight(pos: vec3f) -> f32 {
    let light = vec3f(settings[3], settings[4], settings[5]);
    // Step to light
    let stepSize = 0.005;
    var p: vec3f = pos.xyz;
    var h_prev = pixelState[indexMap(u32(p.x), u32(p.y))];


    let start = pos.xyz;

    for (var t = 0.0; t < 1; ) {
        p = lerp(light,start,t);
        
        if ( p.z <= pixelState[indexMap(u32(floor(p.x+0.5)), u32(floor(p.y+0.5)))]) {
            return 0.7;
        } 
        t += stepSize;
    }
    
    return 1.0;
}

fn rbg2ZeroOne(r: u32, g: u32, b: u32) -> vec3<f32> {
    return vec3f(f32(r) / 255.0, f32(g) / 255.0, f32(b) / 255.0);
}



fn colorGrad(height: f32, pixel: vec2u ) -> vec3<f32> {
    // elements
    let waterColor= rbg2ZeroOne(68,187,255);
    let sandColor = rbg2ZeroOne(240,237,164);
    let grassColor = rbg2ZeroOne(128, 177, 69);
    let forestColor = rbg2ZeroOne(68, 119, 65);
    let mountainColor = rbg2ZeroOne(21,114,65);
    let rockColor = rbg2ZeroOne(200, 200, 200);


    // For light
    let light = vec3f(settings[3], settings[4], settings[5]);
    let pos = vec3f(f32(pixel.x), f32(pixel.y), height);
    
    let normal = calculateNormal(vec2u(u32(pixel.x), u32(pixel.y)));
    let lightVector = normalize(pos-light);

    let time = settings[0];
    let dotProduct = dot(lightVector, normal);

    // Gradient colors
   
    var steepNess = calculateSteepness(pixel.x, pixel.y);

    let noise1 = perlin(pixel, vec2f(16.0,16.0));
    let noise2 = perlin(pixel, vec2f(32.0,32.0));
    let noise3 = perlin(pixel, vec2f(4.0,4.0));
    let inHeight = (noise1 + noise2 + 0.5*noise3)/3;

    var oceanLevel = settings[6]+ 0.005 * inHeight;
    
    
    if(settings[6] == 0)
    {
        oceanLevel = settings[6];
    } 

    // Ocean
    if(height <= oceanLevel)
    {
        let shadow = stepToLight(vec3f(f32(pixel.x), f32(pixel.y), height));
        var c = waterColor;
        
        let diff = f32(clamp(oceanLevel-height, 0, 1));
        let center: vec3f = vec3f(grid.x/2, grid.y/2, 0.0);
        
        var wave = (1 - smoothstep(0.0,0.005,diff));
        wave *= (sin(cos(time*0.05)*2+1000*diff))*0.75;

        
       // c = mix(sandColor, waterColor, clamp(300*diff,0,1));
        let borderShadowScale = 1.2*gaussian_2D(pixel, center, 360.0, 1.0, vec2f(1.0, 1.0));
        c = lerp(c, sandColor, clamp(exp(-diff*500),0.0,0.5));
        c+= wave/8;
        return c * clamp(borderShadowScale, 0.0, 1.0) * shadow;
    }
    
    let shade = stepToLight(vec3f(f32(pixel.x), f32(pixel.y), height));
    if(height < 0.7) {
        if(height <= 0.015){
            return sandColor * (0.8 + 0.2*dotProduct)* shade;
        }

        if(steepNess > 2*PI/7.0 ) {
            return rockColor * (0.8 + 0.2*dotProduct)* shade;
        }

        if(steepNess > PI/7.0 ) {
            return forestColor * (0.7 + 0.4*dotProduct)* shade;
        }

        if(height <0.3)
        {

            return grassColor* (0.9 + 0.1*dotProduct)* shade;
        }
        return forestColor* (0.7 + 0.4*dotProduct)* shade; 
    }
    
    return mix(rockColor,vec3f(1.0,1.0,1.0),clamp(0.7-height,0,1)) * (0.8 + 0.2*dotProduct)* shade;
}

fn calculateNormal(pixel: vec2u) -> vec3f {
    let v1 = vec3f(1,0, 200 * (pixelState[indexMap(pixel.x, pixel.y)] - pixelState[indexMap(pixel.x+1,pixel.y)]));
    let v2 = vec3f(0,1, 200 * (pixelState[indexMap(pixel.x, pixel.y)] - pixelState[indexMap(pixel.x,pixel.y+1)]) );

    return normalize(cross(normalize(v1),normalize(v2)));
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
  
    var p = (pos + vec2f(0.1,0.1))*scale;
    let x = dot(p,vec2f(123.4, 234.5));
    let y = dot(p,vec2f(234.5, 345.6));
    var gradient = vec2f(x,y);
    gradient = sin(gradient);
    gradient = gradient * 43758.5453;

    let time = settings[0];
    let timeScale = settings[1];

    
    return sin(gradient + time*0.2*timeScale);
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