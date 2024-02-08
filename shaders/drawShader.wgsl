struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) textureCoord: vec2f,
};

@group(0) @binding(0) var<uniform> grid: vec2f;
@group(0) @binding(1) var<storage, read_write> pixelState: array<f32>;

@vertex
fn vertexMain(@location(0) position: vec2f) -> VertexOutput {
    var output: VertexOutput;
    output.position = vec4f(position, 0.0, 1.0);
    output.textureCoord = position * 0.5 + 0.5;
    return output;
}

const contrast: f32 = 1.6;
const cotrastThreshold: f32 = 0.75;

@fragment
fn fragmentMain(input: VertexOutput) -> @location(0) vec4f {
    // Get the pixel index
    let pixel = vec2u(input.textureCoord * grid);
    let i = pixel.x + pixel.y * u32(grid.x);

    // Get the cell state
    let red = pixelState[3 * i  + 0];// - cotrastThreshold)*contrast + cotrastThreshold;
    let green = pixelState[3 * i  + 1];// - cotrastThreshold)*contrast + cotrastThreshold;
    let blue = pixelState[3 * i  + 2];// - cotrastThreshold)*contrast + cotrastThreshold;



    return vec4f(red, green, blue, 1.0);
}